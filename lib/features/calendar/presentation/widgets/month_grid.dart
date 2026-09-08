import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/calendar_item.dart';
import '../../domain/week_dates.dart';
import '../../providers/calendar_event_provider.dart';
import 'calendar_style.dart';
import 'period_pager.dart';
import 'pinch_scaler.dart';

/// The month grid — and the pager of the months.
///
/// One filled tile per day on the darker ground, a small gap between them, and
/// a strong radius only on the four corners of the grid.
///
/// ## What stays and what moves
///
/// A month page is still dragged in as a whole, the way the owner asked for:
/// there is no hour gutter here that would have to hold still. Only the
/// weekday header sits outside the pager, and it carries the same seven labels
/// for every month, so nothing about the swipe looks different — it just is
/// not rebuilt three times per frame any more.
///
/// The six week rows live in *one* scroll view around the pager, not one per
/// page. That single body is what lets a pinch resize the rows and keep the
/// week under the fingers under the fingers; a scroll view per page would also
/// lose the scroll position on every swipe.
///
/// ## The row height
///
/// By default there is none: [rowHeight] is null, the six rows are fitted into
/// the viewport and nothing scrolls. The moment the user pinches, an explicit
/// height takes over, is persisted, and a grid taller than the viewport
/// scrolls. [PinchScaler] does the pointer work — see there for why this is
/// not a `ScaleGestureRecognizer`.
class MonthGrid extends StatefulWidget {
  /// First column of the grid — the user's first day of the week.
  final WeekStart weekStart;

  /// The month the calendar is showing, owned by the notifier.
  final DateTime focusedDate;

  /// Reports the month the user swiped to. Goes straight back into
  /// [focusedDate]; the pager's guard keeps that from moving it again.
  final ValueChanged<DateTime> onFocusedDateChanged;

  /// Every item of one day. A callback rather than a list, because the grid
  /// decides itself which days are on screen.
  final List<CalendarItem> Function(DateTime day) itemsForDay;

  /// ISO week number in the leading edge of every row.
  final bool showWeekNumber;

  /// Height of one week row, or null for "fit the six rows to the viewport".
  /// A pinch writes it back through [onRowHeightChanged].
  final double? rowHeight;

  /// The row height the fingers settled on, reported once when the pinch ends.
  /// Writing on every frame would hammer the settings box.
  final ValueChanged<double>? onRowHeightChanged;

  final ValueChanged<DateTime>? onDayTap;
  final ValueChanged<CalendarItem>? onItemTap;

  const MonthGrid({
    super.key,
    required this.weekStart,
    required this.focusedDate,
    required this.onFocusedDateChanged,
    required this.itemsForDay,
    this.showWeekNumber = false,
    this.rowHeight,
    this.onRowHeightChanged,
    this.onDayTap,
    this.onItemTap,
  });

  /// Weeks a month page draws. Fixed at six, so a page never changes height
  /// between a 28 day February and a 31 day month that starts on a Sunday.
  static const int weekRows = 6;

  /// The block holding those six rows. Tests measure the row height through
  /// it — a screenshot cannot tell 96 px from 108.
  static const Key rowsKey = Key('month-grid-rows');

  @override
  State<MonthGrid> createState() => _MonthGridState();
}

