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

class AllTasksPage extends ConsumerWidget {
  const AllTasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todoState = ref.watch(todoProvider);
    final settings = ref.watch(settingsProvider);
    final activeTodos = todoState.todos.where((t) => !t.isCompleted).toList();
    final completedTodos = todoState.todos.where((t) => t.isCompleted).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alle Aufgaben'),
      ),
      body: (activeTodos.isEmpty && completedTodos.isEmpty)
          ? _buildEmptyState()
          : SlidableAutoCloseBehavior(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  if (activeTodos.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Offen (${activeTodos.length})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    ...activeTodos.map((todo) => _buildTodoItem(context, ref, todo, settings.checkboxSize == CheckboxSize.large)),
                  ],
                  if (completedTodos.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
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

  Widget _buildTodoItem(BuildContext context, WidgetRef ref, Todo todo, bool largeCheckbox, {bool isCompleted = false}) {
    return Slidable(
      key: ValueKey(todo.id),
      startActionPane: isCompleted
          ? ActionPane(
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
            )
          : ActionPane(
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
      endActionPane: isCompleted
          ? ActionPane(
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
            )
          : null,
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
              SolarIconsOutline.clipboardList,
              size: 80,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'Keine Aufgaben',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Du hast noch keine Aufgaben erstellt',
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
