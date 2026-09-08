import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chukdoo/features/calendar/domain/models/calendar_event.dart';
import 'package:chukdoo/features/calendar/domain/models/calendar_item.dart';
import 'package:chukdoo/features/calendar/presentation/widgets/time_grid.dart';
import 'package:chukdoo/features/calendar/providers/calendar_event_provider.dart';
import 'package:chukdoo/features/settings/providers/settings_provider.dart';

/// What the owner asked for and a screenshot cannot show: a horizontal swipe
/// over the columns moves the period, and the frame around them does not move
/// with it.
void main() {
  final harnessKey = GlobalKey<_GridHarnessState>();

  /// An all-day event on [day], for the strip above the grid.
  CalendarItem allDay(String title, DateTime day) => EventItem(
    event: CalendarEvent(
      id: title,
      userId: 'test',
      title: title,
      startTime: day,
      endTime: day.add(const Duration(days: 1)),
      isAllDay: true,
      createdAt: day,
      updatedAt: day,
    ),
  );

  Future<List<DateTime>> pumpGrid(
    WidgetTester tester, {
    required CalendarViewMode mode,
    required DateTime focused,
    List<CalendarItem> Function(DateTime day)? itemsForDay,
  }) async {
    final reported = <DateTime>[];
    await tester.pumpWidget(
      _GridHarness(
        key: harnessKey,
        mode: mode,
        initial: focused,
        reported: reported,
        itemsForDay: itemsForDay,
      ),
    );
    await tester.pumpAndSettle();
    return reported;
  }

  /// Left edge of the hour scale — the frame that has to stay put.
  double gutterX(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(TimeGrid.gutterKey)).dx;

  /// Left edge of one hour label, which sits inside the gutter.
  double hourLabelX(WidgetTester tester) =>
      tester.getTopLeft(find.text('09:00')).dx;

  /// Left edge of the day number in the sliding date header.
  double dateX(WidgetTester tester, String day) =>
      tester.getTopLeft(find.text(day)).dx;

  /// A point on the day columns. Not the centre of the `PageView`: it is as
  /// tall as the whole day, so most of it is scrolled off the screen.
  Offset onColumns(WidgetTester tester) =>
      tester.getRect(find.byType(TimeGrid)).center;

  /// A point on the hour scale, at the same height.
  Offset onGutter(WidgetTester tester) {
    final grid = tester.getRect(find.byType(TimeGrid));
    return Offset(grid.left + 20, grid.center.dy);
  }

  testWidgets('a drag over the columns moves the day by one, and the hour '
      'gutter does not move with it', (tester) async {
    final reported = await pumpGrid(
      tester,
      mode: CalendarViewMode.day,
      focused: DateTime(2026, 9, 8),
    );

    final gutterBefore = gutterX(tester);
    final labelBefore = hourLabelX(tester);

    // Past the touch slop first, so what follows is one pixel of drag per
    // pixel of finger.
    final drag = await tester.startGesture(onColumns(tester));
    await drag.moveBy(const Offset(-kDragSlopDefault, 0));
    await tester.pump();
    final dateBefore = dateX(tester, '8');

    // Half way through the drag, with the finger still down.
    await drag.moveBy(const Offset(-100, 0));
    await tester.pump();

    // The frame stays where it is …
    expect(gutterX(tester), gutterBefore);
    expect(hourLabelX(tester), labelBefore);
    // … and the date travels with the columns, by the same 100 pixels.
    expect(dateX(tester, '8'), closeTo(dateBefore - 100, 0.5));
    // The next day is already coming in behind the finger.
    expect(find.text('9'), findsOneWidget);

    // Past the halfway mark of the page, so releasing lands on the next day
    // instead of snapping back.
    await drag.moveBy(const Offset(-400, 0));
    await drag.up();
    await tester.pumpAndSettle();

    // One period, reported once.
    expect(reported, [DateTime(2026, 9, 9)]);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('8'), findsNothing);
    expect(gutterX(tester), gutterBefore);
    expect(hourLabelX(tester), labelBefore);
  });

  testWidgets('a drag over the columns moves the week by seven days', (
    tester,
  ) async {
    final reported = await pumpGrid(
      tester,
      mode: CalendarViewMode.week,
      // A Thursday: the weekday survives the swipe, so opening the day view
      // afterwards lands on the day the user was looking at.
      focused: DateTime(2026, 9, 10),
    );

    final gutterBefore = gutterX(tester);

    await tester.flingFrom(onColumns(tester), const Offset(-400, 0), 1200);
    await tester.pumpAndSettle();

    expect(reported, [DateTime(2026, 9, 17)]);
    // The week of the 14th is on screen, Monday first.
    expect(find.text('14'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(gutterX(tester), gutterBefore);
  });

  testWidgets('a drag on the hour gutter pages nothing', (tester) async {
    final reported = await pumpGrid(
      tester,
      mode: CalendarViewMode.day,
      focused: DateTime(2026, 9, 8),
    );

    await tester.flingFrom(onGutter(tester), const Offset(-400, 0), 1200);
    await tester.pumpAndSettle();

    // The gutter is outside the pager, so it has no drag to give it.
    expect(reported, isEmpty);
    expect(find.text('8'), findsOneWidget);
  });

  testWidgets('the all-day label stays while its chips slide', (tester) async {
    final marked = DateTime(2026, 9, 9);
    await pumpGrid(
      tester,
      mode: CalendarViewMode.day,
      focused: DateTime(2026, 9, 8),
      // Only the day after the focused one is marked, so the chip has to come
      // in from the right while the label stays put.
      itemsForDay: (d) => d == marked ? [allDay('Holiday', marked)] : const [],
    );

    // The strip is reserved for the deepest of the pages that can be shown,
    // so the label is already there before the chip is.
    final labelBefore = tester.getTopLeft(find.text('All day')).dx;
    expect(find.text('Holiday'), findsNothing);

    final drag = await tester.startGesture(onColumns(tester));
    await drag.moveBy(const Offset(-kDragSlopDefault, 0));
    await tester.pump();
    await drag.moveBy(const Offset(-200, 0));
    await tester.pump();

    expect(tester.getTopLeft(find.text('All day')).dx, labelBefore);
    expect(find.text('Holiday'), findsOneWidget);

    await drag.moveBy(const Offset(-400, 0));
    await drag.up();
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('All day')).dx, labelBefore);
    expect(find.text('Holiday'), findsOneWidget);
  });

  testWidgets('a focused date set from outside moves the columns and is not '
      'written back', (tester) async {
    final reported = await pumpGrid(
      tester,
      mode: CalendarViewMode.day,
      focused: DateTime(2026, 9, 8),
    );

    // What Today and the month strip do.
    harnessKey.currentState!.setFocusedFromOutside(DateTime(2026, 9, 9));
    await tester.pumpAndSettle();

    expect(find.text('9'), findsOneWidget);
    expect(reported, isEmpty);
  });
}

/// Stands in for the calendar page: it owns the focused date and writes back
/// what the grid reports.
class _GridHarness extends StatefulWidget {
  final CalendarViewMode mode;
  final DateTime initial;
  final List<DateTime> reported;
  final List<CalendarItem> Function(DateTime day)? itemsForDay;

  const _GridHarness({
    super.key,
    required this.mode,
    required this.initial,
    required this.reported,
    this.itemsForDay,
  });

  @override
  State<_GridHarness> createState() => _GridHarnessState();
}

class _GridHarnessState extends State<_GridHarness> {
  late DateTime _focused = widget.initial;

  void setFocusedFromOutside(DateTime date) => setState(() => _focused = date);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: TimeGrid(
          mode: widget.mode,
          weekStart: WeekStart.monday,
          focusedDate: _focused,
          onFocusedDateChanged: (date) {
            widget.reported.add(date);
            setState(() => _focused = date);
          },
          itemsForDay: widget.itemsForDay ?? (_) => const [],
          startHour: 8,
          endHour: 20,
        ),
      ),
    );
  }
}
