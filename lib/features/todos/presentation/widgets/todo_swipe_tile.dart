import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../shared/widgets/picker_sheet.dart';
import '../../../projects/providers/project_provider.dart';
import '../../domain/models/todo.dart';
import '../../providers/todo_provider.dart';
import '../pages/todo_detail_page.dart';
import 'todo_item.dart';

/// Pushes a route with no slide/fade transition — the page is just *there*.
Route<T> instantRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

/// A todo row with TickTick-style swipe gestures, shared by every list page.
///
/// - Swipe RIGHT  → mark complete (full swipe completes).
/// - Swipe LEFT   → action buttons [Datum, Verschieben, Anheften, Löschen];
///                  swiping past two thirds deletes (with undo). The Datum
///                  button opens a centered TickTick-style quick-date grid.
class TodoSwipeTile extends ConsumerWidget {
  final Todo todo;
  final bool isCompleted;
  final CheckboxSize size;
  final String? projectName;

  /// Position inside the surrounding list group. The first and last row get
  /// the large outer radius, everything between them the small inner one.
  final bool isFirst;
  final bool isLast;

  const TodoSwipeTile({
    super.key,
    required this.todo,
    required this.size,
    this.isCompleted = false,
    this.projectName,
    this.isFirst = true,
    this.isLast = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(todoProvider.notifier);
    final radius = AppShapes.row(isFirst: isFirst, isLast: isLast);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppShapes.listInset,
        0,
        AppShapes.listInset,
        AppShapes.groupGap,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Slidable(
          key: ValueKey(todo.id),

          // ── Swipe right → complete ──
          startActionPane: ActionPane(
            motion: const BehindMotion(),
            extentRatio: 0.28,
            dismissible: DismissiblePane(
              dismissThreshold: 0.5,
              onDismissed: () => _completeWithUndo(context, ref),
            ),
            children: [
              SlidableAction(
                onPressed: (ctx) => _completeWithUndo(ctx, ref),
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                icon: isCompleted ? MdiIcons.refresh : MdiIcons.checkCircle,
                label: isCompleted ? 'Reopen' : 'Completed',
              ),
            ],
          ),

          // ── Swipe left → action buttons; swipe past 2/3 → delete ──
          endActionPane: ActionPane(
            motion: const BehindMotion(),
            extentRatio: isCompleted ? 0.25 : 0.78,
            dismissible: DismissiblePane(
              dismissThreshold: 0.66, // swipe more than two thirds = delete
              onDismissed: () => _deleteWithUndo(context, ref),
            ),
            children: [
              if (!isCompleted) ...[
                SlidableAction(
                  onPressed: (ctx) => _showDateDialog(ctx, ref),
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                  icon: MdiIcons.calendar,
                  label: 'Date',
                ),
                SlidableAction(
                  onPressed: (ctx) => _showMoveSheet(ctx, ref),
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  icon: MdiIcons.folder,
                  label: 'Move',
                ),
                SlidableAction(
                  onPressed: (_) => notifier.togglePin(todo.id),
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white,
                  icon: todo.isPinned
                      ? MdiIcons.bookmark
                      : MdiIcons.bookmarkOutline,
                  label: todo.isPinned ? 'Unpin' : 'Pin',
                ),
              ],
              SlidableAction(
                onPressed: (ctx) => _deleteWithUndo(ctx, ref),
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                icon: MdiIcons.trashCan,
                label: 'Delete',
              ),
            ],
          ),

          child: isCompleted
              ? _row(context, ref, notifier)
              : _draggable(context, ref, notifier),
        ),
      ),
    );
  }

  /// Wrap the row so it can be dragged onto a project/All in the sidebar.
  ///
  /// Uses [LongPressDraggable] on every platform: a quick horizontal flick is
  /// still claimed by the Slidable (swipe actions), while press-and-hold then
  /// move starts a drag toward the sidebar. This is the only way the two
  /// gestures coexist — a plain Draggable steals the horizontal swipe.
  Widget _draggable(BuildContext context, WidgetRef ref, dynamic notifier) {
    return LongPressDraggable<Todo>(
      data: todo,
      delay: const Duration(milliseconds: 200),
      hapticFeedbackOnStart: true,
      feedback: _TodoDragFeedback(todo: todo),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _row(context, ref, notifier),
      ),
      child: _row(context, ref, notifier),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, dynamic notifier) {
    return TodoItem(
      title: todo.title,
      priority: todo.priority.value,
      dueDate: todo.dueDate,
      dueTime: todo.dueTime,
      projectName: projectName,
      isPinned: todo.isPinned,
      isCompleted: isCompleted,
      size: size,
      onTap: () {
        // Desktop → fill the right detail panel; mobile → full-screen push.
        if (MediaQuery.of(context).size.width >= 768) {
          ref.read(selectedTodoProvider.notifier).state = todo;
        } else {
          Navigator.push(context, instantRoute(TodoDetailPage(todo: todo)));
        }
      },
      onComplete: () => _completeWithUndo(context, ref),
    );
  }

  // ── Quick date popup (TickTick-style centered grid) ──
  Future<void> _showDateDialog(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(todoProvider.notifier);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime nextMonday() {
      var d = today.add(const Duration(days: 1));
      while (d.weekday != DateTime.monday) {
        d = d.add(const Duration(days: 1));
      }
      return d;
    }

    // The quick dates use the same sheet as every other picker; "Pick a date"
    // hands over to the shared calendar sheet.
    final picked = await showPickerSheet<String>(
      context: context,
      title: 'Due date',
      options: [
        PickerOption(
          value: 'today',
          label: 'Today',
          icon: MdiIcons.calendar,
        ),
        PickerOption(
          value: 'tomorrow',
          label: 'Tomorrow',
          icon: MdiIcons.weatherSunsetUp,
        ),
        PickerOption(
          value: 'in2',
          label: 'In 2 days',
          icon: MdiIcons.calendarCheck,
        ),
        PickerOption(
          value: 'monday',
          label: 'Next Monday',
          icon: MdiIcons.calendarCheck,
        ),
        PickerOption(
          value: 'pick',
          label: 'Pick a date…',
          icon: MdiIcons.calendarBlankOutline,
        ),
        PickerOption(
          value: 'clear',
          label: 'No date',
          icon: MdiIcons.closeBoxOutline,
        ),
      ],
    );

    if (picked == null || !context.mounted) return;

    switch (picked) {
      case 'today':
        notifier.setDueDate(todo.id, today);
      case 'tomorrow':
        notifier.setDueDate(todo.id, today.add(const Duration(days: 1)));
      case 'in2':
        notifier.setDueDate(todo.id, today.add(const Duration(days: 2)));
      case 'monday':
        notifier.setDueDate(todo.id, nextMonday());
      case 'clear':
        notifier.setDueDate(todo.id, null);
      case 'pick':
        final choice = await showDateTimeSheet(
          context: context,
          title: 'Due date',
          date: todo.dueDate ?? today,
          allowTime: false,
        );
        if (choice != null) notifier.setDueDate(todo.id, choice.date);
    }
  }

  // ── Move-to-project sheet ──
  Future<void> _showMoveSheet(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(todoProvider.notifier);
    final projects = ref.read(projectProvider).sortedProjects;

    // Same picker surface as everywhere else in the app.
    final picked = await showPickerSheet<String>(
      context: context,
      title: 'Move to',
      options: [
        PickerOption(
          value: '',
          label: 'None',
          icon: MdiIcons.inboxOutline,
          selected: todo.projectId == null,
        ),
        for (final p in projects)
          PickerOption(
            value: p.id,
            label: p.name,
            leading: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Color(p.color),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            selected: todo.projectId == p.id,
          ),
      ],
    );

    if (picked == null) return;
    notifier.moveToProject(todo.id, picked.isEmpty ? null : picked);
  }

  // ── Delete with undo ──
  /// Complete (or reopen) the todo and offer an undo, same as delete does.
  void _completeWithUndo(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(todoProvider.notifier);
    final id = todo.id;
    notifier.toggleComplete(id);

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(isCompleted ? 'Task reopened' : 'Task completed'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => notifier.toggleComplete(id),
        ),
      ),
    );
  }

  void _deleteWithUndo(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(todoProvider.notifier);
    final snapshot = todo;
    notifier.deleteTodo(todo.id);
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Task deleted'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => notifier.restoreTodo(snapshot),
        ),
      ),
    );
  }
}

/// One icon-tile in the quick date grid popup.
class _TodoDragFeedback extends StatelessWidget {
  final Todo todo;

  const _TodoDragFeedback({required this.todo});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.getPriorityColor(todo.priority.value);
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(MdiIcons.checkCircle, size: 18, color: color),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                todo.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
