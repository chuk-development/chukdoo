import 'package:flutter/material.dart';

import '../../../../shared/widgets/connected_group.dart';
import '../../providers/calendar_event_provider.dart';

/// Day / 3 days / Week / Month / Agenda as one connected group — the app's
/// segmented control, slim, with the same corner grading as every other group.
///
/// No icons: with five segments a phone gives each one about 50 logical pixels
/// of text, and an icon plus its gap would take half of that and leave every
/// label as an ellipsis. A readable word beats a decorated stub.
class ViewModeSelector extends StatelessWidget {
  final CalendarViewMode currentMode;
  final ValueChanged<CalendarViewMode> onChanged;

  const ViewModeSelector({
    super.key,
    required this.currentMode,
    required this.onChanged,
  });

  /// The switcher order, which is also the order of [CalendarViewMode].
  static const _modes = [
    CalendarViewMode.day,
    CalendarViewMode.threeDay,
    CalendarViewMode.week,
    CalendarViewMode.month,
    CalendarViewMode.agenda,
  ];

  /// Short enough to fit five segments, and the same word the settings use.
  static String labelOf(CalendarViewMode mode) => switch (mode) {
    CalendarViewMode.day => 'Day',
    CalendarViewMode.threeDay => '3 days',
    CalendarViewMode.week => 'Week',
    CalendarViewMode.month => 'Month',
    CalendarViewMode.agenda => 'Agenda',
  };

  @override
  Widget build(BuildContext context) {
    return ConnectedButtonGroup(
      height: 38,
      selectedIndex: _modes.indexOf(currentMode),
      onSelected: (index) => onChanged(_modes[index]),
      items: [for (final mode in _modes) ConnectedItem(label: labelOf(mode))],
    );
  }
}
