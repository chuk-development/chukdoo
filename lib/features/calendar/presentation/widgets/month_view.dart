import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/calendar_item.dart';
import '../../providers/calendar_event_provider.dart';
import '../../providers/calendar_items_provider.dart';
import 'month_grid.dart';

/// The month view — only the wiring.
///
/// It hands [MonthGrid] the user's settings and the items of a day and writes
/// back what the grid reports; the grid, its pager and its pinch zoom are
/// there. The same split the day/week side has between `TimeModeView` and its
/// grid, and it is what keeps the grid testable without a settings box.
class MonthView extends ConsumerWidget {
  final ValueChanged<DateTime>? onDayTap;
  final ValueChanged<CalendarItem>? onItemTap;

  const MonthView({super.key, this.onDayTap, this.onItemTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarItems = ref.watch(calendarItemsProvider);
    final settings = ref.watch(settingsProvider);
    final eventState = ref.watch(calendarEventProvider);
    final notifier = ref.read(calendarEventProvider.notifier);

    return MonthGrid(
      weekStart: settings.calendarWeekStart,
      focusedDate: eventState.focusedDate,
      onFocusedDateChanged: notifier.setFocusedDate,
      itemsForDay: calendarItems.itemsForDay,
      showWeekNumber: settings.calendarShowWeekNumbers,
      // Null is "fit the six rows to the screen" — the default until the user
      // pinches.
      rowHeight: settings.calendarMonthRowHeight,
      onRowHeightChanged: ref
          .read(settingsProvider.notifier)
          .setCalendarMonthRowHeight,
      onDayTap: onDayTap,
      onItemTap: onItemTap,
    );
  }
}
