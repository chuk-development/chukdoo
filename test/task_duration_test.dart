import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chukdoo/features/calendar/domain/models/calendar_item.dart';
import 'package:chukdoo/features/todos/domain/models/todo.dart';

/// A task can now say "from 14:00 to 15:30". The calendar draws that span, so
/// the span has to survive a save and a reload, and a task without a time has
/// to stay the all-day entry it always was.
void main() {
  Todo makeTodo({DateTime? dueDate, TimeOfDay? dueTime, TimeOfDay? endTime}) {
    final now = DateTime(2026, 9, 8, 8);
    return Todo(
      id: 't1',
      userId: 'local',
      title: 'Write the report',
      dueDate: dueDate,
      dueTime: dueTime,
      endTime: endTime,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('TodoItem', () {
    test('a task with a start and an end reports exactly that span', () {
      final item = TodoItem(
        todo: makeTodo(
          dueDate: DateTime(2026, 9, 8),
          dueTime: const TimeOfDay(hour: 14, minute: 0),
          endTime: const TimeOfDay(hour: 15, minute: 30),
        ),
      );

      expect(item.startTime, DateTime(2026, 9, 8, 14, 0));
      expect(item.endTime, DateTime(2026, 9, 8, 15, 30));
      expect(item.isAllDay, isFalse);
    });

    test('a task with a time but no end keeps the default length', () {
      final item = TodoItem(
        todo: makeTodo(
          dueDate: DateTime(2026, 9, 8),
          dueTime: const TimeOfDay(hour: 14, minute: 0),
        ),
      );

      expect(item.endTime, item.startTime.add(TodoItem.defaultLength));
    });

    test('an end at or before the start falls back to the default length', () {
      final item = TodoItem(
        todo: makeTodo(
          dueDate: DateTime(2026, 9, 8),
          dueTime: const TimeOfDay(hour: 14, minute: 0),
          endTime: const TimeOfDay(hour: 13, minute: 0),
        ),
      );

      expect(item.endTime, item.startTime.add(TodoItem.defaultLength));
    });

    test('a task without a time is still all day', () {
      final item = TodoItem(todo: makeTodo(dueDate: DateTime(2026, 9, 8)));

      expect(item.isAllDay, isTrue);
      expect(item.startTime, DateTime(2026, 9, 8));
      expect(item.endTime, item.startTime);
    });
  });

  group('storage', () {
    test('the end time survives the payload that is cached and synced', () {
      final todo = makeTodo(
        dueDate: DateTime(2026, 9, 8),
        dueTime: const TimeOfDay(hour: 9, minute: 5),
        endTime: const TimeOfDay(hour: 10, minute: 45),
      );

      final restored = Todo.fromJson(todo.toJson());

      expect(restored.dueTime, const TimeOfDay(hour: 9, minute: 5));
      expect(restored.endTime, const TimeOfDay(hour: 10, minute: 45));
    });

    test('a row written before the field simply has no end', () {
      final json = makeTodo(
        dueDate: DateTime(2026, 9, 8),
        dueTime: const TimeOfDay(hour: 9, minute: 0),
      ).toJson()..remove('end_time');

      expect(Todo.fromJson(json).endTime, isNull);
    });

    test('taking the time off a task takes its end with it', () {
      final todo = makeTodo(
        dueDate: DateTime(2026, 9, 8),
        dueTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 10, minute: 0),
      );

      final cleared = todo.copyWith(clearDueTime: true);

      expect(cleared.dueTime, isNull);
      expect(cleared.endTime, isNull);
    });
  });
}
