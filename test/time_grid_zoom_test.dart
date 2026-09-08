import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chukdoo/features/calendar/presentation/widgets/time_grid.dart';
import 'package:chukdoo/features/calendar/providers/calendar_event_provider.dart';
import 'package:chukdoo/features/settings/providers/settings_provider.dart';

/// The pinch has to tell two gestures apart that look the same to a
/// screenshot: two fingers zoom the grid, one finger still scrolls and pages.
void main() {
  final day = DateTime(2026, 9, 8);

  Future<List<double>> pumpGrid(
    WidgetTester tester, {
    double hourHeight = AppSettings.calendarHourHeightDefault,
  }) async {
    final settled = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimeGrid(
            mode: CalendarViewMode.day,
            weekStart: WeekStart.monday,
            focusedDate: day,
            onFocusedDateChanged: (_) {},
            itemsForDay: (_) => const [],
            startHour: 0,
            endHour: 24,
            hourHeight: hourHeight,
            onHourHeightChanged: settled.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return settled;
  }

  /// Spreads two fingers apart around the same point, so the span doubles and
  /// the hour height with it. [whileHeld] runs with both fingers still down.
  Future<void> pinchOpen(
    WidgetTester tester, {
    Future<void> Function()? whileHeld,
  }) async {
    final centre = tester.getCenter(find.byType(TimeGrid));
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

  /// The physics of the paged column area right now.
  ScrollPhysics? pagerPhysics(WidgetTester tester) =>
      tester.widget<PageView>(find.byType(PageView)).physics;

  /// The scroll view the gutter and every page share.
  ///
  /// `.first` is the vertical one: the horizontal pager is a scrollable inside
  /// it, and the tree is walked from the outside in.
  ScrollController gridScroll(WidgetTester tester) => tester
      .widget<Scrollable>(
        find
            .descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .controller!;

  testWidgets('two fingers change the hour height', (tester) async {
    final settled = await pumpGrid(tester);

    await pinchOpen(tester);

    // The span went from 100 to 200, so the 60 px hour doubles to 120.
    expect(settled, hasLength(1));
    expect(settled.single, closeTo(120, 1));
  });

  testWidgets('the pager is frozen while two fingers are down', (tester) async {
    await pumpGrid(tester);

    expect(pagerPhysics(tester), isNull);

    await pinchOpen(
      tester,
      whileHeld: () async {
        // A pinch must not be able to drift into the next period.
        expect(pagerPhysics(tester), isA<NeverScrollableScrollPhysics>());
      },
    );

    // And the columns can be swiped again the moment the fingers are gone.
    expect(pagerPhysics(tester), isNull);
  });

  testWidgets('a one-finger drag is a scroll, not a zoom', (tester) async {
    final settled = await pumpGrid(tester);

    await tester.drag(find.byType(TimeGrid), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(settled, isEmpty);
  });

  testWidgets('a one-finger drag still scrolls the grid', (tester) async {
    await pumpGrid(tester);

    final before = gridScroll(tester).offset;

    await tester.drag(find.byType(TimeGrid), const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(gridScroll(tester).offset, greaterThan(before));
  });

  testWidgets('the hour gutter scrolls with the columns', (tester) async {
    await pumpGrid(tester);

    // One body for both, so a label moves by exactly what the shared scroll
    // view moved — two scroll views could drift apart.
    final labelBefore = tester.getTopLeft(find.text('09:00')).dy;
    final offsetBefore = gridScroll(tester).offset;

    await tester.drag(find.byType(TimeGrid), const Offset(0, -120));
    await tester.pumpAndSettle();

    final scrolled = gridScroll(tester).offset - offsetBefore;
    expect(scrolled, greaterThan(0));
    expect(
      tester.getTopLeft(find.text('09:00')).dy,
      closeTo(labelBefore - scrolled, 1),
    );
  });

  testWidgets('the zoom stops at the ends of its range', (tester) async {
    // Already at the top of the range, so doubling it has nowhere to go.
    final settled = await pumpGrid(
      tester,
      hourHeight: AppSettings.calendarHourHeightMax,
    );

    await pinchOpen(tester);

    expect(settled, hasLength(1));
    expect(settled.single, AppSettings.calendarHourHeightMax);
  });
}
