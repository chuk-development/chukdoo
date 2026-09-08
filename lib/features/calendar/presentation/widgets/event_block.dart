import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../shared/widgets/app_check.dart';
import '../../../todos/providers/todo_provider.dart';
import '../../domain/models/calendar_item.dart';
import 'calendar_style.dart';

/// One entry drawn on the time grid.
///
/// An event is a solid block of its colour. A task is deliberately *not* that:
/// it carries the tick of the task lists ([AppCheck]) in its priority colour
/// over a soft tint, so the two never look like the same thing. The tick also
/// works — a task can be ticked off straight from the grid, which is why this
/// is a [ConsumerWidget].
class EventBlock extends ConsumerWidget {
  final CalendarItem item;
  final double height;
  final VoidCallback? onTap;
  final ValueChanged<CalendarItem>? onDragStarted;
  final int calendarColor;

  const EventBlock({
    super.key,
    required this.item,
    required this.height,
    this.onTap,
    this.onDragStarted,
    this.calendarColor = 0,
  });

  Color get _color {
    if (item.color != 0) return Color(item.color);
    if (item is TodoItem) {
      final todo = (item as TodoItem).todo;
      return AppColors.getPriorityColor(todo.priority.value);
    }
    return CalendarStyle.colorOf(calendarColor);
  }

  bool get _isTodo => item is TodoItem;

  Color _onColor(Color bg) => CalendarStyle.onEventColor(bg);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockColor = _color;
    final fg = _onColor(blockColor);
    final displayHeight = height.clamp(20.0, double.infinity);
    // Below this a block only fits one line — the same cut Google Calendar
    // makes between a 30 minute and a 15 minute slot.
    final isCompact = displayHeight < 34;
    final textColor = _isTodo ? AppColors.textPrimary : fg;

    final child = GestureDetector(
      onTap: onTap,
      child: Container(
        height: displayHeight,
        padding: EdgeInsets.symmetric(
          horizontal: 7,
          vertical: isCompact ? 1 : 4,
        ),
        decoration: BoxDecoration(
          // No outline — a task reads as a softer tint of the same color.
          color: _isTodo ? blockColor.withValues(alpha: 0.3) : blockColor,
          borderRadius: BorderRadius.circular(AppShapes.dockChip),
        ),
        child: DefaultTextStyle(
          style: TextStyle(color: textColor),
          child: Row(
            crossAxisAlignment: isCompact
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              if (_isTodo) ...[
                _buildCheck(ref, displayHeight, blockColor),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: isCompact
                    ? Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            maxLines: displayHeight < 58 ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _subtitle(),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: (_isTodo ? AppColors.textSecondary : fg)
                                  .withValues(alpha: _isTodo ? 1 : 0.85),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );

    if (item is EventItem && onDragStarted != null) {
      return LongPressDraggable<CalendarItem>(
        data: item,
        delay: const Duration(milliseconds: 300),
        feedback: Material(
          color: Colors.transparent,
          elevation: 6,
          borderRadius: BorderRadius.circular(AppShapes.dockChip),
          child: SizedBox(
            width: 140,
            child: Opacity(opacity: 0.9, child: child),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: child),
        onDragStarted: () {
          HapticFeedback.mediumImpact();
          onDragStarted?.call(item);
        },
        child: child,
      );
    }

    return child;
  }

  /// The tick of the task lists, shrunk to the block.
  ///
  /// [AppCheck] pads its own tap target to 44, which a 20px slot cannot hold,
  /// so the ring is drawn plain and gets its own tap area here.
  Widget _buildCheck(WidgetRef ref, double displayHeight, Color color) {
    // Never taller than the block itself; the ring stops growing at the small
    // step of the tick scale.
    final diameter = (displayHeight - 8).clamp(12.0, AppCheck.small);
    final todo = (item as TodoItem).todo;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(todoProvider.notifier).toggleComplete(todo.id);
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 2),
        child: AppCheck(
          checked: todo.isCompleted,
          color: color,
          diameter: diameter,
        ),
      ),
    );
  }

  /// Second line of a block: the span it covers. A task without an own end
  /// shows only its start, because its length is a fallback, not a promise.
  String _subtitle() {
    if (_isTodo && (item as TodoItem).todo.endTime == null) {
      return _formatTime(item.startTime);
    }
    return '${_formatTime(item.startTime)} to ${_formatTime(item.endTime)}';
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
