import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/day_window.dart';
import '../../domain/models/calendar_item.dart';
import '../../domain/models/event_layout.dart';
import '../../domain/week_dates.dart';
import '../../providers/calendar_event_provider.dart';
import 'calendar_style.dart';
import 'event_block.dart';
import 'period_pager.dart';
import 'pinch_scaler.dart';
import 'sliding_page_row.dart';

/// The hourly grid behind the day, three day and week view — and the pager of
/// those three views.
///
/// ## Why the pager lives in here
///
/// The whole view used to be one page of a [PeriodPager], so a swipe slid the
/// hour gutter, the date header and the all-day label off the screen together
/// with the columns. The owner asked for the opposite: the frame stays, only
/// the fields move. A frame that stays cannot be inside the thing that moves,
/// so the grid owns the pager instead of sitting in one.
///
/// The build is one vertical scroll view holding a row of
/// `[hour gutter, PageView of day columns]`, with the page given the full grid
/// height. That single scroll view is what keeps the gutter and every page
/// scrolling as one body and what lets a pinch resize both at once — a scroll
/// view per page could not. The date header and the all-day strip sit above
/// it, outside the scrolling, and follow the pager through
/// [SlidingPageRow]: they read the same controller and translate by the same
/// fraction of a page, so they travel with the columns to the pixel.
///
/// The month view still pages as a whole; it has no frame to hold still.
class TimeGrid extends StatefulWidget {
  /// Period one page covers. Only [CalendarViewMode.day],
  /// [CalendarViewMode.threeDay] and [CalendarViewMode.week] draw a time grid.
  final CalendarViewMode mode;

  /// First column of a week — a week page starts on the user's first day.
  final WeekStart weekStart;

  /// The date the calendar is showing, owned by the notifier.
  final DateTime focusedDate;

  /// Reports the period the user swiped to. Goes straight back into
  /// [focusedDate]; the driver's guard keeps that from moving the pager again.
  final ValueChanged<DateTime> onFocusedDateChanged;

  /// Every item of one day, timed and all-day alike. A callback rather than a
  /// list, because the grid decides itself which days are on screen.
  final List<CalendarItem> Function(DateTime day) itemsForDay;

  /// Whether the hour gutter carries the ISO week number. Only the week view
  /// asks for it: three days can straddle two weeks, so one number would be
  /// wrong for part of the row.
  final bool showWeekNumber;

  /// The user's day window. The grid spans [startHour] to [endHour], so the
  /// end is exclusive: 7 to 22 draws fifteen rows and stops at 22:00. That
  /// matches the settings' `calendarDayHourCount`, which is `end - start`.
  ///
  /// This is the window the user asked for, not necessarily the one drawn:
  /// [DayWindow.covering] widens it until every item of the shown days fits,
  /// because a window may shorten the day but must never hide an appointment.
  final int startHour;
  final int endHour;

  /// Height of one hour row. The user's, from the settings — a pinch on the
  /// grid writes it back through [onHourHeightChanged].
  final double hourHeight;
  final double timeColumnWidth;
  final ValueChanged<({DateTime date, TimeOfDay time})>? onSlotTap;
  final ValueChanged<CalendarItem>? onItemTap;
  final void Function(CalendarItem item, DateTime newStart)? onItemDrop;

  /// The hour height the fingers settled on, reported once when the pinch
  /// ends. Writing on every frame would hammer the settings box.
  final ValueChanged<double>? onHourHeightChanged;

  /// A date in the header was tapped — the page opens that single day.
  final ValueChanged<DateTime>? onDateTap;

  const TimeGrid({
    super.key,
    required this.mode,
    required this.weekStart,
    required this.focusedDate,
    required this.onFocusedDateChanged,
    required this.itemsForDay,
    this.showWeekNumber = false,
    this.startHour = 0,
    this.endHour = 24,
    this.hourHeight = AppSettings.calendarHourHeightDefault,
    this.timeColumnWidth = 44.0,
    this.onSlotTap,
    this.onItemTap,
    this.onItemDrop,
    this.onHourHeightChanged,
    this.onDateTap,
  });

  /// Headroom above the first hour row, inside the scroll view. The pinch
  /// anchor has to subtract it to reach grid coordinates.
  static const double topPadding = 8;

