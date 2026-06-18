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
    final settings = ref.watch(settingsProvider);
    final todos = showAll
        ? todoState.todos.where((t) => !t.isCompleted).toList()
        : todoState.inboxTodos;
    final completedTodos = showAll
        ? todoState.todos.where((t) => t.isCompleted).toList()
        : todoState.completedInboxTodos;
    final large = settings.checkboxSize == CheckboxSize.large;

    final pinned = todos.where((t) => t.isPinned).toList();
    final unpinned = todos.where((t) => !t.isPinned).toList();

    Widget item(Todo t, {bool isCompleted = false}) =>
        _buildTodoItem(context, ref, t, large, isCompleted: isCompleted);

    final sections = <Widget>[];
    if (pinned.isNotEmpty) {
      sections.add(_CollapsibleSection(
        title: 'Angeheftet',
        count: pinned.length,
        children: pinned.map((t) => item(t)).toList(),
      ));
      sections.add(_CollapsibleSection(
        title: 'Weitere',
        count: unpinned.length,
        children: unpinned.map((t) => item(t)).toList(),
      ));
    } else {
      sections.addAll(unpinned.map((t) => item(t)));
    }
    if (completedTodos.isNotEmpty) {
      sections.add(_CollapsibleSection(
        title: 'Erledigt',
        count: completedTodos.length,
        children: completedTodos.map((t) => item(t, isCompleted: true)).toList(),
      ));
    }

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
              : SlidableAutoCloseBehavior(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 100),
                    children: sections,
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

/// Collapsible list section with a title, count and chevron (Pinned/Completed…).
class _CollapsibleSection extends StatefulWidget {
  final String title;
  final int count;
  final List<Widget> children;

  const _CollapsibleSection({
    required this.title,
    required this.count,
    required this.children,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 16, 6),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _expanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(SolarIconsOutline.altArrowDown, size: 16, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(width: 8),
                Text('${widget.count}', style: const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
              ],
            ),
          ),
        ),
        if (_expanded) ...widget.children,
      ],
    );
  }
}
