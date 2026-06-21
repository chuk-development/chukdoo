import 'package:flutter/foundation.dart';

/// Environment configuration loaded at compile time via --dart-define flags.
///
/// Build commands:
/// ```bash
/// # Play Store build (full features)
/// flutter build apk \
///   --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=your_key \
///   --dart-define=REVENUECAT_API_KEY=your_key
///
/// # OSS/Self-hosted build (local only, no cloud)
/// flutter build apk --dart-define=SUPABASE_ENABLED=false
///
/// # Build without RevenueCat (no paywall/subscriptions)
/// flutter build apk --dart-define=REVENUECAT_ENABLED=false
/// ```
class EnvConfig {
  const EnvConfig._();

  // Supabase
  static const bool supabaseEnabled =
      bool.fromEnvironment('SUPABASE_ENABLED', defaultValue: true);
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  // Forces Pro entitlement (cloud sync etc.) on without a purchase.
  // Used for test/dev builds that ship without RevenueCat.
  static const bool forcePro =
      bool.fromEnvironment('FORCE_PRO', defaultValue: false);

  // RevenueCat
  static const bool revenueCatEnabled =
      bool.fromEnvironment('REVENUECAT_ENABLED', defaultValue: true);
  static const String revenueCatApiKey =
      String.fromEnvironment('REVENUECAT_API_KEY', defaultValue: '');

  /// Whether Supabase is enabled and properly configured
  static bool get hasValidSupabaseConfig =>
      supabaseEnabled && supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Whether the RevenueCat API key is a sandbox/test key.
  /// RevenueCat force-closes release builds that use a `test_` key, so we
  /// treat those as invalid in release mode.
  static bool get isRevenueCatTestKey => revenueCatApiKey.startsWith('test_');

  /// Whether RevenueCat is configured.
  /// Skips a `test_` key in release builds to avoid the SDK killing the app.
  static bool get hasValidRevenueCatConfig =>
      revenueCatEnabled &&
      revenueCatApiKey.isNotEmpty &&
      !(kReleaseMode && isRevenueCatTestKey);

  /// Whether the app should operate in local-only mode
  static bool get isLocalOnlyMode => !hasValidSupabaseConfig;
}
