import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../projects/presentation/pages/project_page.dart';
import '../../../projects/presentation/widgets/project_edit_dialog.dart';
import '../../../projects/providers/project_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/todo.dart';
import '../../providers/todo_provider.dart';
import '../widgets/todo_input_sheet.dart';
import '../widgets/todo_swipe_tile.dart';
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
        onSubmit: (title, dueDate, dueTime, priority, projectId) {
          ref.read(todoProvider.notifier).addTodo(
            title: title,
            dueDate: dueDate,
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
    final projectState = ref.watch(projectProvider);
    final settings = ref.watch(settingsProvider);
    final todos = showAll
        ? todoState.todos.where((t) => !t.isCompleted).toList()
        : todoState.inboxTodos;
    final completedTodos = showAll
        ? todoState.todos.where((t) => t.isCompleted).toList()
        : todoState.completedInboxTodos;
    final showCompleted = todoState.showCompleted;
    final projects = projectState.sortedProjects;
    final isMobile = MediaQuery.of(context).size.width < 768;

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
          if (completedTodos.isNotEmpty)
            IconButton(
              icon: Icon(
                showCompleted ? SolarIconsBold.checkCircle : SolarIconsOutline.checkCircle,
                color: showCompleted ? AppColors.primary : null,
              ),
              onPressed: () => ref.read(todoProvider.notifier).toggleShowCompleted(),
              tooltip: showCompleted ? 'Erledigte ausblenden' : 'Erledigte anzeigen',
            ),
        ],
      ),
      body: todoState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Project chips (desktop only — mobile uses the drawer)
                if (projects.isNotEmpty && !isMobile)
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      children: [
                        ...projects.map((project) {
                          final count = todoState.todos.where((t) => !t.isCompleted && t.projectId == project.id).length;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              avatar: Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(color: Color(project.color), shape: BoxShape.circle),
                              ),
                              label: Text(
                                count > 0 ? '${project.name} ($count)' : project.name,
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectPage(project: project)));
                              },
                              backgroundColor: AppColors.surface,
                              side: BorderSide(color: AppColors.divider),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          );
                        }),
                        // Add project chip
                        ActionChip(
                          avatar: Icon(Icons.add, size: 16, color: AppColors.textSecondary),
                          label: Text('Projekt', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          onPressed: () => ProjectEditDialog.show(context),
                          backgroundColor: Colors.transparent,
                          side: BorderSide(color: AppColors.divider, style: BorderStyle.solid),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      ],
                    ),
                  ),
                // Todo list
                Expanded(
                  child: todos.isEmpty && (!showCompleted || completedTodos.isEmpty)
                      ? _buildEmptyState()
                      : SlidableAutoCloseBehavior(
                          child: ListView(
                            padding: const EdgeInsets.only(bottom: 100),
                            children: [
                              ...todos.map((todo) => _buildTodoItem(context, ref, todo, settings.checkboxSize == CheckboxSize.large)),
                              if (showCompleted && completedTodos.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                  child: Row(
                                    children: [
                                      Text('Erledigt', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
                                        child: Text('${completedTodos.length}', style: const TextStyle(fontSize: 11)),
                                      ),
                                    ],
                                  ),
                                ),
                                ...completedTodos.map((todo) => _buildTodoItem(context, ref, todo, settings.checkboxSize == CheckboxSize.large, isCompleted: true)),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
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
