import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'features/notifications/notification_service.dart';
import 'features/notifications/reminder_scheduler.dart';
import 'features/subscription/services/revenuecat_service.dart';
import 'features/sync/services/background_sync_service.dart';
import 'features/sync/services/connectivity_service.dart';
import 'features/sync/services/sync_service.dart';
import 'features/system_tray/system_tray_service.dart';
import 'shared/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize locale data for intl package
  await initializeDateFormatting('de_DE', null);
  await initializeDateFormatting('en_US', null);

  // Initialize Hive for local storage (FAST - always works)
  await Hive.initFlutter();
  await Hive.openBox<Map>(AppConstants.hiveTodosBox);
  await Hive.openBox<Map>(AppConstants.hiveProjectsBox);
  await Hive.openBox<Map>(AppConstants.hiveMetaBox);
  await Hive.openBox(AppConstants.hiveSettingsBox);

  // Initialize sync service (local queue - always works)
  await SyncService.initialize();

  // Initialize connectivity monitoring
  await ConnectivityService.instance.initialize();

  // Initialize notifications (local - always works)
  await NotificationService.instance.initialize();

  // Initialize system tray (desktop only)
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    await SystemTrayService.instance.initialize();
  }

  // Schedule all pending reminders (boot recovery)
  await ReminderScheduler.instance.scheduleAllReminders();

  // NON-BLOCKING: Network services with timeout
  // These run in background and don't block app startup
  _initializeNetworkServices();

  runApp(
    const ProviderScope(
      child: ChukdooApp(),
    ),
  );
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

  try {
    // RevenueCat with 5 second timeout
    await RevenueCatService.initialize().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('RevenueCat init timeout - continuing offline');
        return false;
      },
    );
  } catch (e) {
    debugPrint('RevenueCat init failed: $e - continuing offline');
  }

  try {
    // Background sync (non-critical)
    await BackgroundSyncService.initialize();
  } catch (e) {
    debugPrint('BackgroundSync init failed: $e');
  }
}
