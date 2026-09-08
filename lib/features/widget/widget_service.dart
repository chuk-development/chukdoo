import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/platform_utils.dart';
import '../calendar/domain/models/calendar.dart';
import '../calendar/domain/models/calendar_event.dart';
import '../calendar/domain/models/rrule_helper.dart';
import '../calendar/services/ics_feed_service.dart';
import '../habits/domain/models/habit.dart';
import '../notes/domain/markdown_preview.dart';
import '../notes/domain/models/note.dart';
import '../sync/services/sync_service.dart';
import '../todos/domain/models/todo.dart';

/// One instruction that arrived from a home screen widget tap.
///
/// [name] is the verb, [id] the entity it points at (a todo id, a note id) and
/// [date] an ISO day for the calendar. Only [name] is ever set for the plain
/// "open this section" taps.
@immutable
class WidgetAction {
  final String name;
  final String? id;
  final String? date;

  const WidgetAction(this.name, {this.id, this.date});

  static WidgetAction? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['action'];
    if (name is! String || name.isEmpty) return null;
    return WidgetAction(
      name,
      id: raw['id'] as String?,
      date: raw['date'] as String?,
    );
  }

  @override
  String toString() => 'WidgetAction($name, id: $id, date: $date)';
}

/// Feeds the four Android home screen widgets and applies what they wrote back.
///
/// ## How the data gets there
/// Every widget reads plain JSON out of the app's `FlutterSharedPreferences`
/// file — the same trick [SunriseExportService] uses. No Flutter engine has to
/// run for a widget to draw itself, which is the whole point: the launcher can
/// redraw a widget at any time, including right after a reboot.
///
/// ## How a tick gets back
/// A widget cannot write into Hive: Hive lives in the Dart isolate and there is
/// no engine when a broadcast receiver runs. So a tick is queued as a *pending
/// action* in the same preferences file and applied by [processPending] the
/// next time the app starts or resumes. The widget updates its own JSON
/// optimistically, so the row already looks ticked while the app is closed.
///
/// Limit of that design: the change reaches Supabase only once the app is
/// opened again. It is never lost — the queue survives a reboot — it is just
/// not instant.
class WidgetService {
  const WidgetService._();

  static const _platform = MethodChannel('doo.chuk.dev/widget');

  // Data the widgets read.
  static const _keyTasks = 'widget_tasks';
  static const _keyCalendar = 'widget_calendar';
  static const _keyNotes = 'widget_notes';
  static const _keyHabits = 'widget_habits';
  static const _keyUpdatedAt = 'widget_updated_at';

  // Actions the widgets write.
  static const _keyPendingTasks = 'widget_pending_tasks';
  static const _keyPendingHabits = 'widget_pending_habits';

  /// How many rows each widget carries. A home screen widget is never taller
  /// than a screen, and every extra row costs a RemoteViews round trip.
  static const _maxTasks = 15;
  static const _maxCalendar = 15;
  static const _maxNotes = 10;
  static const _maxHabits = 12;

  static final StreamController<WidgetAction> _actions =
      StreamController<WidgetAction>.broadcast();

  /// Taps on a widget that want the app to go somewhere.
  static Stream<WidgetAction> get actions => _actions.stream;

  static bool _handlerInstalled = false;

  /// Start listening for widget taps. Safe to call more than once.
  static void installActionHandler() {
    if (_handlerInstalled || !PlatformUtils.isAndroid) return;
    _handlerInstalled = true;
    _platform.setMethodCallHandler((call) async {
      if (call.method == 'widgetAction') {
        final action = WidgetAction.fromMap(call.arguments);
        if (action != null) _actions.add(action);
      }
      return null;
    });
  }

  /// The tap that launched the app, if it was launched from a widget. Returns
  /// null on every later call — the action is consumed on the native side.
  static Future<WidgetAction?> takeLaunchAction() async {
    if (!PlatformUtils.isAndroid) return null;
    try {
      final raw = await _platform.invokeMethod<Map<Object?, Object?>>(
        'takeLaunchAction',
      );
      return WidgetAction.fromMap(raw);
    } catch (_) {
      return null;
    }
  }

  // ── Keeping the data fresh ────────────────────────────────────────────────

  static final List<StreamSubscription<BoxEvent>> _boxSubs = [];
  static Timer? _debounce;
  static bool _watching = false;

  /// Refresh the widgets whenever anything they show changes.
  ///
  /// Watching the Hive boxes instead of calling [updateAll] from every
  /// notifier is what keeps this feature out of the rest of the code: a sync
  /// pull, an undo and a swipe all land in the same place.
  static void startWatching() {
    if (!PlatformUtils.isAndroid || _watching) return;
    _watching = true;
    for (final name in const [
      AppConstants.hiveTodosBox,
      AppConstants.hiveNotesBox,
      AppConstants.hiveHabitsBox,
      AppConstants.hiveCalendarEventsBox,
      AppConstants.hiveCalendarsBox,
      AppConstants.hiveIcsFeedsBox,
    ]) {
      if (!Hive.isBoxOpen(name)) continue;
      _boxSubs.add(
        Hive.box<Map>(name).watch().listen((_) => _scheduleUpdate()),
      );
    }
    updateAll();
  }

