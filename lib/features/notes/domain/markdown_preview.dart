/// Turns Markdown source into the plain text a note card shows.
///
/// The cards are a preview, not a renderer: raw `#`, `*` and link syntax reads
/// as noise at 14px in a two-column grid. This strips the marks and keeps the
/// words, in the order the author wrote them.
///
/// Deliberately a small hand-written pass instead of a real parser — the card
/// only ever shows the first few lines, so a full AST would cost more than it
/// returns.
String markdownToPlainText(String source) {
  if (source.isEmpty) return '';

  final buffer = <String>[];
  var inFence = false;

  for (final rawLine in source.split('\n')) {
    var line = rawLine;

    // Fenced code: keep the code, drop the fences.
    if (RegExp(r'^\s*(```|~~~)').hasMatch(line)) {
      inFence = !inFence;
      continue;
    }
    if (inFence) {
      buffer.add(line.trim());
      continue;
    }

    // A horizontal rule carries no words.
    if (RegExp(r'^\s*([-*_])\s*(\1\s*){2,}$').hasMatch(line)) continue;

    line = line.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), ''); // heading
    line = line.replaceFirst(RegExp(r'^\s{0,3}>\s?'), ''); // quote
    // A task box becomes a tick so the state survives the strip.
    line = line.replaceFirstMapped(
      RegExp(r'^\s*[-*+]\s+\[( |x|X)\]\s+'),
      (m) => m[1] == ' ' ? '☐ ' : '☑ ',
    );
    line = line.replaceFirst(RegExp(r'^\s*[-*+]\s+'), '• '); // bullet
    line = line.replaceFirst(RegExp(r'^\s*\d+[.)]\s+'), ''); // ordered item
    line = line.replaceAll(RegExp(r'^\s*\|'), '').replaceAll('|', ' '); // table

    buffer.add(line.trim());
  }

  var text = buffer.join('\n');

  text = text.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\([^)]*\)'),
    (m) => m[1] ?? '',
  ); // image → alt
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]*)\]\([^)]*\)'),
    (m) => m[1] ?? '',
  ); // link → label
  text = text.replaceAll(RegExp(r'`+'), ''); // inline code
  text = text.replaceAll(RegExp(r'(\*\*|__|~~)'), ''); // bold, strike
  // Single emphasis marks only when they hug a word, so "2 * 3" survives.
  text = text.replaceAllMapped(
    RegExp(r'(?<!\w)([*_])(\S(?:.*?\S)?)\1(?!\w)'),
    (m) => m[2] ?? '',
  );

  // Collapse the blank lines a preview cannot afford.
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');

  return text.trim();
}
