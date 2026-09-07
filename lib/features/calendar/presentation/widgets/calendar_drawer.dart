import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../shared/widgets/app_drawer_panel.dart';
import '../../providers/calendar_provider.dart';
import 'ics_feeds_sheet.dart';

/// Side panel of the calendar: which calendars are shown, and the way to add
/// one.
class CalendarDrawer extends ConsumerWidget {
  const CalendarDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarContainerProvider);
    final calendars = state.calendars;

    return AppDrawerPanel(
      title: 'Calendars',
      children: [
        for (var i = 0; i < calendars.length; i++)
          AppDrawerTile(
            icon: calendars[i].isVisible
                ? MdiIcons.checkboxMarked
                : MdiIcons.checkboxBlankOutline,
            iconColor: Color(calendars[i].color),
            label: calendars[i].name,
            isFirst: i == 0,
            isLast: i == calendars.length - 1,
            onTap: () => ref
                .read(calendarContainerProvider.notifier)
                .toggleVisibility(calendars[i].id),
          ),
      ],
      footer: AppDrawerActionTile(
        icon: MdiIcons.calendarSync,
        label: 'Subscribed calendars',
        onTap: () {
          Navigator.pop(context);
          IcsFeedsSheet.show(context);
        },
      ),
    );
  }
}
