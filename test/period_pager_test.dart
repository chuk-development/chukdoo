import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chukdoo/features/calendar/domain/week_dates.dart';
import 'package:chukdoo/features/calendar/presentation/widgets/period_pager.dart';
import 'package:chukdoo/features/calendar/providers/calendar_event_provider.dart';
import 'package:chukdoo/features/settings/providers/settings_provider.dart';

/// The two halves of the pager a screenshot cannot show: that a swipe moves
/// the calendar by exactly one period and reports it once, and that a date set
/// from outside moves the pager without being written straight back.
void main() {
  final harnessKey = GlobalKey<_PagerHarnessState>();

  Future<List<DateTime>> pumpPager(
    WidgetTester tester, {
    required CalendarViewMode mode,
    required DateTime focused,
  }) async {
    final reported = <DateTime>[];
    await tester.pumpWidget(
      _PagerHarness(
        key: harnessKey,
        mode: mode,
        initial: focused,
        reported: reported,
      ),
    );
    await tester.pumpAndSettle();
    return reported;
  }

  /// Swipe right to left — the next period comes in from the right.
  Future<void> swipeToNext(WidgetTester tester) async {
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1200);
    await tester.pumpAndSettle();
  }

  testWidgets('a swipe moves the day view by exactly one day, once', (
    tester,
  ) async {
    final reported = await pumpPager(
      tester,
      mode: CalendarViewMode.day,
      focused: DateTime(2026, 9, 8),
    );

    await swipeToNext(tester);

    // Once, not twice: the reported date comes back as the focused date and
    // must not make the pager move again.
    expect(reported, [DateTime(2026, 9, 9)]);
    expect(find.text('2026-09-09'), findsOneWidget);
  });

  testWidgets('a swipe moves the week view by exactly seven days', (
    tester,
  ) async {
    final reported = await pumpPager(
      tester,
      mode: CalendarViewMode.week,
      // A Thursday: the weekday must survive the swipe, so the day view opens
      // on the day the user was looking at.
      focused: DateTime(2026, 9, 10),
    );

    await swipeToNext(tester);

    expect(reported, [DateTime(2026, 9, 17)]);
    // The page itself is the week, so it is labelled with its Monday.
    expect(find.text('2026-09-14'), findsOneWidget);
  });

  testWidgets('a three day page starts on the focused day and holds the two '
      'days after it', (tester) async {
    final reported = await pumpPager(
      tester,
      mode: CalendarViewMode.threeDay,
      focused: DateTime(2026, 9, 8),
    );

    // The focused day is the LEFT column, not the middle one.
    expect(find.text('2026-09-08'), findsOneWidget);
    expect(find.text('cols 2026-09-08 2026-09-09 2026-09-10'), findsOneWidget);
    expect(reported, isEmpty);
  });

  testWidgets('a swipe moves the three day view by exactly three days', (
    tester,
  ) async {
    final reported = await pumpPager(
      tester,
      mode: CalendarViewMode.threeDay,
      focused: DateTime(2026, 9, 8),
    );

    await swipeToNext(tester);

    expect(reported, [DateTime(2026, 9, 11)]);
    expect(find.text('cols 2026-09-11 2026-09-12 2026-09-13'), findsOneWidget);
  });

  testWidgets('a three day pager rebuilds around a day inside a page', (
    tester,
  ) async {
    final reported = await pumpPager(
      tester,
      mode: CalendarViewMode.threeDay,
      focused: DateTime(2026, 9, 8),
    );

    // The middle day of the page on screen: no page starts on it, so the
    // mapping has to be rebuilt around it — otherwise it would not be the
    // left column the view promises.
    harnessKey.currentState!.setFocusedFromOutside(DateTime(2026, 9, 9));
    await tester.pumpAndSettle();

    expect(find.text('cols 2026-09-09 2026-09-10 2026-09-11'), findsOneWidget);
    expect(reported, isEmpty);

    // And it still pages by three days from there.
    await swipeToNext(tester);
    expect(reported, [DateTime(2026, 9, 12)]);
  });

  testWidgets('a swipe moves the month view by exactly one month', (
    tester,
  ) async {
    final reported = await pumpPager(
      tester,
      mode: CalendarViewMode.month,
      focused: DateTime(2026, 12, 20),
    );

    await swipeToNext(tester);

    expect(reported, [DateTime(2027, 1, 1)]);
    expect(find.text('2027-01-01'), findsOneWidget);
  });

  testWidgets('swiping back and forth lands where it started', (tester) async {
    final reported = await pumpPager(
      tester,
      mode: CalendarViewMode.day,
      focused: DateTime(2026, 9, 8),
    );

    await swipeToNext(tester);
    await tester.fling(find.byType(PageView), const Offset(400, 0), 1200);
    await tester.pumpAndSettle();

    expect(reported, [DateTime(2026, 9, 9), DateTime(2026, 9, 8)]);
    expect(find.text('2026-09-08'), findsOneWidget);
  });

  testWidgets('a focused date set from outside moves the pager and is not '
      'written back', (tester) async {
    final reported = await pumpPager(
      tester,
      mode: CalendarViewMode.day,
      focused: DateTime(2026, 9, 8),
    );

    // One period away — this animates.
    harnessKey.currentState!.setFocusedFromOutside(DateTime(2026, 9, 9));
    await tester.pumpAndSettle();

    expect(find.text('2026-09-09'), findsOneWidget);
    expect(reported, isEmpty);

    // Far away — this jumps. Same rule.
    harnessKey.currentState!.setFocusedFromOutside(DateTime(2027, 3, 2));
    await tester.pumpAndSettle();

    expect(find.text('2027-03-02'), findsOneWidget);
    expect(reported, isEmpty);
  });

  testWidgets('switching the view mode rebuilds the pager on the focused '
      'period', (tester) async {
    final reported = await pumpPager(
      tester,
      mode: CalendarViewMode.day,
      focused: DateTime(2026, 9, 10),
    );

    harnessKey.currentState!.setMode(CalendarViewMode.week);
    await tester.pumpAndSettle();

    // The week holding the focused Thursday, not a week counted from the old
    // day mapping.
    expect(find.text('2026-09-07'), findsOneWidget);
    expect(reported, isEmpty);

    // And it still pages by a week from there.
    await swipeToNext(tester);
    expect(reported, [DateTime(2026, 9, 17)]);
  });
}

