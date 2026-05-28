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

  Widget _buildContent() {
    switch (_currentView) {
      case 'all':
        return const InboxPage(showAll: true);
      case 'inbox':
        return const InboxPage();
      case 'today':
        return const TodayPage();
      case 'upcoming':
        return const UpcomingPage();
      case 'completed':
        return const CompletedTasksPage();
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
                        Expanded(child: _buildContent()),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // Mobile layout (unchanged)
          return Scaffold(
            key: _scaffoldKey,
            drawer: const _ProjectDrawer(),
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

class _ProjectDrawer extends ConsumerWidget {
  const _ProjectDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectState = ref.watch(projectProvider);
    final todoState = ref.watch(todoProvider);
    final projects = projectState.sortedProjects;

    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Projekte',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  ...projects.map((project) {
                    final count = todoState.todos
                        .where((t) => !t.isCompleted && t.projectId == project.id)
                        .length;
                    return _ProjectTile(project: project, count: count);
                  }),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(SolarIconsOutline.addCircle, color: AppColors.primary),
              title: Text('Neues Projekt', style: TextStyle(color: AppColors.primary)),
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

class _ProjectTile extends StatelessWidget {
  final Project project;
  final int count;

  const _ProjectTile({required this.project, required this.count});

  @override
  Widget build(BuildContext context) {
    final projectColor = Color(project.color);

    return ListTile(
      leading: Container(
        width: 12, height: 12,
        decoration: BoxDecoration(
          color: projectColor,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      title: Text(
        project.name,
        style: const TextStyle(fontSize: 15),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: project.description != null && project.description!.isNotEmpty
          ? Text(
              project.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            )
          : null,
      trailing: count > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: projectColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: projectColor),
              ),
            )
          : null,
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProjectPage(project: project)),
        );
      },
    );
  }
}
