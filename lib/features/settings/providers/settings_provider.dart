import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/app_constants.dart';

/// Checkbox size options
/// Row density of the task lists. [medium] is the default look; [small] fits
/// more tasks on screen, [large] gives a bigger tap target.
enum CheckboxSize {
  small,
  medium,
  large;

  /// Diameter of the circle.
  double get circle => switch (this) {
    CheckboxSize.small => 20,
    CheckboxSize.medium => 23,
    CheckboxSize.large => 28,
  };

  /// Vertical padding of a task row.
  double get rowPadding => switch (this) {
    CheckboxSize.small => 8,
    CheckboxSize.medium => 11,
    CheckboxSize.large => 15,
  };

  /// Title size of a task row.
  double get titleSize => switch (this) {
    CheckboxSize.small => 15,
    CheckboxSize.medium => 16,
    CheckboxSize.large => 17,
  };

  String get label => switch (this) {
    CheckboxSize.small => 'Small',
    CheckboxSize.medium => 'Medium',
    CheckboxSize.large => 'Large',
  };
}

/// View the calendar opens with.
///
/// Deliberately its own enum instead of the calendar's `CalendarViewMode`: the
/// settings layer must not depend on a feature's provider. The names match, so
/// the calendar maps it with `CalendarViewMode.values.byName(setting.name)`.
enum CalendarDefaultView {
  day,
  week,
  month,
  agenda,
  // Appended instead of inserted after `day`, where the switcher shows it:
  // the setting is persisted by enum index, so a new value in the middle
  // would silently turn everybody's saved "Month" into "Week". [ordered]
  // carries the order the user sees.
  threeDay;

  /// The views in the order the calendar's own switcher offers them.
  static const List<CalendarDefaultView> ordered = [
    day,
    threeDay,
    week,
    month,
    agenda,
  ];

  String get label => switch (this) {
    CalendarDefaultView.day => 'Day',
    CalendarDefaultView.threeDay => '3 days',
    CalendarDefaultView.week => 'Week',
    CalendarDefaultView.month => 'Month',
    CalendarDefaultView.agenda => 'Agenda',
  };
}

/// First column of a week grid / habit week.
enum WeekStart {
  monday,
  sunday;

  String get label => switch (this) {
    WeekStart.monday => 'Monday',
    WeekStart.sunday => 'Sunday',
  };

  /// `DateTime.monday` (1) or `DateTime.sunday` (7) — the value a date
  /// calculation needs.
  int get weekday =>
      this == WeekStart.monday ? DateTime.monday : DateTime.sunday;
}

/// Order the notes list uses before pinning and manual order are applied.
enum NoteSort {
  updated,
  created,
  title;

  String get label => switch (this) {
    NoteSort.updated => 'Last edited',
    NoteSort.created => 'Date created',
    NoteSort.title => 'Title',
  };
}

/// State a note opens in when it is tapped.
enum NoteOpenMode {
  preview,
  edit;

  String get label => switch (this) {
    NoteOpenMode.preview => 'Preview',
    NoteOpenMode.edit => 'Edit',
  };
}

/// Shape of the notes overview.
enum NoteLayout {
  grid,
  list;

  String get label => switch (this) {
    NoteLayout.grid => 'Grid',
    NoteLayout.list => 'List',
  };
}

/// User settings stored locally
class AppSettings {
  /// Size of the checkbox circle in todo items
  final CheckboxSize checkboxSize;

  /// User-chosen name for the main list (formerly "Eingang").
  final String mainListName;

  /// All tag names the user has ever used — drives autocomplete suggestions.
  final List<String> knownTags;

  /// When true, recolor accent + surfaces from the system wallpaper palette
  /// (Material You) instead of the default platinum theme.
  final bool materialYou;

  // ── Calendar ─────────────────────────────────────────────────────────────

  /// View the calendar tab opens with.
  final CalendarDefaultView calendarDefaultView;

  /// Leftmost column of the week and month grids.
  final WeekStart calendarWeekStart;

  /// First hour drawn in the day/week grid (0-23).
  final int calendarDayStartHour;

