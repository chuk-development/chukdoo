import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../settings/presentation/settings_page.dart';
import '../../../todos/presentation/pages/all_tasks_page.dart';
import '../../../todos/presentation/pages/completed_tasks_page.dart';
import '../../../todos/presentation/pages/search_page.dart';
import '../../providers/project_provider.dart';
import 'project_page.dart';

class BrowsePage extends ConsumerWidget {
  const BrowsePage({super.key});

  void _showCreateProjectDialog(BuildContext context, WidgetRef ref) {
    final projectController = TextEditingController();

    void createProject() async {
      final name = projectController.text.trim();
      if (name.isNotEmpty) {
        await ref.read(projectProvider.notifier).addProject(name: name);
        Navigator.pop(context);
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Neues Projekt'),
        content: TextField(
          controller: projectController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Projektname',
          ),
          onSubmitted: (_) => createProject(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: createProject,
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectState = ref.watch(projectProvider);
    final projects = projectState.sortedProjects;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Browsen'),
        actions: [
          IconButton(
            icon: const Icon(SolarIconsOutline.magnifier),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchPage()),
              );
            },
            tooltip: 'Suchen',
          ),
        ],
      ),
      body: ListView(
        children: [
          // Projects section
          _buildSectionHeader('Projekte'),
          _buildMenuItem(
            icon: SolarIconsOutline.inboxLine,
            label: 'Eingang',
            color: AppColors.blue,
            onTap: () {
              // Navigate to inbox (already accessible from bottom nav)
            },
          ),
          // User-created projects
          ...projects.map((project) => _buildMenuItem(
            icon: SolarIconsOutline.folder,
            label: project.name,
            color: Color(project.color),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProjectPage(project: project),
                ),
              );
            },
          )),
          // Add project button
          ListTile(
            leading: Icon(SolarIconsOutline.addCircle, color: AppColors.textSecondary),
            title: Text(
              'Projekt hinzufügen',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            onTap: () => _showCreateProjectDialog(context, ref),
          ),

          const Divider(height: 32),

          // Quick access section
          _buildSectionHeader('Schnellzugriff'),
          _buildMenuItem(
            icon: SolarIconsOutline.clipboardList,
            label: 'Alle Aufgaben',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllTasksPage()),
              );
            },
          ),
          _buildMenuItem(
            icon: SolarIconsOutline.checkCircle,
            label: 'Erledigt',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CompletedTasksPage()),
              );
            },
          ),

          const Divider(height: 32),

          // Settings section
          _buildSectionHeader('Einstellungen'),
          _buildMenuItem(
            icon: SolarIconsOutline.settings,
            label: 'Einstellungen',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
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
        SolarIconsOutline.altArrowRight,
        color: AppColors.textSecondary,
      ),
      onTap: onTap,
    );
  }
}
