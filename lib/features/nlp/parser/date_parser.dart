import 'package:flutter/material.dart';

import 'natural_language_parser.dart';

class DateParseResult {
  final DateTime date;
  final TimeOfDay? time;
  final String matchedText;

  /// Matched text for the time portion when it is separate from the date
  /// (e.g. "montag" + "15 uhr"). Lets the NLP layer strip both from the title.
  final String? timeMatchedText;

  DateParseResult({
    required this.date,
    this.time,
    required this.matchedText,
    this.timeMatchedText,
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

  // Named times of day → (hour, minute). Only used when no explicit time given.
  static const Map<String, int> _germanNamedTimes = {
    'früh': 8,
    'morgens': 8,
    'vormittag': 10,
    'vormittags': 10,
    'mittag': 12,
    'mittags': 12,
    'nachmittag': 15,
    'nachmittags': 15,
    'abend': 18,
    'abends': 18,
    'nacht': 22,
    'nachts': 22,
  };

  static const Map<String, int> _englishNamedTimes = {
    'morning': 8,
    'noon': 12,
    'afternoon': 15,
    'evening': 18,
    'night': 22,
  };

  DateParseResult? parse(String input, Language language) {
    final lower = input.toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime? date;
    String? dateMatch;

    // ── 1. Determine the DATE ──

    // Relative keywords (heute / morgen / übermorgen, today / tomorrow)
    final relativeMap =
        language == Language.german ? _germanRelative : _englishRelative;
    for (final entry in relativeMap.entries) {
      final m = RegExp(r'\b' + entry.key + r'\b', caseSensitive: false)
          .firstMatch(lower);
      if (m != null) {
        date = today.add(Duration(days: entry.value));
        dateMatch = m.group(0);
        break;
      }
    }

    // "next week" / "nächste woche"
    if (date == null) {
      final m = (language == Language.german
              ? RegExp(r'\bnächste\s+woche\b', caseSensitive: false)
              : RegExp(r'\bnext\s+week\b', caseSensitive: false))
          .firstMatch(lower);
      if (m != null) {
        date = today.add(const Duration(days: 7));
        dateMatch = m.group(0);
      }
    }

    // Weekend
    if (date == null) {
      final m = (language == Language.german
              ? RegExp(r'\bwochenende\b', caseSensitive: false)
              : RegExp(r'\bweekend\b', caseSensitive: false))
          .firstMatch(lower);
      if (m != null) {
        var d = today;
        while (d.weekday != DateTime.saturday) {
          d = d.add(const Duration(days: 1));
        }
        date = d;
        dateMatch = m.group(0);
      }
    }

    // Day shortcuts (mo, di, ... or mon, tue, ...). Pick the EARLIEST match in
    // the text so "milch mo kaufen fr" resolves to Monday, not map order.
    if (date == null) {
      final dayShortcuts = language == Language.german
          ? _germanDayShortcuts
          : _englishDayShortcuts;
      int bestIndex = 1 << 30;
      int? bestWeekday;
      String? bestText;
      for (final entry in dayShortcuts.entries) {
        final match = RegExp(
          r'(?<![a-zA-ZäöüßÄÖÜ])' + entry.key + r'(?![a-zA-ZäöüßÄÖÜ])',
          caseSensitive: false,
        ).firstMatch(lower);
        if (match != null && match.start < bestIndex) {
          bestIndex = match.start;
          bestWeekday = entry.value;
          bestText = match.group(0);
        }
      }
      if (bestWeekday != null) {
        var targetDate = today;
        while (targetDate.weekday != bestWeekday) {
          targetDate = targetDate.add(const Duration(days: 1));
        }
        // If it's today, jump to next week's occurrence.
        if (targetDate == today) {
          targetDate = targetDate.add(const Duration(days: 7));
        }
        date = targetDate;
        dateMatch = bestText;
      }
    }

    // Explicit numeric dates (DD.MM / MM/DD)
    if (date == null) {
      final explicit = _parseExplicitDate(input, language, now);
      if (explicit != null) {
        date = explicit.date;
        dateMatch = explicit.matchedText;
      }
    }

    // ── 2. Determine the TIME (independent of the date) ──
    TimeOfDay? time;
    String? timeMatch;

    // Explicit: 14:30, 10:00, or "10 uhr" / "10am" / "10 pm"
    final colon = RegExp(r'(?<!\d)(\d{1,2}):(\d{2})(?!\d)').firstMatch(lower);
    final modified = RegExp(r'(?<!\d)(\d{1,2})\s*(uhr|am|pm)\b', caseSensitive: false)
        .firstMatch(lower);
    if (colon != null) {
      final h = int.parse(colon.group(1)!);
      final min = int.parse(colon.group(2)!);
      if (h <= 23 && min <= 59) {
        time = TimeOfDay(hour: h, minute: min);
        timeMatch = colon.group(0);
      }
    } else if (modified != null) {
      var h = int.parse(modified.group(1)!);
      final mod = modified.group(2)!.toLowerCase();
      if (mod == 'pm' && h < 12) h += 12;
      if (mod == 'am' && h == 12) h = 0;
      if (h <= 23) {
        time = TimeOfDay(hour: h, minute: 0);
        timeMatch = modified.group(0);
      }
    }

    // Named time of day ("morgen früh", "samstag abend")
    if (time == null) {
      final namedTimes =
          language == Language.german ? _germanNamedTimes : _englishNamedTimes;
      for (final entry in namedTimes.entries) {
        final m = RegExp(r'\b' + entry.key + r'\b', caseSensitive: false)
            .firstMatch(lower);
        if (m != null) {
          time = TimeOfDay(hour: entry.value, minute: 0);
          timeMatch = m.group(0);
          break;
        }
      }
    }

    // ── 3. Combine ──
    if (date == null && time == null) return null;
    date ??= today;

    return DateParseResult(
      date: date,
      time: time,
      matchedText: dateMatch ?? timeMatch ?? '',
      // Only carry timeMatch separately when it's not already the main match.
      timeMatchedText: (dateMatch != null) ? timeMatch : null,
    );
  }

  /// Numeric date forms — German DD.MM[.YYYY], US MM/DD[/YYYY].
  DateParseResult? _parseExplicitDate(
      String input, Language language, DateTime now) {
    // German format: DD.MM or DD.MM.YYYY
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
