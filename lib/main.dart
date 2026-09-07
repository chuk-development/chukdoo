import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'features/calendar/services/ics_feed_service.dart';
import 'features/sync/services/connectivity_service.dart';
import 'features/sync/services/sync_service.dart';
import 'native_init.dart';
import 'shared/services/supabase_service.dart';
import 'features/notes/domain/models/note_folder.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize locale data for intl package
  await initializeDateFormatting('en_US', null);

  // Initialize Hive for local storage (FAST - always works)
  await Hive.initFlutter();
  await Hive.openBox<Map>(AppConstants.hiveTodosBox);
  await Hive.openBox<Map>(AppConstants.hiveProjectsBox);
  await Hive.openBox<Map>(AppConstants.hiveMetaBox);
  await Hive.openBox(AppConstants.hiveSettingsBox);
  await Hive.openBox<Map>(AppConstants.hiveCalendarsBox);
  await Hive.openBox<Map>(AppConstants.hiveCalendarEventsBox);
  await Hive.openBox<Map>(AppConstants.hiveHabitsBox);
  await Hive.openBox<Map>(AppConstants.hiveNotesBox);
  await Hive.openBox<Map>(NoteFolder.hiveBox);
  await Hive.openBox<Map>(AppConstants.hiveIcsFeedsBox);

  // Initialize sync service (local queue - always works)
  await SyncService.initialize();

  // Initialize connectivity monitoring
  await ConnectivityService.instance.initialize();

  // Native-only services (notifications, tray, reminders)
  if (!kIsWeb) {
    await initializeNativeServices();
  }

  // NON-BLOCKING: Network services with timeout
  // These run in background and don't block app startup
  _initializeNetworkServices();

  runApp(const ProviderScope(child: ChukdooApp()));
}

/// Initialize network-dependent services in background
/// App works offline even if these fail
Future<void> _initializeNetworkServices() async {
  try {
    // Supabase with 5 second timeout
    await SupabaseService.initialize().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('Supabase init timeout - continuing offline');
        return false;
      },
    );
  } catch (e) {
    debugPrint('Supabase init failed: $e - continuing offline');
  }

  // RevenueCat and BackgroundSync are native-only (use dart:io)
  if (!kIsWeb) {
    await initializeNativeNetworkServices();
  }

  // Subscribed ICS calendars are refreshed on the client, so opening the app
  // is what keeps them current. Failures are recorded per feed.
  await IcsFeedService.refreshAll();
}
