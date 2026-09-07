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

/// Week view: the weekday strip on top, then the tiled time grid — the same
/// build Google Calendar uses for a week.
class WeekView extends ConsumerWidget {
  /// Any day of the week this page draws — one page of the pager is one week,
  /// so it cannot read the focused date. Null falls back to it.
  final DateTime? date;

  final ValueChanged<({DateTime date, TimeOfDay time})>? onSlotTap;
  final ValueChanged<CalendarItem>? onItemTap;
  final void Function(CalendarItem item, DateTime newStart)? onItemDrop;

  /// Passed straight to the grid: true while two fingers zoom it.
  final ValueChanged<bool>? onZoomingChanged;

  const WeekView({
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

    final weekStart = startOfWeek(focused, settings.calendarWeekStart);
    final labels = CalendarStyle.weekdays(settings.calendarWeekStart);

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
          // Day headers. The hour scale's gutter carries the week number when
          // the setting asks for it — the same width the grid keeps free below.
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: _timeColumnWidth,
                  child: settings.calendarShowWeekNumbers
                      ? Padding(
                          padding: const EdgeInsets.only(right: 8, top: 6),
                          child: Text(
                            'W${isoWeekNumberForRow(weekStart)}',
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
                ...List.generate(7, (i) {
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
                            labels[i].toUpperCase(),
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
                              color: isToday
                                  ? CalendarStyle.accent
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 15,
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
              ],
            ),
          ),

          Expanded(
            child: TimeGrid(
              columnCount: 7,
              columnHeaders: labels,
              columnDates: dates,
              itemsByColumn: itemsByColumn,
              allDayItemsByColumn: allDayByColumn,
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
