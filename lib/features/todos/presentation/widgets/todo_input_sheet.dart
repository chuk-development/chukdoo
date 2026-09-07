import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../nlp/parser/natural_language_parser.dart';
import '../../../nlp/parser/date_parser.dart';
import '../../../projects/providers/project_provider.dart';

class TodoInputSheet extends ConsumerStatefulWidget {
  final DateTime? defaultDueDate;
  final String? defaultProjectName;
  final String? defaultProjectId;
  final void Function(
    String title,
    DateTime? dueDate,
    TimeOfDay? dueTime,
    int? priority,
    String? projectId,
    List<String> labels,
    bool pinned,
  ) onSubmit;

  const TodoInputSheet({
    super.key,
    this.defaultDueDate,
    this.defaultProjectName,
    this.defaultProjectId,
    required this.onSubmit,
  });

  @override
  ConsumerState<TodoInputSheet> createState() => _TodoInputSheetState();
}

class _TodoInputSheetState extends ConsumerState<TodoInputSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _parser = NaturalLanguageParser();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int? _selectedPriority;
  String? _selectedProjectName;
  String? _selectedProjectId;
  bool _pinned = false;

  // Track if values were set from text parsing (vs manual picker)
  bool _dateFromParsing = false;
  bool _timeFromParsing = false;
  bool _priorityFromParsing = false;
  bool _projectFromParsing = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.defaultDueDate;
    _selectedProjectName = widget.defaultProjectName;
    _selectedProjectId = widget.defaultProjectId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    if (text.isEmpty) {
      setState(() {
        // Clear all parsed values when text is empty
        if (_dateFromParsing) {
          _selectedDate = widget.defaultDueDate;
          _dateFromParsing = false;
        }
        if (_timeFromParsing) {
          _selectedTime = null;
          _timeFromParsing = false;
        }
        if (_priorityFromParsing) {
          _selectedPriority = null;
          _priorityFromParsing = false;
        }
        if (_projectFromParsing) {
          _selectedProjectName = widget.defaultProjectName;
          _selectedProjectId = widget.defaultProjectId;
          _projectFromParsing = false;
        }
      });
      return;
    }

    final result = _parser.parse(text);
    setState(() {
      // Date: set if parsed, clear if was from parsing and no longer detected
      if (result.dueDate != null) {
        _selectedDate = result.dueDate;
        _dateFromParsing = true;
      } else if (_dateFromParsing) {
        _selectedDate = widget.defaultDueDate;
        _dateFromParsing = false;
      }

      // Time: set if parsed, clear if was from parsing and no longer detected
      if (result.dueTime != null) {
        _selectedTime = result.dueTime;
        _timeFromParsing = true;
      } else if (_timeFromParsing) {
        _selectedTime = null;
        _timeFromParsing = false;
      }

      // Priority: set if parsed, clear if was from parsing and no longer detected
      if (result.priority != null) {
        _selectedPriority = result.priority;
        _priorityFromParsing = true;
      } else if (_priorityFromParsing) {
        _selectedPriority = null;
        _priorityFromParsing = false;
      }

      // Project: set if parsed, clear if was from parsing and no longer detected
      if (result.projectName != null) {
        _selectedProjectName = result.projectName;
        _projectFromParsing = true;
        // Try to find project ID from name
        final projectState = ref.read(projectProvider);
        final matchingProject = projectState.projects
            .where((p) => p.name.toLowerCase() == result.projectName!.toLowerCase())
            .firstOrNull;
        if (matchingProject != null) {
          _selectedProjectId = matchingProject.id;
        }
      } else if (_projectFromParsing) {
        _selectedProjectName = widget.defaultProjectName;
        _selectedProjectId = widget.defaultProjectId;
        _projectFromParsing = false;
      }
    });
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final result = _parser.parse(text);
    widget.onSubmit(
      result.title.isEmpty ? text : result.title,
      _selectedDate ?? result.dueDate,
      _selectedTime ?? result.dueTime,
      _selectedPriority ?? result.priority,
      _selectedProjectId,
      result.labels,
      _pinned,
    );

    // Clear and keep sheet open for next todo
    _controller.clear();
    setState(() {
      _selectedDate = widget.defaultDueDate;
      _selectedTime = null;
      _selectedPriority = null;
      _selectedProjectName = widget.defaultProjectName;
      _selectedProjectId = widget.defaultProjectId;
      _pinned = false;
      // Reset parsing flags
      _dateFromParsing = false;
      _timeFromParsing = false;
      _priorityFromParsing = false;
      _projectFromParsing = false;
    });
    _focusNode.requestFocus();
  }

  /// Keep the keyboard up after tapping a chip / picker / popup. Those steal
  /// focus from the text field, which collapses the keyboard; re-requesting
  /// focus keeps it open so the user can keep typing.
  void _refocus() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      // requestFocus alone won't re-show the keyboard if focus never fully
      // left the field — force the IME to show.
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    // Plain Container (no AnimatedContainer): the implicit resize animation
    // fights the Android keyboard insets and stutters on some ROMs.
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppShapes.sheetTop)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Input field — borderless (no box around it), just bigger.
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 10, 4),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: const TextStyle(fontSize: 20),
              decoration: InputDecoration(
                hintText: 'Task  (mi 15:00 !1 #projekt)',
                hintStyle: TextStyle(
                  fontSize: 20,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                suffixIcon: _SendButton(
                  enabled: _controller.text.trim().isNotEmpty,
                  onPressed: _handleSubmit,
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 46,
                  minHeight: 46,
                ),
              ),
              minLines: 1,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSubmit(),
            ),
          ),

          // Chips row
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 16),
            child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                // Combined date + time
                InkWell(
                  onTap: _pickDateTime,
                  borderRadius: BorderRadius.circular(AppShapes.dockChip),
                  child: _dateChip(),
                ),

                // Priority — focus-preserving anchored menu (keyboard stays up).
                _MenuAnchor(
                  width: 200,
                  itemsBuilder: (close) => [
                    for (final p in [1, 2, 3])
                      _menuRow(
                        leading: Icon(MdiIcons.flag, size: 22, color: AppColors.getPriorityColor(p)),
                        label: 'Priority $p',
                        onTap: () {
                          setState(() {
                            _selectedPriority = p;
                            _priorityFromParsing = false;
                          });
                          close();
                          _refocus();
                        },
                      ),
                    _menuRow(
                      leading: Icon(MdiIcons.flagOutline, size: 22, color: AppColors.textSecondary),
                      label: 'None',
                      onTap: () {
                        setState(() {
                          _selectedPriority = null;
                          _priorityFromParsing = false;
                        });
                        close();
                        _refocus();
                      },
                    ),
                  ],
                  child: _chipBox(
                    icon: _hasPriority ? MdiIcons.flag : MdiIcons.flagOutline,
                    label: _hasPriority ? 'P$_selectedPriority' : null,
                    color: _hasPriority ? AppColors.getPriorityColor(_selectedPriority!) : null,
                  ),
                ),

                // Project / list — focus-preserving anchored menu.
                _MenuAnchor(
                  width: 260,
                  itemsBuilder: (close) {
                    final projects = ref.read(projectProvider).sortedProjects;
                    return [
                      _menuRow(
                        leading: Icon(MdiIcons.inboxOutline, size: 22, color: AppColors.textSecondary),
                        label: 'Inbox',
                        onTap: () {
                          _onProjectSelected(null);
                          close();
                        },
                      ),
                      for (final p in projects)
                        _menuRow(
                          leading: Container(
                            width: 16, height: 16,
                            decoration: BoxDecoration(color: Color(p.color), borderRadius: BorderRadius.circular(4)),
                          ),
                          label: p.name,
                          onTap: () {
                            _onProjectSelected(p.id);
                            close();
                          },
                        ),
                      _menuRow(
                        leading: Icon(MdiIcons.plusCircleOutline, size: 22, color: AppColors.primary),
                        label: 'New Project',
                        labelColor: AppColors.primary,
                        onTap: () {
                          close();
                          _showCreateProjectDialog();
                        },
                      ),
                    ];
                  },
                  child: _chipBox(
                    icon: MdiIcons.folderOutline,
                    label: _selectedProjectName,
                    color: _selectedProjectName != null ? AppColors.primary : null,
                  ),
                ),

                // Pin toggle — same chip, on/off
                InkWell(
                  onTap: () {
                    setState(() => _pinned = !_pinned);
                    _refocus();
                  },
                  borderRadius: BorderRadius.circular(AppShapes.dockChip),
                  child: _chipBox(
                    icon: _pinned ? MdiIcons.bookmark : MdiIcons.bookmarkOutline,
                    color: _pinned ? AppColors.orange : null,
                  ),
                ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  bool get _hasPriority => _selectedPriority != null && _selectedPriority! < 4;

  /// Short date label — drops the year when it falls in the current year so
  /// far-off dates don't stretch the chip (e.g. "21.6." instead of "21.6.2025").
  String get _dateLabelShort {
    final d = _selectedDate!;
    final label = DateParser.formatDate(d, Language.german);
    if (label.endsWith('.${DateTime.now().year}')) {
      return '${d.day}.${d.month}.';
    }
    return label;
  }

  /// Elegant date chip: date as the primary value, optional time as a subtle
  /// secondary segment behind a thin divider — reads as one tidy unit instead
  /// of a long stretched label.
  Widget _dateChip() {
    final hasDate = _selectedDate != null;
    final accent = hasDate ? AppColors.purple : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppShapes.dockChip),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(MdiIcons.calendarOutline, size: 25, color: accent),
          if (hasDate) ...[
            const SizedBox(width: 6),
            Text(_dateLabelShort,
                style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary)),
            if (_selectedTime != null) ...[
              const SizedBox(width: 7),
              Container(width: 1, height: 16, color: AppColors.divider),
              const SizedBox(width: 7),
              Icon(MdiIcons.clockOutline, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(_formatTime(_selectedTime!),
                  style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
            ],
          ],
        ],
      ),
    );
  }

  /// A roomy menu row used inside the anchored Priority / Project menus.
  /// Bigger text + taller hit target than the old PopupMenuItem.
  Widget _menuRow({
    required Widget leading,
    required String label,
    Color? labelColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  color: labelColor ?? AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Compact bordered chip — icon only until a value is chosen, then icon+value.
  Widget _chipBox({
    required IconData icon,
    String? label,
    Color? color,
    bool trailingArrow = false,
  }) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppShapes.dockChip),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 25, color: c),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary)),
          ],
          if (trailingArrow) ...[
            const SizedBox(width: 4),
            Icon(MdiIcons.chevronDown, size: 14, color: AppColors.textSecondary),
          ],
        ],
      ),
    );
  }

  /// Combined date + time picker (one flow).
  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    Widget themed(BuildContext context, Widget? child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(primary: AppColors.primary, surface: AppColors.surface),
          ),
          child: child!,
        );

    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: themed,
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: themed,
    );

    setState(() {
      _selectedDate = date;
      _selectedTime = time; // null = date only
      _dateFromParsing = false;
      _timeFromParsing = false;
    });
    _refocus();
  }

  void _onProjectSelected(String? value) {
    if (value == '__new__') {
      _showCreateProjectDialog();
      return;
    }
    setState(() {
      if (value == null) {
        _selectedProjectName = null;
        _selectedProjectId = null;
      } else {
        final p = ref.read(projectProvider).getById(value);
        _selectedProjectName = p?.name;
        _selectedProjectId = value;
      }
      _projectFromParsing = false;
    });
    _refocus();
  }

  void _showCreateProjectDialog() {
    final projectController = TextEditingController();

    void createProject() async {
      final name = projectController.text.trim();
      if (name.isNotEmpty) {
        final project = await ref.read(projectProvider.notifier).addProject(name: name);
        setState(() {
          _selectedProjectName = project.name;
          _selectedProjectId = project.id;
          _projectFromParsing = false; // Manual selection
        });
        if (mounted) Navigator.pop(context);
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Project'),
        content: TextField(
          controller: projectController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Project name',
            filled: true,
            fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppShapes.dockField),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) => createProject(),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: createProject,
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

/// Anchored dropdown that opens via an [OverlayEntry] (NOT a route), so the
/// text field keeps its focus and the soft keyboard stays open while the menu
/// is showing — unlike [PopupMenuButton], which pushes a route and dismisses
/// the keyboard.
class _MenuAnchor extends StatefulWidget {
  final Widget child;
  final List<Widget> Function(VoidCallback close) itemsBuilder;
  final double width;

  const _MenuAnchor({
    required this.child,
    required this.itemsBuilder,
    this.width = 220,
  });

  @override
  State<_MenuAnchor> createState() => _MenuAnchorState();
}

class _MenuAnchorState extends State<_MenuAnchor> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _open() {
    if (_entry != null) {
      _close();
      return;
    }
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            // Tap-outside barrier — translucent so it doesn't steal focus.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _close,
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 6),
              child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: AppColors.surface,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(AppShapes.dockField),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: widget.width,
                      maxHeight: 340,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.itemsBuilder(_close),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_entry!);
  }

  void _close() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: _open,
        child: widget.child,
      ),
    );
  }
}

/// Compact send button that sits inside the text field as a suffix icon.
class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _SendButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(38, 38),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShapes.dockField)),
        ),
        child: Icon(MdiIcons.send, size: 20),
      ),
    );
  }
}
