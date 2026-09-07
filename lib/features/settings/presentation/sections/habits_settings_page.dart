import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/rounded_group.dart';
import '../../providers/settings_provider.dart';
import '../widgets/settings_sheets.dart';
import '../widgets/settings_tiles.dart';

/// Week shape, the daily nudge and what a skipped day does to a streak.
class HabitsSettingsPage extends ConsumerWidget {
  const HabitsSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final reminder = settings.habitReminderMinutes;

    return SettingsSubPage(
      title: 'Habits',
      children: [
        const SettingsSectionHeader('Week'),
        RoundedGroup(
          children: [
            SettingsNavTile(
              icon: MdiIcons.calendarWeekBeginOutline,
              title: 'First day of week',
              value: settings.habitWeekStart.label,
              onTap: () => pickWeekStart(
                context,
                current: settings.habitWeekStart,
                onPicked: notifier.setHabitWeekStart,
              ),
            ),
          ],
        ),

        const SettingsSectionHeader('Reminder'),
        RoundedGroup(
          children: [
            SettingsNavTile(
              icon: reminder == null
                  ? MdiIcons.bellOffOutline
                  : MdiIcons.bellRingOutline,
              title: 'Daily reminder',
              value: reminder == null ? 'Off' : formatTimeOfDay(reminder),
              onTap: () => _pickReminder(context, ref, reminder),
            ),
            if (reminder != null)
              ListTile(
                leading: Icon(
                  MdiIcons.bellCancelOutline,
                  color: AppColors.textSecondary,
                ),
                title: const Text('Turn the reminder off'),
                onTap: () => notifier.setHabitReminderMinutes(null),
              ),
          ],
        ),

        const SettingsSectionHeader('Streaks'),
        RoundedGroup(
          children: [
            SettingsSwitchTile(
              icon: MdiIcons.fire,
              title: 'A skipped day keeps the streak',
              subtitle: settings.habitSkipKeepsStreak
                  ? 'A day you mark as skipped does not break the streak'
                  : 'Every missed day resets the streak to zero',
              value: settings.habitSkipKeepsStreak,
              onChanged: notifier.setHabitSkipKeepsStreak,
            ),
          ],
        ),
      ],
    );
  }

  /// The time picker every other part of the app uses, themed by
  /// `app_theme.dart`.
  Future<void> _pickReminder(
    BuildContext context,
    WidgetRef ref,
    int? current,
  ) async {
    final initial = current == null
        ? const TimeOfDay(hour: 20, minute: 0)
        : TimeOfDay(hour: current ~/ 60, minute: current % 60);

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;

    await ref
        .read(settingsProvider.notifier)
        .setHabitReminderMinutes(picked.hour * 60 + picked.minute);
  }
}
