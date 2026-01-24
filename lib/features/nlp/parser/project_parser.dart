class ProjectParseResult {
  final String projectName;
  final String matchedText;

  ProjectParseResult({
    required this.projectName,
    required this.matchedText,
  });
}

class ProjectParser {
  // Pattern: #project_name or #"project name with spaces"
  static final RegExp _hashtagPattern = RegExp(
    r'#(?:"([^"]+)"|(\S+))',
  );

  ProjectParseResult? parse(String input) {
    final match = _hashtagPattern.firstMatch(input);
    if (match == null) return null;

    // Group 1 is for quoted names, Group 2 is for single-word names
    final projectName = match.group(1) ?? match.group(2);
    if (projectName == null || projectName.isEmpty) return null;

    return ProjectParseResult(
      projectName: projectName,
      matchedText: match.group(0)!,
    );
  }
}