  /// Height every block gets at least, however short the event is.
  ///
  /// The owner plans by the minute, so a 4 minute event exists and would be
  /// four pixels tall at the default hour height — a coloured hairline with no
  /// room for its title. 24 px carries one line of the compact block. A block
  /// only grows into empty space though: it never passes the top of the next
  /// block in its own column, so a short event cannot swallow the one after
  /// it.
  static const double minBlockHeight = 24;

  /// Height of the date header row.
  ///
  /// Fixed, not intrinsic: the header of every page and the week number in the
  /// gutter beside it have to start the grid at the same y, or the hour scale
  /// would sit a few pixels off its own rows. It holds an 11px label, a 3px
  /// gap and the 30px day circle with room to breathe.
  static const double headerHeight = 56;

  /// One all-day chip plus its gap. Also fixed, for the same reason as
  /// [headerHeight]: the strip is reserved for the tallest of the pages that
  /// can be on screen, so the frame does not resize mid-swipe.
  static const double allDayRowHeight = 32;

  /// Padding the all-day strip adds above and below its rows.
  static const double allDayStripPadding = 8;

  /// Chips beyond this are dropped — three deep is where the strip starts
  /// eating the grid.
  static const int maxAllDayRows = 3;

  /// The hour scale. Tests and the page beside it find the frame by this.
  static const Key gutterKey = Key('time-grid-hour-gutter');

  /// Columns one page of [mode] draws.
  static int columnsFor(CalendarViewMode mode) => switch (mode) {
    CalendarViewMode.day => 1,
    CalendarViewMode.threeDay => threeDayColumns,
    CalendarViewMode.week => 7,
    // Month and agenda never build a time grid; one column keeps the
    // arithmetic defined if one ever does.
    CalendarViewMode.month || CalendarViewMode.agenda => 1,
  };

  @override
  State<TimeGrid> createState() => _TimeGridState();
}

/// Big radius only on the four corners of the whole grid.
Radius _corner(bool isGridCorner) =>
    Radius.circular(isGridCorner ? AppShapes.groupOuter : AppShapes.groupInner);

class _TimeGridState extends State<TimeGrid> {
  late PeriodPageDriver _driver;
  late ScrollController _scrollController;
  Timer? _timer;

  /// The window the last build drew. A page change can widen it, and every row
  /// then moves by the hours that were added.
  DayWindow? _drawnWindow;

  /// The hour height the last build drew with — the settings' one, or the live
  /// one while [PinchScaler] is running a zoom.
  ///
  /// The scaler owns that value, so everything outside `build` (scrolling to
  /// now, holding the scroll still when the window widens) reads the copy the
  /// builder leaves here rather than the settings, which would be the wrong
  /// height mid-pinch. Both readers run in a post-frame callback, so the
  /// builder of that frame has already written it.
  late double _drawnHourHeight;

  int get _columnCount => TimeGrid.columnsFor(widget.mode);

  @override
  void initState() {
    super.initState();
    _drawnHourHeight = widget.hourHeight;
    _driver = PeriodPageDriver(
      mode: widget.mode,
      weekStart: widget.weekStart,
      focusedDate: widget.focusedDate,
      onReportDate: (date) => widget.onFocusedDateChanged(date),
      onRebuild: () => setState(() {}),
    );
    _scrollController = ScrollController();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    // Scroll to current time (or the window start) once laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNow());
  }

  @override
  void didUpdateWidget(TimeGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    _driver.update(
      mode: widget.mode,
      weekStart: widget.weekStart,
      focusedDate: widget.focusedDate,
    );
  }

