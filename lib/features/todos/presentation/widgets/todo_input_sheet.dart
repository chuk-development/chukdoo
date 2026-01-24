import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../../core/theme/app_colors.dart';
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
    );

    // Clear and keep sheet open for next todo
    _controller.clear();
    setState(() {
      _selectedDate = widget.defaultDueDate;
      _selectedTime = null;
      _selectedPriority = null;
      _selectedProjectName = widget.defaultProjectName;
      _selectedProjectId = widget.defaultProjectId;
      // Reset parsing flags
      _dateFromParsing = false;
      _timeFromParsing = false;
      _priorityFromParsing = false;
      _projectFromParsing = false;
    });
    _focusNode.requestFocus();
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Input field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: 'z.B. Arzt anrufen morgen 15 uhr p1',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              maxLines: null,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handleSubmit(),
            ),
          ),

          // Quick action chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Date chip
                _buildChip(
                  icon: SolarIconsOutline.calendar,
                  label: _selectedDate != null
                      ? DateParser.formatDate(_selectedDate!, Language.german)
                      : 'Datum',
                  color: _selectedDate != null ? AppColors.purple : null,
                  onTap: () => _showDatePicker(),
                ),

                // Time chip
                _buildChip(
                  icon: SolarIconsOutline.clockCircle,
                  label: _selectedTime != null
                      ? _formatTime(_selectedTime!)
                      : 'Zeit',
                  color: _selectedTime != null ? AppColors.blue : null,
                  onTap: () => _showTimePicker(),
                ),

                // Priority chip
                _buildChip(
                  icon: SolarIconsOutline.flag,
                  label: _selectedPriority != null && _selectedPriority! < 4
                      ? 'P$_selectedPriority'
                      : 'Priorität',
                  color: _selectedPriority != null && _selectedPriority! < 4
                      ? AppColors.getPriorityColor(_selectedPriority!)
                      : null,
                  onTap: () => _showPriorityPicker(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bottom row with project selector and submit button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                // Project selector
                InkWell(
                  onTap: () => _showProjectPicker(),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          SolarIconsOutline.inboxLine,
                          size: 16,
                          color: _selectedProjectName != null
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedProjectName ?? 'Eingang',
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedProjectName != null
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          SolarIconsOutline.altArrowDown,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),

                // Submit button
                SizedBox(
                  width: 48,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _controller.text.trim().isNotEmpty ? _handleSubmit : null,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(SolarIconsBold.roundArrowUp),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    final isActive = color != null;
    final displayColor = color ?? AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? displayColor.withOpacity(0.15) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: displayColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: displayColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDatePicker() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
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
      setState(() {
        _selectedDate = picked;
        _dateFromParsing = false; // Manual selection
      });
    }
  }

  void _showTimePicker() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
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
      setState(() {
        _selectedTime = picked;
        _timeFromParsing = false; // Manual selection
      });
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
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Priorität',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(3, (index) {
              final priority = index + 1;
              final color = AppColors.getPriorityColor(priority);
              return ListTile(
                leading: Icon(SolarIconsBold.flag, color: color),
                title: Text('Priorität $priority'),
                trailing: _selectedPriority == priority
                    ? const Icon(SolarIconsBold.checkSquare, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedPriority = priority;
                    _priorityFromParsing = false; // Manual selection
                  });
                  Navigator.pop(context);
                },
              );
            }),
            ListTile(
              leading: Icon(SolarIconsOutline.flag, color: AppColors.textSecondary),
              title: const Text('Keine Priorität'),
              trailing: _selectedPriority == null || _selectedPriority == 4
                  ? const Icon(SolarIconsBold.checkSquare, color: AppColors.primary)
                  : null,
              onTap: () {
                setState(() {
                  _selectedPriority = null;
                  _priorityFromParsing = false; // Manual selection
                });
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showProjectPicker() {
    final projectState = ref.read(projectProvider);
    final projects = projectState.sortedProjects;

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
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Projekt',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(SolarIconsBold.inboxLine, color: AppColors.blue),
              title: const Text('Eingang'),
              trailing: _selectedProjectId == null
                  ? const Icon(SolarIconsBold.checkSquare, color: AppColors.primary)
                  : null,
              onTap: () {
                setState(() {
                  _selectedProjectName = null;
                  _selectedProjectId = null;
                  _projectFromParsing = false; // Manual selection
                });
                Navigator.pop(context);
              },
            ),
            if (projects.isNotEmpty) ...[
              const Divider(),
              ...projects.map((project) => ListTile(
                leading: Icon(
                  SolarIconsOutline.folder,
                  color: Color(project.color),
                ),
                title: Text(project.name),
                trailing: _selectedProjectId == project.id
                    ? const Icon(SolarIconsBold.checkSquare, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedProjectName = project.name;
                    _selectedProjectId = project.id;
                    _projectFromParsing = false; // Manual selection
                  });
                  Navigator.pop(context);
                },
              )),
            ],
            const Divider(),
            ListTile(
              leading: Icon(SolarIconsOutline.addCircle, color: AppColors.textSecondary),
              title: const Text('Neues Projekt erstellen'),
              onTap: () {
                Navigator.pop(context);
                _showCreateProjectDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
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
        backgroundColor: AppColors.surface,
        title: const Text('Neues Projekt'),
        content: TextField(
          controller: projectController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Projektname',
          ),
          onSubmitted: (_) => createProject(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: createProject,
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );
  }
}
