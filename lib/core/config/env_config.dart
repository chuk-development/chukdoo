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
/// # OSS/Self-hosted build (local only)
/// flutter build apk --dart-define=SUPABASE_ENABLED=false
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

  // RevenueCat
  static const String revenueCatApiKey =
      String.fromEnvironment('REVENUECAT_API_KEY', defaultValue: '');

  /// Whether Supabase is enabled and properly configured
  static bool get hasValidSupabaseConfig =>
      supabaseEnabled && supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Whether RevenueCat is configured
  static bool get hasValidRevenueCatConfig => revenueCatApiKey.isNotEmpty;

  /// Whether the app should operate in local-only mode
  static bool get isLocalOnlyMode => !hasValidSupabaseConfig;
}
