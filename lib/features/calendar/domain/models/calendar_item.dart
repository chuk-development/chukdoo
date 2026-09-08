import '../../../todos/domain/models/todo.dart';
import 'calendar_event.dart';

/// Unified type for rendering both calendar events and todos in calendar views
sealed class CalendarItem {
  DateTime get startTime;
  DateTime get endTime;
  String get title;
  int get color;
  bool get isAllDay;
}

class EventItem extends CalendarItem {
  final CalendarEvent event;
  final DateTime occurrenceStart;
  final DateTime occurrenceEnd;

  EventItem({
    required this.event,
    DateTime? occurrenceStart,
    DateTime? occurrenceEnd,
  }) : occurrenceStart = occurrenceStart ?? event.startTime,
       occurrenceEnd = occurrenceEnd ?? event.endTime;

  @override
  DateTime get startTime => occurrenceStart;

  @override
  DateTime get endTime => occurrenceEnd;

  @override
  String get title => event.title;

  @override
  int get color => event.color;

  @override
  bool get isAllDay => event.isAllDay;
}

class TodoItem extends CalendarItem {
  final Todo todo;

  TodoItem({required this.todo});

  @override
  DateTime get startTime {
    if (todo.dueDate == null) return DateTime.now();
    if (todo.dueTime != null) {
      return DateTime(
        todo.dueDate!.year,
        todo.dueDate!.month,
        todo.dueDate!.day,
        todo.dueTime!.hour,
        todo.dueTime!.minute,
      );
    }
    return todo.dueDate!;
  }

  /// Length a timed task without its own end is drawn with. The old
  /// behaviour, kept as the fallback so a task from before the end-time
  /// field still fills a readable block.
  static const Duration defaultLength = Duration(minutes: 30);

  @override
  DateTime get endTime {
    if (todo.dueTime == null) return startTime;

    final end = todo.endTime;
    if (end != null) {
      final candidate = DateTime(
        startTime.year,
        startTime.month,
        startTime.day,
        end.hour,
        end.minute,
      );
      // An end at or before the start would draw a block of zero height, so
      // the fallback length takes over (a task does not run past midnight).
      if (candidate.isAfter(startTime)) return candidate;
    }
    return startTime.add(defaultLength);
  }

  @override
  String get title => todo.title;

  @override
  int get color => 0;

  @override
  bool get isAllDay => todo.dueTime == null;
}
