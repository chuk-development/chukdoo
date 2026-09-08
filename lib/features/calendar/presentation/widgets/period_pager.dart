import 'package:flutter/material.dart';

import '../../../settings/providers/settings_provider.dart';
import '../../domain/week_dates.dart';
import '../../providers/calendar_event_provider.dart';

/// The page↔period mapping and the loop guard every horizontally paged
/// calendar surface shares.
///
/// Two surfaces page by period and they page *different things*: [PeriodPager]
/// drags a whole view in (the month grid), while the time grid keeps its hour
/// gutter and its frame still and pages only the day columns, with the date
/// header slid from the same controller. The arithmetic and the guard are the
/// same for both, so they live here once instead of in two copies that drift
/// apart.
///
/// ## The mapping
///
/// A page index is not a date, it is an offset: page [center] is the period
/// the focused date was in when the mapping was built ([_base]), and every
/// other page is that period shifted by `index - center`. The three day view
/// is the one period that is not aligned to anything in the calendar — its
/// pages are blocks of three days counted from [_base], so the focused day is
/// always the left column; a date that lands inside a block rather than on its
/// first day cannot be represented and rebases the mapping instead. The page
/// count is large and centred, so the user reaches decades in either direction
/// without the list ever ending; [_rebase] rebuilds the mapping when the
/// focused date jumps past its ends or when the period length itself changes.
///
/// ## The loop guard
///
/// The two directions must not chase each other: a page change writes the
/// focused date, and a focused date set from outside moves the pager. Both go
/// through the page index, never through the date:
///
/// * a page the user swiped to reports its date, the parent writes it, and the
///   date comes back mapping to the page that is already showing — so [update]
///   finds `target == currentPage` and moves nothing;
/// * a move this driver started (Today, the month strip, a day tapped in the
///   month grid) is remembered in [_programmaticTarget], and every page change
///   it produces is swallowed instead of being written back.
class PeriodPageDriver {
  PeriodPageDriver({
    required CalendarViewMode mode,
    required WeekStart weekStart,
    required DateTime focusedDate,
    required this.onReportDate,
    required this.onRebuild,
  }) : _mode = mode,
       _weekStart = weekStart,
       _focusedDate = focusedDate {
    _base = _periodStart(focusedDate);
    _controller = PageController(initialPage: center);
  }

  /// Pages either side of the centre. Roughly 27 years of days, and far more
  /// of weeks or months — past that [_rebase] takes over.
  static const int pageRadius = 5000;
  static const int center = pageRadius;
  static const int pageCount = pageRadius * 2 + 1;

  /// Called when the user lands on another page. Never called for a move this
  /// driver started itself.
  final ValueChanged<DateTime> onReportDate;

  /// Asks the host `State` to rebuild — a rebase swaps the controller, and the
  /// scrollable has to be handed the new one.
  final VoidCallback onRebuild;

  CalendarViewMode _mode;
  WeekStart _weekStart;
  DateTime _focusedDate;

  /// First day of the period page [center] shows.
  late DateTime _base;
  late PageController _controller;

  /// The page currently on screen. Kept here rather than read from the
  /// controller: the guard has to answer before the controller has a position.
  int _currentPage = center;

  /// Page a move this driver started is heading for, or null while the user
  /// drives. Page changes on the way there must not write the date back.
  int? _programmaticTarget;

  bool _disposed = false;

  PageController get controller => _controller;
  int get currentPage => _currentPage;
  CalendarViewMode get mode => _mode;

  /// A new mode is a new mapping and a new controller; the key makes the
  /// scrollable start over instead of carrying the old offset across.
  Key get pageViewKey => ValueKey(_mode);

  /// Call from `initState` and `didUpdateWidget` with the current inputs.
  void update({
    required CalendarViewMode mode,
    required WeekStart weekStart,
    required DateTime focusedDate,
  }) {
    // A different period length is a different mapping: rebuild it and land on
    // the page holding the focused date.
    final periodChanged = mode != _mode || weekStart != _weekStart;
    _mode = mode;
    _weekStart = weekStart;

    if (periodChanged) {
      _focusedDate = focusedDate;
      _rebase(focusedDate);
      return;
    }

    if (focusedDate == _focusedDate) return;
    _focusedDate = focusedDate;

    final target = _pageFor(focusedDate);
    // The date this driver just reported, coming back. Nothing to do — moving
    // here is what would start the feedback loop.
    if (target == _currentPage) return;

    if (target == null || target < 0 || target >= pageCount) {
      _rebase(focusedDate);
      return;
    }
    _moveTo(target);
  }

  void dispose() {
    _disposed = true;
    _controller.dispose();
  }

  /// First day of the period [date] falls in, for the current mode.
  DateTime _periodStart(DateTime date) {
    switch (_mode) {
      case CalendarViewMode.day:
      case CalendarViewMode.threeDay:
      case CalendarViewMode.agenda:
        return dayStart(date);
      case CalendarViewMode.week:
        return startOfWeek(date, _weekStart);
      case CalendarViewMode.month:
        return DateTime(date.year, date.month, 1);
    }
  }

  /// First day of the period page [index] shows.
  ///
  /// The arithmetic goes through `DateTime(y, m, d + n)` instead of adding a
  /// `Duration`, because a day across a DST change is not 24 hours long and
  /// would slide the whole mapping by an hour.
  DateTime periodStartForPage(int index) {
    final n = index - center;
    switch (_mode) {
      case CalendarViewMode.day:
      case CalendarViewMode.agenda:
        return DateTime(_base.year, _base.month, _base.day + n);
      case CalendarViewMode.threeDay:
        return DateTime(
          _base.year,
          _base.month,
          _base.day + threeDayColumns * n,
        );
      case CalendarViewMode.week:
        return DateTime(_base.year, _base.month, _base.day + 7 * n);
      case CalendarViewMode.month:
        return DateTime(_base.year, _base.month + n, 1);
    }
  }

