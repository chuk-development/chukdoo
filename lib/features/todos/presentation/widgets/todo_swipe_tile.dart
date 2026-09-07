import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../shared/widgets/picker_sheet.dart';
import '../../../projects/providers/project_provider.dart';
import '../../domain/models/todo.dart';
import '../../providers/todo_provider.dart';
import '../pages/todo_detail_page.dart';
import 'swipe_zone_row.dart';
import 'todo_item.dart';

/// Pushes a route with no slide/fade transition — the page is just *there*.
Route<T> instantRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

/// A todo row with zoned swipe gestures, shared by every list page.
///
/// - Swipe RIGHT → one zone: complete (or reopen), with undo.
/// - Swipe LEFT  → a sequence of zones, shortest drag first:
///                 Delete · Pin · Date · Move, then the menu at the far end.
///
/// Nothing happens while the finger moves. The zone under the finger is
/// armed — it fills the revealed strip and ticks the haptics when it changes —
/// and only the release runs it. Swiping all the way left arms the *menu*
/// instead of a destructive action, so a careless full swipe can never delete
/// silently; Delete itself is undoable through the snackbar.
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
        child: SwipeZoneRow(
          key: ValueKey(todo.id),
          startAction: SwipeZoneAction(
            label: isCompleted ? 'Reopen' : 'Completed',
            icon: isCompleted ? MdiIcons.refresh : MdiIcons.checkCircle,
            color: AppColors.green,
            onRun: () => _completeWithUndo(context, ref),
          ),
          endActions: _endActions(context, ref),
          endMenu: SwipeZoneAction(
            label: 'More',
            icon: MdiIcons.dotsHorizontal,
            color: AppColors.surfaceLight,
            foreground: AppColors.textPrimary,
            onRun: () => _showActionMenu(context, ref),
          ),
          child: isCompleted
              ? _row(context, ref, notifier)
              : _draggable(context, ref, notifier),
        ),
      ),
    );
  }

  /// Left-swipe zones, shortest drag first. Delete comes first because it is
  /// the action the owner reaches for most; it is undoable, and the far end of
  /// the swipe opens the menu instead of running it, so the short throw never
  /// turns into an accidental delete on a long one.
  List<SwipeZoneAction> _endActions(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(todoProvider.notifier);
    return [
      SwipeZoneAction(
        label: 'Delete',
        icon: MdiIcons.trashCan,
        color: AppColors.error,
        onRun: () => _deleteWithUndo(context, ref),
      ),
      // A completed row has nothing left to pin, date or move.
      if (!isCompleted) ...[
        SwipeZoneAction(
          label: todo.isPinned ? 'Unpin' : 'Pin',
          icon: todo.isPinned ? MdiIcons.bookmark : MdiIcons.bookmarkOutline,
          color: AppColors.warning,
          onRun: () => notifier.togglePin(todo.id),
        ),
        SwipeZoneAction(
          label: 'Date',
          icon: MdiIcons.calendar,
          color: AppColors.blue,
          onRun: () => _showDateDialog(context, ref),
        ),
        SwipeZoneAction(
          label: 'Move',
          icon: MdiIcons.folder,
          color: AppColors.purple,
          onRun: () => _showMoveSheet(context, ref),
        ),
      ],
    ];
  }

  /// What a full left swipe opens: the same actions as the zones, on the one
  /// modal surface the app uses everywhere.
  Future<void> _showActionMenu(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(todoProvider.notifier);
    final picked = await showPickerSheet<String>(
      context: context,
      title: 'Task',
      options: [
        if (!isCompleted) ...[
          PickerOption(
            value: 'date',
            label: 'Date',
            icon: MdiIcons.calendar,
            color: AppColors.blue,
          ),
          PickerOption(
            value: 'move',
            label: 'Move',
            icon: MdiIcons.folder,
            color: AppColors.purple,
          ),
          PickerOption(
            value: 'pin',
            label: todo.isPinned ? 'Unpin' : 'Pin',
            icon: todo.isPinned ? MdiIcons.bookmark : MdiIcons.bookmarkOutline,
            color: AppColors.warning,
          ),
        ],
        PickerOption(
          value: 'delete',
          label: 'Delete',
          icon: MdiIcons.trashCan,
          color: AppColors.error,
        ),
      ],
    );

    if (picked == null || !context.mounted) return;

    switch (picked) {
      case 'date':
        await _showDateDialog(context, ref);
      case 'move':
        await _showMoveSheet(context, ref);
      case 'pin':
        await notifier.togglePin(todo.id);
      case 'delete':
        _deleteWithUndo(context, ref);
    }
  }

  /// Wrap the row so it can be dragged onto a project/All in the sidebar.
  ///
  /// Uses [LongPressDraggable] on every platform: a quick horizontal flick is
  /// still claimed by the swipe gesture, while press-and-hold then move starts
  /// a drag toward the sidebar. This is the only way the two gestures
  /// coexist — a plain Draggable steals the horizontal swipe.
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
        PickerOption(value: 'today', label: 'Today', icon: MdiIcons.calendar),
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
