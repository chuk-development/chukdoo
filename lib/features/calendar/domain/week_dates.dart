import '../../settings/providers/settings_provider.dart';

/// Week maths every calendar surface shares.
///
/// The first day of a week is a setting now, so month, week, the page title
/// and the item range must all ask the same function — a second copy of
/// `subtract(weekday - 1)` somewhere would silently keep Monday.

/// Columns the three day view draws — Google Calendar's "3 Day".
///
/// One number for the whole feature: the pager strides by it, the view draws
/// that many columns and the item range prefetches a page either side of it.
const int threeDayColumns = 3;

/// [count] consecutive days from [start], midnight each.
///
/// Counted with `DateTime(y, m, d + i)` rather than by adding a `Duration`,
/// because a day across a DST change is not 24 hours long and the column would
/// slide by an hour.
List<DateTime> daysFrom(DateTime start, int count) => [
  for (var i = 0; i < count; i++)
    DateTime(start.year, start.month, start.day + i),
];

/// Midnight of the day [date] falls in.
DateTime dayStart(DateTime date) => DateTime(date.year, date.month, date.day);

/// First day of the week [date] belongs to, for the user's [weekStart].
DateTime startOfWeek(DateTime date, WeekStart weekStart) {
  final day = dayStart(date);
  // DateTime.weekday runs 1 (Mon) to 7 (Sun); the offset is how many days the
  // date sits after the configured first day.
  final offset = (day.weekday - weekStart.weekday + 7) % 7;
  return day.subtract(Duration(days: offset));
}

/// ISO week number a grid row is labelled with, given the row's first day.
///
/// ISO weeks run Monday to Sunday. A row that starts on Sunday therefore
/// straddles two ISO weeks, and its first day still belongs to the week
/// before. Counting from the middle of the row picks the week most of the row
/// is in — and for a Monday row it is the same number either way.
int isoWeekNumberForRow(DateTime rowStart) =>
    isoWeekNumber(rowStart.add(const Duration(days: 3)));

/// ISO-8601 week number of [date].
///
/// ISO weeks always start on Monday and week 1 is the week holding the first
/// Thursday of the year. That is the definition, so it does not follow the
/// user's week start — a "week 32" label must mean the same thing everywhere.
/// The maths runs in UTC because a DST day is not 24 hours long and would
/// truncate the day difference.
int isoWeekNumber(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  // The Thursday of this week decides which ISO year the week counts to.
  final thursday = day.add(Duration(days: 4 - day.weekday));
  final firstThursdayWeek = DateTime.utc(thursday.year, 1, 4);
  final firstMonday = firstThursdayWeek.subtract(
    Duration(days: firstThursdayWeek.weekday - 1),
  );
  return thursday.difference(firstMonday).inDays ~/ 7 + 1;
}