  @override
  void dispose() {
    _driver.dispose();
    _scrollController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ── Days, items, window ──────────────────────────────────────────────────

  /// The columns page [page] draws, left to right.
  List<DateTime> _datesForPage(int page) =>
      daysFrom(_driver.periodStartForPage(page), _columnCount);

  /// The pages that can be on screen: the one under the finger and the two it
  /// can be dragged towards.
  Iterable<int> get _nearbyPages sync* {
    yield _driver.currentPage - 1;
    yield _driver.currentPage;
    yield _driver.currentPage + 1;
  }

  List<CalendarItem> _timedItems(DateTime day) =>
      widget.itemsForDay(day).where((i) => !i.isAllDay).toList();

  List<CalendarItem> _allDayItems(DateTime day) =>
      widget.itemsForDay(day).where((i) => i.isAllDay).toList();

  /// The hour window actually drawn: the user's, widened until every item of
  /// the pages that can be on screen fits.
  ///
  /// Over three pages, not one: the gutter is shared, so the page sliding in
  /// under the finger has to be measured in the same window as the page it
  /// replaces — otherwise its 06:00 event would be drawn at the top edge of a
  /// grid that starts at 08:00 and jump into place after the swipe.
  DayWindow get _window {
    final dates = [for (final page in _nearbyPages) ..._datesForPage(page)];
    return DayWindow.covering(
      startHour: widget.startHour,
      endHour: widget.endHour,
      columnDates: dates,
      itemsByColumn: [for (final date in dates) _timedItems(date)],
    );
  }

  /// All-day rows the strip reserves: the deepest column of any page that can
  /// be on screen, so the frame keeps its height while a page slides in.
  int _allDayRows() {
    var rows = 0;
    for (final page in _nearbyPages) {
      for (final date in _datesForPage(page)) {
        final count = _allDayItems(date).length;
        if (count > rows) rows = count;
      }
    }
    return rows > TimeGrid.maxAllDayRows ? TimeGrid.maxAllDayRows : rows;
  }

  /// Items that arrive late (a sync, a feed refresh) and pages the user swipes
  /// to can widen the window upwards, and every row then moves down by the
  /// hours that were added. Without this the grid would appear to jump
  /// backwards in time under the user's eyes.
  void _keepScrollOnWindowChange(DayWindow window) {
    final previous = _drawnWindow;
    _drawnWindow = window;
    if (previous == null || previous.startHour == window.startHour) return;

    final addedHours = previous.startHour - window.startHour;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(
        (_scrollController.offset + addedHours * _drawnHourHeight).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        ),
      );
    });
  }

  void _scrollToNow() {
    if (!_scrollController.hasClients) return;
    final now = DateTime.now();
    final window = _window;
    // On "now", or on the start of the window when now is outside it. A
    // widened window must not drop the user at 00:00 either — the anchor is
    // measured from the window that is drawn, not from the settings.
    final anchorHour = now.hour.clamp(window.startHour, window.lastHour);
    final target =
        ((anchorHour - window.startHour) * _drawnHourHeight - _drawnHourHeight)
            .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(target);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Not the settings window: the drawn one, widened over every item of the
    // pages that can be on screen so nothing can fall outside the grid.
    final window = _window;
    _keepScrollOnWindowChange(window);

    final allDayRows = _allDayRows();

    return Column(
      children: [
        _buildChrome(allDayRows),

        Expanded(
          child: PinchScaler(
            value: widget.hourHeight,
            min: AppSettings.calendarHourHeightMin,
            max: AppSettings.calendarHourHeightMax,
            scrollController: _scrollController,
            topPadding: TimeGrid.topPadding,
            onSettled: widget.onHourHeightChanged,
            builder: (context, hourHeight, pinching) {
              // Everything outside `build` reads the height from here — see
              // [_drawnHourHeight].
              _drawnHourHeight = hourHeight;
              final totalHeight = window.hourCount * hourHeight;

              return SingleChildScrollView(
                controller: _scrollController,
                // A pinch owns the grid: without this the vertical drag that
                // the first finger already started keeps scrolling and fights
                // the zoom anchor.
                physics: pinching ? const NeverScrollableScrollPhysics() : null,
                // The grid runs under the floating nav bar; this keeps the last
                // hour reachable instead of hiding it behind the pill.
                // Half a line of headroom for the hour labels, and enough at
                // the bottom to scroll the last hour clear of the nav bar.
                padding: EdgeInsets.only(
                  top: TimeGrid.topPadding,
                  bottom: AppShapes.contentBottom(context) + 8,
                ),
                // One body for the gutter and every page: they scroll together
                // and a pinch resizes both, which two scroll views could not
                // do.
                child: SizedBox(
                  height: totalHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        key: TimeGrid.gutterKey,
                        width: widget.timeColumnWidth,
                        child: _HourGutter(
                          window: window,
                          hourHeight: hourHeight,
                        ),
                      ),
                      Expanded(
                        child: PageView.builder(
                          key: _driver.pageViewKey,
                          controller: _driver.controller,
                          // Two fingers on the grid are a zoom, never a period
                          // change.
                          physics: pinching
                              ? const NeverScrollableScrollPhysics()
                              : null,
                          itemCount: PeriodPageDriver.pageCount,
                          onPageChanged: _driver.handlePageChanged,
                          itemBuilder: (context, page) => _buildColumns(
                            page: page,
                            window: window,
                            hourHeight: hourHeight,
                            totalHeight: totalHeight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// The row above the grid: the part of it that stays (week number, all-day
  /// label) beside the part that travels with the pager (dates, all-day
  /// chips).
  Widget _buildChrome(int allDayRows) {
    final stripHeight = allDayRows == 0
        ? 0.0
        : allDayRows * TimeGrid.allDayRowHeight + TimeGrid.allDayStripPadding;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: widget.timeColumnWidth,
          child: Column(
            children: [
              SizedBox(
                height: TimeGrid.headerHeight,
                child: widget.showWeekNumber
                    ? Padding(
                        padding: const EdgeInsets.only(right: 8, top: 10),
                        child: Text(
                          'W${isoWeekNumberForRow(_datesForPage(_driver.currentPage).first)}',
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
              if (stripHeight > 0)
                SizedBox(
                  height: stripHeight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Text(
                      'All day',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SlidingPageRow(
            controller: _driver.controller,
            fallbackPage: _driver.currentPage,
            builder: (context, page) => _buildPageChrome(page, stripHeight),
          ),
        ),
      ],
    );
  }

  /// The dates of one page, and its all-day chips under them. Every page
  /// builds to the same height, so the row does not resize while it slides.
  Widget _buildPageChrome(int page, double stripHeight) {
    final dates = _datesForPage(page);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: [
        SizedBox(
          height: TimeGrid.headerHeight,
          child: Row(
            children: [
              for (final date in dates)
                Expanded(child: _dateHeader(date, today)),
            ],
          ),
        ),
        if (stripHeight > 0)
          SizedBox(
            height: stripHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 2, 4, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final date in dates)
                    Expanded(child: _allDayColumn(date)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// One column head: the weekday over the day number, the day number filled
  /// when it is today. Tapping it opens that single day.
  ///
  /// The day view carries it too, although the page title already names the
  /// day: with the title standing still, this is the only date that moves with
  /// the swipe, and a swipe with no moving date reads as a stuck screen.
  Widget _dateHeader(DateTime day, DateTime today) {
    final isToday = day.isAtSameMomentAs(today);

    return GestureDetector(
      onTap: widget.onDateTap == null ? null : () => widget.onDateTap!(day),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              CalendarStyle.weekdayLabel(day).toUpperCase(),
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
  }

  Widget _allDayColumn(DateTime date) {
    final items = _allDayItems(date).take(TimeGrid.maxAllDayRows);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Column(children: [for (final item in items) _allDayChip(item)]),
    );
  }

  Widget _allDayChip(CalendarItem item) {
    final color = CalendarStyle.colorOf(item.color);

    return GestureDetector(
      onTap: () => widget.onItemTap?.call(item),
      child: Container(
        width: double.infinity,
        height: TimeGrid.allDayRowHeight - 4,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppShapes.dockChip),
        ),
        child: Text(
          item.title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: CalendarStyle.onEventColor(color),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// One page: the hour tiles of its own columns and the blocks on them. No
  /// gutter and no scroll view — both belong to the frame around it.
  Widget _buildColumns({
    required int page,
    required DayWindow window,
    required double hourHeight,
    required double totalHeight,
  }) {
    final dates = _datesForPage(page);

    return _PeriodColumns(
      dates: dates,
      itemsByColumn: [for (final date in dates) _timedItems(date)],
      window: window,
      hourHeight: hourHeight,
      totalHeight: totalHeight,
      onSlotTap: widget.onSlotTap,
      onItemTap: widget.onItemTap,
      onItemDrop: widget.onItemDrop,
    );
  }
}

/// The hour scale. Stays put while the pages slide past it, and scrolls with
/// them because it shares their scroll view.
class _HourGutter extends StatelessWidget {
  final DayWindow window;
  final double hourHeight;

  const _HourGutter({required this.window, required this.hourHeight});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The first row carries no label: its line is the top edge of the
        // grid, and the number would float above it.
        for (var i = 1; i < window.hourCount; i++)
          Positioned(
            // The label sits on the line, not under it.
            top: i * hourHeight - 6,
            left: 2,
            right: 8,
            child: Text(
              '${(window.startHour + i).toString().padLeft(2, '0')}:00',
              // Right against the grid, the way every calendar app sets its
              // hour scale.
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
          ),
      ],
    );
  }
}

/// The columns of one period: the hour tiles, the blocks and the now line.
class _PeriodColumns extends StatelessWidget {
  final List<DateTime> dates;
  final List<List<CalendarItem>> itemsByColumn;
  final DayWindow window;
  final double hourHeight;
  final double totalHeight;
  final ValueChanged<({DateTime date, TimeOfDay time})>? onSlotTap;
  final ValueChanged<CalendarItem>? onItemTap;
  final void Function(CalendarItem item, DateTime newStart)? onItemDrop;

  const _PeriodColumns({
    required this.dates,
    required this.itemsByColumn,
    required this.window,
    required this.hourHeight,
    required this.totalHeight,
    this.onSlotTap,
    this.onItemTap,
    this.onItemDrop,
  });

  @override
  Widget build(BuildContext context) {
    final hours = window.hourCount;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Stack(
      children: [
        // The grid is built from rounded tiles — one per day and hour — with a
        // small gap, the way Google Calendar draws it. Only the four corners
        // of the whole grid are strongly rounded, everything inside stays
        // slightly rounded.
        ...List.generate(hours, (i) {
          return Positioned(
            top: i * hourHeight,
            left: 0,
            right: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var col = 0; col < dates.length; col++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: col == dates.length - 1 ? 0 : AppShapes.groupGap,
                      ),
                      child: Container(
                        height: hourHeight - AppShapes.groupGap,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.only(
                            topLeft: _corner(i == 0 && col == 0),
                            topRight: _corner(
                              i == 0 && col == dates.length - 1,
                            ),
                            bottomLeft: _corner(i == hours - 1 && col == 0),
                            bottomRight: _corner(
                              i == hours - 1 && col == dates.length - 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),

        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final dayWidth = constraints.maxWidth / dates.length;
              return Stack(
                children: [
                  ...List.generate(dates.length, (col) {
                    final date = dates[col];
                    return Positioned(
                      left: col * dayWidth,
                      top: 0,
                      bottom: 0,
                      width: dayWidth,
                      child: _DayColumn(
                        date: date,
                        items: col < itemsByColumn.length
                            ? itemsByColumn[col]
                            : const [],
                        window: window,
                        hourHeight: hourHeight,
                        totalHeight: totalHeight,
                        dayWidth: dayWidth,
                        onSlotTap: onSlotTap,
                        onItemTap: onItemTap,
                        onItemDrop: onItemDrop,
                      ),
                    );
                  }),

                  ..._buildCurrentTimeIndicator(now, today, dayWidth),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCurrentTimeIndicator(
    DateTime now,
    DateTime today,
    double dayWidth,
  ) {
    for (var i = 0; i < dates.length; i++) {
      final date = dates[i];
      if (date.year == today.year &&
          date.month == today.month &&
          date.day == today.day) {
        final y =
            (now.hour - window.startHour) * hourHeight +
            (now.minute / 60.0) * hourHeight;
        // The day window can end before now: no line outside the grid.
        if (y < 0 || y > totalHeight) return [];
        return [
          Positioned(
            top: y - 5,
            left: i * dayWidth - 5,
            width: dayWidth + 5,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(child: Container(height: 2, color: AppColors.error)),
              ],
            ),
          ),
        ];
      }
    }
    return [];
  }
}

/// One day of one page: its blocks, its tap-to-create and its drop target.
class _DayColumn extends StatelessWidget {
  final DateTime date;
  final List<CalendarItem> items;
  final DayWindow window;
  final double hourHeight;
  final double totalHeight;
  final double dayWidth;
  final ValueChanged<({DateTime date, TimeOfDay time})>? onSlotTap;
  final ValueChanged<CalendarItem>? onItemTap;
  final void Function(CalendarItem item, DateTime newStart)? onItemDrop;

  const _DayColumn({
    required this.date,
    required this.items,
    required this.window,
    required this.hourHeight,
    required this.totalHeight,
    required this.dayWidth,
    this.onSlotTap,
    this.onItemTap,
    this.onItemDrop,
  });

  @override
  Widget build(BuildContext context) {
    final layoutInfos = EventLayoutCalculator.calculateLayout(
      items.where((i) => !i.isAllDay).toList(),
    );

    return DragTarget<CalendarItem>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        // This column lives *inside* the scroll view, so its own local y is
        // already the grid's y — no scroll offset and no header height to
        // subtract, which is what the old maths got wrong.
        final box = context.findRenderObject() as RenderBox;
        final gridY = box.globalToLocal(details.offset).dy;

        final hour = window.startHour + (gridY / hourHeight).floor();
        final minute = ((gridY % hourHeight) / hourHeight * 60).round();
        // Dragging keeps the quarter-hour snap: it is a convenience, and the
        // finger cannot aim at a minute. Only the *drawing* is exact.
        final snappedMinute = (minute ~/ 15) * 15;

        final newStart = DateTime(
          date.year,
          date.month,
          date.day,
          hour.clamp(window.startHour, window.lastHour),
          snappedMinute.clamp(0, 45),
        );

        HapticFeedback.mediumImpact();
        onItemDrop?.call(details.data, newStart);
      },
      builder: (context, candidateData, rejectedData) {
        return GestureDetector(
          onTapUp: (details) {
            final tapY = details.localPosition.dy;
            final hour = window.startHour + (tapY / hourHeight).floor();
            final minute = ((tapY % hourHeight) / hourHeight * 60).round();
            // Same as the drop above: creating snaps, drawing does not.
            final snappedMinute = (minute ~/ 15) * 15;
            onSlotTap?.call((
              date: date,
              time: TimeOfDay(
                hour: hour.clamp(window.startHour, window.lastHour),
                minute: snappedMinute.clamp(0, 45),
              ),
            ));
          },
          child: Container(
            color: Colors.transparent,
            child: Stack(
              children: [
                if (candidateData.isNotEmpty)
                  Positioned.fill(
                    child: Container(
                      color: CalendarStyle.accent.withValues(alpha: 0.10),
                    ),
                  ),

                ...layoutInfos.map((info) {
                  final item = info.item;
                  // Minute precision: the position is the event's own minute,
                  // never a rounded slot. 07:03 to 07:11 sits at 07:03 and is
                  // eight minutes long. Times are clipped to this column's
                  // day, so an event running over midnight starts at the top
                  // of the second column instead of at hour 23 of it.
                  final pxPerMinute = hourHeight / 60.0;
                  final startY =
                      (minutesIntoDay(item.startTime, date) -
                          window.startMinutes) *
                      pxPerMinute;
                  final endY =
                      (minutesIntoDay(item.endTime, date) -
                          window.startMinutes) *
                      pxPerMinute;

                  final visibleTop = startY.clamp(0.0, totalHeight);
                  final visibleBottom = endY.clamp(visibleTop, totalHeight);

                  // Room down to the block that will be drawn under this one,
                  // less the gap the grid keeps between two blocks. This is
                  // the line a grown block may not cross.
                  final next = info.nextStartBelow;
                  final room = next == null
                      ? totalHeight - visibleTop
                      : (minutesIntoDay(next, date) - window.startMinutes) *
                                pxPerMinute -
                            visibleTop -
                            AppShapes.groupGap;

                  // A short event grows to [TimeGrid.minBlockHeight] so its
                  // title stays readable, but only into empty space.
                  final realHeight = visibleBottom - visibleTop;
                  final blockHeight = _blockHeight(
                    realHeight: realHeight,
                    room: room,
                    totalHeight: totalHeight - visibleTop,
                  );

                  final blockWidth = dayWidth * info.widthFraction - 3;
                  final blockLeft = dayWidth * info.leftFraction + 1.5;

                  return Positioned(
                    left: blockLeft,
                    top: visibleTop,
                    width: blockWidth.clamp(10.0, dayWidth - 2),
                    child: EventBlock(
                      item: item,
                      height: blockHeight,
                      onTap: () => onItemTap?.call(item),
                      onDragStarted: onItemDrop != null ? (_) {} : null,
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Height of one block: its real length, grown to a readable minimum where
  /// there is free space under it.
  ///
  /// [room] is the distance to the next block in the same layout column (or to
  /// the bottom of the grid). The growth stops there, so a four minute event
  /// keeps its neighbour visible instead of covering it — which is why this is
  /// a layout decision and not something the block itself could take.
  static double _blockHeight({
    required double realHeight,
    required double room,
    required double totalHeight,
  }) {
    final grown = TimeGrid.minBlockHeight < room
        ? TimeGrid.minBlockHeight
        : room;
    final height = realHeight > grown ? realHeight : grown;
    // Never past the bottom of the grid, and never negative.
    return height.clamp(0.0, totalHeight);
  }
}
