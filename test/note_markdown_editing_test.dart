import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chukdoo/features/notes/domain/markdown_editing.dart';
import 'package:chukdoo/features/notes/presentation/widgets/note_format_bar.dart';
import 'package:chukdoo/features/notes/presentation/widgets/note_markdown_view.dart';

/// The note editor has no save button and no undo: every formatting button
/// rewrites the source in place. These tests lock in that the rewrite keeps
/// the text the user wrote and puts the caret somewhere usable.
void main() {
  group('toggleTaskLine', () {
    const source = '# Shopping\n- [ ] milk\n- [x] bread\nplain line';

    test('ticks an open box and leaves the rest alone', () {
      expect(
        toggleTaskLine(source, 1),
        '# Shopping\n- [x] milk\n- [x] bread\nplain line',
      );
    });

    test('unticks a ticked box', () {
      expect(
        toggleTaskLine(source, 2),
        '# Shopping\n- [ ] milk\n- [ ] bread\nplain line',
      );
    });

    test('leaves a line that is not a task untouched', () {
      expect(toggleTaskLine(source, 3), source);
      expect(toggleTaskLine(source, 99), source);
    });
  });

  group('toggleLinePrefix', () {
    test('adds and removes a bullet on the caret line', () {
      final on = toggleLinePrefix('milk', 4, 4, '- ');
      expect(on.text, '- milk');
      expect(on.selectionStart, 6); // caret stayed behind the word

      final off = toggleLinePrefix(on.text, 6, 6, '- ');
      expect(off.text, 'milk');
    });

    test('replaces an existing marker instead of stacking one', () {
      final result = toggleLinePrefix('- milk', 6, 6, '# ');
      expect(result.text, '# milk');
    });

    test('numbers a selected block', () {
      final result = toggleLinePrefix('a\nb\nc', 0, 5, '1. ', ordered: true);
      expect(result.text, '1. a\n2. b\n3. c');
    });
  });

  group('wrapSelection', () {
    test('wraps the selection and keeps it selected', () {
      final result = wrapSelection('make bold now', 5, 9, '**', '**');
      expect(result.text, 'make **bold** now');
      expect(
        result.text.substring(result.selectionStart, result.selectionEnd),
        'bold',
      );
    });

    test('unwraps a selection that already carries the marks', () {
      final result = wrapSelection('make **bold** now', 5, 13, '**', '**');
      expect(result.text, 'make bold now');
    });

    test('inserts a selected placeholder when nothing is selected', () {
      final result = wrapSelection('', 0, 0, '**', '**', placeholder: 'bold');
      expect(result.text, '**bold**');
      expect(
        result.text.substring(result.selectionStart, result.selectionEnd),
        'bold',
      );
    });
  });

  test('insertLink selects the url placeholder', () {
    final result = insertLink('see docs', 4, 8);
    expect(result.text, 'see [docs](url)');
    expect(
      result.text.substring(result.selectionStart, result.selectionEnd),
      'url',
    );
  });

  testWidgets('a preview checkbox writes its new state back into the source', (
    tester,
  ) async {
    var source = '- [ ] milk\n- [x] bread';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteMarkdownView(
            source: source,
            onSourceChanged: (value) => source = value,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(InkWell).first);
    await tester.pump();

    expect(source, '- [x] milk\n- [x] bread');
  });

  testWidgets('the formatting bar wraps the selection and keeps the caret', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'make bold now');
    controller.selection = const TextSelection(baseOffset: 5, extentOffset: 9);
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteFormatBar(controller: controller, focusNode: focus),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Bold'));
    await tester.pump();

    expect(controller.text, 'make **bold** now');
    expect(controller.selection.isValid, isTrue);
  });
}
