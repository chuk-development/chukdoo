import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../domain/models/calendar_item.dart';
import 'calendar_style.dart';

/// Google-Calendar-style timed event block: solid color fill, white text.
class EventBlock extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final blockColor = _color;
    final fg = _onColor(blockColor);
    final displayHeight = height.clamp(20.0, double.infinity);
    final isCompact = displayHeight < 36;

    final child = GestureDetector(
      onTap: onTap,
      child: Container(
        height: displayHeight,
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: isCompact ? 1 : 3),
        decoration: BoxDecoration(
          // No outline — a task reads as a softer tint of the same color.
          color: _isTodo ? blockColor.withValues(alpha: 0.3) : blockColor,
          borderRadius: BorderRadius.circular(AppShapes.dockChip),
        ),
        child: DefaultTextStyle(
          style: TextStyle(color: _isTodo ? AppColors.textPrimary : fg),
          child: isCompact
              ? Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _isTodo ? AppColors.textPrimary : fg,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _isTodo ? AppColors.textPrimary : fg,
                      ),
                      maxLines: displayHeight < 56 ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _isTodo
                          ? 'Task · ${_formatTime(item.startTime)}'
                          : '${_formatTime(item.startTime)} to ${_formatTime(item.endTime)}',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: (_isTodo ? AppColors.textSecondary : fg)
                            .withValues(alpha: _isTodo ? 1 : 0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
