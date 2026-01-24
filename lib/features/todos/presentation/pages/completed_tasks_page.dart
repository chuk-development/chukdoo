import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/todo.dart';
import '../../providers/todo_provider.dart';
import '../widgets/todo_item.dart';
import 'todo_detail_page.dart';

class CompletedTasksPage extends ConsumerWidget {
  const CompletedTasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todoState = ref.watch(todoProvider);
    final settings = ref.watch(settingsProvider);
    final completedTodos = todoState.todos.where((t) => t.isCompleted).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Erledigt'),
        actions: [
          if (completedTodos.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(SolarIconsOutline.menuDots),
              onSelected: (value) {
                if (value == 'delete_all') {
                  _showDeleteAllConfirmation(context, ref, completedTodos);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      Icon(SolarIconsOutline.trashBinTrash, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Alle löschen', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: completedTodos.isEmpty
          ? _buildEmptyState()
          : SlidableAutoCloseBehavior(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      '${completedTodos.length} Aufgaben erledigt',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  ...completedTodos.map((todo) => _buildTodoItem(context, ref, todo, settings.checkboxSize == CheckboxSize.large)),
                ],
              ),
            ),
    );
  }

  void _showDeleteAllConfirmation(BuildContext context, WidgetRef ref, List<Todo> todos) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Alle erledigten Aufgaben löschen?'),
        content: Text(
          '${todos.length} Aufgaben werden endgültig gelöscht. Diese Aktion kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              for (final todo in todos) {
                ref.read(todoProvider.notifier).deleteTodo(todo.id);
              }
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Alle löschen'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Todo todo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Aufgabe löschen?'),
        content: Text('Die Aufgabe "${todo.title}" wird endgültig gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              ref.read(todoProvider.notifier).deleteTodo(todo.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoItem(BuildContext context, WidgetRef ref, Todo todo, bool largeCheckbox) {
    return Slidable(
      key: ValueKey(todo.id),
      startActionPane: ActionPane(
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
            backgroundColor: AppColors.blue,
            foregroundColor: Colors.white,
            icon: SolarIconsBold.refresh,
            label: 'Wiederherstellen',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) {
              _showDeleteConfirmation(context, ref, todo);
            },
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            icon: SolarIconsBold.trashBinTrash,
            label: 'Löschen',
          ),
        ],
      ),
      child: Opacity(
        opacity: 0.6,
        child: TodoItem(
          title: todo.title,
          priority: todo.priority.value,
          dueDate: todo.dueDate,
          isCompleted: true,
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
              SolarIconsOutline.checkCircle,
              size: 80,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'Keine erledigten Aufgaben',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Erledigte Aufgaben werden hier angezeigt',
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
