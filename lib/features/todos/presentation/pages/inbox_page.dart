import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/todo.dart';
import '../../providers/todo_provider.dart';
import '../widgets/todo_input_sheet.dart';
import '../widgets/todo_sectioned_list.dart';
import '../widgets/quick_add_fab.dart';
import 'search_page.dart';

class InboxPage extends ConsumerWidget {
  /// When true, shows ALL uncompleted todos (not just project-less inbox).
  final bool showAll;

  /// Opens the app drawer (mobile hamburger). Null on desktop.
  final VoidCallback? onMenu;

  const InboxPage({super.key, this.showAll = false, this.onMenu});

  void _showAddTodoSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TodoInputSheet(
        onSubmit: (title, dueDate, dueTime, priority, projectId, labels, pinned) {
          ref.read(todoProvider.notifier).addTodo(
            title: title,
            dueDate: dueDate,
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
    final todos = showAll
        ? todoState.todos.where((t) => !t.isCompleted).toList()
        : todoState.inboxTodos;
    final completedTodos = showAll
        ? todoState.todos.where((t) => t.isCompleted).toList()
        : todoState.completedInboxTodos;
    final large = settings.checkboxSize == CheckboxSize.large;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: onMenu != null
            ? IconButton(
                icon: const Icon(SolarIconsOutline.hamburgerMenu),
                onPressed: onMenu,
                tooltip: 'Menü',
              )
            : null,
        title: Text(showAll ? 'Alle Aufgaben' : settings.mainListName),
        actions: [
          IconButton(
            icon: const Icon(SolarIconsOutline.magnifier),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage())),
            tooltip: 'Suchen',
          ),
        ],
      ),
      body: todoState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : (todos.isEmpty && completedTodos.isEmpty)
              ? _buildEmptyState()
              : TodoSectionedList(active: todos, completed: completedTodos, large: large),
      floatingActionButton: QuickAddFab(
        onPressed: () => _showAddTodoSheet(context, ref),
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
              SolarIconsOutline.inboxLine,
              size: 80,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              showAll ? 'Keine offenen Aufgaben' : 'Dein Eingang ist leer',
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
