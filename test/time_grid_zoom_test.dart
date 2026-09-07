import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chukdoo/features/calendar/presentation/widgets/time_grid.dart';
import 'package:chukdoo/features/settings/providers/settings_provider.dart';

/// The pinch has to tell two gestures apart that look the same to a
/// screenshot: two fingers zoom the grid, one finger still scrolls and pages.
void main() {
  final day = DateTime(2026, 9, 8);

  Future<List<double>> pumpGrid(
    WidgetTester tester, {
    double hourHeight = AppSettings.calendarHourHeightDefault,
    List<bool>? zooming,
  }) async {
    final settled = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimeGrid(
            columnCount: 1,
            columnHeaders: const ['Tue'],
            columnDates: [day],
            itemsByColumn: const [[]],
            startHour: 0,
            endHour: 24,
            hourHeight: hourHeight,
            onHourHeightChanged: settled.add,
            onZoomingChanged: zooming?.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return settled;
  }

  /// Spreads two fingers apart around the same point, so the span doubles and
  /// the hour height with it.
  Future<void> pinchOpen(WidgetTester tester) async {
    final centre = tester.getCenter(find.byType(TimeGrid));
    final top = await tester.startGesture(centre - const Offset(0, 50));
    final bottom = await tester.startGesture(centre + const Offset(0, 50));
    await tester.pump();

    for (var step = 0; step < 4; step++) {
      await top.moveBy(const Offset(0, -12.5));
      await bottom.moveBy(const Offset(0, 12.5));
      await tester.pump();
    }

    await top.up();
    await bottom.up();
    await tester.pumpAndSettle();
  }

  testWidgets('two fingers change the hour height', (tester) async {
    final zooming = <bool>[];
    final settled = await pumpGrid(tester, zooming: zooming);

    await pinchOpen(tester);

    // The span went from 100 to 200, so the 60 px hour doubles to 120.
    expect(settled, hasLength(1));
    expect(settled.single, closeTo(120, 1));
    // The page above has to know, so it can hold the pager still.
    expect(zooming, [true, false]);
  });

  testWidgets('a one-finger drag is a scroll, not a zoom', (tester) async {
    final zooming = <bool>[];
    final settled = await pumpGrid(tester, zooming: zooming);

    await tester.drag(find.byType(TimeGrid), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(settled, isEmpty);
    expect(zooming, isEmpty);
  });

  testWidgets('a one-finger drag still scrolls the grid', (tester) async {
    await pumpGrid(tester);

    final scrollable = find.byType(Scrollable);
    final before = tester.widget<Scrollable>(scrollable).controller!.offset;

    await tester.drag(find.byType(TimeGrid), const Offset(0, -120));
    await tester.pumpAndSettle();

    final after = tester.widget<Scrollable>(scrollable).controller!.offset;
    expect(after, greaterThan(before));
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
