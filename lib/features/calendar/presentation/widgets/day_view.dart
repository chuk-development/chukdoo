import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_shapes.dart';
import '../../domain/models/calendar_item.dart';
import '../../providers/calendar_event_provider.dart';
import '../../providers/calendar_items_provider.dart';
import 'time_grid.dart';

/// Google-Calendar-style day view. Navigation is handled by the page header.
class DayView extends ConsumerWidget {
  final ValueChanged<({DateTime date, TimeOfDay time})>? onSlotTap;
  final ValueChanged<CalendarItem>? onItemTap;
  final void Function(CalendarItem item, DateTime newStart)? onItemDrop;

  const DayView({super.key, this.onSlotTap, this.onItemTap, this.onItemDrop});

  static const _timeColumnWidth = 52.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventState = ref.watch(calendarEventProvider);
    final calendarItems = ref.watch(calendarItemsProvider);
    final focused = eventState.focusedDate;
    final date = DateTime(focused.year, focused.month, focused.day);

    final dayItems = calendarItems.itemsForDay(date);
    final timedItems = dayItems.where((i) => !i.isAllDay).toList();
    final allDayItems = dayItems.where((i) => i.isAllDay).toList();

    // No day strip here: the page header already carries the full date
    // ("Thursday, 1 Oct") and repeating it made the day view look unlike the
    // other three modes.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppShapes.listInset),
      child: Column(
        children: [
          Expanded(
            child: TimeGrid(
              columnCount: 1,
              columnHeaders: [DateFormat('EEEE', 'en_US').format(date)],
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
      ),
    );
  }
}
