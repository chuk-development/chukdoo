import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/bottom_nav_bar.dart';
import '../../../../shared/widgets/sync_error_banner.dart';
import '../../../../shared/widgets/app_sidebar.dart';
import '../../../sync/presentation/widgets/auto_sync_manager.dart';
import '../../../calendar/presentation/pages/calendar_page.dart';
import '../../../habits/presentation/pages/habits_page.dart';
import '../../../settings/presentation/settings_page.dart';
import '../../../projects/domain/models/project.dart';
import '../../../projects/presentation/pages/project_page.dart';
import '../../../projects/presentation/widgets/project_edit_dialog.dart';
import '../../../projects/providers/project_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/todo_provider.dart';
import '../../../kanban/presentation/pages/kanban_page.dart';
import 'inbox_page.dart';
import 'today_page.dart';
import 'upcoming_page.dart';
import 'completed_tasks_page.dart';
import 'search_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String _currentView = 'inbox';
  Project? _selectedProject;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Map NavTab to view string for mobile
  NavTab get _currentTab {
    switch (_currentView) {
      case 'all':
      case 'inbox':
      case 'today':
      case 'upcoming':
      case 'completed':
        return NavTab.inbox;
      case 'calendar':
        return NavTab.calendar;
      case 'habits':
        return NavTab.habits;
      case 'settings':
        return NavTab.more;
      default:
        return NavTab.inbox;
    }
  }

  void _onTabSelected(NavTab tab) {
    setState(() {
      switch (tab) {
        case NavTab.inbox:
          _currentView = 'inbox';
        case NavTab.calendar:
          _currentView = 'calendar';
        case NavTab.habits:
          _currentView = 'habits';
        case NavTab.more:
          _currentView = 'settings';
      }
    });
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  Widget _buildContent({bool isDesktop = false}) {
    final menu = isDesktop ? null : _openDrawer;
    switch (_currentView) {
      case 'all':
        return InboxPage(showAll: true, onMenu: menu);
      case 'inbox':
        return InboxPage(onMenu: menu);
      case 'today':
        return TodayPage(onMenu: menu);
      case 'upcoming':
        return UpcomingPage(onMenu: menu);
      case 'completed':
        return CompletedTasksPage(onMenu: menu);
      case 'calendar':
        return const CalendarPage(embedded: true);
      case 'habits':
        return const HabitsPage(embedded: true);
      case 'kanban':
        return const KanbanPage(embedded: true);
      case 'project':
        if (_selectedProject != null) {
          return ProjectPage(project: _selectedProject!);
        }
        return const InboxPage();
      case 'settings':
        return const SettingsPage();
      default:
        return const InboxPage();
    }
  }

  void _handleSidebarViewSelected(String view) {
    if (view == 'add_project') {
      ProjectEditDialog.show(context);
      return;
    }
    setState(() {
      _currentView = view;
    });
  }

  void _handleAddTodo() {
    // Navigate to inbox and let the FAB handle adding
    setState(() {
      _currentView = 'inbox';
    });
  }

  void _handleSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchPage()),
    );
  }

  void _handleProjectTap(dynamic project) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    if (isDesktop) {
      setState(() {
        _selectedProject = project as Project;
        _currentView = 'project';
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProjectPage(project: project as Project)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AutoSyncManager(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 768;

          if (isDesktop) {
            return Scaffold(
              body: Row(
                children: [
                  AppSidebar(
                    currentView: _currentView,
                    onViewSelected: _handleSidebarViewSelected,
                    onAddTodo: _handleAddTodo,
                    onSearch: _handleSearch,
                    onProjectTap: _handleProjectTap,
                  ),
                  Container(
                    width: 1,
                    color: AppColors.divider,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const SyncErrorBanner(),
                        Expanded(child: _buildContent(isDesktop: true)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // Mobile layout
          return Scaffold(
            key: _scaffoldKey,
            drawer: _MobileDrawer(
              currentView: _currentView,
              onViewSelected: (view) {
                Navigator.pop(context);
                _handleSidebarViewSelected(view);
              },
              onProjectTap: (project) {
                Navigator.pop(context);
                _handleProjectTap(project);
              },
            ),
            body: Column(
              children: [
                const SyncErrorBanner(),
                Expanded(child: _buildContent()),
              ],
            ),
            bottomNavigationBar: ChukdooBottomNavBar(
              currentTab: _currentTab,
              onTabSelected: _onTabSelected,
            ),
          );
        },
      ),
    );
  }
}

/// Mobile navigation drawer — lists (main + smart) and projects.
class _MobileDrawer extends ConsumerWidget {
  final String currentView;
  final ValueChanged<String> onViewSelected;
  final void Function(dynamic project) onProjectTap;

  const _MobileDrawer({
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
        title: const Text('Liste umbenennen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name der Liste'),
          onSubmitted: (_) {
            ref.read(settingsProvider.notifier).setMainListName(controller.text);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).setMainListName(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Speichern'),
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

    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'Chukdoo',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),

            // Main list (renameable)
            _DrawerItem(
              icon: SolarIconsBold.bookmark,
              iconColor: AppColors.primary,
              label: settings.mainListName,
              count: todoState.inboxTodos.length,
              isSelected: currentView == 'inbox',
              onTap: () => onViewSelected('inbox'),
              trailing: IconButton(
                icon: const Icon(SolarIconsOutline.pen, size: 16, color: AppColors.textTertiary),
                tooltip: 'Umbenennen',
                onPressed: () => _renameMainList(context, ref, settings.mainListName),
              ),
            ),
            _DrawerItem(
              icon: SolarIconsOutline.sun,
              iconColor: AppColors.green,
              label: 'Heute',
              count: todoState.todayTodos.length,
              isSelected: currentView == 'today',
              onTap: () => onViewSelected('today'),
            ),
            _DrawerItem(
              icon: SolarIconsOutline.calendarMark,
              iconColor: AppColors.blue,
              label: 'Demnächst',
              isSelected: currentView == 'upcoming',
              onTap: () => onViewSelected('upcoming'),
            ),
            _DrawerItem(
              icon: SolarIconsOutline.inbox,
              label: 'Alle',
              count: todoState.todos.where((t) => !t.isCompleted).length,
              isSelected: currentView == 'all',
              onTap: () => onViewSelected('all'),
            ),
            _DrawerItem(
              icon: SolarIconsOutline.checkCircle,
              label: 'Erledigt',
              isSelected: currentView == 'completed',
              onTap: () => onViewSelected('completed'),
            ),

            const Divider(height: 16),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'PROJEKTE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: AppColors.textTertiary),
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: projects.map((project) {
                  final count = todoState.todos
                      .where((t) => !t.isCompleted && t.projectId == project.id)
                      .length;
                  return _DrawerProjectTile(
                    project: project,
                    count: count,
                    onTap: () => onProjectTap(project),
                  );
                }).toList(),
              ),
            ),

            const Divider(height: 1),
            ListTile(
              leading: const Icon(SolarIconsOutline.addCircle, color: AppColors.primary),
              title: const Text('Neues Projekt', style: TextStyle(color: AppColors.primary)),
              onTap: () {
                Navigator.pop(context);
                ProjectEditDialog.show(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? trailing;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.iconColor,
    this.count,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, size: 20, color: isSelected ? AppColors.primary : (iconColor ?? AppColors.textSecondary)),
        title: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: trailing ??
            (count != null && count! > 0
                ? Text('$count', style: const TextStyle(fontSize: 13, color: AppColors.textTertiary))
                : null),
        onTap: onTap,
      ),
    );
  }
}

class _DrawerProjectTile extends StatelessWidget {
  final Project project;
  final int count;
  final VoidCallback onTap;

  const _DrawerProjectTile({required this.project, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final projectColor = Color(project.color);

    return ListTile(
      dense: true,
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: projectColor, borderRadius: BorderRadius.circular(3)),
      ),
      title: Text(project.name, style: const TextStyle(fontSize: 15), overflow: TextOverflow.ellipsis),
      trailing: count > 0
          ? Text('$count', style: const TextStyle(fontSize: 13, color: AppColors.textTertiary))
          : null,
      onTap: onTap,
    );
  }
}
