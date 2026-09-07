import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_shapes.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/calendar_item.dart';
import '../../providers/calendar_event_provider.dart';
import '../../providers/calendar_items_provider.dart';
import 'time_grid.dart';

/// Google-Calendar-style day view. Navigation is handled by the page header
/// and by the pager the page wraps this in.
class DayView extends ConsumerWidget {
  /// The day this page draws. One page of the pager is one day, so it cannot
  /// read the focused date — the page next to the finger is another day than
  /// the focused one. Null falls back to the focused date, for a day view
  /// used on its own.
  final DateTime? date;

  final ValueChanged<({DateTime date, TimeOfDay time})>? onSlotTap;
  final ValueChanged<CalendarItem>? onItemTap;
  final void Function(CalendarItem item, DateTime newStart)? onItemDrop;

  /// Passed straight to the grid: true while two fingers zoom it.
  final ValueChanged<bool>? onZoomingChanged;

  const DayView({
    super.key,
    this.date,
    this.onSlotTap,
    this.onItemTap,
    this.onItemDrop,
    this.onZoomingChanged,
  });

  /// Same narrow hour scale as Google Calendar, so the day columns keep
  /// the width instead of the labels.
  static const _timeColumnWidth = 44.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarItems = ref.watch(calendarItemsProvider);
    final settings = ref.watch(settingsProvider);
    final focused = date ?? ref.watch(calendarEventProvider).focusedDate;
    final day = DateTime(focused.year, focused.month, focused.day);

    final dayItems = calendarItems.itemsForDay(day);
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
              columnHeaders: [DateFormat('EEEE', 'en_US').format(day)],
              columnDates: [day],
              itemsByColumn: [timedItems],
              allDayItemsByColumn: [allDayItems],
              // The day window is the user's, not a fixed 0-24.
              startHour: settings.calendarDayStartHour,
              endHour: settings.calendarDayEndHour,
              hourHeight: settings.calendarHourHeight,
              timeColumnWidth: _timeColumnWidth,
              onSlotTap: onSlotTap,
              onItemTap: onItemTap,
              onItemDrop: onItemDrop,
              onHourHeightChanged: ref
                  .read(settingsProvider.notifier)
                  .setCalendarHourHeight,
              onZoomingChanged: onZoomingChanged,
            ),
          ),
        ],
      ),
    );
  }
}
