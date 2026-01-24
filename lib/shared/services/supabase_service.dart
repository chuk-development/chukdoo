import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env_config.dart';

class SupabaseService {
  const SupabaseService._();

  static bool _initialized = false;

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

    try {
      await Supabase.initialize(
        url: EnvConfig.supabaseUrl,
        anonKey: EnvConfig.supabaseAnonKey,
      ).timeout(const Duration(seconds: 5));

      _initialized = true;
      debugPrint('SupabaseService: Initialized successfully');
      return true;
    } catch (e) {
      debugPrint('SupabaseService: Init failed (offline?): $e');
      _initialized = false;
      return false;
    }
  }

  static User? get currentUser => _clientOrNull?.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;

  static Stream<AuthState>? get authStateChanges =>
      _clientOrNull?.auth.onAuthStateChange;
}
