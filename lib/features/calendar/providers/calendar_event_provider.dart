import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/services/supabase_service.dart';
import '../../sync/services/sync_service.dart';
import '../domain/models/calendar_event.dart';

enum CalendarViewMode { day, week, month, agenda }

class CalendarEventState {
  final List<CalendarEvent> events;
  final CalendarViewMode viewMode;
  final DateTime focusedDate;
  final DateTime? selectedDate;
  final bool isLoading;
  final String? error;

  CalendarEventState({
    this.events = const [],
    this.viewMode = CalendarViewMode.week,
    DateTime? focusedDate,
    this.selectedDate,
    this.isLoading = false,
    this.error,
  }) : focusedDate = focusedDate ?? DateTime.now();

  CalendarEventState copyWith({
    List<CalendarEvent>? events,
    CalendarViewMode? viewMode,
    DateTime? focusedDate,
    DateTime? selectedDate,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearSelectedDate = false,
  }) {
    return CalendarEventState(
      events: events ?? this.events,
      viewMode: viewMode ?? this.viewMode,
      focusedDate: focusedDate ?? this.focusedDate,
      selectedDate: clearSelectedDate ? null : (selectedDate ?? this.selectedDate),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  List<CalendarEvent> eventsForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return events.where((e) {
      return e.startTime.isBefore(dayEnd) && e.endTime.isAfter(dayStart);
    }).toList();
  }

  List<CalendarEvent> eventsForDateRange(DateTime start, DateTime end) {
    return events.where((e) {
      return e.startTime.isBefore(end) && e.endTime.isAfter(start);
    }).toList();
  }

  List<CalendarEvent> get allDayEvents =>
      events.where((e) => e.isAllDay).toList();

  List<CalendarEvent> timedEventsForDay(DateTime day) {
    return eventsForDay(day).where((e) => !e.isAllDay).toList();
  }
}

class CalendarEventNotifier extends StateNotifier<CalendarEventState> {
  CalendarEventNotifier() : super(CalendarEventState()) {
    _loadEvents();
  }

  Box<Map>? _box;
  final _uuid = const Uuid();

  Box<Map> get _eventsBox {
    _box ??= Hive.box<Map>(AppConstants.hiveCalendarEventsBox);
    return _box!;
  }

