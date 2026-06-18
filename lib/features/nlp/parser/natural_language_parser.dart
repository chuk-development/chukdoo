import 'package:flutter/material.dart';

import 'date_parser.dart';
import 'priority_parser.dart';
import 'project_parser.dart';
import 'label_parser.dart';

enum Language { german, english }

class ParseResult {
  final String title;
  final DateTime? dueDate;
  final TimeOfDay? dueTime;
  final int? priority;
  final String? projectName;
  final List<String> labels;
  final Language detectedLanguage;

  /// Segments of the original input for highlighting
  final List<ParsedSegment> segments;

  const ParseResult({
    required this.title,
    this.dueDate,
    this.dueTime,
    this.priority,
    this.projectName,
    this.labels = const [],
    this.detectedLanguage = Language.english,
    this.segments = const [],
  });

  bool get hasDueDate => dueDate != null;
  bool get hasPriority => priority != null && priority! < 4;
  bool get hasProject => projectName != null;
  bool get hasLabels => labels.isNotEmpty;
}

enum SegmentType {
  text,
  date,
  priority,
  project,
  label,
}

class ParsedSegment {
  final String text;
  final SegmentType type;
  final dynamic value;

  const ParsedSegment({
    required this.text,
    required this.type,
    this.value,
  });
}

class NaturalLanguageParser {
  final DateParser _dateParser = DateParser();
  final PriorityParser _priorityParser = PriorityParser();
  final ProjectParser _projectParser = ProjectParser();
  final LabelParser _labelParser = LabelParser();

  ParseResult parse(String input, {Language? preferredLanguage}) {
    if (input.trim().isEmpty) {
      return const ParseResult(title: '');
    }

    final language = preferredLanguage ?? _detectLanguage(input);
    var remaining = input;
    final segments = <ParsedSegment>[];

    DateTime? dueDate;
    TimeOfDay? dueTime;
    int? priority;
    String? projectName;
    List<String> labels = [];

    // Parse priority first (!!1, !!2, !!3, !!4 or p1, p2, p3, p4)
    final priorityResult = _priorityParser.parse(remaining);
    if (priorityResult != null) {
      priority = priorityResult.priority;
      segments.add(ParsedSegment(
        text: priorityResult.matchedText,
        type: SegmentType.priority,
        value: priority,
      ));
      remaining = _removeMatch(remaining, priorityResult.matchedText);
    }

    // Parse project (*project_name) and tags (#tag) BEFORE the date, so a tag
    // like "#so" is never mis-read as a weekday (Sonntag) etc.
    final projectResult = _projectParser.parse(remaining);
    if (projectResult != null) {
      projectName = projectResult.projectName;
      segments.add(ParsedSegment(
        text: projectResult.matchedText,
        type: SegmentType.project,
        value: projectName,
      ));
      remaining = _removeMatch(remaining, projectResult.matchedText);
    }

    // Parse labels / tags (#tag1 #tag2)
    final labelResult = _labelParser.parse(remaining);
    labels = labelResult.labels;
    for (final label in labelResult.matchedTexts) {
      segments.add(ParsedSegment(
        text: label,
        type: SegmentType.label,
        value: label.substring(1), // Remove #
      ));
      remaining = _removeMatch(remaining, label);
    }

    // Parse date/time (after tags/project are stripped)
    final dateResult = _dateParser.parse(remaining, language);
    if (dateResult != null) {
      dueDate = dateResult.date;
      dueTime = dateResult.time;
      segments.add(ParsedSegment(
        text: dateResult.matchedText,
        type: SegmentType.date,
        value: dueDate,
      ));
      remaining = _removeMatch(remaining, dateResult.matchedText);
      if (dateResult.timeMatchedText != null) {
        remaining = _removeMatch(remaining, dateResult.timeMatchedText!);
      }
    }

    // Clean up remaining text
    final title = remaining.trim().replaceAll(RegExp(r'\s+'), ' ');

    return ParseResult(
      title: title,
      dueDate: dueDate,
      dueTime: dueTime,
      priority: priority,
      projectName: projectName,
      labels: labels,
      detectedLanguage: language,
      segments: segments,
    );
  }

