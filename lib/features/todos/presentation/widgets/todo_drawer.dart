import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_drawer_panel.dart';
import '../../../projects/domain/project_icons.dart';
import '../../../projects/presentation/widgets/project_edit_dialog.dart';
import '../../../projects/providers/project_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/todo_provider.dart';

/// Side panel of the to-do section: the fixed lists on top, the projects
/// under them.
class TodoDrawer extends ConsumerWidget {
  final String currentView;
  final ValueChanged<String> onViewSelected;
  final void Function(dynamic project) onProjectTap;

  const TodoDrawer({
    super.key,
    required this.currentView,
    required this.onViewSelected,
    required this.onProjectTap,
  });

  void _renameMainList(BuildContext context, WidgetRef ref, String current) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rename list'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'List name'),
          onSubmitted: (_) {
            ref
                .read(settingsProvider.notifier)
                .setMainListName(controller.text);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(settingsProvider.notifier)
                  .setMainListName(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectState = ref.watch(projectProvider);
    final todoState = ref.watch(todoProvider);
    final settings = ref.watch(settingsProvider);
    final projects = projectState.sortedProjects;

    return AppDrawerPanel(
      title: 'Chukdoo',
      header: [
        AppDrawerTile(
          icon: MdiIcons.bookmark,
          iconColor: AppColors.primary,
          label: settings.mainListName,
          count: todoState.inboxTodos.length,
          isSelected: currentView == 'all',
          isFirst: true,
          isLast: false,
          onTap: () => onViewSelected('all'),
          // Long-press to rename (no edit icon cluttering the row).
          onLongPress: () =>
              _renameMainList(context, ref, settings.mainListName),
        ),
        AppDrawerTile(
          icon: MdiIcons.calendarTodayOutline,
          iconColor: AppColors.green,
          label: 'Today',
          isFirst: false,
          isLast: false,
          count: todoState.todayTodos.length,
          isSelected: currentView == 'today',
          onTap: () => onViewSelected('today'),
        ),
        AppDrawerTile(
          icon: MdiIcons.calendarOutline,
          iconColor: AppColors.blue,
          label: 'Upcoming',
          isFirst: false,
          isLast: false,
          isSelected: currentView == 'upcoming',
          onTap: () => onViewSelected('upcoming'),
        ),
        AppDrawerTile(
          icon: MdiIcons.checkCircleOutline,
          label: 'Completed',
          isFirst: false,
          isLast: true,
          isSelected: currentView == 'completed',
          onTap: () => onViewSelected('completed'),
        ),
        const AppDrawerSection(label: 'Projects'),
      ],
      children: [
        for (var i = 0; i < projects.length; i++)
          AppDrawerTile(
            icon: projectIconFor(projects[i].icon),
            iconColor: Color(projects[i].color),
            label: projects[i].name,
            count: todoState.todos
                .where((t) => !t.isCompleted && t.projectId == projects[i].id)
                .length,
            isFirst: i == 0,
            isLast: i == projects.length - 1,
            onTap: () => onProjectTap(projects[i]),
          ),
      ],
      footer: AppDrawerActionTile(
        icon: MdiIcons.plusCircleOutline,
        label: 'New project',
        onTap: () {
          Navigator.pop(context);
          ProjectEditDialog.show(context);
        },
      ),
    );
  }
}
