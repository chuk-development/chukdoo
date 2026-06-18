import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/calendar_item.dart';
import '../../providers/calendar_event_provider.dart';
import '../../providers/calendar_items_provider.dart';
import 'time_grid.dart';

/// Google-Calendar-style week view. Navigation is handled by the page header.
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

  static const _accent = AppColors.blue;
  static const _dayLabels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
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
        .map((d) => calendarItems.itemsForDay(d).where((i) => i.isAllDay).toList())
        .toList();

    return Column(
      children: [
        // Day headers
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider, width: 1)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: _timeColumnWidth, top: 6, bottom: 6),
            child: Row(
              children: List.generate(7, (i) {
                final day = dates[i];
                final isToday = day.isAtSameMomentAs(today);
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      ref.read(calendarEventProvider.notifier).setFocusedDate(day);
                      ref
                          .read(calendarEventProvider.notifier)
                          .setViewMode(CalendarViewMode.day);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      children: [
                        Text(
                          _dayLabels[i].toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.4,
                            color: isToday ? _accent : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: isToday ? _accent : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                                color: isToday ? Colors.white : AppColors.textPrimary,
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
        ),

        Expanded(
          child: TimeGrid(
            columnCount: 7,
            columnHeaders: _dayLabels,
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
    );
  }
}
