import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/calendar_item.dart';
import '../../domain/week_dates.dart';
import '../../providers/calendar_event_provider.dart';
import '../../providers/calendar_items_provider.dart';
import 'calendar_style.dart';
import 'time_grid.dart';

/// The day-column grid behind the week view and the three day view: a header
/// row of dates on top, the shared [TimeGrid] under it.
///
/// One widget for both, because they differ in nothing but how many columns
/// they draw and where those columns start — a second copy of the header would
/// be a second place to fix every time the grid changes.
class MultiDayView extends ConsumerWidget {
  /// The days drawn, left to right. The first entry is the left column.
  final List<DateTime> dates;

  /// Whether the hour gutter carries the ISO week number. Only the week view
  /// asks for it: three days can straddle two weeks, so one number would be
  /// wrong for part of the row.
  final bool showWeekNumber;

  final ValueChanged<({DateTime date, TimeOfDay time})>? onSlotTap;
  final ValueChanged<CalendarItem>? onItemTap;
  final void Function(CalendarItem item, DateTime newStart)? onItemDrop;

  /// Passed straight to the grid: true while two fingers zoom it.
  final ValueChanged<bool>? onZoomingChanged;

  const MultiDayView({
    super.key,
    required this.dates,
    this.showWeekNumber = false,
    this.onSlotTap,
    this.onItemTap,
    this.onItemDrop,
    this.onZoomingChanged,
  });

  /// Same narrow hour scale as Google Calendar, so the day columns keep
  /// the width instead of the labels.
  static const double timeColumnWidth = 44.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarItems = ref.watch(calendarItemsProvider);
    final settings = ref.watch(settingsProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // The label comes from the date, not from a fixed weekday list: a three
    // day page starts on any weekday.
    final labels = dates.map(CalendarStyle.weekdayLabel).toList();
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
          // Day headers. The hour scale's gutter carries the week number when
          // the setting asks for it — the same width the grid keeps free below.
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: timeColumnWidth,
                  child: showWeekNumber
                      ? Padding(
                          padding: const EdgeInsets.only(right: 8, top: 6),
                          child: Text(
                            'W${isoWeekNumberForRow(dates.first)}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        )
                      : null,
                ),
                for (var i = 0; i < dates.length; i++)
                  Expanded(child: _header(ref, dates[i], labels[i], today)),
              ],
            ),
          ),

          Expanded(
            child: TimeGrid(
              columnCount: dates.length,
              columnHeaders: labels,
              columnDates: dates,
              itemsByColumn: itemsByColumn,
              allDayItemsByColumn: allDayByColumn,
              // The day window is the user's, not a fixed 0-24 — the grid
              // widens it itself when an item falls outside.
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
              onZoomingChanged: onZoomingChanged,
            ),
          ),
        ],
      ),
    );
  }

  /// One column head: the weekday over the day number, the day number filled
  /// when it is today. Tapping it opens that single day.
  Widget _header(WidgetRef ref, DateTime day, String label, DateTime today) {
    final isToday = day.isAtSameMomentAs(today);

    return GestureDetector(
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
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.6,
              color: CalendarStyle.isWeekend(day)
                  ? AppColors.textTertiary
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isToday ? CalendarStyle.accent : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isToday ? AppColors.onPrimary : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
