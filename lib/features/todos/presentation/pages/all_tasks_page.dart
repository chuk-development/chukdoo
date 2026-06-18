import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/todo.dart';
import '../../providers/todo_provider.dart';
import '../widgets/todo_swipe_tile.dart';

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
        title: const Text('All Tasks'),
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
                        'Open (${activeTodos.length})',
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
                        'Completed (${completedTodos.length})',
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

  Widget _buildTodoItem(BuildContext context, WidgetRef ref, Todo todo, bool largeCheckbox, {bool isCompleted = false}) {
    return TodoSwipeTile(
      key: ValueKey(todo.id),
      todo: todo,
      largeCheckbox: largeCheckbox,
      isCompleted: isCompleted,
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
              'No tasks',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You haven\'t created any tasks yet',
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
