import 'package:flutter/material.dart';

import 'natural_language_parser.dart';

class DateParseResult {
  final DateTime date;
  final TimeOfDay? time;
  final String matchedText;

  DateParseResult({
    required this.date,
    this.time,
    required this.matchedText,
  });
}

class DateParser {
  // German day shortcuts
  static const Map<String, int> _germanDayShortcuts = {
    'mo': DateTime.monday,
    'di': DateTime.tuesday,
    'mi': DateTime.wednesday,
    'do': DateTime.thursday,
    'fr': DateTime.friday,
    'sa': DateTime.saturday,
    'so': DateTime.sunday,
    'montag': DateTime.monday,
    'dienstag': DateTime.tuesday,
    'mittwoch': DateTime.wednesday,
    'donnerstag': DateTime.thursday,
    'freitag': DateTime.friday,
    'samstag': DateTime.saturday,
    'sonntag': DateTime.sunday,
  };

  // English day shortcuts
  static const Map<String, int> _englishDayShortcuts = {
    'mon': DateTime.monday,
    'tue': DateTime.tuesday,
    'wed': DateTime.wednesday,
    'thu': DateTime.thursday,
    'fri': DateTime.friday,
    'sat': DateTime.saturday,
    'sun': DateTime.sunday,
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  // German relative date keywords
  static const Map<String, int> _germanRelative = {
    'heute': 0,
    'morgen': 1,
    'übermorgen': 2,
  };

  // English relative date keywords
  static const Map<String, int> _englishRelative = {
    'today': 0,
    'tod': 0,
    'tomorrow': 1,
    'tom': 1,
  };

  // German weekday display names
  static const Map<int, String> _germanWeekdayNames = {
    DateTime.monday: 'Montag',
    DateTime.tuesday: 'Dienstag',
    DateTime.wednesday: 'Mittwoch',
    DateTime.thursday: 'Donnerstag',
    DateTime.friday: 'Freitag',
    DateTime.saturday: 'Samstag',
    DateTime.sunday: 'Sonntag',
  };

  // English weekday display names
  static const Map<int, String> _englishWeekdayNames = {
    DateTime.monday: 'Monday',
    DateTime.tuesday: 'Tuesday',
    DateTime.wednesday: 'Wednesday',
    DateTime.thursday: 'Thursday',
    DateTime.friday: 'Friday',
    DateTime.saturday: 'Saturday',
    DateTime.sunday: 'Sunday',
  };

  DateParseResult? parse(String input, Language language) {
    final lower = input.toLowerCase();
    final now = DateTime.now();

    // Check relative keywords first
    final relativeMap = language == Language.german
        ? _germanRelative
        : _englishRelative;

    for (final entry in relativeMap.entries) {
      final match = RegExp(r'\b' + entry.key + r'\b', caseSensitive: false);
      final m = match.firstMatch(lower);
      if (m != null) {
        final date = DateTime(now.year, now.month, now.day)
            .add(Duration(days: entry.value));
        return DateParseResult(
          date: date,
          matchedText: m.group(0)!,
        );
      }
    }

    // Check "next week" / "nächste woche"
    final nextWeekMatch = language == Language.german
        ? RegExp(r'\bnächste\s+woche\b', caseSensitive: false).firstMatch(lower)
        : RegExp(r'\bnext\s+week\b', caseSensitive: false).firstMatch(lower);
    if (nextWeekMatch != null) {
      final date = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 7));
      return DateParseResult(
        date: date,
        matchedText: nextWeekMatch.group(0)!,
      );
    }

    // Check day shortcuts (mo, di, mi, etc. or mon, tue, wed, etc.)
    final dayShortcuts = language == Language.german
        ? _germanDayShortcuts
        : _englishDayShortcuts;