  /// Last hour drawn in the day/week grid (1-24, always after the start).
  final int calendarDayEndHour;

  /// Length a new event gets when the user does not change it.
  final int calendarDefaultEventMinutes;

  /// Lead time of the reminder a new event gets. `null` = no reminder.
  final int? calendarDefaultReminderMinutes;

  /// ISO week numbers in the month/week grid.
  final bool calendarShowWeekNumbers;

  /// Height of one hour row in the day and week grid, in logical pixels.
  ///
  /// A pinch on the grid writes this, so it is a free double instead of a
  /// step: the value settles wherever the fingers left it.
  final double calendarHourHeight;

  // ── Notes ────────────────────────────────────────────────────────────────

  final NoteSort noteSort;
  final NoteOpenMode noteOpenMode;
  final NoteLayout noteLayout;

  /// Folder the notes tab opens filtered to. `null` = all notes.
  final String? noteDefaultFolderId;

  // ── Habits ───────────────────────────────────────────────────────────────

  /// Leftmost column of the habit week strip.
  final WeekStart habitWeekStart;

  /// Daily "did you do it" reminder, in minutes since midnight.
  /// `null` = no reminder.
  final int? habitReminderMinutes;

  /// When true, a day the user marked as skipped does not break the streak.
  final bool habitSkipKeepsStreak;

  const AppSettings({
    this.checkboxSize = CheckboxSize.medium,
    this.mainListName = 'Aufgaben',
    this.knownTags = const [],
    this.materialYou = false,
    this.calendarDefaultView = CalendarDefaultView.month,
    this.calendarWeekStart = WeekStart.monday,
    this.calendarDayStartHour = 7,
    this.calendarDayEndHour = 22,
    this.calendarDefaultEventMinutes = 60,
    this.calendarDefaultReminderMinutes = 10,
    this.calendarShowWeekNumbers = false,
    this.calendarHourHeight = calendarHourHeightDefault,
    this.noteSort = NoteSort.updated,
    this.noteOpenMode = NoteOpenMode.preview,
    this.noteLayout = NoteLayout.grid,
    this.noteDefaultFolderId,
    this.habitWeekStart = WeekStart.monday,
    this.habitReminderMinutes,
    this.habitSkipKeepsStreak = false,
  });

  /// Number of hour rows the day/week grid draws.
  int get calendarDayHourCount => calendarDayEndHour - calendarDayStartHour;

  /// Range a pinch on the day/week grid may reach. Below the minimum an hour
  /// row no longer fits a single line of text, above the maximum barely three
  /// hours are on screen — both ends stop being useful, so the pinch clamps
  /// here and the settings slider offers exactly this span.
  static const double calendarHourHeightMin = 28;
  static const double calendarHourHeightMax = 140;

  /// One hour is 60 logical pixels until the user pinches, like Google
  /// Calendar: a 30 minute meeting still gets two readable lines.
  static const double calendarHourHeightDefault = 60;

