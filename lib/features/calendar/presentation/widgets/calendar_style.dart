import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/providers/settings_provider.dart';

/// The shared look of the calendar family.
///
/// Agenda, week, month and day show the same data in four shapes, so they
/// must read as one family: the same weekday labels, the same accent for
/// "today" and the same fallback colour for an event without its own.
class CalendarStyle {
  const CalendarStyle._();

  /// Weekday labels in calendar order, Monday first.
  static const List<String> _names = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// Weekday labels in the order a grid draws its columns.
  ///
  /// A function instead of a const list: the first column is a setting now, so
  /// every view has to ask for the order rather than assume Monday.
  static List<String> weekdays(WeekStart weekStart) {
    final offset = weekStart.weekday - DateTime.monday;
    return [for (var i = 0; i < 7; i++) _names[(i + offset) % 7]];
  }

  /// Label of one date's weekday. Independent of the week start — the agenda
  /// names a single day instead of drawing a week.
  static String weekdayLabel(DateTime date) => _names[date.weekday - 1];

  /// True on Saturday and Sunday. Which grid column that is depends on the
  /// week start, so the check is on the date, never on the column index.
  static bool isWeekend(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  /// Marks today and the selected period in every view.
  static Color get accent => AppColors.primary;

  /// Colour of an event that carries none of its own.
  static Color get defaultEventColor => AppColors.primary;

  /// Colour of one item, with the fallback already applied.
  static Color colorOf(int raw) => raw != 0 ? Color(raw) : defaultEventColor;

  /// Foreground that stays readable on a filled block of [background].
  static Color onEventColor(Color background) =>
      background.computeLuminance() > 0.6
      ? const Color(0xFF1A1A22)
      : Colors.white;

  /// The swatches an event can be painted with. Same palette as projects, so
  /// a colour means the same thing everywhere in the app.
  static const List<Color> eventColors = AppColors.projectColors;

  /// Duration of every state change in the calendar UI.
  static const Duration motion = Duration(milliseconds: 220);
}
