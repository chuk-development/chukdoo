import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_shapes.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/calendar_item.dart';
import '../../providers/calendar_event_provider.dart';
import '../../providers/calendar_items_provider.dart';
import 'time_grid.dart';

/// The day, three day and week view — one widget, because they differ in
/// nothing but how many columns a page draws.
///
/// This is only the wiring: it hands the grid the user's settings and the
/// items of a day, and writes back what the grid reports. Everything else —
/// the columns, the hour gutter that stays put, the header that slides with
/// them — belongs to [TimeGrid].
///
/// Day, three days and week used to be three widgets over a shared
/// `MultiDayView`, all four of them a page of the pager. The pager moved into
/// the grid so the frame could stay still, and the four collapsed into this.
class TimeModeView extends ConsumerWidget {
  /// Which of the three time modes to draw. Month and agenda have no time
  /// grid and never get here.
  final CalendarViewMode mode;

  final ValueChanged<({DateTime date, TimeOfDay time})>? onSlotTap;
  final ValueChanged<CalendarItem>? onItemTap;
  final void Function(CalendarItem item, DateTime newStart)? onItemDrop;

  const TimeModeView({
    super.key,
    required this.mode,
    this.onSlotTap,
    this.onItemTap,
    this.onItemDrop,
  });

  /// Same narrow hour scale as Google Calendar, so the day columns keep the
  /// width instead of the labels.
  static const double timeColumnWidth = 44.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarItems = ref.watch(calendarItemsProvider);
    final settings = ref.watch(settingsProvider);
    final eventState = ref.watch(calendarEventProvider);
    final notifier = ref.read(calendarEventProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppShapes.listInset),
      child: TimeGrid(
        mode: mode,
        weekStart: settings.calendarWeekStart,
        focusedDate: eventState.focusedDate,
        onFocusedDateChanged: notifier.setFocusedDate,
        itemsForDay: calendarItems.itemsForDay,
        // Only the week gets the number: three days can straddle two weeks, so
        // one number would be wrong for part of the row.
        showWeekNumber:
            mode == CalendarViewMode.week && settings.calendarShowWeekNumbers,
        // The day window is the user's, not a fixed 0-24 — the grid widens it
        // itself when an item falls outside.
        startHour: settings.calendarDayStartHour,
        endHour: settings.calendarDayEndHour,
        hourHeight: settings.calendarHourHeight,
        timeColumnWidth: timeColumnWidth,
        onSlotTap: onSlotTap,
        onItemTap: onItemTap,
        onItemDrop: onItemDrop,
        onHourHeightChanged: ref
            .read(settingsProvider.notifier)
            .setCalendarHourHeight,
        // A date in the header opens that single day. Not in the day view —
        // it is already showing it.
        onDateTap: mode == CalendarViewMode.day
            ? null
            : (date) {
                notifier.setFocusedDate(date);
                notifier.setViewMode(CalendarViewMode.day);
              },
      ),
    );
  }
}
