import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/todo.dart';
import '../../providers/todo_provider.dart';
import '../widgets/todo_input_sheet.dart';
import '../widgets/todo_item.dart';
import '../widgets/quick_add_fab.dart';
import 'todo_detail_page.dart';

class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  void _showAddTodoSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TodoInputSheet(
        defaultDueDate: DateTime.now(),
        onSubmit: (title, dueDate, dueTime, priority, projectId) {
          ref.read(todoProvider.notifier).addTodo(
            title: title,
            dueDate: dueDate ?? DateTime.now(),
            dueTime: dueTime,
            projectId: projectId,
            priority: priority != null
                ? TodoPriority.fromValue(priority)
                : TodoPriority.p4,
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
        title: const Text('Heute'),
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
                          child: Text(
                            'Heute erledigt (${completedTodos.length})',
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
