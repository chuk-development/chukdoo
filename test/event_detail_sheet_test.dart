import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chukdoo/features/calendar/domain/models/calendar_item.dart';
import 'package:chukdoo/features/calendar/presentation/widgets/event_detail_sheet.dart';
import 'package:chukdoo/features/todos/domain/models/todo.dart';
import 'package:chukdoo/features/todos/providers/todo_provider.dart';

/// The detail card edits itself: every row opens its own picker and the pick
/// is stored on the spot. There is no "Edit" step in between any more.
class _RecordingTodoNotifier extends TodoNotifier {
  _RecordingTodoNotifier(Todo todo) {
    state = TodoState(todos: [todo]);
  }

  final List<Todo> saved = [];

  // Hive, the sync queue and the home screen widget have no place in a widget
  // test, so only the result of the edit is kept.
  @override
  Future<void> updateTodo(Todo todo) async {
    saved.add(todo);
    state = TodoState(todos: [todo]);
  }
}

void main() {
  final todo = Todo(
    id: 't1',
    userId: 'local',
    title: 'Write the report',
    dueDate: DateTime(2026, 9, 8),
    dueTime: const TimeOfDay(hour: 10, minute: 0),
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 1),
  );

  Future<_RecordingTodoNotifier> pumpSheet(WidgetTester tester) async {
    final notifier = _RecordingTodoNotifier(todo);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [todoProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
          home: Scaffold(
            body: EventDetailSheet(item: TodoItem(todo: todo)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  testWidgets('tapping the time opens the picker and saves without an Edit '
      'step', (tester) async {
    final notifier = await pumpSheet(tester);

    // The card offers no way into a separate editor.
    expect(find.text('Edit'), findsNothing);

    await tester.tap(find.text('STARTS'));
    await tester.pumpAndSettle();

    // The shared date/time sheet is up.
    expect(find.byType(CalendarDatePicker), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.text('15'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    // Saved straight away, and the card already shows the new day.
    expect(notifier.saved, hasLength(1));
    expect(notifier.saved.single.dueDate?.day, 15);
    expect(find.textContaining('15 Sep 2026'), findsOneWidget);
  });

  testWidgets('the end of a task is picked in the same card', (tester) async {
    final notifier = await pumpSheet(tester);

    await tester.tap(find.text('ENDS'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    // Half an hour after the start is what the sheet offers first.
    expect(
      notifier.saved.single.endTime,
      const TimeOfDay(hour: 10, minute: 30),
    );
  });
}
