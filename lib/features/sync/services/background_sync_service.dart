import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../../../core/config/env_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/services/encryption_service.dart';
import '../../../shared/services/supabase_service.dart';

const String backgroundSyncTask = 'backgroundSyncTask';
const String periodicSyncTask = 'periodicSyncTask';

/// Callback dispatcher for background work - must be top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('BackgroundSync: Executing task: $task');

    try {
      // Initialize Hive
      await Hive.initFlutter();

      // Check if Supabase is configured
      if (!EnvConfig.hasValidSupabaseConfig) {
        debugPrint('BackgroundSync: Supabase not configured, skipping');
        return true;
      }

      // Initialize Supabase. This restores the persisted session; the token
      // is then refreshed if it is stale, so a background run never uploads
      // with an expired JWT.
      await SupabaseService.initialize();

      if (!await SupabaseService.ensureSyncSession()) {
        debugPrint('BackgroundSync: No usable session, skipping');
        // Not an error: retry on the next scheduled run.
        return true;
      }

      // Open the pending sync box
      final queueBox = await Hive.openBox<Map>(AppConstants.hivePendingBox);
      final pendingCount = queueBox.length;

      if (pendingCount == 0) {
        debugPrint('BackgroundSync: No pending operations');
        return true;
      }

      debugPrint('BackgroundSync: Processing $pendingCount pending operations');

      // Process each pending item
      var hadFailure = false;
      for (final key in queueBox.keys.toList()) {
        try {
          final rawData = queueBox.get(key);
          if (rawData == null) continue;

          final item = Map<String, dynamic>.from(rawData);
          final entityType = item['entityType'] as String;
          final operation = item['operation'] as String;
          final entityId = item['entityId'] as String;
          final data = item['data'] != null
              ? Map<String, dynamic>.from(item['data'] as Map)
              : null;

          // Must match SyncService._processItem table mapping, else ops
          // get written to the wrong table (data corruption).
          final tableName = switch (entityType) {
            'todo' => 'todos',
            'project' => 'projects',
            'calendar' => 'calendars',
            'calendarEvent' => 'calendar_events',
            'habit' => 'habits',
            _ => null,
          };
          if (tableName == null) {
            debugPrint('BackgroundSync: Unknown entityType "$entityType", leaving queued');
            continue;
          }

          if (operation == 'delete') {
            await SupabaseService.client
                .from(tableName)
                .delete()
                .eq('id', entityId);
          } else if (data != null) {
            final encryptedPayload = await EncryptionService.encryptJson(data);
            final userId = data['user_id'] as String?;

            await SupabaseService.client.from(tableName).upsert({
              'id': entityId,
              'user_id': userId,
              'encrypted_payload': encryptedPayload,
              'updated_at': DateTime.now().toIso8601String(),
            });
          }

          // Remove from queue after successful sync
          await queueBox.delete(key);
          debugPrint('BackgroundSync: Synced $entityType $entityId');
        } catch (e) {
          hadFailure = true;
          debugPrint('BackgroundSync: Error syncing item: $e');
        }
      }

      debugPrint('BackgroundSync: Completed (hadFailure=$hadFailure)');
      // Return false on any failure so WorkManager reschedules a retry.
      return !hadFailure;
    } catch (e) {
      debugPrint('BackgroundSync: Error: $e');
      return false;
    }
  });
}

/// Service for managing background sync
class BackgroundSyncService {
  const BackgroundSyncService._();

  /// Initialize background sync
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);

    // Register periodic sync task (minimum 15 minutes on Android)
    await Workmanager().registerPeriodicTask(
      periodicSyncTask,
      periodicSyncTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );

    debugPrint('BackgroundSyncService: Initialized with periodic sync');
  }

  /// Trigger immediate background sync
  static Future<void> triggerSync() async {
    await Workmanager().registerOneOffTask(
      '${backgroundSyncTask}_${DateTime.now().millisecondsSinceEpoch}',
      backgroundSyncTask,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
    debugPrint('BackgroundSyncService: Triggered immediate sync');
  }

  /// Cancel all background tasks
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
    debugPrint('BackgroundSyncService: Cancelled all tasks');
  }
}
