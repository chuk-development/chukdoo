import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../shared/widgets/connected_group.dart';
import '../../providers/calendar_event_provider.dart';

/// Day / Week / Month / Agenda as one connected group — the app's segmented
/// control, slim, with the same corner grading as every other group.
class ViewModeSelector extends StatelessWidget {
  final CalendarViewMode currentMode;
  final ValueChanged<CalendarViewMode> onChanged;

  const ViewModeSelector({
    super.key,
    required this.currentMode,
    required this.onChanged,
  });

  static const _modes = [
    CalendarViewMode.day,
    CalendarViewMode.week,
    CalendarViewMode.month,
    CalendarViewMode.agenda,
  ];

  @override
  Widget build(BuildContext context) {
    return ConnectedButtonGroup(
      height: 38,
      selectedIndex: _modes.indexOf(currentMode),
      onSelected: (index) => onChanged(_modes[index]),
      items: [
        ConnectedItem(label: 'Day', icon: MdiIcons.calendarToday),
        ConnectedItem(label: 'Week', icon: MdiIcons.calendarWeek),
        ConnectedItem(label: 'Month', icon: MdiIcons.calendarMonth),
        ConnectedItem(label: 'Agenda', icon: MdiIcons.formatListBulleted),
      ],
    );
  }
}
