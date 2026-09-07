import '../../../calendar/domain/models/calendar_item.dart';

/// Layout info for positioning an event in the time grid
class EventLayoutInfo {
  final CalendarItem item;
  final int column;
  final int totalColumns;

  const EventLayoutInfo({
    required this.item,
    required this.column,
    required this.totalColumns,
  });

  /// Fraction of the day column width this event should take
  double get widthFraction => 1.0 / totalColumns;

  /// Left offset as fraction of day column width
  double get leftFraction => column * widthFraction;
}

/// Calculates layout positions for overlapping events (Google Calendar algorithm).
///
/// 1. Sort events by start time, then by duration (longest first)
/// 2. Find overlapping groups
/// 3. Within each group, assign columns (first-fit)
/// 4. Divide available width by max columns in group
class EventLayoutCalculator {
  const EventLayoutCalculator._();

  static List<EventLayoutInfo> calculateLayout(List<CalendarItem> items) {
    if (items.isEmpty) return [];

    // Sort by start time, then longest duration first
    final sorted = List<CalendarItem>.from(items)
      ..sort((a, b) {
        final startCompare = a.startTime.compareTo(b.startTime);
        if (startCompare != 0) return startCompare;
        // Longer events first
        return b.endTime.compareTo(a.endTime);
      });

    // Find overlapping groups
    final groups = <List<CalendarItem>>[];
    var currentGroup = <CalendarItem>[sorted.first];
    var groupEnd = sorted.first.endTime;

    for (var i = 1; i < sorted.length; i++) {
      final item = sorted[i];
      if (item.startTime.isBefore(groupEnd)) {
        currentGroup.add(item);
        if (item.endTime.isAfter(groupEnd)) {
          groupEnd = item.endTime;
        }
      } else {
        groups.add(currentGroup);
        currentGroup = [item];
        groupEnd = item.endTime;
      }
    }
    groups.add(currentGroup);

    // Assign columns within each group
    final results = <EventLayoutInfo>[];

    for (final group in groups) {
      final columns = <int, CalendarItem>{};
      final assignments = <CalendarItem, int>{};

      for (final item in group) {
        // Find first available column
        var col = 0;
        while (true) {
          final existing = columns[col];
          if (existing == null || !_overlaps(existing, item)) {
            columns[col] = item;
            assignments[item] = col;
            break;
          }
          col++;
        }
      }

      final totalColumns = columns.length;
      for (final item in group) {
        results.add(
          EventLayoutInfo(
            item: item,
            column: assignments[item]!,
            totalColumns: totalColumns,
          ),
        );
      }
    }

    return results;
  }

  static bool _overlaps(CalendarItem a, CalendarItem b) {
    return a.startTime.isBefore(b.endTime) && b.startTime.isBefore(a.endTime);
  }
}
