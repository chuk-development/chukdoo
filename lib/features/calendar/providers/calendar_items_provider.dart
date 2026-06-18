import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../todos/providers/todo_provider.dart';
import '../domain/models/calendar_item.dart';
import '../domain/models/rrule_helper.dart';
import 'calendar_event_provider.dart';
import 'calendar_provider.dart';

/// Provides a merged list of calendar events and todos for the currently visible date range.
/// Expands recurring events into individual occurrences.
final calendarItemsProvider = Provider<CalendarItemsState>((ref) {
  final eventState = ref.watch(calendarEventProvider);
  final todoState = ref.watch(todoProvider);
  final calendarState = ref.watch(calendarContainerProvider);

  final visibleCalendarIds = calendarState.visibleCalendars.map((c) => c.id).toSet();

  // Determine visible date range based on view mode
  final focused = eventState.focusedDate;
  late DateTime rangeStart;
  late DateTime rangeEnd;

  switch (eventState.viewMode) {
    case CalendarViewMode.day:
      rangeStart = DateTime(focused.year, focused.month, focused.day);
      rangeEnd = rangeStart.add(const Duration(days: 1));
    case CalendarViewMode.week:
      final weekday = focused.weekday;
      rangeStart = DateTime(focused.year, focused.month, focused.day)
          .subtract(Duration(days: weekday - 1));
      rangeEnd = rangeStart.add(const Duration(days: 7));
    case CalendarViewMode.month:
      rangeStart = DateTime(focused.year, focused.month, 1);
      rangeEnd = DateTime(focused.year, focused.month + 1, 1);
    case CalendarViewMode.agenda:
      rangeStart = DateTime(focused.year, focused.month, focused.day);
      rangeEnd = rangeStart.add(const Duration(days: 30));
  }

  final items = <CalendarItem>[];

  // Collect exception originalStartTimes for each parent to exclude from expansion
  final exceptionsByParent = <String, Set<String>>{};
  for (final event in eventState.events) {
    if (event.isException && event.recurrenceId != null && event.originalStartTime != null) {
      exceptionsByParent.putIfAbsent(event.recurrenceId!, () => {});
      // Extract date part from ISO string
      final date = DateTime.tryParse(event.originalStartTime!);
      if (date != null) {
        exceptionsByParent[event.recurrenceId!]!.add(
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        );
      }
    }
  }

  // Add calendar events
  for (final event in eventState.events) {
    // Filter by visible calendars
    if (event.calendarId != null && !visibleCalendarIds.contains(event.calendarId)) {
      continue;
    }

    // Skip deleted exceptions
    if (event.isException && event.title == '__DELETED__') continue;

    if (event.isRecurring && !event.isException) {
      // Expand recurring event
      final excludedDates = exceptionsByParent[event.id];
      final occurrences = RRuleHelper.expandOccurrences(
        event.startTime,
        event.recurrenceRule!,
        rangeStart,
        rangeEnd,
        excludedDates: excludedDates,
      );
      for (final occurrence in occurrences) {
        items.add(EventItem(
          event: event,
          occurrenceStart: occurrence,
          occurrenceEnd: occurrence.add(event.duration),
        ));
      }
    } else if (!event.isException) {
      // Regular non-recurring event
      if (event.startTime.isBefore(rangeEnd) && event.endTime.isAfter(rangeStart)) {
        items.add(EventItem(event: event));
      }
    } else {
      // Exception event (modified occurrence)
      if (event.startTime.isBefore(rangeEnd) && event.endTime.isAfter(rangeStart)) {
        items.add(EventItem(event: event));
      }
    }
  }

  // Add todos with due dates
  for (final todo in todoState.todos) {
    if (todo.isCompleted || todo.dueDate == null) continue;
    final todoDay = DateTime(todo.dueDate!.year, todo.dueDate!.month, todo.dueDate!.day);
    if (todoDay.isBefore(rangeEnd) && todoDay.add(const Duration(days: 1)).isAfter(rangeStart)) {
      items.add(TodoItem(todo: todo));
    }
  }

  // Sort by start time
  items.sort((a, b) => a.startTime.compareTo(b.startTime));

  return CalendarItemsState(items: items, rangeStart: rangeStart, rangeEnd: rangeEnd);
});

class CalendarItemsState {
  final List<CalendarItem> items;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  const CalendarItemsState({
    required this.items,
    required this.rangeStart,
    required this.rangeEnd,
  });

  List<CalendarItem> itemsForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return items.where((i) {
      return i.startTime.isBefore(dayEnd) && i.endTime.isAfter(dayStart);
    }).toList();
  }

  List<CalendarItem> get allDayItems => items.where((i) => i.isAllDay).toList();

  List<CalendarItem> timedItemsForDay(DateTime day) {
    return itemsForDay(day).where((i) => !i.isAllDay).toList();
  }
}
