class PriorityParseResult {
  final int priority;
  final String matchedText;

  PriorityParseResult({
    required this.priority,
    required this.matchedText,
  });
}

class PriorityParser {
  // Patterns: !!1, !!2, !!3, !!4 or p1, p2, p3, p4
  static final RegExp _doubleExclamation = RegExp(
    r'!!([1-4])',
    caseSensitive: false,
  );

  static final RegExp _pPrefix = RegExp(
    r'\bp([1-4])\b',
    caseSensitive: false,
  );

  PriorityParseResult? parse(String input) {
    // Check !! pattern first (higher precedence)
    final exclamationMatch = _doubleExclamation.firstMatch(input);
    if (exclamationMatch != null) {
      return PriorityParseResult(
        priority: int.parse(exclamationMatch.group(1)!),
        matchedText: exclamationMatch.group(0)!,
      );
    }

    // Check p prefix pattern
    final pMatch = _pPrefix.firstMatch(input);
    if (pMatch != null) {
      return PriorityParseResult(
        priority: int.parse(pMatch.group(1)!),
        matchedText: pMatch.group(0)!,
      );
    }

    return null;
  }

  /// Get display label for priority
  static String getLabel(int priority) {
    switch (priority) {
      case 1:
        return 'P1';
      case 2:
        return 'P2';
      case 3:
        return 'P3';
      default:
        return 'P4';
    }
  }
}
