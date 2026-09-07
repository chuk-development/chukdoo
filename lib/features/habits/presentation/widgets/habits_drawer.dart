import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../shared/widgets/app_drawer_panel.dart';
import '../../providers/habit_provider.dart';

/// Side panel of the habits section: which habits the page lists.
class HabitsDrawer extends ConsumerWidget {
  const HabitsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitProvider).habits;
    final filter = ref.watch(habitFilterProvider);

    void select(HabitFilter value) {
      ref.read(habitFilterProvider.notifier).state = value;
      Navigator.pop(context);
    }

    return AppDrawerPanel(
      title: 'Habits',
      header: [
        AppDrawerTile(
          icon: MdiIcons.trophyOutline,
          label: 'All habits',
          count: habits.length,
          isSelected: filter == HabitFilter.all,
          isFirst: true,
          isLast: false,
          onTap: () => select(HabitFilter.all),
        ),
        AppDrawerTile(
          icon: MdiIcons.calendarTodayOutline,
          label: 'Daily',
          count: habits.where((h) => h.frequency == 'daily').length,
          isSelected: filter == HabitFilter.daily,
          isFirst: false,
          isLast: false,
          onTap: () => select(HabitFilter.daily),
        ),
        AppDrawerTile(
          icon: MdiIcons.calendarWeekOutline,
          label: 'Weekly',
          count: habits.where((h) => h.frequency == 'weekly').length,
          isSelected: filter == HabitFilter.weekly,
          isFirst: false,
          isLast: true,
          onTap: () => select(HabitFilter.weekly),
        ),
        const AppDrawerSection(label: 'Streaks'),
      ],
      children: [
        for (var i = 0; i < habits.length; i++)
          AppDrawerTile(
            icon: MdiIcons.fire,
            iconColor: Color(habits[i].color),
            label: habits[i].name,
            count: habits[i].streak,
            isFirst: i == 0,
            isLast: i == habits.length - 1,
            onTap: () => Navigator.pop(context),
          ),
      ],
    );
  }
}
