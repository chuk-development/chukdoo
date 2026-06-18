import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/utils/platform_utils.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// Callback type for notification tap events
typedef NotificationTapCallback = void Function(String todoId);

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Stream controller for notification tap events
  final _tapController = StreamController<String>.broadcast();

  /// Stream of todo IDs from notification taps
  Stream<String> get onNotificationTap => _tapController.stream;

  /// Store pending tap to be handled when app is ready
  String? _pendingTodoId;

  /// Get and clear pending todo ID (for cold start)
  String? consumePendingTodoId() {
    final id = _pendingTodoId;
    _pendingTodoId = null;
    return id;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open',
      defaultIcon: AssetsLinuxIcon('assets/images/app_icon.png'),
    );

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      linux: linuxSettings,
    );

    await _notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Check if app was launched from notification (not supported on Linux)
    if (!PlatformUtils.isLinux) {
      final launchDetails = await _notifications
          .getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        final payload = launchDetails!.notificationResponse?.payload;
        if (payload != null) {
          _pendingTodoId = payload;
          debugPrint(
            'NotificationService: App launched from notification for todo: $payload',
          );
        }
      }
    }

    _isInitialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      debugPrint('NotificationService: Notification tapped for todo: $payload');
      _tapController.add(payload);
    }
  }

  Future<bool> requestPermissions() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    return true;
  }

  /// Stable, positive 31-bit notification id derived from a todo id.
  /// Android notification ids must fit in a 32-bit int; a raw [String.hashCode]
  /// can be negative or exceed that range.
  static int _notificationId(String todoId) => todoId.hashCode & 0x7fffffff;

  Future<void> scheduleReminder({
    required String todoId,
    required String title,
    required DateTime remindAt,
    String? body,
  }) async {
    // Linux doesn't support scheduled notifications
    if (PlatformUtils.isLinux) {
      debugPrint(
        'NotificationService: Scheduled notifications not supported on Linux',
      );
      return;
    }

    final id = _notificationId(todoId);

    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body ?? 'Reminder',
      scheduledDate: tz.TZDateTime.from(remindAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Reminders',
          channelDescription: 'Task reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: todoId,
    );
  }

  Future<void> cancelReminder(String todoId) async {
    await _notifications.cancel(id: _notificationId(todoId));
  }

  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }

  Future<void> showInstantNotification({
    required String title,
    String? body,
    String? payload,
  }) async {
    await _notifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'general',
          'General',
          channelDescription: 'General notifications',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
      ),
      payload: payload,
    );
  }

  /// Show notification for new todos synced from other devices
  Future<void> showNewTodoNotification({
    required int count,
    String? firstTodoTitle,
  }) async {
    final title = count == 1
        ? 'New task synced'
        : '$count new tasks synced';
    final body = firstTodoTitle ?? 'Added from another device';

    await _notifications.show(
      id: 'new_todos'.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'sync',
          'Sync',
          channelDescription: 'Notifications for synced tasks',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
      ),
    );
  }

  /// Show sync status notification (success or error)
  Future<void> showSyncNotification({
    required String message,
    bool isError = false,
  }) async {
    await _notifications.show(
      id: 'sync_status'.hashCode,
      title: isError ? 'Sync error' : 'Sync',
      body: message,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'sync',
          'Sync',
          channelDescription: 'Sync status notifications',
          importance: isError ? Importance.high : Importance.low,
          priority: isError ? Priority.high : Priority.low,
        ),
        iOS: const DarwinNotificationDetails(),
        linux: const LinuxNotificationDetails(),
      ),
    );
  }
}
