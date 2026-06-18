import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/todo.dart';
import '../../providers/todo_provider.dart';
import '../widgets/todo_input_sheet.dart';
import '../widgets/todo_swipe_tile.dart';
import '../widgets/quick_add_fab.dart';

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
            ? IconButton(icon: const Icon(SolarIconsOutline.hamburgerMenu), onPressed: onMenu, tooltip: 'Menü')
            : null,
        title: const Text('Heute'),
        actions: [
          if (completedTodos.isNotEmpty)
            Tooltip(
              message: showCompleted ? 'Erledigte ausblenden' : 'Erledigte anzeigen',
              child: IconButton(
                icon: Icon(
                  showCompleted ? SolarIconsBold.checkCircle : SolarIconsOutline.checkCircle,
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
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      // Active todos
                      ...todos.map((todo) => _buildTodoItem(context, ref, todo, settings.checkboxSize == CheckboxSize.large)),
                      // Completed todos section
                      if (showCompleted && completedTodos.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              Text(
                                'Heute erledigt',
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
    return TodoSwipeTile(
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
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                SolarIconsOutline.sun,
                size: 60,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Keine Aufgaben für heute',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Tippe auf + um eine Aufgabe für heute hinzuzufügen',
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
