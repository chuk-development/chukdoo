import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/bottom_nav_bar.dart';
import '../../../../shared/widgets/sync_error_banner.dart';
import '../../../../shared/widgets/app_sidebar.dart';
import '../../../sync/presentation/widgets/auto_sync_manager.dart';
import '../../../calendar/presentation/pages/calendar_page.dart';
import '../../../habits/presentation/pages/habits_page.dart';
import '../../../notes/presentation/pages/notes_page.dart';
import '../../../settings/presentation/settings_page.dart';
import '../../../projects/domain/models/project.dart';
import '../../../projects/domain/project_icons.dart';
import '../../../projects/presentation/pages/project_page.dart';
import '../../../projects/presentation/widgets/project_edit_dialog.dart';
import '../../../projects/providers/project_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/todo.dart';
import '../../providers/todo_provider.dart';
import '../../../kanban/presentation/pages/kanban_page.dart';
import 'inbox_page.dart';
import 'todo_detail_page.dart';
import 'today_page.dart';
import 'upcoming_page.dart';
import 'completed_tasks_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String _currentView = 'all';
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
      case 'notes':
        return NavTab.notes;
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
          _currentView = 'all';
        case NavTab.calendar:
          _currentView = 'calendar';
        case NavTab.notes:
          _currentView = 'notes';
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
      case 'notes':
        return NotesPage(embedded: true, onMenu: menu);
      case 'kanban':
        return const KanbanPage(embedded: true);
      case 'project':
        if (_selectedProject != null) {
          return ProjectPage(
            project: _selectedProject!,
            // Mobile shows a hamburger (drawer); desktop embeds without one.
            onMenu: menu,
            // Embedded panel can't pop a route — switch back to the main list.
            onDeleted: () => setState(() {
              _selectedProject = null;
              _currentView = 'all';
            }),
          );
        }
        return const InboxPage(showAll: true);
      case 'settings':
        return const SettingsPage();
      default:
        return const InboxPage(showAll: true);
    }
  }

  void _handleSidebarViewSelected(String view) {
    if (view == 'add_project') {
      ProjectEditDialog.show(context);
      return;
    }
    ref.read(selectedTodoProvider.notifier).state = null;
    setState(() {
      _currentView = view;
    });
  }

  void _handleAddTodo() {
    // Navigate to the main list and let the FAB handle adding
    setState(() {
      _currentView = 'all';
    });
  }

  void _handleProjectTap(dynamic project) {
    // Both mobile and desktop render the project inline in the content area so
    // it looks like the main task screen (bottom nav / drawer stay in place)
    // instead of pushing a separate full-screen route.
    ref.read(selectedTodoProvider.notifier).state = null;
    setState(() {
      _selectedProject = project as Project;
      _currentView = 'project';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AutoSyncManager(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 768;

          if (isDesktop) {
            final selectedTodo = ref.watch(selectedTodoProvider);
            return Scaffold(
              body: Row(
                children: [
                  AppSidebar(
                    currentView: _currentView,
                    onViewSelected: _handleSidebarViewSelected,
                    onAddTodo: _handleAddTodo,
                    onProjectTap: _handleProjectTap,
                  ),
                  Container(width: 1, color: AppColors.divider),
                  Expanded(
                    child: Column(
                      children: [
                        const SyncErrorBanner(),
                        Expanded(child: _buildContent(isDesktop: true)),
                      ],
                    ),
                  ),
                  // Right detail panel (TickTick-style 3rd column) — responsive.
                  // No key here: the panel frame stays mounted so switching
                  // notes does NOT re-animate. The inner page is keyed on the
                  // todo id so its fields reload on switch.
                  if (selectedTodo != null)
                    _DesktopDetailPanel(
                      width: (constraints.maxWidth * 0.32).clamp(420.0, 620.0),
                      todo: selectedTodo,
                      onClose: () =>
                          ref.read(selectedTodoProvider.notifier).state = null,
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
        title: const Text('Rename list'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'List name'),
          onSubmitted: (_) {
            ref.read(settingsProvider.notifier).setMainListName(controller.text);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).setMainListName(controller.text);
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

    return Drawer(
      backgroundColor: AppColors.background,
      // Square edges — no rounded right corners.
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'Chukdoo',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),

            // Main list (renameable) — shows all open tasks
            _DrawerItem(
              icon: MdiIcons.bookmark,
              iconColor: AppColors.primary,
              label: settings.mainListName,
              count: todoState.todos.where((t) => !t.isCompleted).length,
              isSelected: currentView == 'all',
              onTap: () => onViewSelected('all'),
              // Long-press to rename (no edit icon cluttering the row).
              onLongPress: () => _renameMainList(context, ref, settings.mainListName),
            ),
            _DrawerItem(
              icon: MdiIcons.calendarTodayOutline,
              iconColor: AppColors.green,
              label: 'Today',
              count: todoState.todayTodos.length,
              isSelected: currentView == 'today',
              onTap: () => onViewSelected('today'),
            ),
            _DrawerItem(
              // Same calendar icon as the bottom nav's Calendar tab.
              icon: MdiIcons.calendarOutline,
              iconColor: AppColors.blue,
              label: 'Upcoming',
              isSelected: currentView == 'upcoming',
              onTap: () => onViewSelected('upcoming'),
            ),
            _DrawerItem(
              icon: MdiIcons.checkCircleOutline,
              label: 'Completed',
              isSelected: currentView == 'completed',
              onTap: () => onViewSelected('completed'),
            ),
            _DrawerItem(
              icon: MdiIcons.noteMultipleOutline,
              iconColor: AppColors.orange,
              label: 'Notes',
              isSelected: currentView == 'notes',
              onTap: () => onViewSelected('notes'),
            ),

            const Divider(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'PROJECTS',
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
              leading: Icon(MdiIcons.plusCircleOutline, color: AppColors.primary),
              title: Text('New Project', style: TextStyle(color: AppColors.primary)),
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
  final VoidCallback? onLongPress;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.iconColor,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      // Clip the ListTile ink to the rounded pill so the tap highlight isn't square.
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        trailing: count != null && count! > 0
            ? Text('$count', style: TextStyle(fontSize: 13, color: AppColors.textTertiary))
            : null,
        onTap: onTap,
        onLongPress: onLongPress,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ListTile(
        dense: true,
        // Rounded ink highlight, matching _DrawerItem.
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(projectIconFor(project.icon), size: 20, color: projectColor),
        title: Text(project.name, style: const TextStyle(fontSize: 15), overflow: TextOverflow.ellipsis),
        trailing: count > 0
            ? Text('$count', style: TextStyle(fontSize: 13, color: AppColors.textTertiary))
            : null,
        onTap: onTap,
      ),
    );
  }
}

/// Desktop right-hand detail panel: responsive width. The frame stays mounted
/// across note switches (no slide-in re-animation); only the inner page swaps,
/// keyed on the todo id so its fields reload.
class _DesktopDetailPanel extends StatelessWidget {
  final double width;
  final Todo todo;
  final VoidCallback onClose;

  const _DesktopDetailPanel({
    required this.width,
    required this.todo,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 1, color: AppColors.divider),
        SizedBox(
          width: width,
          child: TodoDetailPage(
            key: ValueKey(todo.id),
            todo: todo,
            onClose: onClose,
          ),
        ),
      ],
    );
  }
}
