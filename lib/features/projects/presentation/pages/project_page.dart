import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../todos/domain/models/todo.dart';
import '../../../todos/providers/todo_provider.dart';
import '../../../todos/presentation/widgets/todo_input_sheet.dart';
import '../../../todos/presentation/widgets/todo_sectioned_list.dart';
import '../../../todos/presentation/widgets/quick_add_fab.dart';
import '../../domain/models/project.dart';
import '../../providers/project_provider.dart';
import '../widgets/project_edit_dialog.dart';

enum _SortMode { manual, priority, dueDate, name }

class ProjectPage extends ConsumerStatefulWidget {
  final Project project;

  const ProjectPage({super.key, required this.project});

  @override
  ConsumerState<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends ConsumerState<ProjectPage> {
  _SortMode _sortMode = _SortMode.manual;

  void _showAddTodoSheet(BuildContext context) {
    final currentProject = ref.read(projectProvider).getById(widget.project.id) ?? widget.project;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TodoInputSheet(
        defaultProjectName: currentProject.name,
        defaultProjectId: currentProject.id,
        onSubmit: (title, dueDate, dueTime, priority, projectId, labels, pinned) {
          ref.read(todoProvider.notifier).addTodo(
            title: title,
            projectId: projectId ?? currentProject.id,
            dueDate: dueDate,
            dueTime: dueTime,
            priority: priority != null ? TodoPriority.fromValue(priority) : TodoPriority.p4,
            labelIds: labels,
            isPinned: pinned,
          );
        },
      ),
    );
  }

  Future<void> _openEditDialog(BuildContext context) async {
    final currentProject = ref.read(projectProvider).getById(widget.project.id) ?? widget.project;
    final result = await ProjectEditDialog.show(context, project: currentProject);
    if (result == null && context.mounted) {
      Navigator.pop(context);
    }
  }

  List<Todo> _sortTodos(List<Todo> todos) {
    final sorted = List<Todo>.from(todos);
    switch (_sortMode) {
      case _SortMode.manual:
        sorted.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      case _SortMode.priority:
        sorted.sort((a, b) => a.priority.value.compareTo(b.priority.value));
      case _SortMode.dueDate:
        sorted.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
      case _SortMode.name:
        sorted.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final todoState = ref.watch(todoProvider);
    final settings = ref.watch(settingsProvider);
    final projectState = ref.watch(projectProvider);
    final currentProject = projectState.getById(widget.project.id) ?? widget.project;

    final projectTodos = todoState.todos
        .where((t) => !t.isCompleted && t.projectId == currentProject.id)
        .toList();
    final completedTodos = todoState.todos
        .where((t) => t.isCompleted && t.projectId == currentProject.id)
        .toList();

    final sortedTodos = _sortTodos(projectTodos);
    final largeCheckbox = settings.checkboxSize == CheckboxSize.large;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(currentProject.name),
        actions: [
          // Sort menu
          PopupMenuButton<String>(
            icon: const Icon(SolarIconsOutline.sortVertical),
            tooltip: 'Sortieren',
            onSelected: (value) {
              setState(() {
                switch (value) {
                  case 'manual':
                    _sortMode = _SortMode.manual;
                  case 'priority':
                    _sortMode = _SortMode.priority;
                  case 'dueDate':
                    _sortMode = _SortMode.dueDate;
                  case 'name':
                    _sortMode = _SortMode.name;
                }
              });
            },
            itemBuilder: (_) => [
              _sortMenuItem('manual', 'Manuell', _sortMode == _SortMode.manual),
              _sortMenuItem('priority', 'Priorität', _sortMode == _SortMode.priority),
              _sortMenuItem('dueDate', 'Fälligkeitsdatum', _sortMode == _SortMode.dueDate),
              _sortMenuItem('name', 'Name', _sortMode == _SortMode.name),
            ],
          ),
          IconButton(
            icon: const Icon(SolarIconsOutline.pen),
            onPressed: () => _openEditDialog(context),
            tooltip: 'Bearbeiten',
          ),
        ],
      ),
      // Same simple sectioned list as the main "Alle" list — no stats header.
      body: sortedTodos.isEmpty && completedTodos.isEmpty
          ? _buildEmptyState(currentProject)
          : TodoSectionedList(
              active: sortedTodos,
              completed: completedTodos,
              large: largeCheckbox,
            ),
      floatingActionButton: QuickAddFab(
        onPressed: () => _showAddTodoSheet(context),
      ),
    );
  }

  Widget _buildEmptyState(Project currentProject) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(SolarIconsOutline.folder, size: 64, color: Color(currentProject.color).withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('Keine Aufgaben', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Tippe auf + um eine Aufgabe hinzuzufügen',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _sortMenuItem(String value, String label, bool isActive) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (isActive) Icon(Icons.check, size: 18, color: AppColors.primary) else const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}