  /// Parses input and returns segments for real-time highlighting
  List<ParsedSegment> parseForHighlighting(String input, {Language? preferredLanguage}) {
    if (input.trim().isEmpty) {
      return [];
    }

    final language = preferredLanguage ?? _detectLanguage(input);
    final segments = <ParsedSegment>[];
    var currentPos = 0;

    // Find all matches with their positions
    final matches = <_MatchInfo>[];

    // Priority matches
    final priorityResult = _priorityParser.parse(input);
    if (priorityResult != null) {
      final idx = input.toLowerCase().indexOf(priorityResult.matchedText.toLowerCase());
      if (idx >= 0) {
        matches.add(_MatchInfo(
          start: idx,
          end: idx + priorityResult.matchedText.length,
          text: priorityResult.matchedText,
          type: SegmentType.priority,
          value: priorityResult.priority,
        ));
      }
    }

    // Date matches
    final dateResult = _dateParser.parse(input, language);
    if (dateResult != null) {
      final idx = input.toLowerCase().indexOf(dateResult.matchedText.toLowerCase());
      if (idx >= 0) {
        matches.add(_MatchInfo(
          start: idx,
          end: idx + dateResult.matchedText.length,
          text: dateResult.matchedText,
          type: SegmentType.date,
          value: dateResult.date,
        ));
      }
    }

    // Project matches
    final projectResult = _projectParser.parse(input);
    if (projectResult != null) {
      final idx = input.indexOf(projectResult.matchedText);
      if (idx >= 0) {
        matches.add(_MatchInfo(
          start: idx,
          end: idx + projectResult.matchedText.length,
          text: projectResult.matchedText,
          type: SegmentType.project,
          value: projectResult.projectName,
        ));
      }
    }

    // Label matches
    final labelResult = _labelParser.parse(input);
    for (final labelText in labelResult.matchedTexts) {
      var searchStart = 0;
      while (true) {
        final idx = input.indexOf(labelText, searchStart);
        if (idx < 0) break;
        matches.add(_MatchInfo(
          start: idx,
          end: idx + labelText.length,
          text: labelText,
          type: SegmentType.label,
          value: labelText.substring(1),
        ));
        searchStart = idx + labelText.length;
      }
    }

    // Sort matches by position
    matches.sort((a, b) => a.start.compareTo(b.start));

    // Remove overlapping matches
    final filteredMatches = <_MatchInfo>[];
    for (final match in matches) {
      if (filteredMatches.isEmpty ||
          match.start >= filteredMatches.last.end) {
        filteredMatches.add(match);
      }
    }

    // Build segments
    for (final match in filteredMatches) {
      // Add text before match
      if (match.start > currentPos) {
        segments.add(ParsedSegment(
          text: input.substring(currentPos, match.start),
          type: SegmentType.text,
        ));
      }
      // Add match
      segments.add(ParsedSegment(
        text: match.text,
        type: match.type,
        value: match.value,
      ));
      currentPos = match.end;
    }

    // Add remaining text
    if (currentPos < input.length) {
      segments.add(ParsedSegment(
        text: input.substring(currentPos),
        type: SegmentType.text,
      ));
    }

    return segments;
  }

  Language _detectLanguage(String input) {
    final lower = input.toLowerCase();

    const germanIndicators = {
      'morgen', 'heute', 'übermorgen', 'uhr', 'montag', 'dienstag',
      'mittwoch', 'donnerstag', 'freitag', 'samstag', 'sonntag',
      'nächste', 'woche', 'monat', 'mo', 'di', 'mi', 'do', 'fr', 'sa', 'so',
    };

    const englishIndicators = {
      'tomorrow', 'today', 'next', 'week', 'month', 'monday',
      'tuesday', 'wednesday', 'thursday', 'friday', 'saturday',
      'sunday', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun', 'am', 'pm',
    };

    int germanScore = 0;
    int englishScore = 0;

    final words = lower.split(RegExp(r'\s+'));
    for (final word in words) {
      if (germanIndicators.contains(word)) germanScore++;
      if (englishIndicators.contains(word)) englishScore++;
    }

    if (germanScore == englishScore) {
      // Default to German (based on user's screenshots)
      return Language.german;
    }

    return germanScore > englishScore ? Language.german : Language.english;
  }

  String _removeMatch(String input, String match) {
    return input.replaceFirst(RegExp(RegExp.escape(match), caseSensitive: false), '').trim();
  }
}

class _MatchInfo {
  final int start;
  final int end;
  final String text;
  final SegmentType type;
  final dynamic value;

  _MatchInfo({
    required this.start,
    required this.end,
    required this.text,
    required this.type,
    this.value,
  });
}
