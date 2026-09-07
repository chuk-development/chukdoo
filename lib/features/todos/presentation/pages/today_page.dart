import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/todo.dart';
import '../../providers/todo_provider.dart';
import '../widgets/todo_input_sheet.dart';
import '../widgets/todo_swipe_tile.dart';
import '../widgets/quick_add_fab.dart';
import '../../../../shared/widgets/lifted_fab.dart';

class TodayPage extends ConsumerWidget {
  final VoidCallback? onMenu;

  const TodayPage({super.key, this.onMenu});

  void _showAddTodoSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TodoInputSheet(
        defaultDueDate: DateTime.now(),
        onSubmit: (title, dueDate, dueTime, priority, projectId, labels, pinned) {
          ref.read(todoProvider.notifier).addTodo(
            title: title,
            dueDate: dueDate ?? DateTime.now(),
            dueTime: dueTime,
            projectId: projectId,
            priority: priority != null
                ? TodoPriority.fromValue(priority)
                : TodoPriority.p4,
            labelIds: labels,
            isPinned: pinned,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todoState = ref.watch(todoProvider);
    final settings = ref.watch(settingsProvider);
    final todos = todoState.todayTodos;
    final completedTodos = todoState.completedTodayTodos;
    final showCompleted = todoState.showCompleted;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: onMenu != null
            ? IconButton(icon: Icon(MdiIcons.menu), onPressed: onMenu, tooltip: 'Menu')
            : null,
        title: const Text('Today'),
        actions: [
          if (completedTodos.isNotEmpty)
            Tooltip(
              message: showCompleted ? 'Hide completed' : 'Show completed',
              child: IconButton(
                icon: Icon(
                  showCompleted ? MdiIcons.checkCircle : MdiIcons.checkCircleOutline,
                  color: showCompleted ? AppColors.primary : null,
                ),
                onPressed: () {
                  ref.read(todoProvider.notifier).toggleShowCompleted();
                },
              ),
            ),
        ],
      ),
      body: todoState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : todos.isEmpty && (!showCompleted || completedTodos.isEmpty)
              ? _buildEmptyState()
              : SlidableAutoCloseBehavior(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 96),
                    children: [
                      // Active todos
                      for (var i = 0; i < todos.length; i++)
                        _buildTodoItem(context, ref, todos[i], settings.checkboxSize,
                            isFirst: i == 0, isLast: i == todos.length - 1),
                      // Completed todos section
                      if (showCompleted && completedTodos.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              Text(
                                'Completed today',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${completedTodos.length}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (var i = 0; i < completedTodos.length; i++)
                          _buildTodoItem(context, ref, completedTodos[i], settings.checkboxSize,
                              isCompleted: true, isFirst: i == 0, isLast: i == completedTodos.length - 1),
                      ],
                    ],
                  ),
                ),
      floatingActionButton: LiftedFab(child: QuickAddFab(
        onPressed: () => _showAddTodoSheet(context, ref),
      )),
    );
  }

  Widget _buildTodoItem(BuildContext context, WidgetRef ref, Todo todo, CheckboxSize size,
      {bool isCompleted = false, bool isFirst = true, bool isLast = true}) {
    return TodoSwipeTile(
      key: ValueKey(todo.id),
      todo: todo,
      size: size,
      isCompleted: isCompleted,
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
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                MdiIcons.weatherSunny,
                size: 60,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'No tasks for today',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Tap + to add a task for today',
              style: TextStyle(
                fontSize: 14,
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
