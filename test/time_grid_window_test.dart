import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chukdoo/features/calendar/domain/day_window.dart';
import 'package:chukdoo/features/calendar/domain/models/calendar_event.dart';
import 'package:chukdoo/features/calendar/domain/models/calendar_item.dart';
import 'package:chukdoo/features/calendar/presentation/widgets/event_block.dart';
import 'package:chukdoo/features/calendar/presentation/widgets/time_grid.dart';
import 'package:chukdoo/features/settings/providers/settings_provider.dart';

/// Two things a screenshot of the grid cannot prove: that an item outside the
/// user's day window is still drawn, and that a block too short to read grows
/// without taking the room of the block under it.
void main() {
  final day = DateTime(2026, 9, 8);
  const hourHeight = AppSettings.calendarHourHeightDefault; // 60 px = 1 min/px

  CalendarItem event(String title, int fromHour, int fromMinute, int minutes) {
    final start = DateTime(day.year, day.month, day.day, fromHour, fromMinute);
    return EventItem(
      event: CalendarEvent(
        id: title,
        userId: 'test',
        title: title,
        startTime: start,
        endTime: start.add(Duration(minutes: minutes)),
        createdAt: start,
        updatedAt: start,
      ),
    );
  }

  Future<void> pumpGrid(
    WidgetTester tester,
    List<CalendarItem> items, {
    int startHour = 8,
    int endHour = 22,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TimeGrid(
              columnCount: 1,
              columnHeaders: const ['Tue'],
              columnDates: [day],
              itemsByColumn: [items],
              startHour: startHour,
              endHour: endHour,
              hourHeight: hourHeight,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The height the grid handed one block.
  double heightOf(WidgetTester tester, String title) => tester
      .widgetList<EventBlock>(find.byType(EventBlock))
      .firstWhere((b) => b.item.title == title)
      .height;

  group('the drawn window', () {
    test('grows over an item before the settings window', () {
      final window = DayWindow.covering(
        startHour: 8,
        endHour: 22,
        columnDates: [day],
        // 06:03 rounds out to the whole 06:00 row.
        itemsByColumn: [
          [event('Early', 6, 3, 20)],
        ],
      );

      expect(window.startHour, 6);
      expect(window.endHour, 22);
    });

    test('grows over an item after the settings window, to the full hour', () {
      final window = DayWindow.covering(
        startHour: 8,
        endHour: 22,
        columnDates: [day],
        itemsByColumn: [
          [event('Late', 22, 40, 35)],
        ],
      );

      expect(window.startHour, 8);
      // 23:15 needs the 23:00 row, and nothing past midnight.
      expect(window.endHour, 24);
    });

    test('stays the settings window when everything fits', () {
      final window = DayWindow.covering(
        startHour: 8,
        endHour: 22,
        columnDates: [day],
        itemsByColumn: [
          [event('Standup', 9, 30, 15)],
        ],
      );

      expect(window.startHour, 8);
      expect(window.endHour, 22);
    });

    testWidgets('draws an item at 06:00 although the window starts at 08:00', (
      tester,
    ) async {
      await pumpGrid(tester, [event('Early', 6, 0, 30)]);

      // Drawn at all — this is the bug the owner hit: the item existed and the
      // day looked empty.
      expect(find.byType(EventBlock), findsOneWidget);
      // And at the top of the widened grid, not clipped to hour 8.
      final top = tester.getTopLeft(find.byType(EventBlock)).dy;
      final gridTop = tester.getTopLeft(find.byType(SingleChildScrollView)).dy;
      expect(top - gridTop, closeTo(TimeGrid.topPadding, 1));
      expect(heightOf(tester, 'Early'), closeTo(30, 0.5));
    });
  });

  group('short blocks', () {
    testWidgets('a 4 minute event keeps a readable height', (tester) async {
      await pumpGrid(tester, [event('Call', 9, 3, 4)]);

      expect(heightOf(tester, 'Call'), TimeGrid.minBlockHeight);
    });

    testWidgets('a minute-precise event is drawn at its real position', (
      tester,
    ) async {
      await pumpGrid(tester, [
        event('Anchor', 9, 0, 60),
        event('Odd', 10, 3, 8),
      ]);

      // One pixel per minute at the default hour height: 63 minutes into the
      // 09:00 window start, never snapped to 10:00 or 10:15.
      final anchor = tester.getTopLeft(find.byType(EventBlock).first).dy;
      final odd = tester.getTopLeft(find.byType(EventBlock).last).dy;
      expect(odd - anchor, closeTo(63, 0.5));
    });

    testWidgets('a short block never covers the next one', (tester) async {
      await pumpGrid(tester, [
        // Ten minutes apart: the first may not grow to the full minimum.
        event('First', 9, 0, 4),
        event('Second', 9, 10, 60),
      ]);

      expect(heightOf(tester, 'First'), lessThan(TimeGrid.minBlockHeight));
      // Its own four minutes at least, and stopping short of the block below.
      expect(heightOf(tester, 'First'), greaterThanOrEqualTo(4));
      expect(heightOf(tester, 'First'), lessThanOrEqualTo(10));
      // The neighbour keeps its own full hour.
      expect(heightOf(tester, 'Second'), closeTo(60, 0.5));
    });
  });
}
