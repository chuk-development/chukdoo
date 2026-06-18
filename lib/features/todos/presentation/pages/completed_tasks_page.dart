import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:solar_icons/solar_icons.dart';

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
            ? IconButton(icon: const Icon(SolarIconsOutline.hamburgerMenu), onPressed: onMenu, tooltip: 'Menu')
            : null,
        title: const Text('Completed'),
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
                padding: const EdgeInsets.only(bottom: 32),
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

  Widget _buildTodoItem(BuildContext context, WidgetRef ref, Todo todo, bool largeCheckbox) {
    return TodoSwipeTile(
      key: ValueKey(todo.id),
      todo: todo,
      largeCheckbox: largeCheckbox,
      isCompleted: true,
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
