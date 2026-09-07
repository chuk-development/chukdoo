import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../domain/models/todo.dart';
import '../../providers/todo_provider.dart';
import '../../../projects/providers/project_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../nlp/parser/date_parser.dart';
import '../../../nlp/parser/natural_language_parser.dart';
import '../../../notifications/reminder_scheduler.dart';

class TodoDetailPage extends ConsumerStatefulWidget {
  final Todo todo;

  /// When set, the page is hosted in a panel (desktop) — close/save/delete
  /// call this instead of popping a route.
  final VoidCallback? onClose;

  const TodoDetailPage({super.key, required this.todo, this.onClose});

  @override
  ConsumerState<TodoDetailPage> createState() => _TodoDetailPageState();
}

class _TodoDetailPageState extends ConsumerState<TodoDetailPage> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _tagController;
  late FocusNode _descFocus;
  late FocusNode _tagFocus;
  bool _editingDesc = false;
  late DateTime? _dueDate;
  late TimeOfDay? _dueTime;
  late TodoPriority _priority;
  DateTime? _reminderTime;
  late bool _isPinned;
  String? _projectId;
  late List<String> _tags;

  /// In panel mode (onClose set) edits persist without an explicit Save.
  bool get _panelMode => widget.onClose != null;
  bool _skipAutoSave = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo.title);
    _descriptionController = TextEditingController(text: widget.todo.description ?? '');
    _tagController = TextEditingController();
    _tagFocus = FocusNode();
    _descFocus = FocusNode();
    _descFocus.addListener(() {
      if (!_descFocus.hasFocus && _editingDesc) {
        setState(() => _editingDesc = false);
      }
    });
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
    // Persist pending edits when the panel swaps notes / closes.
    if (_panelMode && !_skipAutoSave) {
      ref.read(todoProvider.notifier).updateTodo(_buildUpdated());
      ref.read(settingsProvider.notifier).rememberTags(_tags);
      ReminderScheduler.instance.scheduleForTodo(_buildUpdated());
    }
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    _tagFocus.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  void _close() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.pop(context);
    }
  }

  Todo _buildUpdated() {
    final title = _titleController.text.trim();
    final desc = _descriptionController.text.trim();
    return widget.todo.copyWith(
      title: title.isEmpty ? widget.todo.title : title,
      description: desc.isEmpty ? null : desc,
      dueDate: _dueDate,
      dueTime: _dueTime,
      priority: _priority,
      reminderAt: _reminderTime,
      isPinned: _isPinned,
      projectId: _projectId,
      labelIds: _tags,
      clearDescription: desc.isEmpty,
      clearDueDate: _dueDate == null,
      clearDueTime: _dueTime == null,
      clearReminder: _reminderTime == null,
      clearProjectId: _projectId == null,
    );
  }

  void _save() {
    _skipAutoSave = true;
    final updated = _buildUpdated();
    ref.read(todoProvider.notifier).updateTodo(updated);
    ref.read(settingsProvider.notifier).rememberTags(_tags);
    ReminderScheduler.instance.scheduleForTodo(updated);
    _close();
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete task?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _skipAutoSave = true; // don't let dispose re-create it
              Navigator.pop(context); // close dialog
              ReminderScheduler.instance.cancelForTodo(widget.todo.id);
              ref.read(todoProvider.notifier).deleteTodo(widget.todo.id);
              _close();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
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
          icon: Icon(MdiIcons.closeCircleOutline),
          onPressed: _close,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isPinned ? MdiIcons.bookmark : MdiIcons.bookmarkOutline,
              color: _isPinned ? AppColors.orange : null,
            ),
            tooltip: _isPinned ? 'Unpin' : 'Pin',
            onPressed: () => setState(() => _isPinned = !_isPinned),
          ),
          IconButton(
            icon: Icon(MdiIcons.trashCanOutline),
            onPressed: _delete,
          ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title — normal text weight, not a heading.
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, height: 1.35),
              decoration: const InputDecoration(
                hintText: 'Task',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
              ),
              maxLines: null,
            ),
            const SizedBox(height: 6),
            Divider(height: 1, thickness: 1, color: AppColors.divider),
            const SizedBox(height: 14),

            // Description — Markdown: rendered when not editing, raw on tap.
            _buildDescription(),
            const SizedBox(height: 24),

            // Properties — flat, squared, divided rows.
            _propGroup([
              _propRow(
                icon: MdiIcons.calendarOutline,
                iconColor: _dueDate != null ? AppColors.purple : null,
                label: 'Date',
                value: _dateLabel,
                valueColor: _dueDate != null ? AppColors.textPrimary : null,
                onTap: _pickDateTime,
                onClear: _dueDate != null
                    ? () => setState(() {
                          _dueDate = null;
                          _dueTime = null;
                        })
                    : null,
              ),
              PopupMenuButton<TodoPriority>(
                color: AppColors.surface,
                position: PopupMenuPosition.under,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (p) => setState(() => _priority = p),
                itemBuilder: (_) => [
                  for (final p in [TodoPriority.p1, TodoPriority.p2, TodoPriority.p3])
                    PopupMenuItem(
                      value: p,
                      height: 40,
                      child: Row(
                        children: [
                          Icon(MdiIcons.flag, size: 16, color: AppColors.getPriorityColor(p.value)),
                          const SizedBox(width: 10),
                          Text('Priority ${p.value}'),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: TodoPriority.p4,
                    height: 40,
                    child: Row(
                      children: [
                        Icon(MdiIcons.flagOutline, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        const Text('None'),
                      ],
                    ),
                  ),
                ],
                child: _propRow(
                  icon: _priority == TodoPriority.p4 ? MdiIcons.flagOutline : MdiIcons.flag,
                  iconColor: _priority == TodoPriority.p4
                      ? null
                      : AppColors.getPriorityColor(_priority.value),
                  label: 'Priority',
                  value: _priority == TodoPriority.p4 ? null : 'P${_priority.value}',
                  valueColor: AppColors.getPriorityColor(_priority.value),
                ),
              ),
              PopupMenuButton<String?>(
                color: AppColors.surface,
                position: PopupMenuPosition.under,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (id) => setState(() => _projectId = id),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: null,
                    height: 40,
                    child: Row(
                      children: [
                        Icon(MdiIcons.inboxOutline, size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 10),
                        Text('No project'),
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
                            color: Color(p.color),
                          ),
                          const SizedBox(width: 10),
                          Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                ],
                child: _propRow(
                  icon: MdiIcons.folderOutline,
                  iconColor: project != null ? Color(project.color) : null,
                  label: 'Project',
                  value: project?.name,
                  valueColor: project != null ? AppColors.textPrimary : null,
                ),
              ),
              _propRow(
                icon: MdiIcons.bellOutline,
                iconColor: _reminderTime != null ? AppColors.orange : null,
                label: 'Reminder',
                value: _reminderTime != null
                    ? '${_reminderTime!.day}.${_reminderTime!.month} ${_two(_reminderTime!.hour)}:${_two(_reminderTime!.minute)}'
                    : null,
                valueColor: _reminderTime != null ? AppColors.textPrimary : null,
                onTap: _showReminderPicker,
                onClear: _reminderTime != null ? () => setState(() => _reminderTime = null) : null,
              ),
            ]),

            const SizedBox(height: 16),
            _buildTags(settings.knownTags),
          ],
        ),
      ),
    );
  }

  // ── Description with Markdown ──
  // Renders Markdown when not focused; tap to edit the raw text.
  Widget _buildDescription() {
    final text = _descriptionController.text.trim();

    if (_editingDesc || text.isEmpty) {
      return TextField(
        controller: _descriptionController,
        focusNode: _descFocus,
        autofocus: _editingDesc,
        style: const TextStyle(fontSize: 16, height: 1.4),
        decoration: InputDecoration(
          hintText: 'Description (Markdown supported)',
          hintStyle: TextStyle(color: AppColors.textSecondary),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
        ),
        maxLines: null,
        minLines: 3,
        onChanged: (_) => setState(() {}),
      );
    }

    return InkWell(
      onTap: () {
        setState(() => _editingDesc = true);
        _descFocus.requestFocus();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: GptMarkdown(
          text,
          style: TextStyle(fontSize: 16, height: 1.4, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  /// Rounded surface used to group the tags section.
  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  /// Rounded surface wrapping a vertical list of property rows, hairline-divided.
  Widget _propGroup(List<Widget> rows) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i != rows.length - 1) {
        children.add(Divider(
          height: 1,
          thickness: 1,
          indent: 48,
          color: AppColors.divider,
        ));
      }
    }
    // Material (not Container) so InkWell ripples clip to the rounded corners
    // instead of painting a square highlight on the ancestor Material.
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  /// A single full-width property row: icon · label · value · clear/chevron.
  Widget _propRow({
    required IconData icon,
    Color? iconColor,
    required String label,
    String? value,
    Color? valueColor,
    VoidCallback? onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? AppColors.textSecondary),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(fontSize: 15, color: AppColors.textPrimary)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value ?? '',
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: valueColor ?? AppColors.textSecondary),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(MdiIcons.closeCircleOutline, size: 18, color: AppColors.textTertiary),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(MdiIcons.chevronRight, size: 16, color: AppColors.textTertiary),
              ),
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

    return _sectionCard(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(MdiIcons.pound, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text('Tags', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final tag in _tags)
              Container(
                padding: const EdgeInsets.fromLTRB(13, 8, 9, 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('#$tag',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.primary)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() => _tags.remove(tag)),
                      child: Icon(MdiIcons.closeCircle, size: 18, color: AppColors.primary.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            // Inline input
            SizedBox(
              width: 160,
              child: TextField(
                controller: _tagController,
                focusNode: _tagFocus,
                textInputAction: TextInputAction.next,
                onChanged: (v) {
                  if (v.endsWith(' ')) {
                    _commitTag(v);
                  } else {
                    setState(() {});
                  }
                },
                onSubmitted: _commitTag,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                  prefixText: '#',
                  prefixStyle: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                  hintText: 'Add tag',
                  hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 15),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final s in suggestions)
                GestureDetector(
                  onTap: () => _addTag(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.background,
                      border: Border.all(color: AppColors.divider, width: 1),
                    ),
                    child: Text('#$s', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ),
                ),
            ],
          ),
        ],
      ],
      ),
    );
  }

  void _commitTag(String raw) {
    _addTag(raw);
    _tagController.clear();
    // Keep the field focused so the next tag can be typed straight away.
    _tagFocus.requestFocus();
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
          colorScheme: ColorScheme.dark(primary: AppColors.primary, surface: AppColors.surface),
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
          colorScheme: ColorScheme.dark(primary: AppColors.primary, surface: AppColors.surface),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppShapes.sheetTop)),
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
              const Text('Reminder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              if (dueDateTime != null) ...[
                ListTile(
                  leading: Icon(MdiIcons.bellRingOutline),
                  title: const Text('30 minutes before'),
                  onTap: () {
                    setState(() => _reminderTime = dueDateTime.subtract(const Duration(minutes: 30)));
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Icon(MdiIcons.bellRingOutline),
                  title: const Text('1 hour before'),
                  onTap: () {
                    setState(() => _reminderTime = dueDateTime.subtract(const Duration(hours: 1)));
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Icon(MdiIcons.bellRingOutline),
                  title: const Text('1 day before'),
                  onTap: () {
                    setState(() => _reminderTime = dueDateTime.subtract(const Duration(days: 1)));
                    Navigator.pop(context);
                  },
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Set a due date and time first'),
                ),
              ListTile(
                leading: Icon(MdiIcons.calendarPlusOutline),
                title: const Text('Custom…'),
                onTap: () async {
                  Navigator.pop(context);
                  final date = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (date != null && context.mounted) {
                    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (time != null && context.mounted) {
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

