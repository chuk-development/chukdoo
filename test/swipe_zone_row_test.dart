import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chukdoo/features/todos/presentation/widgets/swipe_zone_row.dart';

/// The zoned swipe of a task row: dragging left crosses Delete · Pin · Date ·
/// Move and only the release runs the armed zone, while a full swipe opens the
/// menu instead of deleting. These tests lock exactly that in — the row must
/// never destroy anything while the finger is still moving.
void main() {
  const rowWidth = 360.0;

  // Same layout the tile builds: four zones, shortest drag first, menu last.
  const labels = ['Delete', 'Pin', 'Date', 'Move'];
  const geometry = SwipeZoneGeometry(width: rowWidth, count: 4, hasMenu: true);

  late List<String> ran;
  late List<String> ticks;

  setUp(() {
    ran = [];
    ticks = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            ticks.add('${call.arguments}');
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  SwipeZoneAction action(String label, Color color) => SwipeZoneAction(
    label: label,
    icon: Icons.circle,
    color: color,
    onRun: () => ran.add(label),
  );

  Future<void> pumpRow(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: rowWidth,
              child: SwipeZoneRow(
                startAction: action('Completed', Colors.green),
                endActions: [
                  action('Delete', Colors.red),
                  action('Pin', Colors.orange),
                  action('Date', Colors.blue),
                  action('Move', Colors.purple),
                ],
                endMenu: action('More', Colors.grey),
                child: const SizedBox(height: 60, child: Text('task row')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Drag the row [travel] pixels (negative = left) in small steps, so every
  /// zone on the way is really entered — a single jump would skip the ticks.
  Future<TestGesture> dragBy(WidgetTester tester, double travel) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SwipeZoneRow)),
    );
    final sign = travel.isNegative ? -1.0 : 1.0;
    var moved = 0.0;
    while (moved < travel.abs()) {
      final step = math.min(20.0, travel.abs() - moved);
      await gesture.moveBy(Offset(sign * step, 0));
      moved += step;
    }
    await tester.pump();
    return gesture;
  }

  /// Colour currently filling the revealed strip. Fully opaque = armed.
  Color fill(WidgetTester tester) {
    return tester
        .widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(SwipeZoneRow),
                matching: find.byType(ColoredBox),
              )
              .first,
        )
        .color;
  }

  /// Middle of zone [index] — where a user who means it stops.
  double middleOf(int index) =>
      geometry.startOf(index) + geometry.zoneWidth / 2;

  testWidgets('a drag too short to arm anything cancels', (tester) async {
    await pumpRow(tester);

    final gesture = await dragBy(tester, -(SwipeZoneGeometry.armStart - 10));
    // The first action is previewed dimmed, so the user sees what is coming.
    expect(fill(tester), Colors.red.withValues(alpha: 0.35));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(ran, isEmpty);
    expect(ticks, isEmpty);
  });

  for (var index = 0; index < labels.length; index++) {
    testWidgets('releasing in zone ${labels[index]} runs it', (tester) async {
      await pumpRow(tester);

      final gesture = await dragBy(tester, -middleOf(index));
      expect(find.text(labels[index]), findsOneWidget);
      expect(fill(tester).a, 1.0, reason: 'armed zones fill opaque');

      await gesture.up();
      await tester.pumpAndSettle();

      expect(ran, [labels[index]]);
    });
  }

  testWidgets('a full swipe opens the menu instead of deleting', (
    tester,
  ) async {
    await pumpRow(tester);

    final gesture = await dragBy(tester, -rowWidth);
    expect(find.text('More'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(ran, ['More']);
    expect(ran, isNot(contains('Delete')));
  });

  testWidgets('every zone crossed ticks the haptics exactly once', (
    tester,
  ) async {
    await pumpRow(tester);

    final gesture = await dragBy(tester, -rowWidth);
    // Four action zones plus the menu.
    expect(ticks.length, 5);

    // Swiping back into a zone already visited arms it again and ticks again.
    await gesture.moveBy(Offset(rowWidth - middleOf(0), 0));
    await tester.pump();
    expect(ticks.length, 6);
    expect(find.text('Delete'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(ran, ['Delete']);
  });

  testWidgets('swiping right arms complete and springs back', (tester) async {
    await pumpRow(tester);

    final gesture = await dragBy(tester, SwipeZoneGeometry.armStart + 20);
    expect(find.text('Completed'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(ran, ['Completed']);
    // The row is home again: nothing is revealed any more.
    expect(
      find.descendant(
        of: find.byType(SwipeZoneRow),
        matching: find.byType(ColoredBox),
      ),
      findsNothing,
    );
  });
}
