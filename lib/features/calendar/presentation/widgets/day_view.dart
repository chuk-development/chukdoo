import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/calendar_item.dart';
import '../../providers/calendar_event_provider.dart';
import '../../providers/calendar_items_provider.dart';
import 'time_grid.dart';

/// Google-Calendar-style day view. Navigation is handled by the page header.
class DayView extends ConsumerWidget {
  final ValueChanged<({DateTime date, TimeOfDay time})>? onSlotTap;
  final ValueChanged<CalendarItem>? onItemTap;
  final void Function(CalendarItem item, DateTime newStart)? onItemDrop;

  const DayView({
    super.key,
    this.onSlotTap,
    this.onItemTap,
    this.onItemDrop,
  });

  static const _accent = AppColors.blue;
  static const _timeColumnWidth = 52.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventState = ref.watch(calendarEventProvider);
    final calendarItems = ref.watch(calendarItemsProvider);
    final focused = eventState.focusedDate;
    final date = DateTime(focused.year, focused.month, focused.day);
    final isToday = _isToday(date);

    final dayItems = calendarItems.itemsForDay(date);
    final timedItems = dayItems.where((i) => !i.isAllDay).toList();
    final allDayItems = dayItems.where((i) => i.isAllDay).toList();

    return Column(
      children: [
        // Compact day strip aligned over the time gutter
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider, width: 1)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: _timeColumnWidth,
                child: Column(
                  children: [
                    Text(
                      DateFormat('E', 'de_DE').format(date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w600,
                        color: isToday ? _accent : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isToday ? _accent : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
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
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy', 'de_DE').format(date),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: TimeGrid(
            columnCount: 1,
            columnHeaders: [DateFormat('EEEE', 'de_DE').format(date)],
            columnDates: [date],
            itemsByColumn: [timedItems],
            allDayItemsByColumn: [allDayItems],
            timeColumnWidth: _timeColumnWidth,
            onSlotTap: onSlotTap,
            onItemTap: onItemTap,
            onItemDrop: onItemDrop,
          ),
        ),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}
