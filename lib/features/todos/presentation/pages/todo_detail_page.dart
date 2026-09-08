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
import '../../../../shared/widgets/app_field.dart';
import '../../../../shared/widgets/picker_sheet.dart';

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

  /// End of the task on its due day. Only reachable once the task has a
  /// start — "to 15:30" says nothing without a "from".
  late TimeOfDay? _endTime;
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
    _descriptionController = TextEditingController(
      text: widget.todo.description ?? '',
    );
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
    _endTime = widget.todo.endTime;
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
      endTime: _endTime,
      priority: _priority,
      reminderAt: _reminderTime,
      isPinned: _isPinned,
      projectId: _projectId,
      labelIds: _tags,
      clearDescription: desc.isEmpty,
      clearDueDate: _dueDate == null,
      clearDueTime: _dueTime == null,
      clearEndTime: _endTime == null,
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
    if (_dueTime != null) return '$label ${_hhmm(_dueTime!)}';
    return label;
  }

  String _hhmm(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';

  /// Value of the "Ends" row. Empty without a start time — the row is dead
  /// then anyway.
  String? get _endLabel =>
      (_dueTime == null || _endTime == null) ? null : _hhmm(_endTime!);

  @override
  Widget build(BuildContext context) {
    final projectState = ref.watch(projectProvider);
    final projects = projectState.sortedProjects;
    final settings = ref.watch(settingsProvider);
    final project = _projectId == null
        ? null
        : projectState.getById(_projectId!);

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
          IconButton(icon: Icon(MdiIcons.trashCanOutline), onPressed: _delete),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and description are two clearly separate fields: each one
            // is its own filled block with a label, so it is obvious which is
            // which.
            _inputBlock(
              label: 'Task',
              isFirst: true,
              isLast: false,
              child: TextField(
                controller: _titleController,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
                decoration: const InputDecoration(
                  hintText: 'What needs doing?',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isCollapsed: true,
                ),
                maxLines: null,
              ),
            ),
            _inputBlock(
              label: 'Description',
              isFirst: false,
              isLast: true,
              child: _buildDescription(),
            ),
            const SizedBox(height: 18),

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
                        _endTime = null;
                      })
                    : null,
              ),
              // From-to: the end turns the task into a real block in the
              // calendar. Dead while the task has no start time.
              _propRow(
                icon: MdiIcons.clockOutline,
                iconColor: _endTime != null ? AppColors.purple : null,
                label: 'Ends',
                value: _endLabel,
                valueColor: _endTime != null ? AppColors.textPrimary : null,
                onTap: _dueTime == null ? null : _pickEndTime,
                onClear: _endTime != null
                    ? () => setState(() => _endTime = null)
                    : null,
              ),
              _propRow(
                icon: _priority == TodoPriority.p4
                    ? MdiIcons.flagOutline
                    : MdiIcons.flag,
                iconColor: _priority == TodoPriority.p4
                    ? null
                    : AppColors.getPriorityColor(_priority.value),
                label: 'Priority',
                value: _priority == TodoPriority.p4
                    ? null
                    : 'P${_priority.value}',
                valueColor: AppColors.getPriorityColor(_priority.value),
                onTap: _pickPriority,
              ),
              _propRow(
                icon: MdiIcons.folderOutline,
                iconColor: project != null ? Color(project.color) : null,
                label: 'Project',
                value: project?.name,
                valueColor: project != null ? AppColors.textPrimary : null,
                onTap: () => _pickProject(projects),
              ),
              _propRow(
                icon: MdiIcons.bellOutline,
                iconColor: _reminderTime != null ? AppColors.orange : null,
                label: 'Reminder',
                value: _reminderTime != null
                    ? '${_reminderTime!.day}.${_reminderTime!.month} ${_two(_reminderTime!.hour)}:${_two(_reminderTime!.minute)}'
                    : null,
                valueColor: _reminderTime != null
                    ? AppColors.textPrimary
                    : null,
                onTap: _showReminderPicker,
                onClear: _reminderTime != null
                    ? () => setState(() => _reminderTime = null)
                    : null,
              ),
            ]),

            const SizedBox(height: 16),
            _buildTags(settings.knownTags),
          ],
        ),
      ),
    );
  }

  /// A labelled input block — the shape every field in the app uses.
  Widget _inputBlock({
    required String label,
    required Widget child,
    required bool isFirst,
    required bool isLast,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppShapes.groupGap),
      child: AppField(
        label: label,
        isFirst: isFirst,
        isLast: isLast,
        child: child,
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
          hintText: 'Markdown supported',
          hintStyle: TextStyle(color: AppColors.textSecondary),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isCollapsed: true,
        ),
        maxLines: null,
        minLines: 2,
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
          style: TextStyle(
            fontSize: 16,
            height: 1.4,
            color: AppColors.textPrimary,
          ),
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
        borderRadius: BorderRadius.circular(AppShapes.groupOuter),
      ),
      child: child,
    );
  }

  /// Rounded surface wrapping a vertical list of property rows, hairline-divided.
  /// The property rows are drawn like every other list in the app: one group,
  /// strong outer corners, soft corners in between, no hairlines.
  Widget _propGroup(List<Widget> rows) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
            Text(
              label,
              style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value ?? '',
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: valueColor ?? AppColors.textSecondary,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    MdiIcons.closeCircleOutline,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  MdiIcons.chevronRight,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
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
        .where(
          (t) => input.isEmpty || t.toLowerCase().contains(input.toLowerCase()),
        )
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
              Text(
                'Tags',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
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
                    borderRadius: BorderRadius.circular(AppShapes.dockChip),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '#$tag',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() => _tags.remove(tag)),
                        child: Icon(
                          MdiIcons.closeCircle,
                          size: 18,
                          color: AppColors.primary.withValues(alpha: 0.7),
                        ),
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
                    prefixStyle: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                    hintText: 'Add tag',
                    hintStyle: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 15,
                    ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppShapes.dockChip),
                        color: AppColors.background,
                      ),
                      child: Text(
                        '#$s',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
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

  // ── Every picker in this page opens the same sheet ──
  Future<void> _pickDateTime() async {
    final choice = await showDateTimeSheet(
      context: context,
      title: 'Due date',
      date: _dueDate,
      time: _dueTime,
    );
    if (choice == null || !mounted) return;
    setState(() {
      _dueDate = choice.date;
      _dueTime = choice.time;
      // Dropping the start drops the span with it.
      if (_dueTime == null) _endTime = null;
    });
  }

  Future<void> _pickEndTime() async {
    final start = _dueTime;
    if (start == null) return;

    // Half an hour is the length the calendar already draws a timed task
    // with, so it is what the sheet offers first.
    final suggested = TimeOfDay(
      hour: (start.hour + (start.minute >= 30 ? 1 : 0)) % 24,
      minute: (start.minute + 30) % 60,
    );

    final choice = await showDateTimeSheet(
      context: context,
      title: 'Ends',
      date: _dueDate,
      time: _endTime ?? suggested,
    );
    if (choice == null || !mounted) return;
    // A task ends on the day it starts, so only the time is taken from the
    // sheet; no time (Clear) means the task has no end again.
    setState(() => _endTime = choice.time);
  }

  Future<void> _pickPriority() async {
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
            selected: _priority == p,
          ),
        PickerOption(
          value: TodoPriority.p4,
          label: 'None',
          icon: MdiIcons.flagOutline,
          selected: _priority == TodoPriority.p4,
        ),
      ],
    );
    if (picked != null && mounted) setState(() => _priority = picked);
  }

  Future<void> _pickProject(List<dynamic> projects) async {
    final picked = await showPickerSheet<String>(
      context: context,
      title: 'Project',
      options: [
        PickerOption(
          value: '',
          label: 'No project',
          icon: MdiIcons.inboxOutline,
          selected: _projectId == null,
        ),
        for (final p in projects)
          PickerOption(
            value: p.id as String,
            label: p.name as String,
            leading: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Color(p.color as int),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            selected: _projectId == p.id,
          ),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() => _projectId = picked.isEmpty ? null : picked);
  }

  Future<void> _showReminderPicker() async {
    final dueDateTime = _dueDate != null && _dueTime != null
        ? DateTime(
            _dueDate!.year,
            _dueDate!.month,
            _dueDate!.day,
            _dueTime!.hour,
            _dueTime!.minute,
          )
        : null;

    final picked = await showPickerSheet<Duration?>(
      context: context,
      title: 'Reminder',
      footnote: dueDateTime == null
          ? 'Set a due date and time to use the quick options.'
          : null,
      options: [
        if (dueDateTime != null) ...[
          PickerOption(
            value: const Duration(minutes: 30),
            label: '30 minutes before',
            icon: MdiIcons.bellRingOutline,
          ),
          PickerOption(
            value: const Duration(hours: 1),
            label: '1 hour before',
            icon: MdiIcons.bellRingOutline,
          ),
          PickerOption(
            value: const Duration(days: 1),
            label: '1 day before',
            icon: MdiIcons.bellRingOutline,
          ),
        ],
        const PickerOption(
          value: null,
          label: 'Pick a date and time…',
          icon: Icons.event,
        ),
      ],
    );

    if (!mounted) return;

    if (picked != null && dueDateTime != null) {
      setState(() => _reminderTime = dueDateTime.subtract(picked));
      return;
    }

    final choice = await showDateTimeSheet(
      context: context,
      title: 'Reminder',
      date: _reminderTime,
      time: _reminderTime != null
          ? TimeOfDay(hour: _reminderTime!.hour, minute: _reminderTime!.minute)
          : null,
    );
    if (choice == null || !mounted) return;
    setState(() {
      final date = choice.date;
      final time = choice.time;
      _reminderTime = date == null
          ? null
          : DateTime(
              date.year,
              date.month,
              date.day,
              time?.hour ?? 9,
              time?.minute ?? 0,
            );
    });
  }
}
