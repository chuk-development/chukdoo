import 'package:flutter/material.dart';

import '../../domain/models/calendar_item.dart';
import '../../domain/week_dates.dart';
import 'multi_day_view.dart';

/// Google Calendar's "3 Day": the focused day and the two days after it.
///
/// The focused day is the LEFT column on purpose — the view answers "what is
/// coming", so centring the day would waste a third of the screen on a day
/// that is already over.
class ThreeDayView extends StatelessWidget {
  /// The left column, and the day one page of the pager starts on. Null is
  /// not allowed here: unlike the week, three days have no period the view
  /// could derive from a focused date on its own.
  final DateTime date;

  final ValueChanged<({DateTime date, TimeOfDay time})>? onSlotTap;
  final ValueChanged<CalendarItem>? onItemTap;
  final void Function(CalendarItem item, DateTime newStart)? onItemDrop;

  /// Passed straight to the grid: true while two fingers zoom it.
  final ValueChanged<bool>? onZoomingChanged;

  const ThreeDayView({
    super.key,
    required this.date,
    this.onSlotTap,
    this.onItemTap,
    this.onItemDrop,
    this.onZoomingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MultiDayView(
      dates: daysFrom(dayStart(date), threeDayColumns),
      onSlotTap: onSlotTap,
      onItemTap: onItemTap,
      onItemDrop: onItemDrop,
      onZoomingChanged: onZoomingChanged,
    );
  }
}
