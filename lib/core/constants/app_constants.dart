class AppConstants {
  const AppConstants._();

  // App info
  static const String appName = 'Chukdoo';
  static const String appVersion = '1.0.0';

  // Donations (RevenueCat / Google Play). The app is free; these are one-off
  // consumable products, they unlock nothing.
  static const String donationOfferingId = 'donations';

  // Encryption
  static const int kdfIterations = 600000;
  static const int backupCodeKdfIterations = 100000;
  static const int saltLength = 16;
  static const String payloadVersion = '1';
  static const int backupCodeCount = 8;

  // Sync
  static const Duration syncInterval = Duration(seconds: 30);
  static const Duration syncDebounce = Duration(milliseconds: 500);

  // UI
  static const Duration animationDuration = Duration(milliseconds: 200);
  static const Duration snackBarDuration = Duration(seconds: 3);

  // Limits
  static const int maxTodoTitleLength = 500;
  static const int maxTodoDescriptionLength = 5000;
  static const int maxProjectNameLength = 100;
  static const int maxLabelNameLength = 50;

  // Storage keys
  static const String keyUserId = 'user_id';
  static const String keyLastSync = 'last_sync';
  static const String keyEncryptionKey = 'encryption_key_';
  static const String keyEncryptionSalt = 'encryption_salt_';
  static const String keyKeyVersion = 'key_version_';

  // Supabase metadata keys
  static const String metadataSaltKey = 'chukdoo_kdf_salt';
  static const String metadataVersionKey = 'chukdoo_key_version';

  // Hive box names
  static const String hiveTodosBox = 'todos';
  static const String hiveProjectsBox = 'projects';
  static const String hiveLabelsBox = 'labels';
  static const String hivePendingBox = 'pending_sync';
  static const String hiveMetaBox = 'meta';
  static const String hiveSettingsBox = 'settings';
  static const String hiveCalendarsBox = 'calendars';
  static const String hiveCalendarEventsBox = 'calendar_events';
  static const String hiveHabitsBox = 'habits';
  static const String hiveNotesBox = 'notes';
  static const String hiveIcsFeedsBox = 'ics_feeds';
}
