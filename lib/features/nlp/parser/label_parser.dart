class LabelParseResult {
  final List<String> labels;
  final List<String> matchedTexts;

  LabelParseResult({
    required this.labels,
    required this.matchedTexts,
  });
}

class LabelParser {
  // Pattern: @label_name (multiple allowed)
  static final RegExp _atPattern = RegExp(
    r'@(\S+)',
  );

  LabelParseResult parse(String input) {
    final matches = _atPattern.allMatches(input);
    final labels = <String>[];
    final matchedTexts = <String>[];

    for (final match in matches) {
      final labelName = match.group(1);
      if (labelName != null && labelName.isNotEmpty) {
        labels.add(labelName);
        matchedTexts.add(match.group(0)!);
      }
    }

    return LabelParseResult(
      labels: labels,
      matchedTexts: matchedTexts,
    );
  }
}
