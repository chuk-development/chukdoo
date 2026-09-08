import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chukdoo/features/calendar/presentation/widgets/month_grid.dart';
import 'package:chukdoo/features/settings/providers/settings_provider.dart';

/// The month grid has to tell two gestures apart that look the same to a
/// screenshot: two fingers scale the week row, one finger still scrolls and
/// pages. And what the fingers settled on has to survive coming back through
/// the settings.
void main() {
  final month = DateTime(2026, 9, 1);

  /// Pumps the grid at [rowHeight] (null = fit the six rows to the screen) and
  /// returns the list every settled row height is reported into. Pumping again
  /// with another height is what the settings landing looks like to the grid.
  Future<List<double>> pumpGrid(
    WidgetTester tester, {
    double? rowHeight,
    List<double>? settled,
  }) async {
    final reported = settled ?? <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthGrid(
            weekStart: WeekStart.monday,
            focusedDate: month,
            onFocusedDateChanged: (_) {},
            itemsForDay: (_) => const [],
            rowHeight: rowHeight,
            onRowHeightChanged: reported.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return reported;
  }

  /// Height of one week row as it is drawn right now.
  double drawnRowHeight(WidgetTester tester) =>
      tester.getSize(find.byKey(MonthGrid.rowsKey)).height / MonthGrid.weekRows;

  /// Spreads two fingers apart around the same point, so the span doubles and
  /// the row height with it. [whileHeld] runs with both fingers still down.
  Future<void> pinchOpen(
    WidgetTester tester, {
    Future<void> Function()? whileHeld,
  }) async {
    final centre = tester.getCenter(find.byType(MonthGrid));
    final top = await tester.startGesture(centre - const Offset(0, 50));
    final bottom = await tester.startGesture(centre + const Offset(0, 50));
    await tester.pump();

    for (var step = 0; step < 4; step++) {
      await top.moveBy(const Offset(0, -12.5));
      await bottom.moveBy(const Offset(0, 12.5));
      await tester.pump();
    }

    if (whileHeld != null) await whileHeld();

    await top.up();
    await bottom.up();
    await tester.pumpAndSettle();
  }

  /// The physics of the month pager right now.
  ScrollPhysics? pagerPhysics(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).physics;

  /// The physics of the vertical scroll view the rows live in.
  ScrollPhysics? scrollPhysics(WidgetTester tester) => tester
      .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
      .physics;

  testWidgets('two fingers change the week row height', (tester) async {
    final settled = await pumpGrid(tester, rowHeight: 90);

    await pinchOpen(tester);

    // The span went from 100 to 200, so the 90 px row doubles to 180.
    expect(settled, hasLength(1));
    expect(settled.single, closeTo(180, 1));
  });

  testWidgets('a one-finger drag is a scroll, not a zoom', (tester) async {
    // Taller than the viewport, so there is something to scroll and the drag
    // is a real gesture rather than an overscroll.
    final settled = await pumpGrid(tester, rowHeight: 160);

    await tester.drag(find.byType(MonthGrid), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(settled, isEmpty);
    expect(drawnRowHeight(tester), 160);
  });

  testWidgets('a one-finger drag still scrolls the grid', (tester) async {
    await pumpGrid(tester, rowHeight: 160);

    final scroll = tester.widget<Scrollable>(
      find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final before = scroll.controller!.offset;

    await tester.drag(find.byType(MonthGrid), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(scroll.controller!.offset, greaterThan(before));
  });

  testWidgets(
    'the pager and the scroll are frozen while two fingers are down',
    (tester) async {
      await pumpGrid(tester, rowHeight: 90);

      expect(pagerPhysics(tester), isNull);
      expect(scrollPhysics(tester), isNull);

      await pinchOpen(
        tester,
        whileHeld: () async {
          // A pinch must not be able to drift into the next month, and the
          // scroll must not fight the zoom anchor.
          expect(pagerPhysics(tester), isA<NeverScrollableScrollPhysics>());
          expect(scrollPhysics(tester), isA<NeverScrollableScrollPhysics>());
        },
      );

      // And both work again the moment the fingers are gone.
      expect(pagerPhysics(tester), isNull);
      expect(scrollPhysics(tester), isNull);
    },
  );

  testWidgets('the pinched height survives the rebuild it comes back in', (
    tester,
  ) async {
    final settled = await pumpGrid(tester, rowHeight: 90);

    await pinchOpen(tester);
    expect(drawnRowHeight(tester), closeTo(180, 1));

    // What the settings box does: the reported height comes back in as the
    // grid's own value. The rows must keep it instead of snapping back to 90.
    await pumpGrid(tester, rowHeight: settled.single, settled: settled);
    expect(drawnRowHeight(tester), closeTo(180, 1));

    // A plain rebuild with nothing changed keeps it too.
    await pumpGrid(tester, rowHeight: settled.single, settled: settled);
    expect(drawnRowHeight(tester), closeTo(180, 1));
    expect(settled, hasLength(1));
  });

  testWidgets('without a stored height the six rows fit the screen', (
    tester,
  ) async {
    await pumpGrid(tester);

    // Six rows, no scrolling: the block is exactly the room under the weekday
    // header.
    final room =
        tester.getSize(find.byType(MonthGrid)).height -
        tester.getSize(find.byKey(MonthGrid.rowsKey)).height;
    expect(room, greaterThan(0));
    expect(drawnRowHeight(tester) * MonthGrid.weekRows, closeTo(600 - room, 1));

    // And a pinch starts from that fitted height rather than from a default.
    final settled = <double>[];
    final fitted = drawnRowHeight(tester);
    await pumpGrid(tester, settled: settled);
    await pinchOpen(tester);
    expect(settled.single, closeTo(fitted * 2, 1));
  });

  testWidgets('the zoom stops at the ends of its range', (tester) async {
    // Already at the top of the range, so doubling it has nowhere to go.
    final settled = await pumpGrid(
      tester,
      rowHeight: AppSettings.calendarMonthRowHeightMax,
    );

    await pinchOpen(tester);

    expect(settled, hasLength(1));
    expect(settled.single, AppSettings.calendarMonthRowHeightMax);
  });
}
