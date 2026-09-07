import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/rounded_group.dart';
import '../../../settings/presentation/settings_page.dart';
import '../../../todos/presentation/pages/all_tasks_page.dart';
import '../../../todos/presentation/pages/completed_tasks_page.dart';
import '../../../todos/presentation/pages/search_page.dart';
import '../../../todos/providers/todo_provider.dart';
import '../../domain/models/project.dart';
import '../../providers/project_provider.dart';
import '../widgets/project_edit_dialog.dart';
import 'project_page.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../core/theme/app_shapes.dart';

class BrowsePage extends ConsumerWidget {
  const BrowsePage({super.key});

  int _incompleteCount(TodoState todoState, String projectId) {
    return todoState.todos
        .where((t) => !t.isCompleted && t.projectId == projectId)
        .length;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectState = ref.watch(projectProvider);
    final todoState = ref.watch(todoProvider);
    final projects = projectState.sortedProjects;

    return AppScaffold(
  title: 'Browse',
  actions: [
          Tooltip(
            message: 'Search',
            child: IconButton(
              icon: Icon(MdiIcons.magnify),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchPage()),
                );
              },
            ),
          ),
        ],
  body: ListView(
        padding: EdgeInsets.only(bottom: AppShapes.contentBottom(context)),
        children: [
          // Projects section
          _buildSectionHeader('Projects'),
          RoundedGroup(
            children: [
              _buildMenuItem(
                icon: MdiIcons.inboxOutline,
                label: 'Inbox',
                color: AppColors.blue,
                onTap: () {
                  // Navigate to inbox (already accessible from bottom nav)
                },
              ),
              ...projects.map((project) {
                final count = _incompleteCount(todoState, project.id);
                return _buildProjectItem(
                  context: context,
                  ref: ref,
                  project: project,
                  taskCount: count,
                );
              }),
              ListTile(
                leading: Icon(
                  MdiIcons.plusCircleOutline,
                  color: AppColors.textSecondary,
                ),
                title: Text(
                  'Add project',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                onTap: () => ProjectEditDialog.show(context),
              ),
            ],
          ),

          // Quick access section
          _buildSectionHeader('Quick access'),
          RoundedGroup(
            children: [
              _buildMenuItem(
                icon: MdiIcons.clipboardListOutline,
                label: 'Main',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AllTasksPage()),
                  );
                },
              ),
              _buildMenuItem(
                icon: MdiIcons.checkCircleOutline,
                label: 'Completed',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CompletedTasksPage(),
                    ),
                  );
                },
              ),
            ],
          ),

          // Settings section
          _buildSectionHeader('Settings'),
          RoundedGroup(
            children: [
              _buildMenuItem(
                icon: MdiIcons.cogOutline,
                label: 'Settings',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
              ),
            ],
          ),
        ],
      ),
);
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    Color? color,
    VoidCallback? onTap,
  }) {
    final displayColor = color ?? AppColors.textPrimary;

    return ListTile(
      leading: Icon(icon, color: displayColor),
      title: Text(
        label,
        style: TextStyle(color: displayColor),
      ),
      trailing: Icon(
        MdiIcons.chevronRight,
        color: AppColors.textSecondary,
      ),
      onTap: onTap,
    );
  }

  Widget _buildProjectItem({
    required BuildContext context,
    required WidgetRef ref,
    required Project project,
    required int taskCount,
  }) {
    final projectColor = Color(project.color);

    return ListTile(
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: projectColor,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              project.name,
              style: TextStyle(color: projectColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (taskCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$taskCount',
                style: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
      subtitle: project.description != null && project.description!.isNotEmpty
          ? Text(
              project.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Edit',
            child: IconButton(
              icon: Icon(MdiIcons.pencilOutline, size: 18,
                  color: AppColors.textSecondary),
              onPressed: () async {
                final result =
                    await ProjectEditDialog.show(context, project: project);
                // If deleted (result is null and project no longer exists), no navigation needed
                if (result == null) return;
              },
              visualDensity: VisualDensity.compact,
            ),
          ),
          Icon(
            MdiIcons.chevronRight,
            color: AppColors.textSecondary,
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectPage(project: project),
          ),
        );
      },
    );
  }
}
