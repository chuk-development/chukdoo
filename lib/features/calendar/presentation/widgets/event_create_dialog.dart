import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/calendar.dart';
import '../../domain/models/calendar_event.dart';
import '../../domain/models/rrule_helper.dart';
import '../../providers/calendar_event_provider.dart';
import '../../providers/calendar_provider.dart';

const _accent = AppColors.blue;

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

  /// Opens the editor as a centered, floating card that scales + fades in.
  static Future<void> show(
    BuildContext context, {
    DateTime? initialDate,
    TimeOfDay? initialTime,
    CalendarEvent? editEvent,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Event',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, animation, secondaryAnimation) => EventCreateDialog(
        initialDate: initialDate,
        initialTime: initialTime,
        editEvent: editEvent,
      ),
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return FadeTransition(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(0, (1 - fade.value) * 28),
            child: Transform.scale(
              scale: 0.88 + 0.12 * curved.value,
              child: child,
            ),
          ),
        );
      },
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
  List<int> _reminderMinutes = [15];

  bool get _isEditing => widget.editEvent != null;

  @override
  void initState() {
    super.initState();
    final event = widget.editEvent;
    final now = DateTime.now();

    _titleController = TextEditingController(text: event?.title ?? '');
    _descriptionController = TextEditingController(text: event?.description ?? '');
    _locationController = TextEditingController(text: event?.location ?? '');

    if (event != null) {
      _startDate = event.startTime;
      _startTime = TimeOfDay.fromDateTime(event.startTime);
      _endDate = event.endTime;
      _endTime = TimeOfDay.fromDateTime(event.endTime);
      _isAllDay = event.isAllDay;
      _selectedCalendarId = event.calendarId;
      _recurrenceRule = event.recurrenceRule;
      _reminderMinutes = List.from(event.reminderMinutes);
    } else {
      _startDate = widget.initialDate ?? now;
      _startTime =
          widget.initialTime ?? TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
      // Default end is one hour after start; roll over to the next day if that
      // crosses midnight (avoids invalid hour 24 and end-before-start).
      final endHour = _startTime.hour + 1;
      _endDate =
          endHour > 23 ? _startDate.add(const Duration(days: 1)) : _startDate;
      _endTime = TimeOfDay(hour: endHour % 24, minute: _startTime.minute);
    }
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
    final dateFormat = DateFormat('EEE, d. MMM yyyy', 'en_US');
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height * 0.86;

    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          24 + media.padding.top,
          16,
          24 + media.viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
          child: Material(
            color: AppColors.background,
            elevation: 16,
            shadowColor: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: AppColors.textSecondary,
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          _isEditing ? 'Edit event' : 'New event',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                      FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: AppColors.divider),

                // Scrollable content
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      // Title
                      TextField(
                controller: _titleController,
                autofocus: !_isEditing,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                cursorColor: _accent,
                decoration: _inputDecoration('Add title'),
              ),
              const SizedBox(height: 16),

              // Time card
              _Card(
                children: [
                  _SwitchRow(
                    icon: Icons.schedule,
                    label: 'All day',
                    value: _isAllDay,
                    onChanged: (v) => setState(() => _isAllDay = v),
                  ),
                  const _RowDivider(),
                  _TapRow(
                    icon: Icons.play_arrow_rounded,
                    title: 'Start',
                    value: _isAllDay
                        ? dateFormat.format(_startDate)
                        : '${dateFormat.format(_startDate)} · ${_startTime.format(context)}',
                    onTap: _pickStartDateTime,
                  ),
                  const _RowDivider(),
                  _TapRow(
                    icon: Icons.stop_rounded,
                    title: 'End',
                    value: _isAllDay
                        ? dateFormat.format(_endDate)
                        : '${dateFormat.format(_endDate)} · ${_endTime.format(context)}',
                    onTap: _pickEndDateTime,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Details card
              _Card(
                children: [
                  _FieldRow(
                    icon: Icons.location_on_outlined,
                    controller: _locationController,
                    hint: 'Add location',
                  ),
                  const _RowDivider(),
                  _FieldRow(
                    icon: Icons.notes_rounded,
                    controller: _descriptionController,
                    hint: 'Add description',
                    maxLines: 3,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Options card
              _Card(
                children: [
                  if (calendarState.calendars.isNotEmpty) ...[
                    _TapRow(
                      leading: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: _getSelectedCalendarColor(calendarState),
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: 'Calendar',
                      value: _getSelectedCalendarName(calendarState),
                      onTap: () => _pickCalendar(calendarState.calendars),
                    ),
                    const _RowDivider(),
                  ],
                  _TapRow(
                    icon: Icons.repeat_rounded,
                    title: 'Repeat',
                    value: _recurrenceRule != null
                        ? _describeRecurrence(_recurrenceRule!)
                        : 'None',
                    onTap: _pickRecurrence,
                  ),
                  const _RowDivider(),
                  _TapRow(
                    icon: Icons.notifications_outlined,
                    title: 'Reminder',
                    value: _describeReminders(),
                    onTap: _pickReminder,
                  ),
                ],
              ),

              // Delete
              if (_isEditing) ...[
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: _delete,
                  icon: Icon(Icons.delete_outline, color: AppColors.error),
                  label: Text('Delete event', style: TextStyle(color: AppColors.error)),
                ),
              ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {Widget? prefix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.w400),
      prefixIcon: prefix,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
    );
  }

  // ---------------- Save / delete ----------------

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    final startDateTime = _isAllDay
        ? DateTime(_startDate.year, _startDate.month, _startDate.day)
        : DateTime(_startDate.year, _startDate.month, _startDate.day, _startTime.hour, _startTime.minute);

    final endDateTime = _isAllDay
        ? DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59)
        : DateTime(_endDate.year, _endDate.month, _endDate.day, _endTime.hour, _endTime.minute);

    if (_isEditing) {
      final updated = widget.editEvent!.copyWith(
        title: title,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        startTime: startDateTime,
        endTime: endDateTime,
        isAllDay: _isAllDay,
        calendarId: _selectedCalendarId,
        recurrenceRule: _recurrenceRule,
        reminderMinutes: _reminderMinutes,
        clearDescription: _descriptionController.text.trim().isEmpty,
        clearLocation: _locationController.text.trim().isEmpty,
        clearRecurrenceRule: _recurrenceRule == null,
      );
      ref.read(calendarEventProvider.notifier).updateEvent(updated);
    } else {
      ref.read(calendarEventProvider.notifier).addEvent(
            title: title,
            description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
            calendarId: _selectedCalendarId,
            startTime: startDateTime,
            endTime: endDateTime,
            isAllDay: _isAllDay,
            recurrenceRule: _recurrenceRule,
            reminderMinutes: _reminderMinutes,
          );
    }

    Navigator.pop(context);
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete event?'),
        content: const Text('This event will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(calendarEventProvider.notifier).deleteEvent(widget.editEvent!.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ---------------- Pickers ----------------

  Future<void> _pickStartDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    if (!_isAllDay) {
      final time = await showTimePicker(context: context, initialTime: _startTime);
      if (time != null && mounted) {
        setState(() {
          _startDate = date;
          _startTime = time;
          _syncEndAfterStart();
        });
      } else if (mounted) {
        setState(() {
          _startDate = date;
          _syncEndAfterStart();
        });
      }
    } else {
      setState(() {
        _startDate = date;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      });
    }
  }

  Future<void> _pickEndDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    if (!_isAllDay) {
      final time = await showTimePicker(context: context, initialTime: _endTime);
      if (time != null && mounted) {
        setState(() {
          _endDate = date;
          _endTime = time;
        });
      } else if (mounted) {
        setState(() => _endDate = date);
      }
    } else {
      setState(() => _endDate = date);
    }
  }

  /// Keep end >= start when only start is changed.
  void _syncEndAfterStart() {
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day, _startTime.hour, _startTime.minute);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day, _endTime.hour, _endTime.minute);
    if (!end.isAfter(start)) {
      final newEnd = start.add(const Duration(hours: 1));
      _endDate = newEnd;
      _endTime = TimeOfDay(hour: newEnd.hour, minute: newEnd.minute);
    }
  }

  void _pickCalendar(List<Calendar> calendars) {
    _showSheet(
      title: 'Calendar',
      children: calendars.map((cal) {
        return _SheetTile(
          leading: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: Color(cal.color), shape: BoxShape.circle),
          ),
          label: cal.name,
          selected: _selectedCalendarId == cal.id,
          onTap: () {
            setState(() => _selectedCalendarId = cal.id);
            Navigator.pop(context);
          },
        );
      }).toList(),
    );
  }

  void _pickRecurrence() {
    final options = <(String, String?)>[
      ('None', null),
      ('Daily', 'FREQ=DAILY'),
      ('Weekly', 'FREQ=WEEKLY'),
      ('Monthly', 'FREQ=MONTHLY'),
      ('Yearly', 'FREQ=YEARLY'),
      ('Weekdays (Mon-Fri)', 'FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR'),
    ];

    _showSheet(
      title: 'Repeat',
      children: options.map((opt) {
        return _SheetTile(
          label: opt.$1,
          selected: _recurrenceRule == opt.$2,
          onTap: () {
            setState(() => _recurrenceRule = opt.$2);
            Navigator.pop(context);
          },
        );
      }).toList(),
    );
  }

  void _pickReminder() {
    final options = <(String, int)>[
      ('At time of event', 0),
      ('5 minutes before', 5),
      ('15 minutes before', 15),
      ('30 minutes before', 30),
      ('1 hour before', 60),
      ('1 day before', 1440),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Reminder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              ...options.map((opt) {
                final isSelected = _reminderMinutes.contains(opt.$2);
                return CheckboxListTile(
                  title: Text(opt.$1, style: TextStyle(color: AppColors.textPrimary)),
                  value: isSelected,
                  activeColor: _accent,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) {
                    setSheet(() {
                      setState(() {
                        if (v == true) {
                          _reminderMinutes.add(opt.$2);
                        } else {
                          _reminderMinutes.remove(opt.$2);
                        }
                      });
                    });
                  },
                );
              }),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSheet({required String title, required List<Widget> children}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            ...children,
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------------- Helpers ----------------

  Color _getSelectedCalendarColor(CalendarContainerState state) {
    if (_selectedCalendarId == null) return _accent;
    final cal = state.calendars.where((c) => c.id == _selectedCalendarId).firstOrNull;
    return cal != null ? Color(cal.color) : _accent;
  }

  String _getSelectedCalendarName(CalendarContainerState state) {
    if (_selectedCalendarId == null) return 'Default';
    final cal = state.calendars.where((c) => c.id == _selectedCalendarId).firstOrNull;
    return cal?.name ?? 'Default';
  }

  String _describeRecurrence(String rule) {
    final config = RRuleHelper.parseRRule(rule);
    if (config == null) return rule;
    return switch (config.frequency) {
      RecurrenceFrequency.daily => config.interval == 1 ? 'Daily' : 'Alle ${config.interval} Tage',
      RecurrenceFrequency.weekly => config.interval == 1 ? 'Weekly' : 'Alle ${config.interval} Wochen',
      RecurrenceFrequency.monthly => config.interval == 1 ? 'Monthly' : 'Alle ${config.interval} Monate',
      RecurrenceFrequency.yearly => config.interval == 1 ? 'Yearly' : 'Alle ${config.interval} Jahre',
    };
  }

  String _describeReminders() {
    if (_reminderMinutes.isEmpty) return 'None';
    return _reminderMinutes.map((m) {
      if (m == 0) return 'At time of event';
      if (m < 60) return '$m min before';
      if (m == 60) return '1 hour before';
      if (m == 1440) return '1 day before';
      return '${m ~/ 60} hours before';
    }).join(', ');
  }
}

// ==================== Reusable UI pieces ====================

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: AppColors.divider, indent: 52);
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
              child: leading ?? Icon(icon, color: AppColors.textSecondary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  if (value != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      value!,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 24, child: Icon(icon, color: AppColors.textSecondary, size: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _accent,
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final IconData icon;
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _FieldRow({
    required this.icon,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: SizedBox(width: 24, child: Icon(icon, color: AppColors.textSecondary, size: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              cursorColor: _accent,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: AppColors.textTertiary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.textTertiary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final Widget? leading;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SheetTile({
    this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: Text(label, style: TextStyle(color: AppColors.textPrimary)),
      trailing: selected ? const Icon(Icons.check, color: _accent) : null,
      onTap: onTap,
    );
  }
}
