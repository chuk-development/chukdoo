import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../../core/theme/app_colors.dart';
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
  final bool largeCheckbox;
  final String? projectName;

  const TodoSwipeTile({
    super.key,
    required this.todo,
    required this.largeCheckbox,
    this.isCompleted = false,
    this.projectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(todoProvider.notifier);

    return Slidable(
      key: ValueKey(todo.id),

      // ── Swipe right → complete ──
      startActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.28,
        dismissible: DismissiblePane(
          dismissThreshold: 0.5,
          onDismissed: () => notifier.toggleComplete(todo.id),
        ),
        children: [
          SlidableAction(
            onPressed: (_) => notifier.toggleComplete(todo.id),
            backgroundColor: AppColors.green,
            foregroundColor: Colors.white,
            icon: isCompleted ? SolarIconsBold.refreshCircle : SolarIconsBold.checkCircle,
            label: isCompleted ? 'Offen' : 'Erledigt',
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
              icon: SolarIconsBold.calendar,
              label: 'Datum',
            ),
            SlidableAction(
              onPressed: (ctx) => _showMoveSheet(ctx, ref),
              backgroundColor: AppColors.purple,
              foregroundColor: Colors.white,
              icon: SolarIconsBold.folder,
              label: 'Verschieben',
            ),
            SlidableAction(
              onPressed: (_) => notifier.togglePin(todo.id),
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              icon: todo.isPinned ? SolarIconsBold.bookmark : SolarIconsOutline.bookmark,
              label: todo.isPinned ? 'Lösen' : 'Anheften',
            ),
          ],
          SlidableAction(
            onPressed: (ctx) => _deleteWithUndo(ctx, ref),
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            icon: SolarIconsBold.trashBinTrash,
            label: 'Löschen',
          ),
        ],
      ),

      child: isCompleted
          ? _row(context, ref, notifier)
          : LongPressDraggable<Todo>(
              data: todo,
              delay: const Duration(milliseconds: 220),
              hapticFeedbackOnStart: true,
              feedback: _TodoDragFeedback(todo: todo),
              childWhenDragging: Opacity(
                opacity: 0.35,
                child: _row(context, ref, notifier),
              ),
              child: _row(context, ref, notifier),
            ),
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
      largeCheckbox: largeCheckbox,
      onTap: () {
        // Desktop → fill the right detail panel; mobile → full-screen push.
        if (MediaQuery.of(context).size.width >= 768) {
          ref.read(selectedTodoProvider.notifier).state = todo;
        } else {
          Navigator.push(context, instantRoute(TodoDetailPage(todo: todo)));
        }
      },
      onComplete: () => notifier.toggleComplete(todo.id),
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

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final cells = <Widget>[
          _DateCell(
            icon: SolarIconsBold.calendar,
            label: 'Heute',
            color: AppColors.blue,
            onTap: () {
              notifier.setDueDate(todo.id, today);
              Navigator.pop(ctx);
            },
          ),
          _DateCell(
            icon: SolarIconsBold.sunrise,
            label: 'Morgen',
            color: AppColors.blue,
            onTap: () {
              notifier.setDueDate(todo.id, today.add(const Duration(days: 1)));
              Navigator.pop(ctx);
            },
          ),
          _DateCell(
            icon: SolarIconsBold.calendarMark,
            label: 'Übermorgen',
            color: AppColors.blue,
            onTap: () {
              notifier.setDueDate(todo.id, today.add(const Duration(days: 2)));
              Navigator.pop(ctx);
            },
          ),
          _DateCell(
            icon: SolarIconsBold.calendarMark,
            label: 'Nächster\nMontag',
            color: AppColors.blue,
            onTap: () {
              notifier.setDueDate(todo.id, nextMonday());
              Navigator.pop(ctx);
            },
          ),
          _DateCell(
            icon: SolarIconsOutline.calendarMinimalistic,
            label: 'Datum\nauswählen',
            color: AppColors.blue,
            onTap: () async {
              Navigator.pop(ctx);
              final picked = await showDatePicker(
                context: context,
                initialDate: todo.dueDate ?? today,
                firstDate: today.subtract(const Duration(days: 365)),
                lastDate: today.add(const Duration(days: 365 * 5)),
              );
              if (picked != null) notifier.setDueDate(todo.id, picked);
            },
          ),
          _DateCell(
            icon: SolarIconsOutline.closeSquare,
            label: 'Zurücksetzen',
            color: AppColors.textSecondary,
            onTap: () {
              notifier.setDueDate(todo.id, null);
              Navigator.pop(ctx);
            },
          ),
        ];

        return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  runSpacing: 16,
                  children: cells,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Move-to-project sheet ──
  Future<void> _showMoveSheet(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(todoProvider.notifier);
    final projects = ref.read(projectProvider).sortedProjects;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text('Verschieben nach', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(SolarIconsOutline.inbox, color: AppColors.textSecondary),
              title: const Text('Eingang'),
              trailing: todo.projectId == null
                  ? const Icon(SolarIconsBold.checkCircle, color: AppColors.primary)
                  : null,
              onTap: () {
                notifier.moveToProject(todo.id, null);
                Navigator.pop(ctx);
              },
            ),
            ...projects.map((p) => ListTile(
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: Color(p.color), borderRadius: BorderRadius.circular(3)),
                  ),
                  title: Text(p.name, overflow: TextOverflow.ellipsis),
                  trailing: todo.projectId == p.id
                      ? const Icon(SolarIconsBold.checkCircle, color: AppColors.primary)
                      : null,
                  onTap: () {
                    notifier.moveToProject(todo.id, p.id);
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Delete with undo ──
  void _deleteWithUndo(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(todoProvider.notifier);
    final snapshot = todo;
    notifier.deleteTodo(todo.id);
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Aufgabe gelöscht'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () => notifier.restoreTodo(snapshot),
        ),
      ),
    );
  }
}

/// One icon-tile in the quick date grid popup.
class _DateCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DateCell({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating chip shown under the cursor while dragging a todo onto a project.
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
            Icon(SolarIconsBold.checkCircle, size: 18, color: color),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                todo.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
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
