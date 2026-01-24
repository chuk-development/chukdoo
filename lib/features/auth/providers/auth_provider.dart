import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/constants/app_constants.dart';
import '../../../shared/services/encryption_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../subscription/services/revenuecat_service.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  needsPassword,
  needsEmailConfirmation,
  localMode, // User is using app in local-only mode (not logged in)
}

class AppAuthState {
  final AuthStatus status;
  final supabase.User? user;
  final String? error;
  final bool isLoading;
  // For email confirmation flow - store credentials temporarily
  final String? pendingEmail;
  final String? pendingPassword;
  // For onboarding flow
  final bool hasCompletedOnboarding;

  const AppAuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.isLoading = false,
    this.pendingEmail,
    this.pendingPassword,
    this.hasCompletedOnboarding = true, // Default true for existing users
  });

  AppAuthState copyWith({
    AuthStatus? status,
    supabase.User? user,
    String? error,
    bool? isLoading,
    String? pendingEmail,
    String? pendingPassword,
    bool? hasCompletedOnboarding,
    bool clearError = false,
    bool clearPending = false,
  }) {
    return AppAuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
      pendingEmail: clearPending ? null : (pendingEmail ?? this.pendingEmail),
      pendingPassword: clearPending ? null : (pendingPassword ?? this.pendingPassword),
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    );
  }
}

/// Key for storing last authenticated user ID in Hive
const _lastUserIdKey = 'last_authenticated_user_id';
/// Key for storing onboarding completion status
const _onboardingCompletedKey = 'onboarding_completed';
/// Key for storing local mode user ID (generated for offline users)
const _localUserIdKey = 'local_user_id';

class AuthNotifier extends StateNotifier<AppAuthState> {
  AuthNotifier() : super(const AppAuthState()) {
    _init();
  }

  StreamSubscription<supabase.AuthState>? _authSubscription;

  /// INSTANT startup - local only, no network
  /// New users go directly to local mode (offline-first default)
  Future<void> _init() async {
    try {
      final metaBox = Hive.box<Map>(AppConstants.hiveMetaBox);

      // Check if onboarding has been completed
      final onboardingCompleted = metaBox.get(_onboardingCompletedKey)?['completed'] as bool? ?? false;

      // Check for local mode user (offline-first users)
      final localUserId = metaBox.get(_localUserIdKey)?['userId'] as String?;

      // Check for authenticated user (cloud users)
      final lastUserId = metaBox.get(_lastUserIdKey)?['userId'] as String?;

      // STEP 1: First-time user - show onboarding then go to local mode
      if (!onboardingCompleted && localUserId == null && lastUserId == null) {
        debugPrint('AuthProvider: First-time user - showing onboarding');
        state = const AppAuthState(
          status: AuthStatus.localMode,
          hasCompletedOnboarding: false,
        );
        return;
      }

      // STEP 2: Returning local mode user - go directly to local mode
      if (localUserId != null && lastUserId == null) {
        debugPrint('AuthProvider: Returning local mode user');
        state = const AppAuthState(status: AuthStatus.localMode);
        return;
      }

      // STEP 3: Try to authenticate instantly from cloud cache
      if (lastUserId != null) {
        // Try to load encryption key locally (INSTANT - no network)
        final hasKey = await EncryptionService.tryLoadKeyLocal(lastUserId);
        if (hasKey) {
          // SUCCESS: We have cached credentials, open app immediately
          debugPrint('AuthProvider: Instant auth from local cache');
          state = const AppAuthState(status: AuthStatus.authenticated);

          // Background sync (non-blocking)
          _startBackgroundSync(lastUserId);
          return;
        }
      }

      // STEP 4: No local cache, need to check Supabase
      // Wait briefly for Supabase to initialize (it might already be ready)
      await _waitForSupabaseOrTimeout();

      if (!SupabaseService.isAvailable) {
        // Supabase not ready
        if (lastUserId != null) {
          // Had a cloud user but no key - needs password
          state = const AppAuthState(status: AuthStatus.needsPassword);
        } else if (localUserId != null) {
          // Local user returning
          state = const AppAuthState(status: AuthStatus.localMode);
        } else {
          // First time or cleared state - go to local mode
          state = AppAuthState(
            status: AuthStatus.localMode,
            hasCompletedOnboarding: onboardingCompleted,
          );
        }
        return;
      }

      // Check Supabase session
      final session = SupabaseService.client.auth.currentSession;
      if (session != null) {
        // Save userId for next instant startup
        await _saveLastUserId(session.user.id);

        // Try to load key (might need password)
        final hasKey = await EncryptionService.tryLoadKeyLocal(session.user.id);
        if (hasKey) {
          state = AppAuthState(
            status: AuthStatus.authenticated,
            user: session.user,
          );
          _startBackgroundSync(session.user.id);
        } else {
          state = AppAuthState(
            status: AuthStatus.needsPassword,
            user: session.user,
          );
        }
      } else if (localUserId != null) {
        // No cloud session but has local user
        state = const AppAuthState(status: AuthStatus.localMode);
      } else {
        // No session and no local user - go to local mode (offline-first default)
        state = AppAuthState(
          status: AuthStatus.localMode,
          hasCompletedOnboarding: onboardingCompleted,
        );
      }

      // Set up auth listener for future changes
      _setupAuthListener();
    } catch (e) {
      debugPrint('AuthProvider: Init error: $e');
      // On error, default to local mode instead of login
      state = const AppAuthState(status: AuthStatus.localMode);
    }
  }

