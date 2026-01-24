import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../todos/domain/models/todo.dart';

/// Service for updating the Android home screen widget
class WidgetService {
  static const _platform = MethodChannel('doo.chuk.dev/widget');
  static const _prefsKey = 'today_todos';

  /// Update the widget with today's todos
  static Future<void> updateWidget() async {
    if (!Platform.isAndroid) return;

    try {
      // Get all todos
      final todosBox = Hive.box<Map>(AppConstants.hiveTodosBox);
      final allTodos = todosBox.values.map((m) {
        final map = Map<String, dynamic>.from(m);
        return Todo.fromJson(map);
      }).toList();

      // Filter for today's incomplete todos
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final todayTodos = allTodos.where((todo) {
        if (todo.isCompleted) return false;
        if (todo.dueDate == null) return false;

        final dueDay = DateTime(
          todo.dueDate!.year,
          todo.dueDate!.month,
          todo.dueDate!.day,
        );

        return dueDay.isAtSameMomentAs(today) || dueDay.isBefore(today);
      }).toList();

      // Sort by priority then by time
      todayTodos.sort((a, b) {
        // Priority first (lower is higher priority)
        final priorityCompare = a.priority.value.compareTo(b.priority.value);
        if (priorityCompare != 0) return priorityCompare;

        // Then by due time
        if (a.dueTime != null && b.dueTime != null) {
          final aMinutes = a.dueTime!.hour * 60 + a.dueTime!.minute;
          final bMinutes = b.dueTime!.hour * 60 + b.dueTime!.minute;
          return aMinutes.compareTo(bMinutes);
        }

        return 0;
      });

      // Take top 5
      final topTodos = todayTodos.take(5).toList();

      // Convert to JSON for the widget
      final todosJson = topTodos.map((todo) {
        return {
          'id': todo.id,
          'title': todo.title,
          'due_date': todo.dueDate?.toIso8601String(),
          'due_time': todo.dueTime != null
              ? '${todo.dueTime!.hour.toString().padLeft(2, '0')}:${todo.dueTime!.minute.toString().padLeft(2, '0')}'
              : null,
          'priority': todo.priority.value,
          'is_completed': todo.isCompleted,
        };
      }).toList();

      // Store in SharedPreferences for the widget to read
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(todosJson));

      // Notify the widget to refresh
      try {
        await _platform.invokeMethod('updateWidget');
      } catch (e) {
        // Platform channel not available - that's fine
        debugPrint('WidgetService: Platform channel not available');
      }

      debugPrint('WidgetService: Updated widget with ${topTodos.length} todos');
    } catch (e) {
      debugPrint('WidgetService: Error updating widget: $e');
    }
  }

  /// Clear widget data
  static Future<void> clearWidget() async {
    if (!Platform.isAndroid) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);

      try {
        await _platform.invokeMethod('updateWidget');
      } catch (e) {
        // Platform channel not available
      }
    } catch (e) {
      debugPrint('WidgetService: Error clearing widget: $e');
    }
  }
}
