import 'package:flutter/material.dart';
import 'features/notifications/notification_service.dart';
import 'features/notifications/reminder_scheduler.dart';
import 'features/donations/services/revenuecat_service.dart';
import 'features/sync/services/background_sync_service.dart';
import 'features/system_tray/system_tray_service.dart';

Future<void> initializeNativeServices() async {
  await NotificationService.instance.initialize();
  await SystemTrayService.instance.initialize();
  await ReminderScheduler.instance.scheduleAllReminders();
}

Future<void> initializeNativeNetworkServices() async {
  try {
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
    await BackgroundSyncService.initialize();
  } catch (e) {
    debugPrint('BackgroundSync init failed: $e');
  }
}