  /// Wait for Supabase to initialize, but don't block forever
  Future<void> _waitForSupabaseOrTimeout() async {
    const maxWait = Duration(milliseconds: 500);
    const checkInterval = Duration(milliseconds: 50);
    var elapsed = Duration.zero;

    while (!SupabaseService.isAvailable && elapsed < maxWait) {
      await Future.delayed(checkInterval);
      elapsed += checkInterval;
    }
  }

  /// Save user ID for instant startup next time
  Future<void> _saveLastUserId(String userId) async {
    final metaBox = Hive.box<Map>(AppConstants.hiveMetaBox);
    await metaBox.put(_lastUserIdKey, {'userId': userId});
  }

  /// Clear saved user ID on logout
  Future<void> _clearLastUserId() async {
    final metaBox = Hive.box<Map>(AppConstants.hiveMetaBox);
    await metaBox.delete(_lastUserIdKey);
  }

  /// Start background sync - doesn't block UI
  void _startBackgroundSync(String userId) {
    // Fire and forget - sync happens in background
    Future(() async {
      try {
        // Wait for Supabase if not ready yet
        await _waitForSupabaseOrTimeout();

        if (SupabaseService.isAvailable) {
          // Sync encryption metadata
          await EncryptionService.syncKeyMetadata();

          // Login to RevenueCat
          RevenueCatService.login(userId);

          debugPrint('AuthProvider: Background sync completed');
        }
      } catch (e) {
        debugPrint('AuthProvider: Background sync failed: $e');
      }
    });
  }

