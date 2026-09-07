import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../todos/domain/models/todo.dart';
import '../../../todos/providers/todo_provider.dart';
import '../../../todos/presentation/pages/todo_detail_page.dart';
import '../../../projects/providers/project_provider.dart';

class KanbanPage extends ConsumerStatefulWidget {
  final bool embedded;

  const KanbanPage({super.key, this.embedded = false});

  @override
  ConsumerState<KanbanPage> createState() => _KanbanPageState();
}

class _KanbanPageState extends ConsumerState<KanbanPage> {
  /// null = show all projects ("Alle")
  String? _filterProjectId;
  /// true when "Alle" is selected (default)
  bool get _showAll => _filterProjectId == null;

  /// Sort todos: P1 first, then by due date (nulls last)
  List<Todo> _sorted(List<Todo> items) {
    final list = List<Todo>.from(items);
    list.sort((a, b) {
      final priCmp = a.priority.value.compareTo(b.priority.value);
      if (priCmp != 0) return priCmp;
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final todoState = ref.watch(todoProvider);
    final projectState = ref.watch(projectProvider);
    final projects = projectState.sortedProjects;

    var todos = todoState.todos.toList();
    if (_filterProjectId != null) {
      todos = todos.where((t) => t.projectId == _filterProjectId).toList();
    }

    final todoItems = _sorted(todos.where((t) => t.status == TodoStatus.todo && !t.isCompleted).toList());
    final inProgressItems = _sorted(todos.where((t) => t.status == TodoStatus.inProgress && !t.isCompleted).toList());
    final doneItems = _sorted(todos.where((t) => t.status == TodoStatus.done || t.isCompleted).toList());

    final hasAnyTodos = todoItems.isNotEmpty || inProgressItems.isNotEmpty || doneItems.isNotEmpty;

    // Filtered project name for empty state
    final filterProjectName = _filterProjectId != null
        ? projectState.getById(_filterProjectId!)?.name ?? 'Project'
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kanban Board'),
        automaticallyImplyLeading: false,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: Icon(MdiIcons.chevronLeft),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: Column(
        children: [
          // Project filter chips
          if (projects.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                children: [
                  // "Alle" chip
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        'All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _showAll ? FontWeight.w600 : FontWeight.normal,
                          color: _showAll ? AppColors.background : AppColors.textSecondary,
                        ),
                      ),
                      selected: _showAll,
                      onSelected: (_) => setState(() => _filterProjectId = null),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      showCheckmark: false,
                    ),
                  ),
                  // Per-project chips
                  ...projects.map((project) {
                    final isSelected = _filterProjectId == project.id;
                    final count = todoState.todos.where((t) => !t.isCompleted && t.projectId == project.id).length;
                    final projColor = Color(project.color);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(color: projColor, shape: BoxShape.circle),
                        ),
                        label: Text(
                          count > 0 ? '${project.name} ($count)' : project.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? AppColors.background : AppColors.textSecondary,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _filterProjectId = project.id),
                        selectedColor: projColor,
                        backgroundColor: AppColors.surface,
                        showCheckmark: false,
                      ),
                    );
                  }),
                ],
              ),
            ),

          // Kanban columns
          Expanded(
            child: !hasAnyTodos && _filterProjectId != null
                ? _buildEmptyProjectState(filterProjectName!)
                : Padding(
                    // Inside the shell the floating nav bar would cover the
                    // bottom of the columns.
                    padding: EdgeInsets.fromLTRB(
                      AppShapes.listInset,
                      AppShapes.listInset,
                      AppShapes.listInset,
                      AppShapes.listInset,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _KanbanColumn(
                          title: 'To do',
                          icon: MdiIcons.clipboardListOutline,
                          color: AppColors.blue,
                          todos: todoItems,
                          status: TodoStatus.todo,
                          onStatusChange: _changeTodoStatus,
                          onTap: _openDetail,
                        ),
                        const SizedBox(width: 10),
                        _KanbanColumn(
                          title: 'In progress',
                          icon: MdiIcons.playCircleOutline,
                          color: AppColors.orange,
                          todos: inProgressItems,
                          status: TodoStatus.inProgress,
                          onStatusChange: _changeTodoStatus,
                          onTap: _openDetail,
                        ),
                        const SizedBox(width: 10),
                        _KanbanColumn(
                          title: 'Done',
                          icon: MdiIcons.checkCircleOutline,
                          color: AppColors.green,
                          todos: doneItems,
                          status: TodoStatus.done,
                          onStatusChange: _changeTodoStatus,
                          onTap: _openDetail,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyProjectState(String projectName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              MdiIcons.clipboardListOutline,
              size: 64,
              color: AppColors.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 20),
            Text(
              'No tasks in "$projectName"',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a task and assign it to this project',
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

  void _changeTodoStatus(Todo todo, TodoStatus newStatus) {
    ref.read(todoProvider.notifier).updateTodo(
          todo.copyWith(
            status: newStatus,
            isCompleted: newStatus == TodoStatus.done,
            completedAt: newStatus == TodoStatus.done ? DateTime.now() : null,
          ),
        );
  }

  void _openDetail(Todo todo) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TodoDetailPage(todo: todo)));
  }
}

/// One board column: a header block and a card block, separated by the same
/// 3px gap every grouped list in the app uses.
class _KanbanColumn extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Todo> todos;
  final TodoStatus status;
  final void Function(Todo, TodoStatus) onStatusChange;
  final void Function(Todo) onTap;

  static const Duration _highlight = Duration(milliseconds: 220);

  const _KanbanColumn({
    required this.title,
    required this.icon,
    required this.color,
    required this.todos,
    required this.status,
    required this.onStatusChange,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DragTarget<Todo>(
        onWillAcceptWithDetails: (details) => details.data.status != status,
        onAcceptWithDetails: (details) {
          HapticFeedback.mediumImpact();
          onStatusChange(details.data, status);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          // Drag-over is shown by tinting the blocks, not by an outline.
          final blockColor = isHovering
              ? Color.alphaBlend(color.withValues(alpha: 0.16), AppColors.surface)
              : AppColors.surface;

          return Column(
            children: [
              // Header block
              AnimatedContainer(
                duration: _highlight,
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: blockColor,
                  borderRadius: AppShapes.row(isFirst: true, isLast: false),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppShapes.dockChip),
                      ),
                      child: Text('${todos.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppShapes.groupGap),

              // Card block
              Expanded(
                child: AnimatedContainer(
                  duration: _highlight,
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: AppShapes.row(isFirst: false, isLast: true),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: todos.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'Drag tasks here',
                              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: todos.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: AppShapes.groupGap),
                            child: _KanbanCard(
                              todo: todos[index],
                              isFirst: index == 0,
                              isLast: index == todos.length - 1,
                              onTap: () => onTap(todos[index]),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KanbanCard extends ConsumerWidget {
  final Todo todo;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _KanbanCard({
    required this.todo,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectState = ref.watch(projectProvider);
    final project = todo.projectId != null ? projectState.getById(todo.projectId!) : null;
    final priorityColor = AppColors.getPriorityColor(todo.priority.value);
    final projectColor = project != null ? Color(project.color) : null;

    final card = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: AppShapes.row(isFirst: isFirst, isLast: isLast),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project badge (prominent, top of card)
            if (project != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: projectColor!.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppShapes.dockChip),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: projectColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        project.name,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: projectColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],

            // Title
            Text(
              todo.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: todo.isCompleted ? AppColors.textTertiary : AppColors.textPrimary,
                decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            // Metadata row: due date + priority
            if (todo.dueDate != null || todo.priority.value < 4) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (todo.dueDate != null) ...[
                    Icon(MdiIcons.calendarOutline, size: 12, color: AppColors.textTertiary),
                    const SizedBox(width: 3),
                    Text(
                      '${todo.dueDate!.day}.${todo.dueDate!.month}',
                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                  const Spacer(),
                  if (todo.priority.value < 4)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppShapes.dockChip),
                      ),
                      child: Text(
                        'P${todo.priority.value}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: priorityColor),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    // A dragged card leaves its group, so it gets the full outer radius.
    final feedback = Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(AppShapes.groupOuter),
      color: Colors.transparent,
      child: SizedBox(
        width: 200,
        child: Opacity(
          opacity: 0.9,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(AppShapes.groupOuter),
            ),
            clipBehavior: Clip.antiAlias,
            child: card,
          ),
        ),
      ),
    );

    // Use Draggable on desktop (click-drag), LongPressDraggable on mobile (avoids scroll conflict)
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (isDesktop) {
      return Draggable<Todo>(
        data: todo,
        feedback: feedback,
        childWhenDragging: Opacity(opacity: 0.3, child: card),
        child: card,
      );
    }

    return LongPressDraggable<Todo>(
      data: todo,
      delay: const Duration(milliseconds: 200),
      feedback: feedback,
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      onDragStarted: () => HapticFeedback.lightImpact(),
      child: card,
    );
  }
}
