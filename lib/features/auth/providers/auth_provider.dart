import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/constants/app_constants.dart';
import '../../../shared/services/encryption_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../donations/services/revenuecat_service.dart';
import '../services/backup_code_service.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  needsPassword,
  needsEmailConfirmation,
  needsBackupCodesConfirmation, // User must save backup codes before proceeding
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
  // For backup codes flow - codes to show after signup
  final List<String>? pendingBackupCodes;
  // For onboarding flow
  final bool hasCompletedOnboarding;

  const AppAuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.isLoading = false,
    this.pendingEmail,
    this.pendingPassword,
    this.pendingBackupCodes,
    this.hasCompletedOnboarding = true, // Default true for existing users
  });

  AppAuthState copyWith({
    AuthStatus? status,
    supabase.User? user,
    String? error,
    bool? isLoading,
    String? pendingEmail,
    String? pendingPassword,
    List<String>? pendingBackupCodes,
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
      pendingBackupCodes: clearPending ? null : (pendingBackupCodes ?? this.pendingBackupCodes),
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
    // Listen before anything else: the stream is alive even while Supabase is
    // still initializing, so a late session restore is never missed.
    _setupAuthListener();
    _init();
  }

  StreamSubscription<supabase.AuthState>? _authSubscription;

  /// True while an interactive auth flow owns the state (sign in, sign up,
  /// unlock, recovery). The auth listener stays out of the way meanwhile.
  bool _authFlowInProgress = false;

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

          // Background sync (non-blocking). It also adopts the Supabase
          // session once the SDK has restored it, so the UI and the sync layer
          // report the same user instead of drifting apart.
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

      // Check Supabase session. An expired access token still counts as a
      // session - it only needs a refresh, which happens in the background.
      final session = SupabaseService.currentSession;
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
    } catch (e) {
      debugPrint('AuthProvider: Init error: $e');
      // On error, default to local mode instead of login
      state = const AppAuthState(status: AuthStatus.localMode);
    }
  }

  /// Wait for Supabase to initialize, but don't block forever.
  /// Only ever awaited off the startup path or from background work.
  Future<void> _waitForSupabaseOrTimeout([
    Duration maxWait = const Duration(milliseconds: 500),
  ]) async {
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
        // Supabase initializes in parallel with the app start and may retry
        // after a slow first attempt, so give it real time here. Nothing on
        // screen waits for this.
        await _waitForSupabaseOrTimeout(const Duration(seconds: 30));

        if (SupabaseService.isAvailable) {
          // Adopt the restored session and refresh the token if it is stale,
          // so the UI user matches the user the sync layer uses.
          await SupabaseService.ensureFreshSession();
          _adoptSupabaseUser();

          if (SupabaseService.currentSession == null &&
              state.status == AuthStatus.authenticated &&
              !_authFlowInProgress) {
            // The SDK is up but holds no session: the refresh token was
            // revoked or the stored session is gone. Sync could never work in
            // this state, so ask for a sign-in instead of showing a signed-in
            // UI that silently fails. Session presence is a local fact, so
            // being offline cannot land us here.
            debugPrint('AuthProvider: Cloud session gone - sign-in required');
            state = const AppAuthState(
              status: AuthStatus.unauthenticated,
              error: 'Your session expired. Please sign in again.',
            );
            return;
          }

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

  /// Attach the Supabase user to an authenticated state that was opened from
  /// the local cache. Never changes the status - an unreachable backend must
  /// not flip the UI to "signed out".
  void _adoptSupabaseUser() {
    if (state.status != AuthStatus.authenticated) return;
    if (state.user != null) return;

    final user = SupabaseService.currentUser;
    if (user == null) return;

    debugPrint('AuthProvider: Adopted Supabase user ${user.id}');
    state = state.copyWith(user: user);
  }

  /// Refresh the access token when the app comes back to the foreground.
  /// Safe to call often: it is a no-op while the token is still valid.
  Future<void> onAppResumed() async {
    if (!SupabaseService.isAvailable) return;
    await SupabaseService.ensureFreshSession();
    _adoptSupabaseUser();
  }

  /// Set up listener for auth state changes (login/logout from other sources).
  ///
  /// Only an explicit sign-out signs the user out here. A missing session in
  /// any other event means "not restored yet" or "offline", never "signed out":
  /// wiping the local state there is what made the UI and the sync layer
  /// disagree.
  void _setupAuthListener() {
    _authSubscription?.cancel();
    _authSubscription = SupabaseService.authStateChanges.listen((data) async {
      final event = data.event;
      final session = data.session;

      if (session != null) {
        await _saveLastUserId(session.user.id);

        // An interactive flow (sign in, sign up, unlock, recovery) owns the
        // state until it finishes. Otherwise the SIGNED_IN event would bounce
        // the user through /unlock before the key is set up.
        if (_authFlowInProgress) return;

        // Token refreshes must not restart the unlock flow or pull the user
        // out of a screen they still have to finish - just keep the user
        // object current.
        switch (state.status) {
          case AuthStatus.authenticated:
          case AuthStatus.needsEmailConfirmation:
          case AuthStatus.needsBackupCodesConfirmation:
            state = state.copyWith(user: session.user);
            return;
          case AuthStatus.localMode:
            // Local mode is a deliberate choice. "Connect to cloud" is the way
            // out of it, not a background token refresh.
            return;
          case AuthStatus.initial:
          case AuthStatus.unauthenticated:
          case AuthStatus.needsPassword:
            break;
        }

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
        return;
      }

      // No session in the event.
      final signedOut = event == supabase.AuthChangeEvent.signedOut;
      if (!signedOut) {
        debugPrint('AuthProvider: ${event.name} without session - keeping state');
        return;
      }

      // Local-mode users have no cloud session to lose.
      if (state.status == AuthStatus.localMode) return;

      // Real sign-out: either the user pressed it or the refresh token was
      // revoked server-side.
      debugPrint('AuthProvider: Signed out by Supabase');
      await _clearLastUserId();
      state = const AppAuthState(status: AuthStatus.unauthenticated);
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    _authFlowInProgress = true;

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
          // Email already confirmed - initialize with Master Key architecture
          final encryptionResult = await EncryptionService.initializeForNewUser(
            userId: response.user!.id,
            password: password,
          );

          if (encryptionResult.success) {
            // Save userId for instant startup next time
            await _saveLastUserId(response.user!.id);
            // Login to RevenueCat (non-blocking)
            RevenueCatService.login(response.user!.id);

            // Show backup codes before proceeding
            state = AppAuthState(
              status: AuthStatus.needsBackupCodesConfirmation,
              user: response.user,
              pendingBackupCodes: encryptionResult.codes,
            );
          } else {
            state = state.copyWith(
              isLoading: false,
              error: 'Encryption failed: ${encryptionResult.error}',
            );
          }
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
    } finally {
      _authFlowInProgress = false;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    _authFlowInProgress = true;

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
    } finally {
      _authFlowInProgress = false;
    }
  }

  /// Called when user is logged in but needs to enter password for encryption
  Future<void> unlockWithPassword(String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    _authFlowInProgress = true;

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
    } finally {
      _authFlowInProgress = false;
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
      // The SDK drops the local session before it calls the server, so a
      // failing network call must still leave the user signed out here.
      debugPrint('AuthProvider: Sign out error: $e');
      state = const AppAuthState(status: AuthStatus.unauthenticated);
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

  /// Called when user confirms they've saved backup codes
  void confirmBackupCodesSaved() {
    if (state.status != AuthStatus.needsBackupCodesConfirmation) return;

    state = AppAuthState(
      status: AuthStatus.authenticated,
      user: state.user,
    );
  }

  /// Recover account with backup code
  Future<void> recoverWithBackupCode({
    required String code,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    _authFlowInProgress = true;

    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'No user signed in.',
        );
        return;
      }

      final salt = await EncryptionService.getSaltBytes(user.id);
      if (salt == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Salt not found.',
        );
        return;
      }

      final result = await BackupCodeService.recoverWithBackupCode(
        userId: user.id,
        code: code,
        newPassword: newPassword,
        salt: salt,
      );

      if (result.success) {
        // Initialize encryption with new password
        await EncryptionService.initializeAfterRecovery(
          userId: user.id,
          newPassword: newPassword,
        );
        await _saveLastUserId(user.id);
        RevenueCatService.login(user.id);

        state = AppAuthState(
          status: AuthStatus.authenticated,
          user: user,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result.error ?? 'Recovery failed.',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    } finally {
      _authFlowInProgress = false;
    }
  }

  /// Regenerate backup codes (returns new codes to display)
  Future<List<String>?> regenerateBackupCodes(String currentPassword) async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;

    final salt = await EncryptionService.getSaltBytes(user.id);
    if (salt == null) return null;

    final result = await BackupCodeService.regenerateBackupCodes(
      userId: user.id,
      currentPassword: currentPassword,
      salt: salt,
    );

    return result.success ? result.codes : null;
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
