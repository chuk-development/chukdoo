import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Check if app was launched from notification
    final launchDetails = await _notifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails!.notificationResponse?.payload;
      if (payload != null) {
        _pendingTodoId = payload;
        debugPrint('NotificationService: App launched from notification for todo: $payload');
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
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    return true;
  }

  Future<void> scheduleReminder({
    required String todoId,
    required String title,
    required DateTime remindAt,
    String? body,
  }) async {
    final id = todoId.hashCode;

    await _notifications.zonedSchedule(
      id,
      title,
      body ?? 'Erinnerung',
      tz.TZDateTime.from(remindAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Erinnerungen',
          channelDescription: 'Erinnerungen für Aufgaben',
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
    final id = todoId.hashCode;
    await _notifications.cancel(id);
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
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'general',
          'Allgemein',
          channelDescription: 'Allgemeine Benachrichtigungen',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }
}
