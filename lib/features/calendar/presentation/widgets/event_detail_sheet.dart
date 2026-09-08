import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../shared/widgets/app_check.dart';
import '../../../../shared/widgets/app_field.dart';
import '../../../../shared/widgets/picker_sheet.dart';
import '../../../todos/domain/models/todo.dart';
import '../../../todos/presentation/pages/todo_detail_page.dart';
import '../../../todos/providers/todo_provider.dart';
import '../../domain/models/calendar_event.dart';
import '../../domain/models/calendar_item.dart';
import '../../domain/models/rrule_helper.dart';
import '../../providers/calendar_event_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../services/ics_feed_service.dart';
import 'calendar_style.dart';
import 'color_swatch_grid.dart';

/// What one entry of the calendar holds — and the place where it is changed.
///
/// Every row edits itself: tapping the time opens the date/time sheet, tapping
/// the reminder the reminder list, tapping the title renames it. Each pick is
/// saved straight away, so there is no "Edit" round-trip any more; only the
/// destructive action still has a button of its own.
///
/// The colour is the cap of the card, not a bar floating over it: it is the
/// first row of the same group, so it carries the group's outer radius on top
/// and the small inner radius where it meets the title.
class EventDetailSheet extends ConsumerWidget {
  final CalendarItem item;

  const EventDetailSheet({super.key, required this.item});

  /// One rhythm for the whole sheet, taken from the shape scale.
  static const double _gap = AppShapes.listInset;