  static void _scheduleUpdate() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), updateAll);
  }

  /// Only used by tests and a full sign-out.
  static Future<void> stopWatching() async {
    _debounce?.cancel();
    for (final sub in _boxSubs) {
      await sub.cancel();
    }
    _boxSubs.clear();
    _watching = false;
  }

  // ── Writing the data ──────────────────────────────────────────────────────

  /// Refresh every widget. Cheap: four Hive boxes read in memory.
  static Future<void> updateAll() async {
    if (!PlatformUtils.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyTasks, jsonEncode(_buildTasks()));
      await prefs.setString(_keyCalendar, jsonEncode(_buildCalendar()));
      await prefs.setString(_keyNotes, jsonEncode(_buildNotes()));
      await prefs.setString(_keyHabits, jsonEncode(_buildHabits()));
      await prefs.setInt(_keyUpdatedAt, DateTime.now().millisecondsSinceEpoch);
      await _notify();
    } catch (e) {
      debugPrint('WidgetService.updateAll: $e');
    }
  }

  /// Tasks changed: that moves both the task list and the calendar.
  static Future<void> updateWidget() => updateAll();

  /// Drop every widget's data (sign-out).
  static Future<void> clearWidget() async {
    if (!PlatformUtils.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in [_keyTasks, _keyCalendar, _keyNotes, _keyHabits]) {
        await prefs.remove(key);
      }
      await _notify();
    } catch (e) {
      debugPrint('WidgetService.clearWidget: $e');
    }
  }

  static Future<void> _notify() async {
    try {
      await _platform.invokeMethod('updateWidgets');
    } catch (_) {
      // No engine attached (background isolate) or no channel — the launcher
      // picks the new data up on its own next update.
    }
  }

  // ── Payload builders ──────────────────────────────────────────────────────

  static String _hhmm(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static String _isoDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static List<Todo> _allTodos() {
    final box = Hive.box<Map>(AppConstants.hiveTodosBox);
    return box.values
        .map((m) => Todo.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// The main list: everything open that is not filed under a project, in the
  /// order the app itself shows it (pinned, then sortOrder, then newest).
  static List<Map<String, Object?>> _buildTasks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todos =
        _allTodos().where((t) => !t.isCompleted && t.projectId == null).toList()
          ..sort((a, b) {
            if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
            final order = a.sortOrder.compareTo(b.sortOrder);
            if (order != 0) return order;
            return b.createdAt.compareTo(a.createdAt);
          });

    return todos.take(_maxTasks).map((t) {
      final due = t.dueDate;
      final dueDay = due == null
          ? null
          : DateTime(due.year, due.month, due.day);
      return <String, Object?>{
        'id': t.id,
        'title': t.title,
        'time': t.dueTime == null
            ? null
            : _hhmm(t.dueTime!.hour, t.dueTime!.minute),
        'date': dueDay == null ? null : _dueLabel(dueDay, today, t.dueTime),
        'priority': t.priority.value,
        'overdue': dueDay != null && dueDay.isBefore(today),
        'pinned': t.isPinned,
        'is_completed': false,
      };
    }).toList();
  }

  /// "Today", "Tomorrow", "Mon 14 Sep" — plus the time when there is one.
  static String _dueLabel(DateTime day, DateTime today, TimeOfDay? time) {
    final diff = day.difference(today).inDays;
    final label = switch (diff) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      _ => '${_weekday(day)} ${day.day} ${_month(day)}',
    };
    if (time == null) return label;
    return '$label · ${_hhmm(time.hour, time.minute)}';
  }

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _weekday(DateTime d) => _weekdays[d.weekday - 1];
  static String _month(DateTime d) => _months[d.month - 1];

  /// What is still coming today, then everything tomorrow. Events and dated
  /// tasks alike, exactly like the agenda view.
  static Map<String, Object?> _buildCalendar() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final rangeEnd = DateTime(now.year, now.month, now.day + 2);

    // Which calendars and feeds are switched on.
    final calendarBox = Hive.box<Map>(AppConstants.hiveCalendarsBox);
    final calendars = calendarBox.values
        .map((m) => Calendar.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    final knownIds = {for (final c in calendars) c.id};
    final visibleIds = {
      for (final c in calendars)
        if (c.isVisible) c.id,
    };
    final colorOfCalendar = {for (final c in calendars) c.id: c.color};
    final hiddenFeedIds = {
      for (final f in IcsFeedService.feeds)
        if (!f.isVisible) f.id,
    };

    final eventBox = Hive.box<Map>(AppConstants.hiveCalendarEventsBox);
    final events = eventBox.values
        .map((m) => CalendarEvent.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    // A modified occurrence replaces the one the rule would produce.
    final exceptionDays = <String, Set<String>>{};
    for (final e in events) {
      if (e.isException &&
          e.recurrenceId != null &&
          e.originalStartTime != null) {
        final date = DateTime.tryParse(e.originalStartTime!);
        if (date != null) {
          exceptionDays
              .putIfAbsent(e.recurrenceId!, () => {})
              .add(_isoDay(date));
        }
      }
    }

    final items = <Map<String, Object?>>[];

    void addEvent(CalendarEvent e, DateTime start, DateTime end) {
      if (!start.isBefore(rangeEnd) || !end.isAfter(today)) return;
      final color = e.color != 0
          ? e.color
          : (colorOfCalendar[e.calendarId] ?? 0xFFE7E7EC);
      items.add({
        'id': e.id,
        'kind': 'event',
        'title': e.title,
        'start': start.millisecondsSinceEpoch,
        'time': e.isAllDay ? null : _hhmm(start.hour, start.minute),
        'end': e.isAllDay ? null : _hhmm(end.hour, end.minute),
        'all_day': e.isAllDay,
        'color': _hex(color),
        'day': _isoDay(DateTime(start.year, start.month, start.day)),
      });
    }

    for (final e in events) {
      if (e.calendarId != null &&
          knownIds.contains(e.calendarId) &&
          !visibleIds.contains(e.calendarId)) {
        continue;
      }
      if (e.calendarId != null && hiddenFeedIds.contains(e.calendarId)) {
        continue;
      }
      if (e.isException && e.title == '__DELETED__') continue;

      if (e.isRecurring && !e.isException) {
        final occurrences = RRuleHelper.expandOccurrences(
          e.startTime,
          e.recurrenceRule!,
          today,
          rangeEnd,
          excludedDates: exceptionDays[e.id],
        );
        for (final start in occurrences) {
          addEvent(e, start, start.add(e.duration));
        }
      } else {
        addEvent(e, e.startTime, e.endTime);
      }
    }

    for (final t in _allTodos()) {
      if (t.isCompleted || t.dueDate == null) continue;
      final day = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      if (day.isBefore(today) || !day.isBefore(rangeEnd)) continue;
      final start = t.dueTime == null
          ? day
          : DateTime(
              day.year,
              day.month,
              day.day,
              t.dueTime!.hour,
              t.dueTime!.minute,
            );
      items.add({
        'id': t.id,
        'kind': 'task',
        'title': t.title,
        'start': start.millisecondsSinceEpoch,
        'time': t.dueTime == null
            ? null
            : _hhmm(t.dueTime!.hour, t.dueTime!.minute),
        'end': null,
        'all_day': t.dueTime == null,
        'color': _hex(_priorityColor(t.priority.value)),
        'day': _isoDay(day),
      });
    }

    // Today's past entries are noise on a home screen; an all-day entry stays
    // until the day is over.
    final nowMs = now.millisecondsSinceEpoch;
    items.removeWhere((i) {
      if (i['day'] != _isoDay(today)) return false;
      if (i['all_day'] == true) return false;
      return (i['start'] as int) <
          nowMs - const Duration(minutes: 30).inMilliseconds;
    });

    items.sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));

    return {
      'today': _isoDay(today),
      'tomorrow': _isoDay(tomorrow),
      'header': '${_weekday(today)}, ${today.day} ${_month(today)}',
      'items': items.take(_maxCalendar).toList(),
    };
  }

  static int _priorityColor(int priority) => switch (priority) {
    1 => 0xFFFF5252,
    2 => 0xFFFFB74D,
    3 => 0xFF64B5F6,
    _ => 0xFF8C90A0,
  };

  /// The most recently edited notes, title plus a plain-text snippet.
  static List<Map<String, Object?>> _buildNotes() {
    final box = Hive.box<Map>(AppConstants.hiveNotesBox);
    final notes =
        box.values
            .map((m) => Note.fromJson(Map<String, dynamic>.from(m)))
            .where((n) => !n.isEmpty)
            .toList()
          ..sort((a, b) {
            if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
            return b.updatedAt.compareTo(a.updatedAt);
          });

    return notes.take(_maxNotes).map((n) {
      final plain = markdownToPlainText(n.content).replaceAll('\n', ' ').trim();
      final title = n.title.trim().isNotEmpty
          ? n.title.trim()
          : (plain.isEmpty ? 'Untitled' : _firstWords(plain, 40));
      final snippet = n.title.trim().isNotEmpty
          ? plain
          : plain.length > 40
          ? plain.substring(40).trim()
          : '';
      return <String, Object?>{
        'id': n.id,
        'title': title,
        'snippet': _firstWords(snippet, 120),
        'pinned': n.isPinned,
        'color': n.color == null ? null : _hex(n.color!),
      };
    }).toList();
  }

  static String _firstWords(String text, int max) {
    if (text.length <= max) return text;
    return '${text.substring(0, max).trimRight()}…';
  }

  /// Today's habits, with the streak and whether they are already ticked.
  static List<Map<String, Object?>> _buildHabits() {
    final box = Hive.box<Map>(AppConstants.hiveHabitsBox);
    final habits =
        box.values
            .map((m) => Habit.fromJson(Map<String, dynamic>.from(m)))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final today = _isoDay(DateTime.now());

    final rows = habits.map((h) {
      final done = h.completions.contains(today);
      return <String, Object?>{
        'id': h.id,
        'name': h.name,
        'streak': h.calculateStreak(),
        'done': done,
        'frequency': h.frequency,
        'color': _hex(h.color),
      };
    }).toList();

    // Open ones first — a widget's first row is the one that gets tapped.
    rows.sort((a, b) {
      final ad = a['done'] == true ? 1 : 0;
      final bd = b['done'] == true ? 1 : 0;
      return ad.compareTo(bd);
    });

    return rows.take(_maxHabits).toList();
  }

  // ── Applying what the widgets wrote ───────────────────────────────────────

  /// Apply every tick that happened on a widget while the app was closed.
  /// Returns true when something actually changed, so the caller knows whether
  /// it has to refresh its providers.
  static Future<bool> processPending() async {
    if (!PlatformUtils.isAndroid) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      // The widget writes straight into the preferences file; Flutter's
      // in-memory cache does not see that without a reload.
      await prefs.reload();

      final tasks = _decodeMap(prefs.getString(_keyPendingTasks));
      final habits = _decodeMap(prefs.getString(_keyPendingHabits));
      if (tasks.isEmpty && habits.isEmpty) return false;

      var mutated = false;
      if (tasks.isNotEmpty) mutated |= await _applyTaskActions(tasks);
      if (habits.isNotEmpty) mutated |= await _applyHabitActions(habits);

      await prefs.remove(_keyPendingTasks);
      await prefs.remove(_keyPendingHabits);
      if (mutated) await updateAll();
      return mutated;
    } catch (e) {
      debugPrint('WidgetService.processPending: $e');
      return false;
    }
  }

  static Map<String, bool> _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return {
          for (final e in decoded.entries)
            if (e.key is String && e.value is bool)
              e.key as String: e.value as bool,
        };
      }
    } catch (_) {}
    return const {};
  }

  static Future<bool> _applyTaskActions(Map<String, bool> actions) async {
    final box = Hive.box<Map>(AppConstants.hiveTodosBox);
    final now = DateTime.now();
    var mutated = false;

    for (final entry in actions.entries) {
      final raw = box.get(entry.key);
      if (raw == null) continue;
      final todo = Todo.fromJson(Map<String, dynamic>.from(raw));
      if (todo.isCompleted == entry.value) continue;
      final updated = todo.copyWith(
        isCompleted: entry.value,
        completedAt: entry.value ? now : null,
        updatedAt: now,
      );
      await box.put(updated.id, updated.toJson());
      await SyncService.queueOperation(
        entityType: SyncEntityType.todo,
        operation: SyncOperation.update,
        entityId: updated.id,
        data: updated.toJson(),
      );
      mutated = true;
    }
    return mutated;
  }

  /// Keys are `<habitId>|<yyyy-MM-dd>`; the value says whether that day should
  /// end up completed.
  static Future<bool> _applyHabitActions(Map<String, bool> actions) async {
    final box = Hive.box<Map>(AppConstants.hiveHabitsBox);
    var mutated = false;

    for (final entry in actions.entries) {
      final parts = entry.key.split('|');
      if (parts.length != 2) continue;
      final raw = box.get(parts[0]);
      if (raw == null) continue;
      final habit = Habit.fromJson(Map<String, dynamic>.from(raw));
      final has = habit.completions.contains(parts[1]);
      if (has == entry.value) continue;

      final completions = entry.value
          ? [...habit.completions, parts[1]]
          : habit.completions.where((c) => c != parts[1]).toList();
      var updated = habit.copyWith(
        completions: completions,
        updatedAt: DateTime.now(),
        version: habit.version + 1,
      );
      updated = updated.copyWith(streak: updated.calculateStreak());

      await box.put(updated.id, updated.toJson());
      await SyncService.queueOperation(
        entityType: SyncEntityType.habit,
        operation: SyncOperation.update,
        entityId: updated.id,
        data: updated.toJson(),
      );
      mutated = true;
    }
    return mutated;
  }
}
