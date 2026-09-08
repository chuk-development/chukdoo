import 'models/calendar_item.dart';

/// Minutes from the top of [day] that [time] sits at, clipped to that day.
///
/// The grid draws one column per date, so an event that runs over midnight
/// has to be cut at the column's own edges: reading `time.hour` alone would
/// draw the tail of a night shift at 23:00 of the *next* day.
///
/// The comparison is on the date, not on `difference()`: a DST day is 23 or
/// 25 hours long while the grid still draws 24 equal rows, so the difference
/// would slide the block by an hour.
double minutesIntoDay(DateTime time, DateTime day) {
  final date = DateTime(time.year, time.month, time.day);
  final columnDate = DateTime(day.year, day.month, day.day);
  if (date.isBefore(columnDate)) return 0;
  if (date.isAfter(columnDate)) return _minutesPerDay;
  return (time.hour * 60 + time.minute).toDouble();
}

const double _minutesPerDay = 24 * 60;

/// The hour window the time grid actually draws.
///
/// The settings hold a day window (say 08:00 to 22:00) so the usual day is not
/// mostly empty rows. That window may not *hide* anything though: an event at
/// 06:00 outside it had nowhere to be drawn and the day simply looked empty,
/// which reads as a lost appointment.
///
/// So the drawn window is the settings window widened until it covers every
/// timed item of the days on screen, rounded out to full hours. The setting
/// itself never changes — only the drawing grows.
class DayWindow {
  /// First hour with a row.
  final int startHour;

  /// End of the span, exclusive: 7 to 22 draws fifteen rows and stops at 22:00.
  final int endHour;

  const DayWindow({required this.startHour, required this.endHour});

  /// Last hour that still has a row.
  int get lastHour => endHour - 1;

  /// Number of hour rows.
  int get hourCount => endHour - startHour;

  /// Minutes from midnight the window starts at — the offset every block
  /// position is measured from.
  double get startMinutes => startHour * 60.0;

  /// The settings window [startHour]..[endHour], widened to hold every timed
  /// item of [columnDates].
  factory DayWindow.covering({
    required int startHour,
    required int endHour,
    required List<DateTime> columnDates,
    required List<List<CalendarItem>> itemsByColumn,
  }) {
    var start = startHour.clamp(0, 23);
    var end = endHour.clamp(1, 24);

    for (var col = 0; col < columnDates.length; col++) {
      if (col >= itemsByColumn.length) break;
      final day = columnDates[col];
      for (final item in itemsByColumn[col]) {
        // All-day items live in their own strip above the grid.
        if (item.isAllDay) continue;

        final from = minutesIntoDay(item.startTime, day);
        final to = minutesIntoDay(item.endTime, day);

        // Round out to the full hour, so a 06:03 start still gets the whole
        // 06:00 row and its label.
        final firstHour = (from / 60).floor().clamp(0, 23);
        final lastHour = (to / 60).ceil().clamp(1, 24);

        if (firstHour < start) start = firstHour;
        if (lastHour > end) end = lastHour;
      }
    }

    // A zero-height grid is not a window. Only reachable from a broken
    // setting, but the grid divides by this.
    if (end <= start) end = (start + 1).clamp(1, 24);

    return DayWindow(startHour: start, endHour: end);
  }

  @override
  bool operator ==(Object other) =>
      other is DayWindow &&
      other.startHour == startHour &&
      other.endHour == endHour;

  @override
  int get hashCode => Object.hash(startHour, endHour);

  @override
  String toString() => 'DayWindow($startHour-$endHour)';
}
