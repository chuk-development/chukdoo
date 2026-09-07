import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/todo.dart';
import '../../providers/todo_provider.dart';
import '../widgets/todo_input_sheet.dart';
import '../widgets/todo_sectioned_list.dart';
import '../widgets/quick_add_fab.dart';
import '../../../../shared/widgets/lifted_fab.dart';

class InboxPage extends ConsumerStatefulWidget {
  /// When true, shows ALL uncompleted todos (not just project-less inbox).
  final bool showAll;

  /// Opens the app drawer (mobile hamburger). Null on desktop.
  final VoidCallback? onMenu;

  const InboxPage({super.key, this.showAll = false, this.onMenu});

  @override
  ConsumerState<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends ConsumerState<InboxPage> {
  bool _searching = false;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _stopSearch() => setState(() {
        _searching = false;
        _query = '';
        _searchController.clear();
      });

  void _showAddTodoSheet() {
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
  Widget build(BuildContext context) {
    final showAll = widget.showAll;
    final todoState = ref.watch(todoProvider);
    final settings = ref.watch(settingsProvider);
    // Both variants show the main list (no project). Project tasks are only
    // shown inside their project.
    var todos = todoState.inboxTodos;
    var completedTodos = todoState.completedInboxTodos;
    final size = settings.checkboxSize;

    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      bool match(Todo t) =>
          t.title.toLowerCase().contains(q) ||
          (t.description ?? '').toLowerCase().contains(q);
      todos = todos.where(match).toList();
      completedTodos = completedTodos.where(match).toList();
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: _searching
            ? IconButton(
                icon: Icon(MdiIcons.chevronLeft),
                onPressed: _stopSearch,
                tooltip: 'Back',
              )
            : (widget.onMenu != null
                ? IconButton(
                    icon: Icon(MdiIcons.menu),
                    onPressed: widget.onMenu,
                    tooltip: 'Menu',
                  )
                : null),
        titleSpacing: _searching ? 0 : null,
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Search tasks…',
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 18),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : Text(showAll ? 'Main' : settings.mainListName),
        actions: _searching
            ? [
                if (_query.isNotEmpty)
                  IconButton(
                    icon: Icon(MdiIcons.closeCircle),
                    onPressed: () => setState(() {
                      _query = '';
                      _searchController.clear();
                    }),
                    tooltip: 'Clear',
                  ),
              ]
            : [
                IconButton(
                  icon: Icon(MdiIcons.magnify),
                  onPressed: () => setState(() => _searching = true),
                  tooltip: 'Search',
                ),
              ],
      ),
      body: todoState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : (todos.isEmpty && completedTodos.isEmpty)
              ? (q.isNotEmpty ? _buildNoResults() : _buildEmptyState())
              : TodoSectionedList(active: todos, completed: completedTodos, size: size),
      floatingActionButton: LiftedFab(child: _searching
          ? null
          : QuickAddFab(onPressed: _showAddTodoSheet)),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(MdiIcons.magnify, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text('No matches for "$_query"',
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
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
              MdiIcons.inboxOutline,
              size: 80,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              widget.showAll ? 'No open tasks' : 'Your inbox is empty',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to add a task',
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