  AppSettings copyWith({
    CheckboxSize? checkboxSize,
    String? mainListName,
    List<String>? knownTags,
    bool? materialYou,
    CalendarDefaultView? calendarDefaultView,
    WeekStart? calendarWeekStart,
    int? calendarDayStartHour,
    int? calendarDayEndHour,
    int? calendarDefaultEventMinutes,
    int? calendarDefaultReminderMinutes,
    bool clearCalendarDefaultReminder = false,
    bool? calendarShowWeekNumbers,
    double? calendarHourHeight,
    NoteSort? noteSort,
    NoteOpenMode? noteOpenMode,
    NoteLayout? noteLayout,
    String? noteDefaultFolderId,
    bool clearNoteDefaultFolder = false,
    WeekStart? habitWeekStart,
    int? habitReminderMinutes,
    bool clearHabitReminder = false,
    bool? habitSkipKeepsStreak,
  }) {
    return AppSettings(
      checkboxSize: checkboxSize ?? this.checkboxSize,
      mainListName: mainListName ?? this.mainListName,
      knownTags: knownTags ?? this.knownTags,
      materialYou: materialYou ?? this.materialYou,
      calendarDefaultView: calendarDefaultView ?? this.calendarDefaultView,
      calendarWeekStart: calendarWeekStart ?? this.calendarWeekStart,
      calendarDayStartHour: calendarDayStartHour ?? this.calendarDayStartHour,
      calendarDayEndHour: calendarDayEndHour ?? this.calendarDayEndHour,
      calendarDefaultEventMinutes:
          calendarDefaultEventMinutes ?? this.calendarDefaultEventMinutes,
      calendarDefaultReminderMinutes: clearCalendarDefaultReminder
          ? null
          : (calendarDefaultReminderMinutes ??
                this.calendarDefaultReminderMinutes),
      calendarShowWeekNumbers:
          calendarShowWeekNumbers ?? this.calendarShowWeekNumbers,
      calendarHourHeight: calendarHourHeight ?? this.calendarHourHeight,
      noteSort: noteSort ?? this.noteSort,
      noteOpenMode: noteOpenMode ?? this.noteOpenMode,
      noteLayout: noteLayout ?? this.noteLayout,
      noteDefaultFolderId: clearNoteDefaultFolder
          ? null
          : (noteDefaultFolderId ?? this.noteDefaultFolderId),
      habitWeekStart: habitWeekStart ?? this.habitWeekStart,
      habitReminderMinutes: clearHabitReminder
          ? null
          : (habitReminderMinutes ?? this.habitReminderMinutes),
      habitSkipKeepsStreak: habitSkipKeepsStreak ?? this.habitSkipKeepsStreak,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  static const _checkboxSizeKey = 'checkbox_size';
  static const _mainListNameKey = 'main_list_name';
  static const _knownTagsKey = 'known_tags';
  static const _materialYouKey = 'material_you';
  static const _calendarViewKey = 'calendar_default_view';
  static const _calendarWeekStartKey = 'calendar_week_start';
  static const _calendarDayStartKey = 'calendar_day_start_hour';
  static const _calendarDayEndKey = 'calendar_day_end_hour';
  static const _calendarEventMinutesKey = 'calendar_event_minutes';
  static const _calendarReminderKey = 'calendar_reminder_minutes';
  static const _calendarWeekNumbersKey = 'calendar_week_numbers';
  static const _calendarHourHeightKey = 'calendar_hour_height';
  static const _noteSortKey = 'note_sort';
  static const _noteOpenModeKey = 'note_open_mode';
  static const _noteLayoutKey = 'note_layout';
  static const _noteFolderKey = 'note_default_folder';
  static const _habitWeekStartKey = 'habit_week_start';
  static const _habitReminderKey = 'habit_reminder_minutes';
  static const _habitSkipStreakKey = 'habit_skip_keeps_streak';

  /// Hive has no null for an int box value, so "off" is stored as -1.
  static const int _off = -1;

  Box? _box;

  Box get _settingsBox {
    _box ??= Hive.box(AppConstants.hiveSettingsBox);
    return _box!;
  }

  /// Reads an enum by its stored index, falling back to [fallback] when the
  /// stored value is from an older build that knew fewer options.
  T _enum<T extends Enum>(String key, List<T> values, T fallback) {
    final index = _settingsBox.get(key, defaultValue: fallback.index) as int;
    return index >= 0 && index < values.length ? values[index] : fallback;
  }

  void _loadSettings() {
    // Stored as an index. The old setting only knew normal(0)/large(1), so a
    // stored 0 becomes medium and a stored 1 stays large.
    final sizeIndex =
        _settingsBox.get(_checkboxSizeKey, defaultValue: 1) as int;
    final size = sizeIndex < CheckboxSize.values.length
        ? CheckboxSize.values[sizeIndex]
        : CheckboxSize.medium;
    final mainListName =
        _settingsBox.get(_mainListNameKey, defaultValue: 'Aufgaben') as String;
    final knownTags =
        (_settingsBox.get(_knownTagsKey) as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final materialYou =
        _settingsBox.get(_materialYouKey, defaultValue: false) as bool;

    final calendarReminder =
        _settingsBox.get(_calendarReminderKey, defaultValue: 10) as int;
    final habitReminder =
        _settingsBox.get(_habitReminderKey, defaultValue: _off) as int;
    final defaultFolder =
        _settingsBox.get(_noteFolderKey, defaultValue: '') as String;

    state = AppSettings(
      checkboxSize: size,
      mainListName: mainListName,
      knownTags: knownTags,
      materialYou: materialYou,
      calendarDefaultView: _enum(
        _calendarViewKey,
        CalendarDefaultView.values,
        CalendarDefaultView.month,
      ),
      calendarWeekStart: _enum(
        _calendarWeekStartKey,
        WeekStart.values,
        WeekStart.monday,
      ),
      calendarDayStartHour:
          _settingsBox.get(_calendarDayStartKey, defaultValue: 7) as int,
      calendarDayEndHour:
          _settingsBox.get(_calendarDayEndKey, defaultValue: 22) as int,
      calendarDefaultEventMinutes:
          _settingsBox.get(_calendarEventMinutesKey, defaultValue: 60) as int,
      calendarDefaultReminderMinutes: calendarReminder == _off
          ? null
          : calendarReminder,
      calendarShowWeekNumbers:
          _settingsBox.get(_calendarWeekNumbersKey, defaultValue: false)
              as bool,
      // Clamped on read as well: a value written by an older build (or a
      // hand-edited box) must never make an hour row zero pixels high.
      calendarHourHeight:
          (_settingsBox.get(
                    _calendarHourHeightKey,
                    defaultValue: AppSettings.calendarHourHeightDefault,
                  )
                  as num)
              .toDouble()
              .clamp(
                AppSettings.calendarHourHeightMin,
                AppSettings.calendarHourHeightMax,
              ),
      noteSort: _enum(_noteSortKey, NoteSort.values, NoteSort.updated),
      noteOpenMode: _enum(
        _noteOpenModeKey,
        NoteOpenMode.values,
        NoteOpenMode.preview,
      ),
      noteLayout: _enum(_noteLayoutKey, NoteLayout.values, NoteLayout.grid),
      // An empty string is "all notes" — Hive has no null for a String value.
      noteDefaultFolderId: defaultFolder.isEmpty ? null : defaultFolder,
      habitWeekStart: _enum(
        _habitWeekStartKey,
        WeekStart.values,
        WeekStart.monday,
      ),
      habitReminderMinutes: habitReminder == _off ? null : habitReminder,
      habitSkipKeepsStreak:
          _settingsBox.get(_habitSkipStreakKey, defaultValue: false) as bool,
    );
  }

  Future<void> setMaterialYou(bool enabled) async {
    await _settingsBox.put(_materialYouKey, enabled);
    state = state.copyWith(materialYou: enabled);
  }

  Future<void> setCheckboxSize(CheckboxSize size) async {
    await _settingsBox.put(_checkboxSizeKey, size.index);
    state = state.copyWith(checkboxSize: size);
  }

  Future<void> setMainListName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _settingsBox.put(_mainListNameKey, trimmed);
    state = state.copyWith(mainListName: trimmed);
  }

  // ── Calendar ─────────────────────────────────────────────────────────────

  Future<void> setCalendarDefaultView(CalendarDefaultView view) async {
    await _settingsBox.put(_calendarViewKey, view.index);
    state = state.copyWith(calendarDefaultView: view);
  }

  Future<void> setCalendarWeekStart(WeekStart start) async {
    await _settingsBox.put(_calendarWeekStartKey, start.index);
    state = state.copyWith(calendarWeekStart: start);
  }

  /// Both grid bounds go through one setter: an end that is not after the
  /// start would make the day grid zero rows high.
  Future<void> setCalendarDayHours({int? startHour, int? endHour}) async {
    var start = (startHour ?? state.calendarDayStartHour).clamp(0, 23);
    var end = (endHour ?? state.calendarDayEndHour).clamp(1, 24);
    if (end <= start) {
      if (startHour != null) {
        end = (start + 1).clamp(1, 24);
      } else {
        start = (end - 1).clamp(0, 23);
      }
    }
    await _settingsBox.put(_calendarDayStartKey, start);
    await _settingsBox.put(_calendarDayEndKey, end);
    state = state.copyWith(
      calendarDayStartHour: start,
      calendarDayEndHour: end,
    );
  }

  Future<void> setCalendarDefaultEventMinutes(int minutes) async {
    await _settingsBox.put(_calendarEventMinutesKey, minutes);
    state = state.copyWith(calendarDefaultEventMinutes: minutes);
  }

  Future<void> setCalendarDefaultReminderMinutes(int? minutes) async {
    await _settingsBox.put(_calendarReminderKey, minutes ?? _off);
    state = state.copyWith(
      calendarDefaultReminderMinutes: minutes,
      clearCalendarDefaultReminder: minutes == null,
    );
  }

  Future<void> setCalendarShowWeekNumbers(bool show) async {
    await _settingsBox.put(_calendarWeekNumbersKey, show);
    state = state.copyWith(calendarShowWeekNumbers: show);
  }

  /// Hour height of the day/week grid, written by the pinch on the grid and
  /// by the slider in the calendar settings.
  Future<void> setCalendarHourHeight(double height) async {
    final clamped = height.clamp(
      AppSettings.calendarHourHeightMin,
      AppSettings.calendarHourHeightMax,
    );
    if (clamped == state.calendarHourHeight) return;
    await _settingsBox.put(_calendarHourHeightKey, clamped);
    state = state.copyWith(calendarHourHeight: clamped);
  }

  // ── Notes ────────────────────────────────────────────────────────────────

  Future<void> setNoteSort(NoteSort sort) async {
    await _settingsBox.put(_noteSortKey, sort.index);
    state = state.copyWith(noteSort: sort);
  }

  Future<void> setNoteOpenMode(NoteOpenMode mode) async {
    await _settingsBox.put(_noteOpenModeKey, mode.index);
    state = state.copyWith(noteOpenMode: mode);
  }

  Future<void> setNoteLayout(NoteLayout layout) async {
    await _settingsBox.put(_noteLayoutKey, layout.index);
    state = state.copyWith(noteLayout: layout);
  }

  Future<void> setNoteDefaultFolderId(String? folderId) async {
    await _settingsBox.put(_noteFolderKey, folderId ?? '');
    state = state.copyWith(
      noteDefaultFolderId: folderId,
      clearNoteDefaultFolder: folderId == null,
    );
  }

  // ── Habits ───────────────────────────────────────────────────────────────

  Future<void> setHabitWeekStart(WeekStart start) async {
    await _settingsBox.put(_habitWeekStartKey, start.index);
    state = state.copyWith(habitWeekStart: start);
  }

  Future<void> setHabitReminderMinutes(int? minutesSinceMidnight) async {
    await _settingsBox.put(_habitReminderKey, minutesSinceMidnight ?? _off);
    state = state.copyWith(
      habitReminderMinutes: minutesSinceMidnight,
      clearHabitReminder: minutesSinceMidnight == null,
    );
  }

  Future<void> setHabitSkipKeepsStreak(bool keeps) async {
    await _settingsBox.put(_habitSkipStreakKey, keeps);
    state = state.copyWith(habitSkipKeepsStreak: keeps);
  }

  /// Remember new tag names so they can be suggested later (case-insensitive).
  Future<void> rememberTags(Iterable<String> tags) async {
    final existing = {for (final t in state.knownTags) t.toLowerCase(): t};
    var changed = false;
    for (final raw in tags) {
      final t = raw.trim();
      if (t.isEmpty) continue;
      if (!existing.containsKey(t.toLowerCase())) {
        existing[t.toLowerCase()] = t;
        changed = true;
      }
    }
    if (!changed) return;
    final merged = existing.values.toList()..sort();
    await _settingsBox.put(_knownTagsKey, merged);
    state = state.copyWith(knownTags: merged);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((
  ref,
) {
  return SettingsNotifier();
});
