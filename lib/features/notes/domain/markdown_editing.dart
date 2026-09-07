/// Text transforms behind the note editor's formatting bar.
///
/// Pure string work, deliberately free of Flutter: a button press is "rewrite
/// the source and say where the caret goes", and that is far easier to get
/// right — and to test — without a widget tree around it.
library;

/// A rewritten source plus the selection the field must adopt afterwards.
///
/// The caret matters as much as the text: a formatting button that leaves the
/// caret in the wrong place forces the user to tap back into the line, which
/// is exactly the friction the bar exists to remove.
class MarkdownEdit {
  final String text;
  final int selectionStart;
  final int selectionEnd;

  const MarkdownEdit(this.text, this.selectionStart, this.selectionEnd);

  const MarkdownEdit.caret(this.text, int offset)
    : selectionStart = offset,
      selectionEnd = offset;
}

/// Every block marker a line can already carry. Applying a new marker strips
/// the old one first, so "bullet" on a quote line replaces it instead of
/// stacking `> - `.
final RegExp _blockPrefix = RegExp(
  r'^(\s*)(#{1,6} |> |[-*+] \[[ xX]\] |[-*+] |\d+[.)] )',
);

/// Marker of an unchecked / checked task line.
final RegExp taskLine = RegExp(r'^(\s*)([-*+]) \[([ xX])\] ?(.*)$');

/// Start offset of the line that contains [offset].
int _lineStart(String text, int offset) {
  final i = text.lastIndexOf('\n', offset > 0 ? offset - 1 : 0);
  return i == -1 ? 0 : i + 1;
}

/// End offset (exclusive of the newline) of the line containing [offset].
int _lineEnd(String text, int offset) {
  final i = text.indexOf('\n', offset);
  return i == -1 ? text.length : i;
}

/// Add [prefix] to every line the selection touches, or take it away again
/// when every one of them already carries it.
///
/// [prefix] is a literal such as `'# '`, `'- '`, `'> '` or `'- [ ] '`. Pass
/// [ordered] for a numbered list: the lines are then numbered `1.`, `2.`, …
/// instead of all getting the same marker.
MarkdownEdit toggleLinePrefix(
  String text,
  int start,
  int end,
  String prefix, {
  bool ordered = false,
}) {
  final from = _lineStart(text, start);
  final to = _lineEnd(text, end);
  final block = text.substring(from, to);
  final lines = block.split('\n');

  String indentOf(String line) => _blockPrefix.firstMatch(line)?[1] ?? '';
  String bodyOf(String line) => line.replaceFirst(_blockPrefix, '');

  // "Already formatted" is judged on every line, so a half-formatted block
  // completes instead of clearing — pressing a button twice is how one undoes.
  final allMarked = lines.every((line) {
    final match = _blockPrefix.firstMatch(line);
    if (match == null) return false;
    final marker = match[2]!;
    return ordered ? RegExp(r'^\d+[.)] $').hasMatch(marker) : marker == prefix;
  });

  final rewritten = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    // A blank line inside a multi-line selection keeps its emptiness: a
    // bullet on nothing is noise the user would have to delete by hand.
    if (line.trim().isEmpty && lines.length > 1) {
      rewritten.add(line);
      continue;
    }
    final body = bodyOf(line);
    if (allMarked) {
      rewritten.add(indentOf(line) + body);
    } else {
      final marker = ordered ? '${i + 1}. ' : prefix;
      rewritten.add('${indentOf(line)}$marker$body');
    }
  }

  final replacement = rewritten.join('\n');
  final newText = text.replaceRange(from, to, replacement);
  final delta = replacement.length - block.length;

  // A caret follows its own line; a range keeps covering the block it changed.
  if (start == end) {
    final firstDelta = rewritten.first.length - lines.first.length;
    final moved = (start + firstDelta).clamp(from, from + replacement.length);
    return MarkdownEdit.caret(newText, moved);
  }
  return MarkdownEdit(newText, from, (end + delta).clamp(from, newText.length));
}

/// Wrap the selection in [left] … [right], or unwrap it when it already is.
///
/// With nothing selected the marks are inserted and [placeholder] is left
/// selected, so the next keystroke replaces it — an empty `****` with the
/// caret in the middle looks broken on a phone keyboard.
MarkdownEdit wrapSelection(
  String text,
  int start,
  int end,
  String left,
  String right, {
  String placeholder = '',
}) {
  if (start == end) {
    final inserted = '$left$placeholder$right';
    final newText = text.replaceRange(start, start, inserted);
    final caret = start + left.length;
    return MarkdownEdit(newText, caret, caret + placeholder.length);
  }

  final selected = text.substring(start, end);
  if (selected.startsWith(left) &&
      selected.endsWith(right) &&
      selected.length >= left.length + right.length) {
    final inner = selected.substring(
      left.length,
      selected.length - right.length,
    );
    final newText = text.replaceRange(start, end, inner);
    return MarkdownEdit(newText, start, start + inner.length);
  }

  final newText = text.replaceRange(start, end, '$left$selected$right');
  return MarkdownEdit(newText, start + left.length, end + left.length);
}

/// Insert a Markdown link. The selection becomes the label; the `url`
/// placeholder is left selected so the address can be typed straight away.
MarkdownEdit insertLink(String text, int start, int end) {
  final label = start == end ? 'text' : text.substring(start, end);
  const url = 'url';
  final inserted = '[$label]($url)';
  final newText = text.replaceRange(start, end, inserted);
  final urlStart = start + label.length + 3;
  return MarkdownEdit(newText, urlStart, urlStart + url.length);
}

/// Flip the checkbox on source line [lineIndex] (`- [ ]` ⇄ `- [x]`).
///
/// Returns the source unchanged when that line is not a task, so the preview
/// can call it without knowing whether its hit really landed on one.
String toggleTaskLine(String source, int lineIndex) {
  final lines = source.split('\n');
  if (lineIndex < 0 || lineIndex >= lines.length) return source;

  final match = taskLine.firstMatch(lines[lineIndex]);
  if (match == null) return source;

  final checked = match[3] != ' ';
  lines[lineIndex] =
      '${match[1]}${match[2]} [${checked ? ' ' : 'x'}] '
      '${match[4]}';
  return lines.join('\n');
}