  Future<void> _loadEvents() async {
    state = state.copyWith(isLoading: true);

    try {
      final maps = _eventsBox.values.toList();
      final events = maps.map((m) {
        final map = Map<String, dynamic>.from(m);
        return CalendarEvent.fromJson(map);
      }).toList();

      events.sort((a, b) => a.startTime.compareTo(b.startTime));

      state = state.copyWith(events: events, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await _loadEvents();
  }

  Future<void> addEvent({
    required String title,
    String? description,
    String? location,
    String? calendarId,
    required DateTime startTime,
    required DateTime endTime,
    bool isAllDay = false,
    int color = 0,
    String? recurrenceRule,
    List<int> reminderMinutes = const [],
  }) async {
    final userId = SupabaseService.currentUser?.id ?? 'local';
    final now = DateTime.now();

    final event = CalendarEvent(
      id: _uuid.v4(),
      userId: userId,
      calendarId: calendarId,
      title: title,
      description: description,
      location: location,
      startTime: startTime,
      endTime: endTime,
      isAllDay: isAllDay,
      color: color,
      recurrenceRule: recurrenceRule,
      reminderMinutes: reminderMinutes,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );

    await _eventsBox.put(event.id, event.toJson());

    await SyncService.queueOperation(
      entityType: SyncEntityType.calendarEvent,
      operation: SyncOperation.create,
      entityId: event.id,
      data: event.toJson(),
    );

    state = state.copyWith(
      events: [...state.events, event]..sort((a, b) => a.startTime.compareTo(b.startTime)),
    );
  }

  Future<void> updateEvent(CalendarEvent event) async {
    final updated = event.copyWith(updatedAt: DateTime.now());

    await _eventsBox.put(updated.id, updated.toJson());

    await SyncService.queueOperation(
      entityType: SyncEntityType.calendarEvent,
      operation: SyncOperation.update,
      entityId: updated.id,
      data: updated.toJson(),
    );

    final events = state.events.map((e) {
      return e.id == updated.id ? updated : e;
    }).toList();

    state = state.copyWith(events: events);
  }

  Future<void> deleteEvent(String eventId) async {
    await _eventsBox.delete(eventId);

    await SyncService.queueOperation(
      entityType: SyncEntityType.calendarEvent,
      operation: SyncOperation.delete,
      entityId: eventId,
    );

    final events = state.events.where((e) => e.id != eventId).toList();
    state = state.copyWith(events: events);
  }

  /// Move an event to a new time (preserves duration) — for drag-and-drop
  Future<void> moveEvent(String eventId, DateTime newStart) async {
    final idx = state.events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return;
    final event = state.events[idx];
    final duration = event.duration;
    final updated = event.copyWith(
      startTime: newStart,
      endTime: newStart.add(duration),
    );
    await updateEvent(updated);
  }

  /// Resize an event (change end time) — for drag-to-resize
  Future<void> resizeEvent(String eventId, DateTime newEnd) async {
    final idx = state.events.indexWhere((e) => e.id == eventId);
    if (idx == -1) return;
    final event = state.events[idx];
    if (newEnd.isAfter(event.startTime)) {
      final updated = event.copyWith(endTime: newEnd);
      await updateEvent(updated);
    }
  }

  /// Create an exception for a single occurrence of a recurring event
  Future<void> editSingleOccurrence(
    CalendarEvent parentEvent,
    DateTime occurrenceStart, {
    String? title,
    String? description,
    String? location,
    DateTime? newStart,
    DateTime? newEnd,
  }) async {
    final userId = SupabaseService.currentUser?.id ?? 'local';
    final now = DateTime.now();
    final duration = parentEvent.duration;

    final exception = CalendarEvent(
      id: _uuid.v4(),
      userId: userId,
      calendarId: parentEvent.calendarId,
      title: title ?? parentEvent.title,
      description: description ?? parentEvent.description,
      location: location ?? parentEvent.location,
      startTime: newStart ?? occurrenceStart,
      endTime: newEnd ?? (newStart ?? occurrenceStart).add(duration),
      isAllDay: parentEvent.isAllDay,
      color: parentEvent.color,
      recurrenceId: parentEvent.id,
      originalStartTime: occurrenceStart.toIso8601String(),
      reminderMinutes: parentEvent.reminderMinutes,
      createdAt: now,
      updatedAt: now,
    );

    await _eventsBox.put(exception.id, exception.toJson());

    await SyncService.queueOperation(
      entityType: SyncEntityType.calendarEvent,
      operation: SyncOperation.create,
      entityId: exception.id,
      data: exception.toJson(),
    );

    state = state.copyWith(
      events: [...state.events, exception]..sort((a, b) => a.startTime.compareTo(b.startTime)),
    );
  }

  /// Delete a single occurrence of a recurring event
  Future<void> deleteSingleOccurrence(
    CalendarEvent parentEvent,
    DateTime occurrenceStart,
  ) async {
    // Create a "deleted" exception (marker)
    await editSingleOccurrence(
      parentEvent,
      occurrenceStart,
      title: '__DELETED__',
    );
  }

  /// Edit this and all following occurrences (split the RRULE)
  Future<void> editThisAndFollowing(
    CalendarEvent parentEvent,
    DateTime fromOccurrence, {
    String? title,
    String? description,
    String? location,
    String? recurrenceRule,
  }) async {
    // 1. End the parent's recurrence before the edit point
    final untilDate = fromOccurrence.subtract(const Duration(days: 1));
    final existingRule = parentEvent.recurrenceRule ?? '';
    final truncatedRule = existingRule.contains('UNTIL')
        ? existingRule.replaceFirst(RegExp(r'UNTIL=[^;]+'), 'UNTIL=${_formatUntilDate(untilDate)}')
        : '$existingRule;UNTIL=${_formatUntilDate(untilDate)}';
    await updateEvent(parentEvent.copyWith(recurrenceRule: truncatedRule));

    // 2. Create a new recurring event starting from the edit point
    await addEvent(
      title: title ?? parentEvent.title,
      description: description ?? parentEvent.description,
      location: location ?? parentEvent.location,
      calendarId: parentEvent.calendarId,
      startTime: fromOccurrence,
      endTime: fromOccurrence.add(parentEvent.duration),
      isAllDay: parentEvent.isAllDay,
      color: parentEvent.color,
      recurrenceRule: recurrenceRule ?? parentEvent.recurrenceRule,
      reminderMinutes: parentEvent.reminderMinutes,
    );
  }

  // View state management
  void setViewMode(CalendarViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  void setFocusedDate(DateTime date) {
    state = state.copyWith(focusedDate: date);
  }

  void setSelectedDate(DateTime? date) {
    if (date == null) {
      state = state.copyWith(clearSelectedDate: true);
    } else {
      state = state.copyWith(selectedDate: date);
    }
  }

  void goToToday() {
    state = state.copyWith(focusedDate: DateTime.now());
  }

  String _formatUntilDate(DateTime date) {
    return '${date.year}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}'
        'T235959Z';
  }
}

final calendarEventProvider =
    StateNotifierProvider<CalendarEventNotifier, CalendarEventState>((ref) {
  return CalendarEventNotifier();
});
