import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env_config.dart';

/// Access to the Supabase backend and the single source of truth for the
/// signed-in session.
///
/// Session rules (the user signs in once and stays signed in):
/// - The SDK persists the session locally (SharedPreferences) and restores it
///   on start. Nothing here reads the session only once at startup.
/// - `autoRefreshToken` keeps the access token fresh while the app runs. On top
///   of that [ensureFreshSession] refreshes explicitly on app resume and before
///   a sync run, because a sync can start before the auto-refresh ticker fires.
/// - A refresh that fails because the device is offline NEVER signs the user
///   out: the SDK keeps the session and we keep reporting "signed in". Only a
///   revoked/invalid refresh token drops the session, and that arrives as an
///   `AuthChangeEvent.signedOut` event.
class SupabaseService {
  const SupabaseService._();

  /// Refresh the access token when it expires inside this window.
  static const _refreshMargin = Duration(minutes: 5);

  /// How long a single initialize() attempt may take before we continue
  /// offline. Init itself is local work, so this only guards a hung platform
  /// channel.
  static const _initTimeout = Duration(seconds: 5);

  /// Backoff for retrying initialize() in the background. A failed attempt must
  /// not disable cloud sync for the rest of the app run.
  static const _initRetryDelays = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 20),
    Duration(minutes: 1),
    Duration(minutes: 5),
  ];

  static bool _initialized = false;
  static bool _initializing = false;
  static int _initAttempt = 0;

  /// De-duplicates concurrent [ensureFreshSession] calls (resume + sync can
  /// fire at the same moment).
  static Future<bool>? _pendingRefresh;

  static StreamSubscription<AuthState>? _authRelaySubscription;

  /// Relay of the SDK auth stream. It exists before Supabase is initialized so
  /// listeners never miss the wiring, and it survives a late init.
  static final StreamController<AuthState> _authEventsController =
      StreamController<AuthState>.broadcast();

  /// Whether Supabase has been successfully initialized
  static bool get isInitialized => _initialized;

  /// Whether Supabase features are available
  static bool get isAvailable => _initialized && EnvConfig.hasValidSupabaseConfig;

  static SupabaseClient? get _clientOrNull =>
      _initialized ? Supabase.instance.client : null;

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
        'Supabase not initialized. Call SupabaseService.initialize() first or check isAvailable.',
      );
    }
    return Supabase.instance.client;
  }

  static GoTrueClient get auth => client.auth;

  /// Initialize Supabase if configured via environment variables.
  /// Returns true if initialization was successful, false if skipped (local-only mode).
  ///
  /// Does not block on the network: the SDK restores the persisted session from
  /// local storage and refreshes it in the background.
  static Future<bool> initialize() async {
    debugPrint('SupabaseService: Checking config...');
    debugPrint('SupabaseService: supabaseEnabled=${EnvConfig.supabaseEnabled}');
    debugPrint('SupabaseService: supabaseUrl=${EnvConfig.supabaseUrl}');
    debugPrint('SupabaseService: hasValidConfig=${EnvConfig.hasValidSupabaseConfig}');

    if (!EnvConfig.hasValidSupabaseConfig) {
      // Local-only mode - Supabase not configured
      debugPrint('SupabaseService: Local-only mode - Supabase not configured');
      _initialized = false;
      return false;
    }

    if (_initialized) return true;
    if (_initializing) return false;
    _initializing = true;

    try {
      await Supabase.initialize(
        url: EnvConfig.supabaseUrl,
        anonKey: EnvConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          // Keep the JWT fresh in the background for as long as the app runs.
          autoRefreshToken: true,
          // localStorage defaults to SharedPreferences, which persists the
          // session across restarts. Stated here so it is not "fixed" away.
        ),
      ).timeout(_initTimeout);

      _initialized = true;
      _startAuthRelay();
      debugPrint('SupabaseService: Initialized successfully');
      return true;
    } catch (e) {
      // A timeout does not mean the SDK failed - Supabase.initialize() may have
      // completed just after we gave up. Trust the SDK's own flag.
      if (Supabase.instance.isInitialized) {
        _initialized = true;
        _startAuthRelay();
        debugPrint('SupabaseService: Init slow but completed: $e');
        return true;
      }

      debugPrint('SupabaseService: Init failed (offline?): $e');
      _initialized = false;
      _scheduleInitRetry();
      return false;
    } finally {
      _initializing = false;
    }
  }

  /// Retry initialization in the background so a slow start does not disable
  /// cloud sync until the app is restarted.
  static void _scheduleInitRetry() {
    if (_initAttempt >= _initRetryDelays.length) return;
    final delay = _initRetryDelays[_initAttempt];
    _initAttempt++;

    Future.delayed(delay, () async {
      if (_initialized) return;
      debugPrint('SupabaseService: Retrying init (attempt $_initAttempt)');
      await initialize();
    });
  }

  /// Pipe the SDK auth stream into our own broadcast stream.
  static void _startAuthRelay() {
    if (_authRelaySubscription != null) return;
    _authRelaySubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen(_authEventsController.add, onError: (Object e) {
      debugPrint('SupabaseService: Auth stream error: $e');
    });
  }

  static User? get currentUser => currentSession?.user;

  /// The persisted session, expired access token included. An expired token is
  /// not a signed-out user - it only needs a refresh.
  static Session? get currentSession => _clientOrNull?.auth.currentSession;

  /// Single source of truth for "the user has a cloud account on this device".
  /// The UI and the sync layer both read this, so they cannot disagree.
  static bool get isAuthenticated => currentSession != null;

  /// Whether the access token is expired or expires inside [_refreshMargin].
  static bool get needsTokenRefresh {
    final session = currentSession;
    if (session == null) return false;

    final expiresAt = session.expiresAt;
    if (expiresAt == null) return false;

    final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    return expiry.isBefore(DateTime.now().add(_refreshMargin));
  }

  /// Make sure the access token is usable, refreshing it if it is close to
  /// expiry. Returns whether a session is still present afterwards.
  ///
  /// Returns true without touching the network when the token is still valid.
  /// A transient failure (offline, timeout, 5xx) keeps the session and returns
  /// true, so the caller may retry later instead of treating it as a sign-out.
  /// Returns false only when the session is really gone - no session at all, or
  /// the server rejected the refresh token, in which case the SDK has already
  /// dropped the session and emitted `signedOut`.
  static Future<bool> ensureFreshSession() async {
    if (!isAvailable) return false;
    if (currentSession == null) return false;
    if (!needsTokenRefresh) return true;

    final pending = _pendingRefresh;
    if (pending != null) return pending;

    final refresh = _refreshSession();
    _pendingRefresh = refresh;
    try {
      return await refresh;
    } finally {
      _pendingRefresh = null;
    }
  }

  static Future<bool> _refreshSession() async {
    try {
      debugPrint('SupabaseService: Refreshing access token...');
      await auth.refreshSession();
      debugPrint('SupabaseService: Access token refreshed');
      return currentSession != null;
    } catch (e) {
      // The SDK removes the session itself when the refresh token is invalid
      // or revoked, and keeps it on every transient error. So the session it
      // still holds is the answer - never sign the user out on our own.
      final stillSignedIn = currentSession != null;
      debugPrint(
        'SupabaseService: Token refresh failed '
        '(${stillSignedIn ? 'transient, session kept' : 'session revoked'}): $e',
      );
      return stillSignedIn;
    }
  }

  /// Ready-to-sync check: Supabase available, a session present and its access
  /// token fresh. Used by every sync entry point.
  static Future<bool> ensureSyncSession() async {
    if (!isAvailable) return false;
    return ensureFreshSession();
  }

  /// Auth state changes. Alive before Supabase is initialized, so a listener
  /// set up at app start also sees a late init.
  static Stream<AuthState> get authStateChanges => _authEventsController.stream;
}