  /// Length a block falls back to when an edit would leave it empty.
  static const Duration _minLength = Duration(minutes: 15);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Air above the card. The title is the card's first row now, and
            // it needs room to the top edge of the box.
            const SizedBox(height: _gap * 2),
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _gap),
                  child: _group(_rows(context, ref)),
                ),
              ),
            ),
            const SizedBox(height: _gap * 2),
            _buildActions(context, ref),
            const SizedBox(height: _gap),
          ],
        ),
      ),
    );
  }

  // ---------------- Rows ----------------

  List<Widget> _rows(BuildContext context, WidgetRef ref) {
    return item is TodoItem
        ? _todoRows(context, ref)
        : _eventRows(context, ref);
  }

  List<Widget> _eventRows(BuildContext context, WidgetRef ref) {
    final event = _liveEvent(ref);
    final calendarState = ref.watch(calendarContainerProvider);
    final isFeed = IcsFeedService.isFeedEvent(event);
    final color = _eventColor(event, calendarState);
    final dateFormat = DateFormat('EEE, d MMM yyyy', 'en_US');
    final timeFormat = DateFormat('HH:mm', 'en_US');

    final rows = <Widget>[
      _ColorCap(
        color: color,
        // A subscribed event is replaced on every refresh, so nothing on it
        // can be changed here.
        onTap: isFeed ? null : () => _pickColor(context, ref, event, color),
      ),
      _DetailRow(
        value: event.title,
        isTitle: true,
        onTap: isFeed
            ? null
            : () async {
                final name = await _editText(
                  context,
                  title: 'Title',
                  hint: 'Add title',
                  value: event.title,
                );
                if (name == null || name.isEmpty) return;
                _saveEvent(ref, event.copyWith(title: name));
              },
      ),
      _DetailRow(
        icon: MdiIcons.calendarStart,
        label: 'Starts',
        value: item.isAllDay
            ? '${dateFormat.format(item.startTime)} · All day'
            : '${dateFormat.format(item.startTime)} · '
                  '${timeFormat.format(item.startTime)}',
        onTap: isFeed ? null : () => _pickStart(context, ref, event),
      ),
      _DetailRow(
        icon: MdiIcons.calendarEnd,
        label: 'Ends',
        value: item.isAllDay
            ? dateFormat.format(item.endTime)
            : '${dateFormat.format(item.endTime)} · '
                  '${timeFormat.format(item.endTime)}',
        onTap: isFeed ? null : () => _pickEnd(context, ref, event),
      ),
      _DetailRow(
        icon: MdiIcons.mapMarkerOutline,
        label: 'Location',
        value: event.location?.isNotEmpty == true ? event.location! : null,
        placeholder: 'Add a place',
        onTap: isFeed
            ? null
            : () async {
                final text = await _editText(
                  context,
                  title: 'Location',
                  hint: 'Add a place',
                  value: event.location ?? '',
                );
                if (text == null) return;
                _saveEvent(
                  ref,
                  event.copyWith(
                    location: text.isEmpty ? null : text,
                    clearLocation: text.isEmpty,
                  ),
                );
              },
      ),
      _DetailRow(
        icon: MdiIcons.textLong,
        label: 'Description',
        value: event.description?.isNotEmpty == true
            ? event.description!
            : null,
        placeholder: 'Add details',
        onTap: isFeed
            ? null
            : () async {
                final text = await _editText(
                  context,
                  title: 'Description',
                  hint: 'Add details',
                  value: event.description ?? '',
                  maxLines: 5,
                );
                if (text == null) return;
                _saveEvent(
                  ref,
                  event.copyWith(
                    description: text.isEmpty ? null : text,
                    clearDescription: text.isEmpty,
                  ),
                );
              },
      ),
      _DetailRow(
        icon: MdiIcons.repeat,
        label: 'Repeat',
        value: _describeRecurrence(event.recurrenceRule),
        onTap: isFeed ? null : () => _pickRecurrence(context, ref, event),
      ),
      _DetailRow(
        icon: MdiIcons.bellOutline,
        label: 'Reminder',
        value: _describeReminder(event.reminderMinutes),
        onTap: isFeed ? null : () => _pickReminder(context, ref, event),
      ),
    ];

    if (isFeed) {
      final feed = IcsFeedService.feeds
          .where((f) => f.id == event.calendarId)
          .firstOrNull;
      rows.add(
        _DetailRow(
          icon: MdiIcons.calendarSync,
          label: 'Calendar',
          value: '${feed?.name ?? 'Subscribed calendar'} · read-only',
        ),
      );
    } else {
      // The calendar an event belongs to is always shown, even when it has
      // none — otherwise "which calendar is this in" has no answer in the UI.
      final cal = calendarState.calendars
          .where((c) => c.id == event.calendarId)
          .firstOrNull;
      rows.add(
        _DetailRow(
          leading: _Dot(
            color: cal != null ? Color(cal.color) : AppColors.textTertiary,
          ),
          label: 'Calendar',
          value: cal?.name ?? 'No calendar',
          onTap: () => _pickCalendar(context, ref, event, calendarState),
        ),
      );
    }

    return rows;
  }

  List<Widget> _todoRows(BuildContext context, WidgetRef ref) {
    final todo = _liveTodo(ref);
    final color = AppColors.getPriorityColor(todo.priority.value);
    final dateFormat = DateFormat('EEE, d MMM yyyy', 'en_US');

    String two(int v) => v.toString().padLeft(2, '0');
    String hhmm(TimeOfDay t) => '${two(t.hour)}:${two(t.minute)}';

    return [
      _ColorCap(color: color, onTap: () => _pickPriority(context, ref, todo)),
      // The tick sits on the title, exactly like in a task list: tap the ring
      // to finish the task, tap the text to rename it.
      _DetailRow(
        leading: AppCheck(
          checked: todo.isCompleted,
          color: color,
          diameter: AppCheck.small,
          onTap: () {
            ref.read(todoProvider.notifier).toggleComplete(todo.id);
            Navigator.pop(context);
          },
        ),
        value: todo.title,
        isTitle: true,
        onTap: () async {
          final name = await _editText(
            context,
            title: 'Task',
            hint: 'What needs doing?',
            value: todo.title,
          );
          if (name == null || name.isEmpty) return;
          ref
              .read(todoProvider.notifier)
              .updateTodo(todo.copyWith(title: name));
        },
      ),
      _DetailRow(
        icon: MdiIcons.calendarStart,
        label: 'Starts',
        value: todo.dueDate == null
            ? null
            : todo.dueTime == null
            ? '${dateFormat.format(todo.dueDate!)} · All day'
            : '${dateFormat.format(todo.dueDate!)} · ${hhmm(todo.dueTime!)}',
        placeholder: 'No date',
        onTap: () => _pickTodoStart(context, ref, todo),
      ),
      _DetailRow(
        icon: MdiIcons.clockOutline,
        label: 'Ends',
        value: todo.endTime == null ? null : hhmm(todo.endTime!),
        // Without a start there is nothing to end, so the row stays dead —
        // the same rule the task editor follows.
        placeholder: todo.dueTime == null ? 'Set a time first' : 'No end',
        onTap: todo.dueTime == null
            ? null
            : () => _pickTodoEnd(context, ref, todo),
      ),
      _DetailRow(
        icon: todo.priority == TodoPriority.p4
            ? MdiIcons.flagOutline
            : MdiIcons.flag,
        iconColor: todo.priority == TodoPriority.p4 ? null : color,
        label: 'Priority',
        value: todo.priority == TodoPriority.p4
            ? 'None'
            : 'Priority ${todo.priority.value}',
        onTap: () => _pickPriority(context, ref, todo),
      ),
    ];
  }

  // ---------------- Actions ----------------

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    if (item is TodoItem) {
      final todo = _liveTodo(ref);
      return _actionBar(
        onDelete: () {
          ref.read(todoProvider.notifier).deleteTodo(todo.id);
          Navigator.pop(context);
        },
        primary: FilledButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TodoDetailPage(todo: todo)),
            );
          },
          style: _primaryStyle,
          child: const Text('Open task'),
        ),
      );
    }

    final event = _liveEvent(ref);
    // An event from a subscribed feed is replaced on every refresh, so it
    // cannot be edited or deleted here.
    if (IcsFeedService.isFeedEvent(event)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: _gap * 2),
        child: Text(
          'This event comes from a subscribed calendar and cannot be changed.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
      );
    }

    return _actionBar(
      onDelete: () {
        ref.read(calendarEventProvider.notifier).deleteEvent(event.id);
        Navigator.pop(context);
      },
      primary: FilledButton(
        onPressed: () => Navigator.pop(context),
        style: _primaryStyle,
        child: const Text('Done'),
      ),
    );
  }

  /// Delete on the left, the closing action on the right, with the sheet's
  /// rhythm between them — the two used to sit shoulder to shoulder.
  Widget _actionBar({required VoidCallback onDelete, required Widget primary}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _gap),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onDelete,
            icon: Icon(MdiIcons.trashCanOutline, size: 18),
            label: const Text('Delete'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const Spacer(),
          const SizedBox(width: _gap),
          primary,
        ],
      ),
    );
  }

  ButtonStyle get _primaryStyle => FilledButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.onPrimary,
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
  );

  // ---------------- Live data ----------------

  /// The event as it is *now*. The sheet stays open while it is edited, so it
  /// must read the stored event again instead of the copy it was built with.
  CalendarEvent _liveEvent(WidgetRef ref) {
    final base = (item as EventItem).event;
    return ref
            .watch(calendarEventProvider)
            .events
            .where((e) => e.id == base.id)
            .firstOrNull ??
        base;
  }

  Todo _liveTodo(WidgetRef ref) {
    final base = (item as TodoItem).todo;
    return ref
            .watch(todoProvider)
            .todos
            .where((t) => t.id == base.id)
            .firstOrNull ??
        base;
  }

  void _saveEvent(WidgetRef ref, CalendarEvent event) {
    ref.read(calendarEventProvider.notifier).updateEvent(event);
  }

  // ---------------- Pickers ----------------

  Future<void> _pickStart(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final choice = await showDateTimeSheet(
      context: context,
      title: 'Starts',
      date: item.startTime,
      time: item.isAllDay ? null : TimeOfDay.fromDateTime(item.startTime),
      allowTime: !item.isAllDay,
    );
    if (choice?.date == null) return;

    final picked = _combine(choice!.date!, choice.time, item.startTime);
    // The sheet can show one occurrence of a series, so the stored event is
    // moved by the same step the user moved the occurrence by.
    final shift = picked.difference(item.startTime);
    final length = event.duration;
    final start = event.startTime.add(shift);
    var end = event.endTime;
    if (!end.isAfter(start)) end = start.add(length);
    _saveEvent(ref, event.copyWith(startTime: start, endTime: end));
  }

  Future<void> _pickEnd(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final choice = await showDateTimeSheet(
      context: context,
      title: 'Ends',
      date: item.endTime,
      time: item.isAllDay ? null : TimeOfDay.fromDateTime(item.endTime),
      allowTime: !item.isAllDay,
    );
    if (choice?.date == null) return;

    final picked = _combine(choice!.date!, choice.time, item.endTime);
    final shift = picked.difference(item.endTime);
    var end = event.endTime.add(shift);
    // An end at or before the start would draw nothing at all.
    if (!end.isAfter(event.startTime)) end = event.startTime.add(_minLength);
    _saveEvent(ref, event.copyWith(endTime: end));
  }

  Future<void> _pickColor(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
    Color current,
  ) async {
    final calendarState = ref.read(calendarContainerProvider);
    final calendarColor = _calendarColor(event, calendarState);

    final picked = await showAppPicker<int>(
      context: context,
      builder: (ctx) => PickerSheetScaffold(
        title: 'Event colour',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _gap),
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppShapes.groupOuter),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.pop(ctx, 0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 15,
                    ),
                    child: Row(
                      children: [
                        _Dot(color: calendarColor, size: 22),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Calendar colour',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (event.color == 0)
                          Icon(
                            MdiIcons.check,
                            size: 20,
                            color: AppColors.primary,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: _gap),
            ColorSwatchGrid(
              selected: event.color,
              onPick: (value) => Navigator.pop(ctx, value),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    _saveEvent(ref, event.copyWith(color: picked));
  }

  Future<void> _pickRecurrence(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    // 'none' is the sentinel for "does not repeat" — a dismissed sheet gives
    // null and must stay distinguishable from a cleared rule.
    const options = <(String, String)>[
      ('Does not repeat', 'none'),
      ('Every day', 'FREQ=DAILY'),
      ('Every week', 'FREQ=WEEKLY'),
      ('Every weekday (Mon to Fri)', 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR'),
      ('Every 2 weeks', 'FREQ=WEEKLY;INTERVAL=2'),
      ('Every month', 'FREQ=MONTHLY'),
      ('Every year', 'FREQ=YEARLY'),
    ];

    final picked = await showPickerSheet<String>(
      context: context,
      title: 'Repeat',
      options: [
        for (final opt in options)
          PickerOption(
            value: opt.$2,
            label: opt.$1,
            icon: opt.$2 == 'none' ? MdiIcons.repeatOff : MdiIcons.repeat,
            selected: (event.recurrenceRule ?? 'none') == opt.$2,
          ),
      ],
    );
    if (picked == null) return;
    _saveEvent(
      ref,
      event.copyWith(
        recurrenceRule: picked == 'none' ? null : picked,
        clearRecurrenceRule: picked == 'none',
      ),
    );
  }

  Future<void> _pickReminder(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    // -1 is the sentinel for "no reminder".
    const options = <(String, int)>[
      ('No reminder', -1),
      ('At the time of the event', 0),
      ('5 minutes before', 5),
      ('10 minutes before', 10),
      ('15 minutes before', 15),
      ('30 minutes before', 30),
      ('1 hour before', 60),
      ('2 hours before', 120),
      ('1 day before', 1440),
    ];

    final current = event.reminderMinutes.isEmpty
        ? -1
        : event.reminderMinutes.first;
    final picked = await showPickerSheet<int>(
      context: context,
      title: 'Reminder',
      options: [
        for (final opt in options)
          PickerOption(
            value: opt.$2,
            label: opt.$1,
            icon: opt.$2 == -1 ? MdiIcons.bellOffOutline : MdiIcons.bellOutline,
            selected: current == opt.$2,
          ),
      ],
    );
    if (picked == null) return;
    _saveEvent(
      ref,
      event.copyWith(
        reminderMinutes: picked < 0 ? const <int>[] : <int>[picked],
      ),
    );
  }

  Future<void> _pickCalendar(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
    CalendarContainerState state,
  ) async {
    // The empty string stands for "no calendar", so a dismissed sheet stays
    // distinguishable from a cleared choice.
    final picked = await showPickerSheet<String>(
      context: context,
      title: 'Calendar',
      options: [
        PickerOption(
          value: '',
          label: 'No calendar',
          leading: _Dot(color: AppColors.textTertiary),
          selected: event.calendarId == null,
        ),
        for (final cal in state.calendars)
          PickerOption(
            value: cal.id,
            label: cal.name,
            leading: _Dot(color: Color(cal.color)),
            selected: event.calendarId == cal.id,
          ),
      ],
    );
    if (picked == null) return;
    _saveEvent(
      ref,
      event.copyWith(
        calendarId: picked.isEmpty ? null : picked,
        clearCalendarId: picked.isEmpty,
      ),
    );
  }

  Future<void> _pickTodoStart(
    BuildContext context,
    WidgetRef ref,
    Todo todo,
  ) async {
    final choice = await showDateTimeSheet(
      context: context,
      title: 'Starts',
      date: todo.dueDate,
      time: todo.dueTime,
    );
    if (choice == null) return;
    ref
        .read(todoProvider.notifier)
        .updateTodo(
          todo.copyWith(
            dueDate: choice.date,
            dueTime: choice.time,
            clearDueDate: choice.date == null,
            // The end goes with the start: copyWith drops it by itself.
            clearDueTime: choice.time == null,
          ),
        );
  }

  Future<void> _pickTodoEnd(
    BuildContext context,
    WidgetRef ref,
    Todo todo,
  ) async {
    final start = todo.dueTime;
    if (start == null) return;
    final suggested = TimeOfDay(
      hour: (start.hour + (start.minute >= 30 ? 1 : 0)) % 24,
      minute: (start.minute + 30) % 60,
    );

    final choice = await showDateTimeSheet(
      context: context,
      title: 'Ends',
      date: todo.dueDate,
      time: todo.endTime ?? suggested,
    );
    if (choice == null) return;
    // A task ends on the day it starts, so only the time is taken over.
    ref
        .read(todoProvider.notifier)
        .updateTodo(
          todo.copyWith(
            endTime: choice.time,
            clearEndTime: choice.time == null,
          ),
        );
  }

  Future<void> _pickPriority(
    BuildContext context,
    WidgetRef ref,
    Todo todo,
  ) async {
    final picked = await showPickerSheet<TodoPriority>(
      context: context,
      title: 'Priority',
      options: [
        for (final p in [TodoPriority.p1, TodoPriority.p2, TodoPriority.p3])
          PickerOption(
            value: p,
            label: 'Priority ${p.value}',
            icon: MdiIcons.flag,
            color: AppColors.getPriorityColor(p.value),
            selected: todo.priority == p,
          ),
        PickerOption(
          value: TodoPriority.p4,
          label: 'None',
          icon: MdiIcons.flagOutline,
          selected: todo.priority == TodoPriority.p4,
        ),
      ],
    );
    if (picked == null) return;
    ref.read(todoProvider.notifier).updateTodo(todo.copyWith(priority: picked));
  }

  /// One line of text, typed in the same flying card every picker uses.
  /// Returns null when the sheet was dismissed, '' when the text was emptied.
  Future<String?> _editText(
    BuildContext context, {
    required String title,
    required String hint,
    required String value,
    int maxLines = 1,
  }) {
    return showAppPicker<String>(
      context: context,
      builder: (ctx) => _TextEditSheet(
        title: title,
        hint: hint,
        value: value,
        maxLines: maxLines,
      ),
    );
  }

  // ---------------- Helpers ----------------

  /// Rows drawn as one group: strong outer corners, soft corners between two
  /// rows, the 3px gap of every list in the app.
  Widget _group(List<Widget> rows) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppShapes.groupGap),
            child: Material(
              color: AppColors.surface,
              borderRadius: AppShapes.row(
                isFirst: i == 0,
                isLast: i == rows.length - 1,
              ),
              clipBehavior: Clip.antiAlias,
              child: rows[i],
            ),
          ),
      ],
    );
  }

  DateTime _combine(DateTime date, TimeOfDay? time, DateTime fallback) {
    final t = time ?? TimeOfDay.fromDateTime(fallback);
    return DateTime(date.year, date.month, date.day, t.hour, t.minute);
  }

  Color _calendarColor(CalendarEvent event, CalendarContainerState state) {
    final cal = state.calendars
        .where((c) => c.id == event.calendarId)
        .firstOrNull;
    return cal != null ? Color(cal.color) : CalendarStyle.defaultEventColor;
  }

  Color _eventColor(CalendarEvent event, CalendarContainerState state) =>
      event.color != 0 ? Color(event.color) : _calendarColor(event, state);

  String _describeRecurrence(String? rule) {
    if (rule == null || rule.isEmpty) return 'Does not repeat';
    if (rule.contains('BYDAY=MO,TU,WE,TH,FR')) return 'Every weekday';

    final config = RRuleHelper.parseRRule(rule);
    if (config == null) return rule;
    final n = config.interval;
    return switch (config.frequency) {
      RecurrenceFrequency.daily => n == 1 ? 'Every day' : 'Every $n days',
      RecurrenceFrequency.weekly => n == 1 ? 'Every week' : 'Every $n weeks',
      RecurrenceFrequency.monthly => n == 1 ? 'Every month' : 'Every $n months',
      RecurrenceFrequency.yearly => n == 1 ? 'Every year' : 'Every $n years',
    };
  }

  String _describeReminder(List<int> minutes) {
    if (minutes.isEmpty) return 'No reminder';
    final m = minutes.first;
    if (m == 0) return 'At the time of the event';
    if (m < 60) return '$m minutes before';
    if (m == 60) return '1 hour before';
    if (m == 1440) return '1 day before';
    if (m % 1440 == 0) return '${m ~/ 1440} days before';
    return '${m ~/ 60} hours before';
  }
}

