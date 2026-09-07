import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../domain/models/calendar_item.dart';
import '../../providers/calendar_event_provider.dart';
import '../../providers/calendar_items_provider.dart';
import 'calendar_style.dart';
import 'time_grid.dart';

/// Week view: the weekday strip on top, then the tiled time grid — the same
/// build Google Calendar uses for a week.
class WeekView extends ConsumerWidget {
  final ValueChanged<({DateTime date, TimeOfDay time})>? onSlotTap;
  final ValueChanged<CalendarItem>? onItemTap;
  final void Function(CalendarItem item, DateTime newStart)? onItemDrop;

  const WeekView({
    super.key,
    this.onSlotTap,
    this.onItemTap,
    this.onItemDrop,
  });

  static const _timeColumnWidth = 52.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventState = ref.watch(calendarEventProvider);
    final calendarItems = ref.watch(calendarItemsProvider);
    final focused = eventState.focusedDate;

    final weekStart = DateTime(focused.year, focused.month, focused.day)
        .subtract(Duration(days: focused.weekday - 1));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final dates = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final itemsByColumn = dates.map(calendarItems.timedItemsForDay).toList();
    final allDayByColumn = dates
        .map(
          (d) => calendarItems.itemsForDay(d).where((i) => i.isAllDay).toList(),
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppShapes.listInset),
      child: Column(
      children: [
        // Day headers
        Padding(
          padding: const EdgeInsets.only(
            left: _timeColumnWidth,
            top: 4,
            bottom: 6,
          ),
          child: Row(
            children: List.generate(7, (i) {
              final day = dates[i];
              final isToday = day.isAtSameMomentAs(today);
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    ref
                        .read(calendarEventProvider.notifier)
                        .setFocusedDate(day);
                    ref
                        .read(calendarEventProvider.notifier)
                        .setViewMode(CalendarViewMode.day);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      Text(
                        CalendarStyle.weekdays[i].toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.6,
                          color: i >= 5
                              ? AppColors.textTertiary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isToday
                              ? CalendarStyle.accent
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isToday
                                  ? AppColors.onPrimary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),

        Expanded(
          child: TimeGrid(
            columnCount: 7,
            columnHeaders: CalendarStyle.weekdays,
            columnDates: dates,
            itemsByColumn: itemsByColumn,
            allDayItemsByColumn: allDayByColumn,
            timeColumnWidth: _timeColumnWidth,
            onSlotTap: onSlotTap,
            onItemTap: onItemTap,
            onItemDrop: onItemDrop,
          ),
        ),
      ],
      ),
    );
  }
}
