import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../shared/widgets/app_field.dart';
import '../../../../shared/widgets/picker_sheet.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/calendar.dart';
import '../../domain/models/calendar_event.dart';
import '../../domain/models/rrule_helper.dart';
import '../../providers/calendar_event_provider.dart';
import '../../providers/calendar_provider.dart';
import 'calendar_style.dart';
import 'color_swatch_grid.dart';

/// The event editor: one stable sheet with filled fields and no outline.
///
/// The sheet's height never depends on the keyboard — only the scroll view
/// takes the keyboard inset — so typing never resizes the form or throws the
/// user back to the top. The primary action lives in the header, where the
/// keyboard cannot cover it.
class EventCreateDialog extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final CalendarEvent? editEvent;

  const EventCreateDialog({
    super.key,
    this.initialDate,
    this.initialTime,
    this.editEvent,
  });

  static Future<void> show(
    BuildContext context, {
    DateTime? initialDate,
    TimeOfDay? initialTime,
    CalendarEvent? editEvent,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // The route must not resize with the keyboard; the form handles the
      // inset itself.
      builder: (_) => EventCreateDialog(
        initialDate: initialDate,
        initialTime: initialTime,
        editEvent: editEvent,
      ),
    );
  }

  @override
  ConsumerState<EventCreateDialog> createState() => _EventCreateDialogState();
}

