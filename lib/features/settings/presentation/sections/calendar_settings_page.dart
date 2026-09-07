import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../shared/widgets/picker_sheet.dart';
import '../../../../shared/widgets/rounded_group.dart';
import '../../providers/settings_provider.dart';
import '../widgets/settings_sheets.dart';
import '../widgets/settings_tiles.dart';

/// Everything the calendar tab opens with: its view, its week, its day grid
/// and the defaults a new event inherits.
class CalendarSettingsPage extends ConsumerWidget {
  const CalendarSettingsPage({super.key});

  /// Lengths offered for a new event. Anything else is set per event.
  static const List<int> _durations = [15, 30, 45, 60, 90, 120, 180, 240];

  /// Lead times offered for the default reminder. `null` = no reminder.
  static const List<int?> _reminders = [null, 0, 5, 10, 15, 30, 60, 120, 1440];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return SettingsSubPage(
      title: 'Calendar',
      children: [
        const SettingsSectionHeader('View'),
        RoundedGroup(
          children: [
            SettingsNavTile(
              icon: MdiIcons.calendarMonthOutline,
              title: 'Default view',
              value: settings.calendarDefaultView.label,
              onTap: () async {
                final picked = await showPickerSheet<CalendarDefaultView>(
                  context: context,
                  title: 'Default view',
                  options: [
                    for (final view in CalendarDefaultView.values)
                      PickerOption(
                        value: view,
                        label: view.label,
                        icon: _viewIcon(view),
                        selected: view == settings.calendarDefaultView,
                      ),
                  ],
                );
                if (picked != null) notifier.setCalendarDefaultView(picked);
              },
            ),
            SettingsNavTile(
              icon: MdiIcons.calendarWeekBeginOutline,
              title: 'First day of week',
              value: settings.calendarWeekStart.label,
              onTap: () => pickWeekStart(
                context,
                current: settings.calendarWeekStart,
                onPicked: notifier.setCalendarWeekStart,
              ),
            ),
            SettingsSwitchTile(
              icon: MdiIcons.numeric,
              title: 'Week numbers',
              subtitle: 'Show the ISO week number in the week and month grid',
              value: settings.calendarShowWeekNumbers,
              onChanged: notifier.setCalendarShowWeekNumbers,
            ),
          ],
        ),

        const SettingsSectionHeader('Day grid'),
        RoundedGroup(
          children: [
            SettingsNavTile(
              icon: MdiIcons.weatherSunsetUp,
              title: 'Grid starts at',
              value: formatHour(settings.calendarDayStartHour),
              onTap: () async {
                final picked = await _pickHour(
                  context,
                  title: 'Grid starts at',
                  hours: List.generate(24, (i) => i),
                  current: settings.calendarDayStartHour,
                );
                if (picked != null) {
                  notifier.setCalendarDayHours(startHour: picked);
                }
              },
            ),
            SettingsNavTile(
              icon: MdiIcons.weatherSunsetDown,
              title: 'Grid ends at',
              value: formatHour(settings.calendarDayEndHour),
              onTap: () async {
                final picked = await _pickHour(
                  context,
                  title: 'Grid ends at',
                  hours: List.generate(24, (i) => i + 1),
                  current: settings.calendarDayEndHour,
                );
                if (picked != null) {
                  notifier.setCalendarDayHours(endHour: picked);
                }
              },
            ),
          ],
        ),
        const SettingsFootnote(
          'Events outside these hours stay visible — the grid only scrolls to '
          'this range first.',
        ),

        const SettingsSectionHeader('New events'),
        RoundedGroup(
          children: [
            SettingsNavTile(
              icon: MdiIcons.timerOutline,
              title: 'Default duration',
              value: formatMinutes(settings.calendarDefaultEventMinutes),
              onTap: () async {
                final picked = await showPickerSheet<int>(
                  context: context,
                  title: 'Default duration',
                  options: [
                    for (final minutes in _durations)
                      PickerOption(
                        value: minutes,
                        label: formatMinutes(minutes),
                        icon: MdiIcons.timerOutline,
                        selected:
                            minutes == settings.calendarDefaultEventMinutes,
                      ),
                  ],
                );
                if (picked != null) {
                  notifier.setCalendarDefaultEventMinutes(picked);
                }
              },
            ),
            SettingsNavTile(
              icon: MdiIcons.bellOutline,
              title: 'Default reminder',
              value: formatLeadTime(settings.calendarDefaultReminderMinutes),
              onTap: () async {
                // A sentinel instead of null, so a dismissed sheet ("no
                // choice") stays different from the "None" option.
                const noneSentinel = -1;
                final picked = await showPickerSheet<int>(
                  context: context,
                  title: 'Default reminder',
                  options: [
                    for (final minutes in _reminders)
                      PickerOption(
                        value: minutes ?? noneSentinel,
                        label: formatLeadTime(minutes),
                        icon: minutes == null
                            ? MdiIcons.bellOffOutline
                            : MdiIcons.bellOutline,
                        selected:
                            minutes == settings.calendarDefaultReminderMinutes,
                      ),
                  ],
                );
                if (picked != null) {
                  notifier.setCalendarDefaultReminderMinutes(
                    picked == noneSentinel ? null : picked,
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  static IconData _viewIcon(CalendarDefaultView view) => switch (view) {
    CalendarDefaultView.day => MdiIcons.calendarTodayOutline,
    CalendarDefaultView.week => MdiIcons.calendarWeekOutline,
    CalendarDefaultView.month => MdiIcons.calendarMonthOutline,
    CalendarDefaultView.agenda => MdiIcons.formatListBulleted,
  };

  static Future<int?> _pickHour(
    BuildContext context, {
    required String title,
    required List<int> hours,
    required int current,
  }) {
    return showPickerSheet<int>(
      context: context,
      title: title,
      options: [
        for (final hour in hours)
          PickerOption(
            value: hour,
            label: formatHour(hour),
            icon: MdiIcons.clockOutline,
            selected: hour == current,
          ),
      ],
    );
  }
}
