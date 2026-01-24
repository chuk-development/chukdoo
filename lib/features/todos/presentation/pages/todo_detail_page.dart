import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/todo.dart';
import '../../providers/todo_provider.dart';
import '../../../nlp/parser/date_parser.dart';
import '../../../nlp/parser/natural_language_parser.dart';
import '../../../notifications/reminder_scheduler.dart';

class TodoDetailPage extends ConsumerStatefulWidget {
  final Todo todo;

  const TodoDetailPage({super.key, required this.todo});

  @override
  ConsumerState<TodoDetailPage> createState() => _TodoDetailPageState();
}

class _TodoDetailPageState extends ConsumerState<TodoDetailPage> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime? _dueDate;
  late TimeOfDay? _dueTime;
  late TodoPriority _priority;
  DateTime? _reminderTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo.title);
    _descriptionController = TextEditingController(text: widget.todo.description ?? '');
    _dueDate = widget.todo.dueDate;
    _dueTime = widget.todo.dueTime;
    _priority = widget.todo.priority;
    _reminderTime = widget.todo.reminderAt; // Load existing reminder
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final updated = widget.todo.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      dueDate: _dueDate,
      dueTime: _dueTime,
      priority: _priority,
      reminderAt: _reminderTime,
      clearDescription: _descriptionController.text.trim().isEmpty,
      clearDueDate: _dueDate == null,
      clearDueTime: _dueTime == null,
      clearReminder: _reminderTime == null,
    );
    ref.read(todoProvider.notifier).updateTodo(updated);

    // Schedule or cancel reminder using ReminderScheduler
    ReminderScheduler.instance.scheduleForTodo(updated);

    Navigator.pop(context);
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Aufgabe löschen?'),
        content: const Text('Diese Aktion kann nicht rückgängig gemacht werden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Cancel any scheduled reminder
              ReminderScheduler.instance.cancelForTodo(widget.todo.id);
              ref.read(todoProvider.notifier).deleteTodo(widget.todo.id);
              Navigator.pop(context); // Close detail page
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(SolarIconsOutline.closeCircle),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(SolarIconsOutline.trashBinTrash),
            onPressed: _delete,
          ),
          TextButton(
            onPressed: _save,
            child: const Text('Speichern'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Aufgabe',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
              maxLines: null,
            ),
            const Divider(),

            // Description
            TextField(
              controller: _descriptionController,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Beschreibung hinzufügen',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
              maxLines: null,
              minLines: 3,
            ),
            const SizedBox(height: 24),

            // Due Date
            _buildOptionTile(
              icon: SolarIconsOutline.calendar,
              iconColor: _dueDate != null ? AppColors.purple : AppColors.textSecondary,
              title: 'Fälligkeitsdatum',
              value: _dueDate != null 
                  ? DateParser.formatDate(_dueDate!, Language.german)
                  : 'Kein Datum',
              onTap: _showDatePicker,
              onClear: _dueDate != null ? () => setState(() => _dueDate = null) : null,
            ),

            // Due Time
            _buildOptionTile(
              icon: SolarIconsOutline.clockCircle,
              iconColor: _dueTime != null ? AppColors.blue : AppColors.textSecondary,
              title: 'Uhrzeit',
              value: _dueTime != null ? _formatTime(_dueTime!) : 'Keine Zeit',
              onTap: _showTimePicker,
              onClear: _dueTime != null ? () => setState(() => _dueTime = null) : null,
            ),

            // Priority
            _buildOptionTile(
              icon: SolarIconsOutline.flag,
              iconColor: AppColors.getPriorityColor(_priority.value),
              title: 'Priorität',
              value: 'Priorität ${_priority.value}',
              onTap: _showPriorityPicker,
            ),

            // Reminder
            _buildOptionTile(
              icon: SolarIconsOutline.bell,
              iconColor: _reminderTime != null ? AppColors.orange : AppColors.textSecondary,
              title: 'Erinnerung',
              value: _reminderTime != null 
                  ? '${_reminderTime!.day}.${_reminderTime!.month} ${_formatTime(TimeOfDay.fromDateTime(_reminderTime!))}'
                  : 'Keine Erinnerung',
              onTap: _showReminderPicker,
              onClear: _reminderTime != null ? () => setState(() => _reminderTime = null) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: Text(value, style: TextStyle(color: AppColors.textSecondary)),
      trailing: onClear != null
          ? IconButton(
              icon: const Icon(SolarIconsOutline.closeSquare, size: 20),
              onPressed: onClear,
            )
          : const Icon(SolarIconsOutline.altArrowRight),
      onTap: onTap,
    );
  }

  void _showDatePicker() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _showTimePicker() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _dueTime = picked);
    }
  }

  void _showPriorityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text('Priorität', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ...[TodoPriority.p1, TodoPriority.p2, TodoPriority.p3].map((p) => ListTile(
              leading: Icon(SolarIconsBold.flag, color: AppColors.getPriorityColor(p.value)),
              title: Text('Priorität ${p.value}'),
              trailing: _priority == p ? const Icon(SolarIconsBold.checkSquare, color: AppColors.primary) : null,
              onTap: () {
                setState(() => _priority = p);
                Navigator.pop(context);
              },
            )),
            ListTile(
              leading: Icon(SolarIconsOutline.flag, color: AppColors.textSecondary),
              title: const Text('Keine Priorität'),
              trailing: _priority == TodoPriority.p4 ? const Icon(SolarIconsBold.checkSquare, color: AppColors.primary) : null,
              onTap: () {
                setState(() => _priority = TodoPriority.p4);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showReminderPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final now = DateTime.now();
        final dueDateTime = _dueDate != null && _dueTime != null
            ? DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day, _dueTime!.hour, _dueTime!.minute)
            : null;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const Text('Erinnerung', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              if (dueDateTime != null) ...[
                ListTile(
                  leading: const Icon(SolarIconsOutline.bellBing),
                  title: const Text('30 Minuten vorher'),
                  onTap: () {
                    setState(() => _reminderTime = dueDateTime.subtract(const Duration(minutes: 30)));
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(SolarIconsOutline.bellBing),
                  title: const Text('1 Stunde vorher'),
                  onTap: () {
                    setState(() => _reminderTime = dueDateTime.subtract(const Duration(hours: 1)));
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(SolarIconsOutline.bellBing),
                  title: const Text('1 Tag vorher'),
                  onTap: () {
                    setState(() => _reminderTime = dueDateTime.subtract(const Duration(days: 1)));
                    Navigator.pop(context);
                  },
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Setze zuerst ein Fälligkeitsdatum und Uhrzeit'),
                ),
              ListTile(
                leading: const Icon(SolarIconsOutline.calendarAdd),
                title: const Text('Benutzerdefiniert...'),
                onTap: () async {
                  Navigator.pop(context);
                  final date = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (date != null && mounted) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null && mounted) {
                      setState(() {
                        _reminderTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                      });
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
