import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../todos/domain/models/todo.dart';
import 'notification_service.dart';

/// Service for scheduling and managing todo reminders
class ReminderScheduler {
  static final ReminderScheduler _instance = ReminderScheduler._();
  static ReminderScheduler get instance => _instance;

  ReminderScheduler._();

  /// Schedule all pending reminders on app startup
  /// Call this after Hive and NotificationService are initialized
  Future<void> scheduleAllReminders() async {
    try {
      final todosBox = Hive.box<Map>(AppConstants.hiveTodosBox);
      final todos = todosBox.values.map((m) {
        final map = Map<String, dynamic>.from(m);
        return Todo.fromJson(map);
      }).toList();

      int scheduled = 0;
      for (final todo in todos) {
        if (await _shouldScheduleReminder(todo)) {
          await _scheduleReminder(todo);
          scheduled++;
        }
      }

      debugPrint('ReminderScheduler: Scheduled $scheduled reminders');
    } catch (e) {
      debugPrint('ReminderScheduler: Error scheduling reminders: $e');
    }
  }

  /// Schedule a reminder for a specific todo
  Future<void> scheduleForTodo(Todo todo) async {
    if (await _shouldScheduleReminder(todo)) {
      await _scheduleReminder(todo);
    } else {
      // Cancel any existing reminder if conditions not met
      await cancelForTodo(todo.id);
    }
  }

  /// Cancel reminder for a specific todo
  Future<void> cancelForTodo(String todoId) async {
    try {
      await NotificationService.instance.cancelReminder(todoId);
    } catch (e) {
      debugPrint('ReminderScheduler: Error canceling reminder: $e');
    }
  }

  /// Cancel all reminders
  Future<void> cancelAll() async {
    try {
      await NotificationService.instance.cancelAllReminders();
      debugPrint('ReminderScheduler: All reminders canceled');
    } catch (e) {
      debugPrint('ReminderScheduler: Error canceling all reminders: $e');
    }
  }

  /// Check if a reminder should be scheduled for this todo
  Future<bool> _shouldScheduleReminder(Todo todo) async {
    // Don't schedule if:
    // - Todo is completed
    // - No reminder time set
    // - Reminder time is in the past
    if (todo.isCompleted) return false;
    if (todo.reminderAt == null) return false;
    if (todo.reminderAt!.isBefore(DateTime.now())) return false;

    return true;
  }

  /// Actually schedule the reminder notification
  Future<void> _scheduleReminder(Todo todo) async {
    if (todo.reminderAt == null) return;

    try {
      await NotificationService.instance.scheduleReminder(
        todoId: todo.id,
        title: todo.title,
        remindAt: todo.reminderAt!,
        body: _buildReminderBody(todo),
      );
      debugPrint('ReminderScheduler: Scheduled reminder for ${todo.id} at ${todo.reminderAt}');
    } catch (e) {
      debugPrint('ReminderScheduler: Error scheduling reminder for ${todo.id}: $e');
    }
  }

  /// Build the notification body text
  String _buildReminderBody(Todo todo) {
    final parts = <String>[];

    if (todo.dueDate != null) {
      final now = DateTime.now();
      final dueDate = todo.dueDate!;

      if (dueDate.year == now.year &&
          dueDate.month == now.month &&
          dueDate.day == now.day) {
        parts.add('Due today');
      } else if (dueDate.isBefore(now)) {
        parts.add('Overdue');
      } else {
        parts.add('Due: ${_formatDate(dueDate)}');
      }

      if (todo.dueTime != null) {
        parts.add('at ${_formatTime(todo.dueTime!)}');
      }
    }

    if (parts.isEmpty) {
      return 'Reminder for your task';
    }

    return parts.join(' ');
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}