/// The colour of the entry, drawn as the cap of the card instead of a bar
/// floating over it: outer radius on top, inner radius where it meets the
/// title, the same width as every row below it.
class _ColorCap extends StatelessWidget {
  final Color color;
  final VoidCallback? onTap;

  const _ColorCap({required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final band = Container(height: 14, color: color);
    if (onTap == null) return band;
    return InkWell(onTap: onTap, child: band);
  }
}

/// A filled dot, used wherever a colour stands for a calendar.
class _Dot extends StatelessWidget {
  final Color color;
  final double size;

  const _Dot({required this.color, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// One row of the card. Tappable rows carry a chevron, so it is visible that
/// they edit themselves.
class _DetailRow extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final String? label;
  final String? value;

  /// Shown greyed out when [value] is null — "Add a place" instead of a hole.
  final String? placeholder;
  final bool isTitle;
  final VoidCallback? onTap;

  const _DetailRow({
    this.icon,
    this.iconColor,
    this.leading,
    this.label,
    this.value,
    this.placeholder,
    this.isTitle = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    final text = hasValue ? value! : (placeholder ?? '');

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isTitle ? 16 : 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null || icon != null) ...[
            SizedBox(
              width: 24,
              child: Center(
                child:
                    leading ??
                    Icon(
                      icon,
                      size: 20,
                      color: iconColor ?? AppColors.textSecondary,
                    ),
              ),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label != null) ...[
                  Text(
                    label!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  text,
                  style: TextStyle(
                    fontSize: isTitle ? 19 : 15,
                    fontWeight: isTitle ? FontWeight.w700 : FontWeight.w500,
                    height: 1.25,
                    color: hasValue
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                  ),
                  maxLines: isTitle ? 3 : 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                MdiIcons.chevronRight,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

/// The rename / location / description sheet: one field, one Save.
class _TextEditSheet extends StatefulWidget {
  final String title;
  final String hint;
  final String value;
  final int maxLines;

  const _TextEditSheet({
    required this.title,
    required this.hint,
    required this.value,
    required this.maxLines,
  });

  @override
  State<_TextEditSheet> createState() => _TextEditSheetState();
}

class _TextEditSheetState extends State<_TextEditSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return PickerSheetScaffold(
      title: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppShapes.listInset,
            ),
            child: AppField(
              child: TextField(
                controller: _controller,
                autofocus: true,
                minLines: widget.maxLines > 1 ? 3 : 1,
                maxLines: widget.maxLines,
                textCapitalization: TextCapitalization.sentences,
                cursorColor: AppColors.primary,
                style: const TextStyle(fontSize: 16),
                decoration: AppField.decoration(widget.hint),
                onSubmitted: widget.maxLines > 1 ? null : (_) => _submit(),
              ),
            ),
          ),
          const SizedBox(height: AppShapes.listInset),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppShapes.listInset,
            ),
            child: Row(
              children: [
                const Spacer(),
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