class _EventCreateDialogState extends ConsumerState<EventCreateDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;

  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  bool _isAllDay = false;
  String? _selectedCalendarId;
  String? _recurrenceRule;

  /// 0 means "use the calendar colour".
  int _color = 0;

  /// Minutes before the start, empty when the event has no reminder. A new
  /// event starts from the setting; an edited one from what it carries.
  List<int> _reminderMinutes = const [];

  /// Length a new event gets, from the settings. Also the length the form
  /// falls back to when an edit pushes the end before the start.
  int _defaultEventMinutes = 60;

  bool get _isEditing => widget.editEvent != null;

  @override
  void initState() {
    super.initState();
    final event = widget.editEvent;
    final now = DateTime.now();
    // The default length also governs an edit: it is the length the form
    // falls back to when a new start pushes the end before it.
    _defaultEventMinutes = ref
        .read(settingsProvider)
        .calendarDefaultEventMinutes;

    _titleController = TextEditingController(text: event?.title ?? '');
    _descriptionController = TextEditingController(
      text: event?.description ?? '',
    );
    _locationController = TextEditingController(text: event?.location ?? '');

    if (event != null) {
      _startDate = event.startTime;
      _startTime = TimeOfDay.fromDateTime(event.startTime);
      _endDate = event.endTime;
      _endTime = TimeOfDay.fromDateTime(event.endTime);
      _isAllDay = event.isAllDay;
      _selectedCalendarId = event.calendarId;
      _recurrenceRule = event.recurrenceRule;
      _color = event.color;
      _reminderMinutes = List.from(event.reminderMinutes);
    } else {
      // No reminder is a real choice, so null means "leave it off".
      final reminder = ref
          .read(settingsProvider)
          .calendarDefaultReminderMinutes;
      _reminderMinutes = reminder == null ? const [] : <int>[reminder];

      _startDate = widget.initialDate ?? now;
      _startTime =
          widget.initialTime ?? TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
      // The default length is a setting. Computing the end as a DateTime keeps
      // it right when the event runs past midnight — an hour 24 does not
      // exist, and an end before the start would be worse.
      final end = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      ).add(Duration(minutes: _defaultEventMinutes));
      _endDate = end;
      _endTime = TimeOfDay(hour: end.hour, minute: end.minute);

      // A new event lands in the default calendar instead of nowhere — an
      // event with no calendar cannot be hidden and looks lost in the drawer.
      final calendars = ref.read(calendarContainerProvider);
      _selectedCalendarId =
          calendars.defaultCalendar?.id ?? calendars.calendars.firstOrNull?.id;
    }
  }

  /// A birthday is always a whole day and comes back every year, so picking
  /// the birthday calendar sets those two fields instead of asking twice.
  void _applyCalendarRules(CalendarContainerState state) {
    final cal = state.calendars
        .where((c) => c.id == _selectedCalendarId)
        .firstOrNull;
    if (cal?.kind != CalendarKind.birthdays) return;
    _isAllDay = true;
    _recurrenceRule ??= 'FREQ=YEARLY';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calendarState = ref.watch(calendarContainerProvider);
    final dateFormat = DateFormat('EEE, d MMM yyyy', 'en_US');
    final media = MediaQuery.of(context);

    // The height is read from the window, never from the keyboard inset, so
    // opening the keyboard leaves the sheet exactly where it is.
    final sheetHeight = (media.size.height - media.padding.top) * 0.92;

    return SizedBox(
      height: sheetHeight,
      child: Material(
        color: AppColors.background,
        elevation: 0,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppShapes.sheetTop),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                // Only the scroll view knows about the keyboard: its content
                // can be scrolled clear of it while the sheet stays put.
                padding: EdgeInsets.fromLTRB(
                  AppShapes.listInset,
                  8,
                  AppShapes.listInset,
                  24 + media.viewInsets.bottom + media.padding.bottom,
                ),
                children: [
                  // Title — the one field that carries the event.
                  AppField(
                    child: TextField(
                      controller: _titleController,
                      autofocus: !_isEditing,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      cursorColor: AppColors.primary,
                      decoration: AppField.decoration('Add title'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // When
                  _Group(
                    children: [
                      _SwitchRow(
                        icon: MdiIcons.weatherSunny,
                        label: 'All day',
                        value: _isAllDay,
                        onChanged: (v) => setState(() => _isAllDay = v),
                      ),
                      _TapRow(
                        icon: MdiIcons.calendarStart,
                        title: 'Starts',
                        value: _isAllDay
                            ? dateFormat.format(_startDate)
                            : '${dateFormat.format(_startDate)} · '
                                  '${_startTime.format(context)}',
                        onTap: _pickStartDateTime,
                      ),
                      _TapRow(
                        icon: MdiIcons.calendarEnd,
                        title: 'Ends',
                        value: _isAllDay
                            ? dateFormat.format(_endDate)
                            : '${dateFormat.format(_endDate)} · '
                                  '${_endTime.format(context)}',
                        onTap: _pickEndDateTime,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Where and what — filled blocks, never an outline.
                  AppFieldGroup(
                    children: [
                      AppField(
                        label: 'Location',
                        isFirst: true,
                        isLast: false,
                        child: TextField(
                          controller: _locationController,
                          textCapitalization: TextCapitalization.sentences,
                          cursorColor: AppColors.primary,
                          style: const TextStyle(fontSize: 15),
                          decoration: AppField.decoration('Add a place'),
                        ),
                      ),
                      AppField(
                        label: 'Description',
                        isFirst: false,
                        isLast: true,
                        child: TextField(
                          controller: _descriptionController,
                          minLines: 2,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          cursorColor: AppColors.primary,
                          style: const TextStyle(fontSize: 15),
                          decoration: AppField.decoration('Add details'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // How
                  _Group(
                    children: [
                      _TapRow(
                        leading: _Dot(color: _calendarColor(calendarState)),
                        title: 'Calendar',
                        value: _calendarName(calendarState),
                        onTap: () => _pickCalendar(calendarState.calendars),
                      ),
                      _TapRow(
                        leading: _Dot(color: _effectiveColor(calendarState)),
                        title: 'Colour',
                        value: _colorName(),
                        onTap: () => _pickColor(calendarState),
                      ),
                      _TapRow(
                        icon: MdiIcons.repeat,
                        title: 'Repeat',
                        value: _describeRecurrence(_recurrenceRule),
                        onTap: _pickRecurrence,
                      ),
                      _TapRow(
                        icon: MdiIcons.bellOutline,
                        title: 'Reminder',
                        value: _describeReminder(),
                        onTap: _pickReminder,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Close, title, delete and save. Save sits here because the keyboard can
  /// never cover the header.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 12, 6),
      child: Row(
        children: [
          IconButton(
            icon: Icon(MdiIcons.close),
            color: AppColors.textSecondary,
            onPressed: () => Navigator.pop(context),
            tooltip: 'Close',
          ),
          Expanded(
            child: Text(
              _isEditing ? 'Edit event' : 'New event',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (_isEditing)
            IconButton(
              icon: Icon(MdiIcons.trashCanOutline),
              color: AppColors.error,
              onPressed: _confirmDelete,
              tooltip: 'Delete',
            ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Save / delete ----------------

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    final startDateTime = _isAllDay
        ? DateTime(_startDate.year, _startDate.month, _startDate.day)
        : DateTime(
            _startDate.year,
            _startDate.month,
            _startDate.day,
            _startTime.hour,
            _startTime.minute,
          );

    final endDateTime = _isAllDay
        ? DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59)
        : DateTime(
            _endDate.year,
            _endDate.month,
            _endDate.day,
            _endTime.hour,
            _endTime.minute,
          );

    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();

    if (_isEditing) {
      final updated = widget.editEvent!.copyWith(
        title: title,
        description: description.isEmpty ? null : description,
        location: location.isEmpty ? null : location,
        startTime: startDateTime,
        endTime: endDateTime,
        isAllDay: _isAllDay,
        calendarId: _selectedCalendarId,
        color: _color,
        recurrenceRule: _recurrenceRule,
        reminderMinutes: _reminderMinutes,
        clearCalendarId: _selectedCalendarId == null,
        clearDescription: description.isEmpty,
        clearLocation: location.isEmpty,
        clearRecurrenceRule: _recurrenceRule == null,
      );
      ref.read(calendarEventProvider.notifier).updateEvent(updated);
    } else {
      ref
          .read(calendarEventProvider.notifier)
          .addEvent(
            title: title,
            description: description.isEmpty ? null : description,
            location: location.isEmpty ? null : location,
            calendarId: _selectedCalendarId,
            startTime: startDateTime,
            endTime: endDateTime,
            isAllDay: _isAllDay,
            color: _color,
            recurrenceRule: _recurrenceRule,
            reminderMinutes: _reminderMinutes,
          );
    }

    Navigator.pop(context);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showPickerSheet<bool>(
      context: context,
      title: 'Delete this event?',
      options: [
        PickerOption(
          value: true,
          label: 'Delete event',
          icon: MdiIcons.trashCanOutline,
          color: AppColors.error,
        ),
        PickerOption(
          value: false,
          label: 'Keep it',
          icon: MdiIcons.undoVariant,
        ),
      ],
      footnote: 'A deleted event cannot be restored.',
    );
    if (confirmed != true || !mounted) return;

    ref.read(calendarEventProvider.notifier).deleteEvent(widget.editEvent!.id);
    if (mounted) Navigator.pop(context);
  }

  // ---------------- Pickers ----------------

  Future<void> _pickStartDateTime() async {
    final choice = await showDateTimeSheet(
      context: context,
      title: 'Starts',
      date: _startDate,
      time: _isAllDay ? null : _startTime,
      allowTime: !_isAllDay,
    );
    if (choice?.date == null || !mounted) return;

    setState(() {
      _startDate = choice!.date!;
      if (!_isAllDay && choice.time != null) _startTime = choice.time!;
      _syncEndAfterStart();
      if (_endDate.isBefore(_startDate)) _endDate = _startDate;
    });
  }

  Future<void> _pickEndDateTime() async {
    final choice = await showDateTimeSheet(
      context: context,
      title: 'Ends',
      date: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      time: _isAllDay ? null : _endTime,
      allowTime: !_isAllDay,
    );
    if (choice?.date == null || !mounted) return;

    setState(() {
      _endDate = choice!.date!;
      if (!_isAllDay && choice.time != null) _endTime = choice.time!;
    });
  }

  /// Keep end >= start when only start is changed.
  void _syncEndAfterStart() {
    final start = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final end = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );
    if (!end.isAfter(start)) {
      final newEnd = start.add(Duration(minutes: _defaultEventMinutes));
      _endDate = newEnd;
      _endTime = TimeOfDay(hour: newEnd.hour, minute: newEnd.minute);
    }
  }

  Future<void> _pickCalendar(List<Calendar> calendars) async {
    // The empty string stands for "no calendar", so a dismissed sheet (null)
    // stays distinguishable from a cleared choice.
    final picked = await showPickerSheet<String>(
      context: context,
      title: 'Calendar',
      options: [
        PickerOption(
          value: '',
          label: 'No calendar',
          leading: _Dot(color: AppColors.textTertiary),
          selected: _selectedCalendarId == null,
        ),
        for (final cal in calendars)
          PickerOption(
            value: cal.id,
            label: cal.name,
            leading: _Dot(color: Color(cal.color)),
            selected: _selectedCalendarId == cal.id,
          ),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedCalendarId = picked.isEmpty ? null : picked;
      _applyCalendarRules(ref.read(calendarContainerProvider));
    });
  }

  Future<void> _pickColor(CalendarContainerState calendarState) async {
    final picked = await showAppPicker<int>(
      context: context,
      builder: (ctx) => PickerSheetScaffold(
        title: 'Event colour',
        child: _ColorGrid(
          selected: _color,
          calendarColor: _calendarColor(calendarState),
          onPick: (value) => Navigator.pop(ctx, value),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _color = picked);
  }

  Future<void> _pickRecurrence() async {
    // 'none' is the sentinel for "does not repeat" — see _pickCalendar.
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
            selected: (_recurrenceRule ?? 'none') == opt.$2,
          ),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _recurrenceRule = picked == 'none' ? null : picked);
  }

  Future<void> _pickReminder() async {
    // One reminder, picked from a plain list — no checkmark grid.
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

    final current = _reminderMinutes.isEmpty ? -1 : _reminderMinutes.first;
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
    if (picked == null || !mounted) return;
    setState(() => _reminderMinutes = picked < 0 ? const [] : <int>[picked]);
  }

  // ---------------- Helpers ----------------

  /// Colour of the calendar the event belongs to.
  Color _calendarColor(CalendarContainerState state) {
    final cal = state.calendars
        .where((c) => c.id == _selectedCalendarId)
        .firstOrNull;
    return cal != null ? Color(cal.color) : CalendarStyle.defaultEventColor;
  }

  /// Colour the event is actually drawn with.
  Color _effectiveColor(CalendarContainerState state) =>
      _color != 0 ? Color(_color) : _calendarColor(state);

  String _calendarName(CalendarContainerState state) {
    if (_selectedCalendarId == null) return 'No calendar';
    final cal = state.calendars
        .where((c) => c.id == _selectedCalendarId)
        .firstOrNull;
    return cal?.name ?? 'No calendar';
  }

  String _colorName() {
    if (_color == 0) return 'Calendar colour';
    final index = CalendarStyle.eventColors.indexWhere(
      (c) => c.toARGB32() == _color,
    );
    return index == -1 ? 'Custom' : _colorLabels[index];
  }

  static const _colorLabels = [
    'Indigo',
    'Red',
    'Amber',
    'Sand',
    'Slate',
    'Blue',
    'Purple',
    'Pink',
    'Platinum',
    'Blue grey',
  ];

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

  String _describeReminder() {
    if (_reminderMinutes.isEmpty) return 'No reminder';
    final m = _reminderMinutes.first;
    if (m == 0) return 'At the time of the event';
    if (m < 60) return '$m minutes before';
    if (m == 60) return '1 hour before';
    if (m == 1440) return '1 day before';
    if (m % 1440 == 0) return '${m ~/ 1440} days before';
    return '${m ~/ 60} hours before';
  }
}

// ==================== Reusable UI pieces ====================

/// A group of rows: strong outer corners, soft corners in between, 3px gaps —
/// the same block every list in the app is built from.
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppShapes.groupGap),
            child: Material(
              color: AppColors.surface,
              borderRadius: AppShapes.row(
                isFirst: i == 0,
                isLast: i == children.length - 1,
              ),
              clipBehavior: Clip.antiAlias,
              child: children[i],
            ),
          ),
      ],
    );
  }
}

/// A filled dot, used wherever a colour stands for a calendar or an event.
class _Dot extends StatelessWidget {
  final Color color;
  final double size;

  const _Dot({required this.color, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _TapRow extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? value;
  final VoidCallback onTap;

  const _TapRow({
    this.icon,
    this.leading,
    required this.title,
    this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Center(
                child:
                    leading ??
                    Icon(icon, color: AppColors.textSecondary, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  if (value != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      value!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              MdiIcons.chevronRight,
              color: AppColors.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Icon(icon, color: AppColors.textSecondary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// The colour choices of an event: the calendar's own colour first, then the
/// app palette as one block of swatches.
class _ColorGrid extends StatelessWidget {
  final int selected;
  final Color calendarColor;
  final ValueChanged<int> onPick;

  const _ColorGrid({
    required this.selected,
    required this.calendarColor,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppShapes.listInset,
            ),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppShapes.groupOuter),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onPick(0),
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
                      if (selected == 0)
                        Icon(
                          MdiIcons.check,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppShapes.groupGap),
          ColorSwatchGrid(selected: selected, onPick: onPick),
        ],
      ),
    );
  }
}
