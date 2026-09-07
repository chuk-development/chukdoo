import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chukdoo/features/calendar/presentation/widgets/month_strip.dart';

/// The strip looked right but did not react to taps, so this asserts the one
/// thing a picture cannot show: that a pill actually reports a month.
void main() {
  Future<void> pumpStrip(
    WidgetTester tester, {
    required DateTime focused,
    required ValueChanged<DateTime> onPick,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [MonthStrip(focused: focused, onPick: onPick)],
          ),
        ),
      ),
    );
  }

  testWidgets('tapping a month reports it', (tester) async {
    DateTime? picked;
    await pumpStrip(
      tester,
      focused: DateTime(2026, 9, 1),
      onPick: (m) => picked = m,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Oct'));
    await tester.pump();

    expect(picked, DateTime(2026, 10, 1));
  });

  testWidgets('the year is a marker, not a button', (tester) async {
    var picks = 0;
    await pumpStrip(
      tester,
      focused: DateTime(2026, 1, 1),
      onPick: (_) => picks++,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('2026'), warnIfMissed: false);
    await tester.pump();

    expect(picks, 0);
  });

  testWidgets('a shaky finger still selects', (tester) async {
    DateTime? picked;
    await pumpStrip(
      tester,
      focused: DateTime(2026, 9, 1),
      onPick: (m) => picked = m,
    );
    await tester.pumpAndSettle();

    // A real finger moves a few pixels between touch and lift; that used to
    // hand the gesture to the scroll view and swallow the selection.
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Oct')),
    );
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.moveBy(const Offset(-6, 2));
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.up();
    await tester.pump();

    expect(picked, DateTime(2026, 10, 1));
  });

  testWidgets('the strip opens on the focused month', (tester) async {
    await pumpStrip(tester, focused: DateTime(2026, 9, 1), onPick: (_) {});
    await tester.pumpAndSettle();

    expect(find.text('Sep'), findsOneWidget);
  });
}
