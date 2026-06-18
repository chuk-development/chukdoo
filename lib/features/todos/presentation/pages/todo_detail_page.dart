import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/todo.dart';
import '../../providers/todo_provider.dart';
import '../../../projects/providers/project_provider.dart';
import '../../../settings/providers/settings_provider.dart';
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
  late TextEditingController _tagController;
  late DateTime? _dueDate;
  late TimeOfDay? _dueTime;
  late TodoPriority _priority;
  DateTime? _reminderTime;
  late bool _isPinned;
  String? _projectId;
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo.title);
    _descriptionController = TextEditingController(text: widget.todo.description ?? '');
    _tagController = TextEditingController();
    _dueDate = widget.todo.dueDate;
    _dueTime = widget.todo.dueTime;
    _priority = widget.todo.priority;
    _reminderTime = widget.todo.reminderAt;
    _isPinned = widget.todo.isPinned;
    _projectId = widget.todo.projectId;
    _tags = List<String>.from(widget.todo.labelIds);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
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
      isPinned: _isPinned,
      projectId: _projectId,
      labelIds: _tags,
      clearDescription: _descriptionController.text.trim().isEmpty,
      clearDueDate: _dueDate == null,
      clearDueTime: _dueTime == null,
      clearReminder: _reminderTime == null,
      clearProjectId: _projectId == null,
    );
    ref.read(todoProvider.notifier).updateTodo(updated);
    ref.read(settingsProvider.notifier).rememberTags(_tags);
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
              Navigator.pop(context);
              ReminderScheduler.instance.cancelForTodo(widget.todo.id);
              ref.read(todoProvider.notifier).deleteTodo(widget.todo.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  String? get _dateLabel {
    if (_dueDate == null) return null;
    final label = DateParser.formatDate(_dueDate!, Language.german);
    if (_dueTime != null) return '$label ${_two(_dueTime!.hour)}:${_two(_dueTime!.minute)}';
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final projectState = ref.watch(projectProvider);
    final projects = projectState.sortedProjects;
    final settings = ref.watch(settingsProvider);
    final project = _projectId == null ? null : projectState.getById(_projectId!);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(SolarIconsOutline.closeCircle),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isPinned ? SolarIconsBold.bookmark : SolarIconsOutline.bookmark,
              color: _isPinned ? AppColors.orange : null,
            ),
            tooltip: _isPinned ? 'Lösen' : 'Anheften',
            onPressed: () => setState(() => _isPinned = !_isPinned),
          ),
          IconButton(
            icon: const Icon(SolarIconsOutline.trashBinTrash),
            onPressed: _delete,
          ),
          TextButton(onPressed: _save, child: const Text('Speichern')),
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
              decoration: const InputDecoration(
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
            const SizedBox(height: 16),

            // Compact meta chips — icons only, value shown when set.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Date + time combined
                _Chip(
                  icon: SolarIconsOutline.calendar,
                  iconColor: _dueDate != null ? AppColors.purple : null,
                  value: _dateLabel,
                  onTap: _pickDateTime,
                  onClear: _dueDate != null
                      ? () => setState(() {
                            _dueDate = null;
                            _dueTime = null;
                          })
                      : null,
                ),

                // Priority — small anchored popup menu
                PopupMenuButton<TodoPriority>(
                  color: AppColors.surface,
                  position: PopupMenuPosition.under,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (p) => setState(() => _priority = p),
                  itemBuilder: (_) => [
                    for (final p in [TodoPriority.p1, TodoPriority.p2, TodoPriority.p3])
                      PopupMenuItem(
                        value: p,
                        height: 40,
                        child: Row(
                          children: [
                            Icon(SolarIconsBold.flag, size: 16, color: AppColors.getPriorityColor(p.value)),
                            const SizedBox(width: 10),
                            Text('Priorität ${p.value}'),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: TodoPriority.p4,
                      height: 40,
                      child: Row(
                        children: [
                          Icon(SolarIconsOutline.flag, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 10),
                          const Text('Keine'),
                        ],
                      ),
                    ),
                  ],
                  child: _Chip(
                    icon: _priority == TodoPriority.p4 ? SolarIconsOutline.flag : SolarIconsBold.flag,
                    iconColor: _priority == TodoPriority.p4
                        ? null
                        : AppColors.getPriorityColor(_priority.value),
                    value: _priority == TodoPriority.p4 ? null : 'P${_priority.value}',
                  ),
                ),

                // Project — small anchored popup menu
                PopupMenuButton<String?>(
                  color: AppColors.surface,
                  position: PopupMenuPosition.under,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (id) => setState(() => _projectId = id),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: null,
                      height: 40,
                      child: Row(
                        children: [
                          Icon(SolarIconsOutline.inbox, size: 16, color: AppColors.textSecondary),
                          SizedBox(width: 10),
                          Text('Kein Projekt'),
                        ],
                      ),
                    ),
                    for (final p in projects)
                      PopupMenuItem(
                        value: p.id,
                        height: 40,
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(color: Color(p.color), borderRadius: BorderRadius.circular(3)),
                            ),
                            const SizedBox(width: 10),
                            Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                  ],
                  child: _Chip(
                    icon: SolarIconsOutline.folder,
                    iconColor: project != null ? Color(project.color) : null,
                    value: project?.name,
                  ),
                ),

                // Reminder
                _Chip(
                  icon: SolarIconsOutline.bell,
                  iconColor: _reminderTime != null ? AppColors.orange : null,
                  value: _reminderTime != null
                      ? '${_reminderTime!.day}.${_reminderTime!.month} ${_two(_reminderTime!.hour)}:${_two(_reminderTime!.minute)}'
                      : null,
                  onTap: _showReminderPicker,
                  onClear: _reminderTime != null ? () => setState(() => _reminderTime = null) : null,
                ),
              ],
            ),

            const SizedBox(height: 24),
            _buildTags(settings.knownTags),
          ],
        ),
      ),
    );
  }

  // ── Tags (# adds a tag; autocompleted & saved) ──
  Widget _buildTags(List<String> knownTags) {
    final input = _tagController.text.trim().replaceFirst('#', '');
    final suggestions = knownTags
        .where((t) => !_tags.any((e) => e.toLowerCase() == t.toLowerCase()))
        .where((t) => input.isEmpty || t.toLowerCase().contains(input.toLowerCase()))
        .take(8)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(SolarIconsOutline.hashtagCircle, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text('Tags', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final tag in _tags)
              Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('#$tag', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() => _tags.remove(tag)),
                      child: const Icon(SolarIconsOutline.closeCircle, size: 15, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            // Inline input
            SizedBox(
              width: 140,
              child: TextField(
                controller: _tagController,
                onChanged: (v) {
                  if (v.endsWith(' ')) {
                    _commitTag(v);
                  } else {
                    setState(() {});
                  }
                },
                onSubmitted: _commitTag,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  prefixText: '#',
                  hintText: 'Tag',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in suggestions)
                GestureDetector(
                  onTap: () => _addTag(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.surface,
                    ),
                    child: Text('#$s', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _commitTag(String raw) {
    _addTag(raw);
    _tagController.clear();
  }

  void _addTag(String raw) {
    final tag = raw.trim().replaceFirst('#', '').trim();
    if (tag.isEmpty) return;
    if (_tags.any((e) => e.toLowerCase() == tag.toLowerCase())) {
      _tagController.clear();
      setState(() {});
      return;
    }
    setState(() {
      _tags.add(tag);
      _tagController.clear();
    });
  }

  // ── Combined date + time picker ──
  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: AppColors.surface),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary, surface: AppColors.surface),
        ),
        child: child!,
      ),
    );

    setState(() {
      _dueDate = date;
      _dueTime = time; // null = date only
    });
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
                title: const Text('Benutzerdefiniert…'),
                onTap: () async {
                  Navigator.pop(context);
                  final date = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (date != null && mounted) {
                    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
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

/// Compact metadata chip — icon, optional value, optional clear button.
class _Chip extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String? value;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const _Chip({
    required this.icon,
    this.iconColor,
    this.value,
    this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: iconColor ?? AppColors.textSecondary),
              if (value != null) ...[
                const SizedBox(width: 6),
                Text(value!, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
              ],
              if (onClear != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(SolarIconsOutline.closeCircle, size: 15, color: AppColors.textTertiary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