  /// Set up listener for auth state changes (login/logout from other sources)
  void _setupAuthListener() {
    final authStream = SupabaseService.authStateChanges;
    if (authStream != null) {
      _authSubscription = authStream.listen((data) async {
        final session = data.session;
        if (session != null) {
          await _saveLastUserId(session.user.id);
          final hasKey = await EncryptionService.tryLoadKeyLocal(session.user.id);
          if (hasKey) {
            RevenueCatService.login(session.user.id);
            state = AppAuthState(
              status: AuthStatus.authenticated,
              user: session.user,
            );
          } else {
            state = AppAuthState(
              status: AuthStatus.needsPassword,
              user: session.user,
            );
          }
        } else {
          await _clearLastUserId();
          state = const AppAuthState(status: AuthStatus.unauthenticated);
        }
      });
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await SupabaseService.auth.signUp(
        email: email,
        password: password,
        data: displayName != null ? {'display_name': displayName} : null,
      );

      if (response.user != null) {
        // Check if email confirmation is needed
        // If emailConfirmedAt is null, user needs to confirm email
        if (response.user!.emailConfirmedAt == null) {
          // Store credentials for easy login after confirmation
          state = AppAuthState(
            status: AuthStatus.needsEmailConfirmation,
            user: response.user,
            pendingEmail: email,
            pendingPassword: password,
          );
        } else {
          // Email already confirmed (e.g., confirmation disabled in Supabase)
          await EncryptionService.initializeForPassword(password);
          // Save userId for instant startup next time
          await _saveLastUserId(response.user!.id);
          // Login to RevenueCat (non-blocking)
          RevenueCatService.login(response.user!.id);
          state = AppAuthState(
            status: AuthStatus.authenticated,
            user: response.user,
          );
        }
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Sign up failed. Please try again.',
        );
      }
    } on supabase.AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await SupabaseService.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Initialize encryption with password
        await EncryptionService.initializeForPassword(password);
        // Save userId for instant startup next time
        await _saveLastUserId(response.user!.id);
        // Login to RevenueCat to link purchases with user
        RevenueCatService.login(response.user!.id);
        state = AppAuthState(
          status: AuthStatus.authenticated,
          user: response.user,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Sign in failed. Please check your credentials.',
        );
      }
    } on supabase.AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Called when user is logged in but needs to enter password for encryption
  Future<void> unlockWithPassword(String password) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await EncryptionService.initializeForPassword(password);
      final user = SupabaseService.currentUser;
      // Save userId for instant startup next time
      if (user != null) {
        await _saveLastUserId(user.id);
        // Login to RevenueCat (non-blocking)
        RevenueCatService.login(user.id);
      }
      state = AppAuthState(
        status: AuthStatus.authenticated,
        user: user,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Incorrect password. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await EncryptionService.clearKey();
      await _clearLastUserId();
      // Logout from RevenueCat
      await RevenueCatService.logout();
      if (SupabaseService.isAvailable) {
        await SupabaseService.auth.signOut();
      }
      state = const AppAuthState(status: AuthStatus.unauthenticated);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Go to login page with pending credentials pre-filled
  void goToLoginWithCredentials() {
    state = AppAuthState(
      status: AuthStatus.unauthenticated,
      pendingEmail: state.pendingEmail,
      pendingPassword: state.pendingPassword,
    );
  }

  /// Clear pending credentials
  void clearPendingCredentials() {
    state = state.copyWith(clearPending: true);
  }

  Future<void> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await SupabaseService.auth.resetPasswordForEmail(email);
      state = state.copyWith(isLoading: false);
    } on supabase.AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Complete onboarding and start using app in local mode
  Future<void> completeOnboarding() async {
    final metaBox = Hive.box<Map>(AppConstants.hiveMetaBox);

    // Mark onboarding as completed
    await metaBox.put(_onboardingCompletedKey, {'completed': true});

    // Create a local user ID for local-only storage
    final localUserId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    await metaBox.put(_localUserIdKey, {'userId': localUserId});

    state = const AppAuthState(
      status: AuthStatus.localMode,
      hasCompletedOnboarding: true,
    );

    debugPrint('AuthProvider: Onboarding completed, local user created: $localUserId');
  }

  /// Skip onboarding and go directly to local mode
  Future<void> skipOnboarding() async {
    await completeOnboarding();
  }

  /// Get local user ID (for local storage operations)
  String? getLocalUserId() {
    final metaBox = Hive.box<Map>(AppConstants.hiveMetaBox);
    return metaBox.get(_localUserIdKey)?['userId'] as String?;
  }

  /// Go to login page to connect cloud account
  void goToLogin() {
    state = const AppAuthState(status: AuthStatus.unauthenticated);
  }

  /// Return to local mode (from login page without logging in)
  void returnToLocalMode() {
    state = const AppAuthState(status: AuthStatus.localMode);
  }

  /// Check if user is in local mode (not connected to cloud)
  bool get isInLocalMode => state.status == AuthStatus.localMode;

  /// Check if user has cloud account connected
  bool get hasCloudAccount => state.user != null || state.status == AuthStatus.authenticated;

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AppAuthState>((ref) {
  return AuthNotifier();
});
