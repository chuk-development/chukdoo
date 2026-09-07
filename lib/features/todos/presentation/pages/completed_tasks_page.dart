import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/todo.dart';
import '../../providers/todo_provider.dart';
import '../widgets/todo_swipe_tile.dart';

class CompletedTasksPage extends ConsumerWidget {
  final VoidCallback? onMenu;

  const CompletedTasksPage({super.key, this.onMenu});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todoState = ref.watch(todoProvider);
    final settings = ref.watch(settingsProvider);
    final completedTodos = todoState.todos.where((t) => t.isCompleted).toList();

    return Scaffold(
      appBar: AppBar(
        leading: onMenu != null
            ? IconButton(icon: Icon(MdiIcons.menu), onPressed: onMenu, tooltip: 'Menu')
            : null,
        title: const Text('Completed'),
        actions: [
          if (completedTodos.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(MdiIcons.dotsHorizontal),
              onSelected: (value) {
                if (value == 'delete_all') {
                  _showDeleteAllConfirmation(context, ref, completedTodos);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      Icon(MdiIcons.trashCanOutline, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Delete all', style: TextStyle(color: AppColors.error)),
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
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      '${completedTodos.length} tasks completed',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  for (var i = 0; i < completedTodos.length; i++)
                    _buildTodoItem(context, ref, completedTodos[i], settings.checkboxSize,
                        isFirst: i == 0, isLast: i == completedTodos.length - 1),
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
        title: const Text('Delete all completed tasks?'),
        content: Text(
          '${todos.length} tasks will be permanently deleted. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              for (final todo in todos) {
                ref.read(todoProvider.notifier).deleteTodo(todo.id);
              }
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoItem(BuildContext context, WidgetRef ref, Todo todo, CheckboxSize size,
      {bool isFirst = true, bool isLast = true}) {
    return TodoSwipeTile(
      key: ValueKey(todo.id),
      todo: todo,
      size: size,
      isCompleted: true,
      isFirst: isFirst,
      isLast: isLast,
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
              MdiIcons.checkCircleOutline,
              size: 80,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'No completed tasks',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Completed tasks will appear here',
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