class _MonthGridState extends State<MonthGrid> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppShapes.listInset),
      child: Column(
        children: [
          _WeekdayHeader(
            weekStart: widget.weekStart,
            showWeekNumber: widget.showWeekNumber,
          ),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The height a row gets while the user has not pinched: the
                // viewport split into six. Clamped to the same range a pinch
                // may reach, so a very short window cannot squeeze a week into
                // a line of pixels.
                final fitted = (constraints.maxHeight / MonthGrid.weekRows)
                    .clamp(
                      AppSettings.calendarMonthRowHeightMin,
                      AppSettings.calendarMonthRowHeightMax,
                    );

                return PinchScaler(
                  // The fitted height is what the user sees when nothing is
                  // stored, so a pinch has to start from it — otherwise the
                  // first move would jump the rows.
                  value: widget.rowHeight ?? fitted,
                  min: AppSettings.calendarMonthRowHeightMin,
                  max: AppSettings.calendarMonthRowHeightMax,
                  scrollController: _scrollController,
                  onSettled: widget.onRowHeightChanged,
                  builder: (context, rowHeight, pinching) {
                    return SingleChildScrollView(
                      controller: _scrollController,
                      // A pinch owns the grid: without this the vertical drag
                      // the first finger already started keeps scrolling and
                      // fights the zoom anchor.
                      physics: pinching
                          ? const NeverScrollableScrollPhysics()
                          : null,
                      // The grid runs under the floating nav bar; this keeps
                      // the last week reachable instead of hiding it behind
                      // the pill.
                      padding: EdgeInsets.only(
                        bottom: AppShapes.contentBottom(context),
                      ),
                      child: SizedBox(
                        key: MonthGrid.rowsKey,
                        height: rowHeight * MonthGrid.weekRows,
                        child: PeriodPager(
                          mode: CalendarViewMode.month,
                          weekStart: widget.weekStart,
                          focusedDate: widget.focusedDate,
                          onFocusedDateChanged: widget.onFocusedDateChanged,
                          // Two fingers on the grid are a zoom, never a month
                          // change.
                          physics: pinching
                              ? const NeverScrollableScrollPhysics()
                              : null,
                          pageBuilder: (context, monthStart) => _MonthPage(
                            monthStart: monthStart,
                            weekStart: widget.weekStart,
                            rowHeight: rowHeight,
                            showWeekNumber: widget.showWeekNumber,
                            itemsForDay: widget.itemsForDay,
                            onDayTap: widget.onDayTap,
                            onItemTap: widget.onItemTap,
                          ),
                        ),
                      ),
                    );
                  },
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

/// The seven weekday labels over the grid — the same ones the week view uses.
///
/// They are identical for every month, so they stay outside the pager instead
/// of sliding with it.
class _WeekdayHeader extends StatelessWidget {
  final WeekStart weekStart;
  final bool showWeekNumber;

  const _WeekdayHeader({required this.weekStart, required this.showWeekNumber});

  @override
  Widget build(BuildContext context) {
    final labels = CalendarStyle.weekdays(weekStart);
    // Any week that starts on the user's first day answers which of the seven
    // columns are the weekend.
    final anyWeek = startOfWeek(DateTime.now(), weekStart);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 8),
      child: Row(
        children: [
          // Keeps the labels above their column when the week numbers take the
          // leading edge.
          if (showWeekNumber) const SizedBox(width: _weekNumberWidth),
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
                        CalendarStyle.isWeekend(anyWeek.add(Duration(days: i)))
                        ? AppColors.textTertiary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One month: six week rows of seven day tiles.
class _MonthPage extends StatelessWidget {
  /// First of the month this page draws.
  final DateTime monthStart;
  final WeekStart weekStart;
  final double rowHeight;
  final bool showWeekNumber;
  final List<CalendarItem> Function(DateTime day) itemsForDay;
  final ValueChanged<DateTime>? onDayTap;
  final ValueChanged<CalendarItem>? onItemTap;

  const _MonthPage({
    required this.monthStart,
    required this.weekStart,
    required this.rowHeight,
    required this.showWeekNumber,
    required this.itemsForDay,
    required this.onDayTap,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    // The grid always begins on the user's first day of the week, so the
    // month's first row can reach back into the previous month.
    final gridStart = startOfWeek(monthStart, weekStart);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: List.generate(MonthGrid.weekRows, (week) {
        return SizedBox(
          height: rowHeight,
          child: Row(
            children: [
              if (showWeekNumber)
                _WeekNumber(rowStart: gridStart.add(Duration(days: week * 7))),
              ...List.generate(7, (dayOfWeek) {
                final date = gridStart.add(
                  Duration(days: week * 7 + dayOfWeek),
                );
                return Expanded(
                  child: _MonthCell(
                    date: date,
                    isCurrentMonth: date.month == monthStart.month,
                    isToday: date.isAtSameMomentAs(today),
                    items: itemsForDay(date),
                    onTap: () => onDayTap?.call(date),
                    onItemTap: onItemTap,
                    row: week,
                    col: dayOfWeek,
                    rowCount: MonthGrid.weekRows,
                    colCount: 7,
                  ),
                );
              }),
            ],
          ),
        );
      }),
    );
  }
}

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
                    // A pinched-open row therefore shows more of a busy day
                    // instead of a taller "+3 more".
                    final maxChips = (constraints.maxHeight / 18).floor().clamp(
                      0,
                      8,
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
