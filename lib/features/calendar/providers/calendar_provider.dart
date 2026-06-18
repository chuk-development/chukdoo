import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/services/supabase_service.dart';
import '../../sync/services/sync_service.dart';
import '../domain/models/calendar.dart';

class CalendarContainerState {
  final List<Calendar> calendars;
  final bool isLoading;
  final String? error;

  const CalendarContainerState({
    this.calendars = const [],
    this.isLoading = false,
    this.error,
  });

  CalendarContainerState copyWith({
    List<Calendar>? calendars,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return CalendarContainerState(
      calendars: calendars ?? this.calendars,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  Calendar? get defaultCalendar =>
      calendars.where((c) => c.isDefault).firstOrNull;

  List<Calendar> get visibleCalendars =>
      calendars.where((c) => c.isVisible).toList();
}

class CalendarContainerNotifier extends StateNotifier<CalendarContainerState> {
  CalendarContainerNotifier() : super(const CalendarContainerState()) {
    _loadCalendars();
  }

  Box<Map>? _box;
  final _uuid = const Uuid();

  Box<Map> get _calendarsBox {
    _box ??= Hive.box<Map>(AppConstants.hiveCalendarsBox);
    return _box!;
  }

  Future<void> _loadCalendars() async {
    state = state.copyWith(isLoading: true);

    try {
      final maps = _calendarsBox.values.toList();
      final calendars = maps.map((m) {
        final map = Map<String, dynamic>.from(m);
        return Calendar.fromJson(map);
      }).toList();

      calendars.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      state = state.copyWith(calendars: calendars, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await _loadCalendars();
  }

  Future<Calendar> addCalendar({
    required String name,
    String? description,
    int color = 0xFF4285F4,
    bool isDefault = false,
  }) async {
    final userId = SupabaseService.currentUser?.id ?? 'local';
    final now = DateTime.now();

    final calendar = Calendar(
      id: _uuid.v4(),
      userId: userId,
      name: name,
      description: description,
      color: color,
      isDefault: isDefault,
      sortOrder: state.calendars.length,
      createdAt: now,
      updatedAt: now,
    );

    await _calendarsBox.put(calendar.id, calendar.toJson());

    await SyncService.queueOperation(
      entityType: SyncEntityType.calendar,
      operation: SyncOperation.create,
      entityId: calendar.id,
      data: calendar.toJson(),
    );

    state = state.copyWith(
      calendars: [...state.calendars, calendar],
    );

    return calendar;
  }

  Future<void> updateCalendar(Calendar calendar) async {
    final updated = calendar.copyWith(updatedAt: DateTime.now());

    await _calendarsBox.put(updated.id, updated.toJson());

    await SyncService.queueOperation(
      entityType: SyncEntityType.calendar,
      operation: SyncOperation.update,
      entityId: updated.id,
      data: updated.toJson(),
    );

    final calendars = state.calendars.map((c) {
      return c.id == updated.id ? updated : c;
    }).toList();

    state = state.copyWith(calendars: calendars);
  }

  Future<void> deleteCalendar(String calendarId) async {
    await _calendarsBox.delete(calendarId);

    await SyncService.queueOperation(
      entityType: SyncEntityType.calendar,
      operation: SyncOperation.delete,
      entityId: calendarId,
    );

    final calendars = state.calendars.where((c) => c.id != calendarId).toList();
    state = state.copyWith(calendars: calendars);
  }

  Future<void> toggleVisibility(String calendarId) async {
    final calendar = state.calendars.firstWhere((c) => c.id == calendarId);
    await updateCalendar(calendar.copyWith(isVisible: !calendar.isVisible));
  }

  /// Ensure a default calendar exists
  Future<Calendar> ensureDefaultCalendar() async {
    final existing = state.defaultCalendar;
    if (existing != null) return existing;

    return addCalendar(
      name: 'Kalender',
      isDefault: true,
      color: 0xFF4285F4,
    );
  }
}

final calendarContainerProvider =
    StateNotifierProvider<CalendarContainerNotifier, CalendarContainerState>((ref) {
  return CalendarContainerNotifier();
});
