import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/calendar_item.dart';
import '../../domain/week_dates.dart';
import '../../providers/calendar_event_provider.dart';
import 'multi_day_view.dart';

/// Week view: the weekday strip on top, then the tiled time grid — the same
/// build Google Calendar uses for a week.
///
/// The grid itself is [MultiDayView]; this only says which seven days it is
/// and that the gutter carries the week number.
class WeekView extends ConsumerWidget {
  /// Any day of the week this page draws — one page of the pager is one week,
  /// so it cannot read the focused date. Null falls back to it.
  final DateTime? date;

  final ValueChanged<({DateTime date, TimeOfDay time})>? onSlotTap;
  final ValueChanged<CalendarItem>? onItemTap;
  final void Function(CalendarItem item, DateTime newStart)? onItemDrop;

  /// Passed straight to the grid: true while two fingers zoom it.
  final ValueChanged<bool>? onZoomingChanged;

  const WeekView({
    super.key,
    this.date,
    this.onSlotTap,
    this.onItemTap,
    this.onItemDrop,
    this.onZoomingChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final focused = date ?? ref.watch(calendarEventProvider).focusedDate;

    return MultiDayView(
      dates: daysFrom(startOfWeek(focused, settings.calendarWeekStart), 7),
      showWeekNumber: settings.calendarShowWeekNumbers,
      onSlotTap: onSlotTap,
      onItemTap: onItemTap,
      onItemDrop: onItemDrop,
      onZoomingChanged: onZoomingChanged,
    );
  }
}
