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

/// The month grid: one filled tile per day on the darker ground, a small gap
/// between them, and a strong radius only on the four corners of the grid.
///
/// Navigation is handled by the page header and by swiping.
class MonthView extends ConsumerWidget {
  final ValueChanged<DateTime>? onDayTap;
  final ValueChanged<CalendarItem>? onItemTap;

  const MonthView({super.key, this.onDayTap, this.onItemTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventState = ref.watch(calendarEventProvider);
    final calendarItems = ref.watch(calendarItemsProvider);
    final settings = ref.watch(settingsProvider);
    final focused = eventState.focusedDate;

    final firstOfMonth = DateTime(focused.year, focused.month, 1);
    // The grid always begins on the user's first day of the week, so the
    // month's first row can reach back into the previous month.
    final gridStart = startOfWeek(firstOfMonth, settings.calendarWeekStart);
    final labels = CalendarStyle.weekdays(settings.calendarWeekStart);
    final showWeeks = settings.calendarShowWeekNumbers;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppShapes.listInset),
      child: Column(
        children: [
          // Weekday header — the same labels the week view uses.
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 2, 0, 8),
            child: Row(
              children: [
                // Keeps the labels above their column when the week numbers
                // take the leading edge.
                if (showWeeks) const SizedBox(width: _weekNumberWidth),
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        labels[i].toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color:
                              CalendarStyle.isWeekend(
                                gridStart.add(Duration(days: i)),
                              )
                              ? AppColors.textTertiary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 6-week grid. It fills the viewport and scrolls, so the nav bar
          // has real content to blur and the last week can still be pulled
          // clear of the pill.
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rowHeight = (constraints.maxHeight / 6).clamp(
                  88.0,
                  200.0,
                );
                return SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: AppShapes.contentBottom(context),
                  ),
                  child: Column(
                    children: List.generate(6, (week) {
                      return SizedBox(
                        height: rowHeight,
                        child: Row(
                          children: [
                            if (showWeeks)
                              _WeekNumber(
                                rowStart: gridStart.add(
                                  Duration(days: week * 7),
                                ),
                              ),
                            ...List.generate(7, (dayOfWeek) {
                              final date = gridStart.add(
                                Duration(days: week * 7 + dayOfWeek),
                              );
                              final isCurrentMonth =
                                  date.month == focused.month;
                              final isToday = date.isAtSameMomentAs(today);
                              final dayItems = calendarItems.itemsForDay(date);

                              return Expanded(
                                child: _MonthCell(
                                  date: date,
                                  isCurrentMonth: isCurrentMonth,
                                  isToday: isToday,
                                  items: dayItems,
                                  onTap: () => onDayTap?.call(date),
                                  onItemTap: onItemTap,
                                  row: week,
                                  col: dayOfWeek,
                                  rowCount: 6,
                                  colCount: 7,
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Width of the week-number gutter. Narrow on purpose: it is a mark, not a
/// column of the grid.
const double _weekNumberWidth = 20;

/// The ISO week number of one grid row — a quiet label in the leading edge,
/// with no block of its own so the grid keeps reading as seven columns.
class _WeekNumber extends StatelessWidget {
  final DateTime rowStart;

  const _WeekNumber({required this.rowStart});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _weekNumberWidth,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          '${isoWeekNumberForRow(rowStart)}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  final DateTime date;
  final int row;
  final int col;
  final int rowCount;
  final int colCount;
  final bool isCurrentMonth;
  final bool isToday;
  final List<CalendarItem> items;
  final VoidCallback onTap;
  final ValueChanged<CalendarItem>? onItemTap;

  const _MonthCell({
    required this.date,
    required this.row,
    required this.col,
    required this.rowCount,
    required this.colCount,
    required this.isCurrentMonth,
    required this.isToday,
    required this.items,
    required this.onTap,
    required this.onItemTap,
  });

  /// Only the four corners of the whole grid are strongly rounded. Every
  /// other corner — including the ones along an edge — stays slightly
  /// rounded, like the corners between two rows of a task list.
  Radius _corner({required bool vertical, required bool horizontal}) {
    if (vertical && horizontal) {
      return const Radius.circular(AppShapes.groupOuter);
    }
    return const Radius.circular(AppShapes.groupInner);
  }

  @override
  Widget build(BuildContext context) {
    final top = row == 0;
    final bottom = row == rowCount - 1;
    final left = col == 0;
    final right = col == colCount - 1;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.all(AppShapes.groupGap / 2),
        decoration: BoxDecoration(
          // A day out of the focused month sits a step further back instead
          // of being framed off.
          color: isCurrentMonth
              ? AppColors.surface
              : Color.alphaBlend(
                  AppColors.surface.withValues(alpha: 0.45),
                  AppColors.background,
                ),
          borderRadius: BorderRadius.only(
            topLeft: _corner(vertical: top, horizontal: left),
            topRight: _corner(vertical: top, horizontal: right),
            bottomLeft: _corner(vertical: bottom, horizontal: left),
            bottomRight: _corner(vertical: bottom, horizontal: right),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Day number — today is a filled circle, the way every view in
            // the app marks today.
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isToday ? CalendarStyle.accent : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isToday
                          ? AppColors.onPrimary
                          : isCurrentMonth
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ),

            // Event chips
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // ~18px per chip incl. spacing; reserve room for "+N".
                    final maxChips = (constraints.maxHeight / 18).floor().clamp(
                      0,
                      4,
                    );
                    final overflow = items.length - maxChips;
                    final visible = items.take(maxChips).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...visible.map(_chip),
                        if (overflow > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 6, top: 1),
                            child: Text(
                              '+$overflow more',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One event inside a day tile: an all-day event is a solid pill, a timed
  /// event a soft tint with a dot — the same pair the week grid uses.
  Widget _chip(CalendarItem item) {
    final color = CalendarStyle.colorOf(item.color);
    return GestureDetector(
      onTap: () => onItemTap?.call(item),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: item.isAllDay ? color : color.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(AppShapes.groupInner),
        ),
        child: Row(
          children: [
            if (!item.isAllDay) ...[
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: item.isAllDay
                      ? CalendarStyle.onEventColor(color)
                      : (isCurrentMonth
                            ? AppColors.textPrimary
                            : AppColors.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