    // Use word boundary regex to find day shortcuts
    // This prevents false positives like "milch" matching "mi"
    // We need to check that the shortcut is not part of a larger word
    for (final entry in dayShortcuts.entries) {
      // Use negative lookbehind/lookahead for letters (including German umlauts)
      final pattern = RegExp(
        r'(?<![a-zA-ZäöüßÄÖÜ])' + entry.key + r'(?![a-zA-ZäöüßÄÖÜ])',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(lower);
      if (match != null) {
        final targetWeekday = entry.value;
        var targetDate = DateTime(now.year, now.month, now.day);

        // Find the next occurrence of this weekday
        while (targetDate.weekday != targetWeekday) {
          targetDate = targetDate.add(const Duration(days: 1));
        }

        // If it's today, move to next week
        if (targetDate.day == now.day &&
            targetDate.month == now.month &&
            targetDate.year == now.year) {
          targetDate = targetDate.add(const Duration(days: 7));
        }

        return DateParseResult(
          date: targetDate,
          matchedText: match.group(0)!,
        );
      }
    }

    // Check for time patterns (10:00, 10 uhr, 10am, 14:30)
    final timePattern = RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?\s*(uhr|am|pm)?\b',
      caseSensitive: false,
    );
    final timeMatch = timePattern.firstMatch(lower);
    if (timeMatch != null) {
      var hour = int.parse(timeMatch.group(1)!);
      final minute = timeMatch.group(2) != null
          ? int.parse(timeMatch.group(2)!)
          : 0;
      final modifier = timeMatch.group(3)?.toLowerCase();

      // Handle AM/PM
      if (modifier == 'pm' && hour < 12) {
        hour += 12;
      } else if (modifier == 'am' && hour == 12) {
        hour = 0;
      }

      // Return today's date with the time
      return DateParseResult(
        date: DateTime(now.year, now.month, now.day),
        time: TimeOfDay(hour: hour, minute: minute),
        matchedText: timeMatch.group(0)!,
      );
    }

    // Check for date patterns (1.12, 12/1, Dec 1)
    // German format: DD.MM or DD.MM.YYYY
    final germanDatePattern = RegExp(r'\b(\d{1,2})\.(\d{1,2})(?:\.(\d{2,4}))?\b');
    final germanDateMatch = germanDatePattern.firstMatch(input);
    if (germanDateMatch != null && language == Language.german) {
      final day = int.parse(germanDateMatch.group(1)!);
      final month = int.parse(germanDateMatch.group(2)!);
      var year = now.year;
      if (germanDateMatch.group(3) != null) {
        year = int.parse(germanDateMatch.group(3)!);
        if (year < 100) year += 2000;
      }

      // Validate date
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateParseResult(
          date: DateTime(year, month, day),
          matchedText: germanDateMatch.group(0)!,
        );
      }
    }

    // US format: MM/DD or MM/DD/YYYY
    final usDatePattern = RegExp(r'\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b');
    final usDateMatch = usDatePattern.firstMatch(input);
    if (usDateMatch != null && language == Language.english) {
      final month = int.parse(usDateMatch.group(1)!);
      final day = int.parse(usDateMatch.group(2)!);
      var year = now.year;
      if (usDateMatch.group(3) != null) {
        year = int.parse(usDateMatch.group(3)!);
        if (year < 100) year += 2000;
      }

      // Validate date
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateParseResult(
          date: DateTime(year, month, day),
          matchedText: usDateMatch.group(0)!,
        );
      }
    }

    return null;
  }

  /// Get display name for a weekday
  static String getWeekdayName(int weekday, Language language) {
    final names = language == Language.german
        ? _germanWeekdayNames
        : _englishWeekdayNames;
    return names[weekday] ?? '';
  }

  /// Format a date for display based on context
  static String formatDate(DateTime date, Language language) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    final diff = targetDate.difference(today).inDays;

    if (diff == 0) {
      return language == Language.german ? 'Heute' : 'Today';
    } else if (diff == 1) {
      return language == Language.german ? 'Morgen' : 'Tomorrow';
    } else if (diff == 2 && language == Language.german) {
      return 'Übermorgen';
    } else if (diff > 0 && diff < 7) {
      return getWeekdayName(date.weekday, language);
    } else {
      // Format as date
      if (language == Language.german) {
        return '${date.day}.${date.month}.${date.year}';
      } else {
        return '${date.month}/${date.day}/${date.year}';
      }
    }
  }
}
