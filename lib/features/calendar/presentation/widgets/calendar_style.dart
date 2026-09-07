import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The shared look of the calendar family.
///
/// Agenda, week, month and day show the same data in four shapes, so they
/// must read as one family: the same weekday labels, the same accent for
/// "today" and the same fallback colour for an event without its own.
class CalendarStyle {
  const CalendarStyle._();

  /// Weekday labels, Monday first. Every view uses these strings.
  static const List<String> weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// Marks today and the selected period in every view.
  static Color get accent => AppColors.primary;

  /// Colour of an event that carries none of its own.
  static Color get defaultEventColor => AppColors.primary;

  /// Colour of one item, with the fallback already applied.
  static Color colorOf(int raw) =>
      raw != 0 ? Color(raw) : defaultEventColor;

  /// Foreground that stays readable on a filled block of [background].
  static Color onEventColor(Color background) => background.computeLuminance() > 0.6
      ? const Color(0xFF1A1A22)
      : Colors.white;

  /// The swatches an event can be painted with. Same palette as projects, so
  /// a colour means the same thing everywhere in the app.
  static const List<Color> eventColors = AppColors.projectColors;

  /// Duration of every state change in the calendar UI.
  static const Duration motion = Duration(milliseconds: 220);
}