  /// The page [date] belongs to, or null when no page starts on it. Inverse
  /// of [periodStartForPage].
  ///
  /// Only the three day view can answer null: its blocks are counted from
  /// [_base], so a day in the middle of a block would not be the left column
  /// the view promises. The caller rebases on it instead.
  int? _pageFor(DateTime date) {
    final start = _periodStart(date);
    switch (_mode) {
      case CalendarViewMode.day:
      case CalendarViewMode.agenda:
        return center + _wholeDaysBetween(_base, start);
      case CalendarViewMode.threeDay:
        final days = _wholeDaysBetween(_base, start);
        if (days % threeDayColumns != 0) return null;
        return center + days ~/ threeDayColumns;
      case CalendarViewMode.week:
        return center + _wholeDaysBetween(_base, start) ~/ 7;
      case CalendarViewMode.month:
        return center +
            (start.year - _base.year) * 12 +
            (start.month - _base.month);
    }
  }

  /// Days from [from] to [to], both midnight. Rounded, because a DST day is
  /// 23 or 25 hours long and `inDays` would truncate it to the wrong day.
  static int _wholeDaysBetween(DateTime from, DateTime to) =>
      (to.difference(from).inHours / 24).round();

  /// The date a landed page writes back.
  ///
  /// A week keeps the weekday the user was on, so switching to the day view
  /// afterwards opens the day they were looking at rather than a Monday. A
  /// month reports its first, which is all the month grid reads.
  DateTime _reportedDateForPage(int index) {
    final start = periodStartForPage(index);
    if (_mode != CalendarViewMode.week) return start;
    final offset = _wholeDaysBetween(
      startOfWeek(_focusedDate, _weekStart),
      dayStart(_focusedDate),
    ).clamp(0, 6);
    return DateTime(start.year, start.month, start.day + offset);
  }

  /// Throws the mapping away and centres it on [date].
  void _rebase(DateTime date) {
    final old = _controller;
    _base = _periodStart(date);
    _currentPage = center;
    _programmaticTarget = null;
    _controller = PageController(initialPage: center);
    onRebuild();
    // The old controller is still attached until the scrollable rebuilds with
    // the new one, and detaching from a disposed controller throws — so it
    // dies one frame later.
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _moveTo(int target) {
    if (!_controller.hasClients) {
      // No position yet (the first build has not laid out): rebuild the
      // mapping so the initial page is the right one.
      _rebase(_focusedDate);
      return;
    }

    _programmaticTarget = target;

    // One period away is a step the user can follow, so it animates. Anything
    // further — Today from another year, a month picked in the strip — jumps:
    // flying through 300 pages is motion sickness, not feedback.
    if ((target - _currentPage).abs() == 1) {
      _controller
          .animateToPage(
            target,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() {
            // An interrupted animation never reaches the target, and a stuck
            // guard would swallow every later swipe.
            if (!_disposed && _programmaticTarget == target) {
              _programmaticTarget = null;
            }
          });
      return;
    }

    _controller.jumpToPage(target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _programmaticTarget != target) return;
      _currentPage = target;
      _programmaticTarget = null;
    });
  }

  /// Hand every `onPageChanged` of the paged scrollable to this.
  void handlePageChanged(int index) {
    if (index == _currentPage) return;
    _currentPage = index;

    if (_programmaticTarget != null) {
      if (index == _programmaticTarget) _programmaticTarget = null;
      return;
    }

    onReportDate(_reportedDateForPage(index));
  }
}

/// Horizontal pager over calendar periods that moves the *whole* view.
///
/// Used by the month grid, where there is no frame to hold still: the month
/// page is one block and dragging it in under the finger is the motion the
/// user expects. The day, three day and week views page only their columns —
/// see the time grid, which drives [PeriodPageDriver] itself.
class PeriodPager extends StatefulWidget {
  /// Period length of one page. Agenda has no period and never gets here.
  final CalendarViewMode mode;

  /// First column of a week — a week page starts on the user's first day.
  final WeekStart weekStart;

  /// The date the calendar is showing, owned by the notifier.
  final DateTime focusedDate;

  /// Called when the user lands on another page. Never called for a move this
  /// widget started itself.
  final ValueChanged<DateTime> onFocusedDateChanged;

  /// Builds one page for the first day of its period (the day itself, the
  /// week's first day, or the first of the month).
  final Widget Function(BuildContext context, DateTime periodStart) pageBuilder;

  /// Set to [NeverScrollableScrollPhysics] to freeze the pager.
  final ScrollPhysics? physics;

  const PeriodPager({
    super.key,
    required this.mode,
    required this.weekStart,
    required this.focusedDate,
    required this.onFocusedDateChanged,
    required this.pageBuilder,
    this.physics,
  });

  @override
  State<PeriodPager> createState() => _PeriodPagerState();
}

class _PeriodPagerState extends State<PeriodPager> {
  late final PeriodPageDriver _driver;

  @override
  void initState() {
    super.initState();
    _driver = PeriodPageDriver(
      mode: widget.mode,
      weekStart: widget.weekStart,
      focusedDate: widget.focusedDate,
      onReportDate: (date) => widget.onFocusedDateChanged(date),
      onRebuild: () => setState(() {}),
    );
  }

  @override
  void didUpdateWidget(PeriodPager oldWidget) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      key: _driver.pageViewKey,
      controller: _driver.controller,
      physics: widget.physics,
      itemCount: PeriodPageDriver.pageCount,
      onPageChanged: _driver.handlePageChanged,
      itemBuilder: (context, index) =>
          widget.pageBuilder(context, _driver.periodStartForPage(index)),
    );
  }
}
