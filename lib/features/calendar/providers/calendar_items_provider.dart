import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/providers/settings_provider.dart';
import '../../todos/providers/todo_provider.dart';
import '../domain/models/calendar_item.dart';
import '../domain/week_dates.dart';
import '../domain/models/rrule_helper.dart';
import 'calendar_event_provider.dart';
import 'calendar_provider.dart';
import 'ics_feeds_provider.dart';

/// Provides a merged list of calendar events and todos for the currently visible date range.
/// Expands recurring events into individual occurrences.
final calendarItemsProvider = Provider<CalendarItemsState>((ref) {
  final eventState = ref.watch(calendarEventProvider);
  final todoState = ref.watch(todoProvider);
  final calendarState = ref.watch(calendarContainerProvider);
  final hiddenFeedIds = ref.watch(hiddenFeedIdsProvider);
  final settings = ref.watch(settingsProvider);

  final visibleCalendarIds = calendarState.visibleCalendars
      .map((c) => c.id)
      .toSet();
  // Events of a subscribed ICS feed carry the feed's id, which is not one of
  // the user's own calendars. Only a known calendar can be hidden — otherwise
  // every subscribed feed would be filtered away and never appear.
  final knownCalendarIds = calendarState.calendars.map((c) => c.id).toSet();

  // Determine visible date range based on view mode
  final focused = eventState.focusedDate;
  late DateTime rangeStart;
  late DateTime rangeEnd;

  // The pager keeps the period on either side built, so it can be dragged in
  // under the finger. Loading only the focused period would slide an empty
  // grid in and fill it after the swipe settles, so every range reaches one
  // period back and one period forward.
  switch (eventState.viewMode) {
    case CalendarViewMode.day:
      final day = DateTime(focused.year, focused.month, focused.day);
      rangeStart = DateTime(day.year, day.month, day.day - 1);
      rangeEnd = DateTime(day.year, day.month, day.day + 2);
    case CalendarViewMode.threeDay:
      // The focused day is the left column of the page, so the page covers
      // the three days from it — plus the page before and after, which the
      // pager keeps built either side of the finger.
      final first = DateTime(focused.year, focused.month, focused.day);
      rangeStart = DateTime(
        first.year,
        first.month,
        first.day - threeDayColumns,
      );
      rangeEnd = DateTime(
        first.year,
        first.month,
        first.day + threeDayColumns * 2,
      );
    case CalendarViewMode.week:
      // The week the grid draws, not a Monday week — otherwise the first
      // column of a Sunday week would be outside the loaded range and look
      // empty.
      final week = startOfWeek(focused, settings.calendarWeekStart);
      rangeStart = DateTime(week.year, week.month, week.day - 7);
      rangeEnd = DateTime(week.year, week.month, week.day + 14);
    case CalendarViewMode.month:
      // A month grid draws six full weeks, so it already shows days of the
      // month before and after — those were empty until this range grew.
      rangeStart = DateTime(focused.year, focused.month - 1, 1);
      rangeEnd = DateTime(focused.year, focused.month + 2, 1);
    case CalendarViewMode.agenda:
      // Agenda is the running list of what is coming: everything with a date
      // in the next three months, events and dated tasks alike.
      rangeStart = DateTime(focused.year, focused.month, focused.day);
      rangeEnd = rangeStart.add(const Duration(days: 90));
  }

  final items = <CalendarItem>[];

  // Collect exception originalStartTimes for each parent to exclude from expansion
  final exceptionsByParent = <String, Set<String>>{};
  for (final event in eventState.events) {
    if (event.isException &&
        event.recurrenceId != null &&
        event.originalStartTime != null) {
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
    if (event.calendarId != null &&
        knownCalendarIds.contains(event.calendarId) &&
        !visibleCalendarIds.contains(event.calendarId)) {
      continue;
    }

    // A feed switched off in the drawer must disappear from every view too.
    if (event.calendarId != null && hiddenFeedIds.contains(event.calendarId)) {
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
        items.add(
          EventItem(
            event: event,
            occurrenceStart: occurrence,
            occurrenceEnd: occurrence.add(event.duration),
          ),
        );
      }
    } else if (!event.isException) {
      // Regular non-recurring event
      if (event.startTime.isBefore(rangeEnd) &&
          event.endTime.isAfter(rangeStart)) {
        items.add(EventItem(event: event));
      }
    } else {
      // Exception event (modified occurrence)
      if (event.startTime.isBefore(rangeEnd) &&
          event.endTime.isAfter(rangeStart)) {
        items.add(EventItem(event: event));
      }
    }
  }

  // Add todos with due dates
  for (final todo in todoState.todos) {
    if (todo.isCompleted || todo.dueDate == null) continue;
    final todoDay = DateTime(
      todo.dueDate!.year,
      todo.dueDate!.month,
      todo.dueDate!.day,
    );
    if (todoDay.isBefore(rangeEnd) &&
        todoDay.add(const Duration(days: 1)).isAfter(rangeStart)) {
      items.add(TodoItem(todo: todo));
    }
  }

  // Sort by start time
  items.sort((a, b) => a.startTime.compareTo(b.startTime));

  return CalendarItemsState(
    items: items,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
  );
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
