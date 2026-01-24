import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../todos/domain/models/todo.dart';
import '../../../todos/providers/todo_provider.dart';
import '../../../todos/presentation/widgets/todo_input_sheet.dart';
import '../../../todos/presentation/widgets/todo_item.dart';
import '../../../todos/presentation/widgets/quick_add_fab.dart';
import '../../../todos/presentation/pages/todo_detail_page.dart';
import '../../domain/models/project.dart';
import '../../providers/project_provider.dart';

class ProjectPage extends ConsumerWidget {
  final Project project;

  const ProjectPage({super.key, required this.project});

  void _showAddTodoSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TodoInputSheet(
        defaultProjectName: project.name,
        defaultProjectId: project.id,
        onSubmit: (title, dueDate, dueTime, priority, projectId) {
          ref.read(todoProvider.notifier).addTodo(
            title: title,
            projectId: projectId ?? project.id,
            dueDate: dueDate,
            dueTime: dueTime,
            priority: priority != null
                ? TodoPriority.fromValue(priority)
                : TodoPriority.p4,
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Projekt löschen?'),
        content: Text(
          'Das Projekt "${project.name}" wird gelöscht. Aufgaben bleiben im Eingang erhalten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              ref.read(projectProvider.notifier).deleteProject(project.id);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close project page
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todoState = ref.watch(todoProvider);
    final settings = ref.watch(settingsProvider);
    final showCompleted = todoState.showCompleted;

    // Get todos for this project
    final projectTodos = todoState.todos
        .where((t) => !t.isCompleted && t.projectId == project.id)
        .toList();
    final completedTodos = todoState.todos
        .where((t) => t.isCompleted && t.projectId == project.id)
        .toList();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          if (completedTodos.isNotEmpty)
            IconButton(
              icon: Icon(
                showCompleted ? SolarIconsBold.checkCircle : SolarIconsOutline.checkCircle,
                color: showCompleted ? AppColors.primary : null,
              ),
              onPressed: () {
                ref.read(todoProvider.notifier).toggleShowCompleted();
              },
              tooltip: showCompleted ? 'Erledigte ausblenden' : 'Erledigte anzeigen',
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteConfirmation(context, ref);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(SolarIconsOutline.trashBinTrash, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Projekt löschen', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: projectTodos.isEmpty && (!showCompleted || completedTodos.isEmpty)
          ? _buildEmptyState()
          : SlidableAutoCloseBehavior(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  // Active todos
                  ...projectTodos.map((todo) => _buildTodoItem(context, ref, todo, settings.checkboxSize == CheckboxSize.large)),
                  // Completed todos section
                  if (showCompleted && completedTodos.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Erledigt (${completedTodos.length})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    ...completedTodos.map((todo) => _buildTodoItem(context, ref, todo, settings.checkboxSize == CheckboxSize.large, isCompleted: true)),
                  ],
                ],
              ),
            ),
      floatingActionButton: QuickAddFab(
        onPressed: () => _showAddTodoSheet(context, ref),
      ),
    );
  }

  Widget _buildTodoItem(BuildContext context, WidgetRef ref, Todo todo, bool largeCheckbox, {bool isCompleted = false}) {
    return Slidable(
      key: ValueKey(todo.id),
      startActionPane: isCompleted ? null : ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.25,
        dismissible: DismissiblePane(
          dismissThreshold: 0.5,
          onDismissed: () {
            ref.read(todoProvider.notifier).toggleComplete(todo.id);
          },
        ),
        children: [
          SlidableAction(
            onPressed: (_) {
              ref.read(todoProvider.notifier).toggleComplete(todo.id);
            },
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
            icon: SolarIconsBold.checkCircle,
            label: 'Erledigt',
          ),
        ],
      ),
      child: Opacity(
        opacity: isCompleted ? 0.6 : 1.0,
        child: TodoItem(
          title: todo.title,
          priority: todo.priority.value,
          dueDate: todo.dueDate,
          isCompleted: isCompleted,
          largeCheckbox: largeCheckbox,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TodoDetailPage(todo: todo),
              ),
            );
          },
          onComplete: () {
            ref.read(todoProvider.notifier).toggleComplete(todo.id);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              SolarIconsOutline.folder,
              size: 80,
              color: Color(project.color).withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'Keine Aufgaben in diesem Projekt',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tippe auf + um eine Aufgabe hinzuzufügen',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