/// Stands in for the calendar page: it owns the focused date, writes back what
/// the pager reports, and can also set the date from outside the way the Today
/// action and the month strip do.
class _PagerHarness extends StatefulWidget {
  final CalendarViewMode mode;
  final DateTime initial;
  final List<DateTime> reported;

  const _PagerHarness({
    super.key,
    required this.mode,
    required this.initial,
    required this.reported,
  });

  @override
  State<_PagerHarness> createState() => _PagerHarnessState();
}

class _PagerHarnessState extends State<_PagerHarness> {
  late DateTime _focused = widget.initial;
  late CalendarViewMode _mode = widget.mode;

  void setFocusedFromOutside(DateTime date) => setState(() => _focused = date);

  void setMode(CalendarViewMode mode) => setState(() => _mode = mode);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: PeriodPager(
          mode: _mode,
          weekStart: WeekStart.monday,
          focusedDate: _focused,
          onFocusedDateChanged: (date) {
            widget.reported.add(date);
            setState(() => _focused = date);
          },
          pageBuilder: (context, periodStart) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_stamp(periodStart)),
                // The columns the three day view builds from the page start.
                if (_mode == CalendarViewMode.threeDay)
                  Text(
                    'cols '
                    '${daysFrom(periodStart, threeDayColumns).map(_stamp).join(' ')}',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _stamp(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}'
    '-${date.day.toString().padLeft(2, '0')}';
