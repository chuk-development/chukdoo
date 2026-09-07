import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
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
  /// True while the user scrolls down: the nav bar folds its labels away.
  bool _navCollapsed = false;

  /// +1 when the next tab lies to the right, -1 when it lies to the left.
  int _pageDir = 1;

  /// Only the bottom nav animates. Picking a view in the drawer swaps the page
  /// instantly — an animation there just delays the result.
  bool _animatePage = true;

  String _currentView = 'all';
  Project? _selectedProject;

  /// Views visited before the current one. The system back gesture walks this
  /// stack instead of closing the app on the first swipe.
  final List<({String view, Project? project})> _viewHistory = [];
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

  /// Remember the current view so back can return to it.
  void _pushHistory() {
    _viewHistory.add((view: _currentView, project: _selectedProject));
    // A tab loop must not grow without bound.
    if (_viewHistory.length > 20) _viewHistory.removeAt(0);
  }

  /// Step back to the previous view. Returns false when there is none left,
  /// which lets the system close the app.
  bool _goBack() {
    if (_viewHistory.isEmpty) return false;
    final previous = _viewHistory.removeLast();
    setState(() {
      _pageDir = -1;
      _currentView = previous.view;
      _selectedProject = previous.project;
    });
    return true;
  }

  void _onTabSelected(NavTab tab) {
    // Remember which way the new page comes from, so the views read as sheets
    // lying next to each other.
    _pageDir = tab.tabIndex >= _currentTab.tabIndex ? 1 : -1;
    _animatePage = true;
    _pushHistory();
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
        return CalendarPage(embedded: true, onMenu: menu);
      case 'habits':
        return HabitsPage(embedded: true, onMenu: menu);
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
    _animatePage = false;
    _pushHistory();
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
    _animatePage = false;
    _pushHistory();
    setState(() {
      _selectedProject = project as Project;
      _currentView = 'project';
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The shell has no routes of its own, so the back gesture has to walk
      // the view history instead of leaving the app on the first swipe.
      canPop: _viewHistory.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: AutoSyncManager(
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
            // The bar is a floating pill: content keeps running underneath it
            // while every page gets its height added to the bottom inset, so
            // nothing important can hide behind it.
            extendBody: true,
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
            // Scaffold already adds the bar's height to the body's bottom
            // inset when extendBody is on, so nothing is injected here — doing
            // it twice left a dead strip above the bar.
            body: NotificationListener<UserScrollNotification>(
              onNotification: (notification) {
                // Scrolling down folds the labels away, scrolling up brings
                // them back.
                if (notification.direction == ScrollDirection.reverse &&
                    !_navCollapsed) {
                  setState(() => _navCollapsed = true);
                } else if (notification.direction == ScrollDirection.forward &&
                    _navCollapsed) {
                  setState(() => _navCollapsed = false);
                }
                return false;
              },
              child: Column(
                children: [
                  const SyncErrorBanner(),
                  // Tabs are pages lying next to each other: the new page
                  // slides in from the side you moved towards, the old one
                  // slides out the other way.
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: _animatePage
                          ? const Duration(milliseconds: 260)
                          : Duration.zero,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final key = ValueKey(
                          '$_currentView-${_selectedProject?.id ?? ''}',
                        );
                        final incoming = child.key == key;
                        final dx = _pageDir.toDouble();
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(incoming ? dx : -dx, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        );
                      },
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previousChildren, ?currentChild],
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(
                          '$_currentView-${_selectedProject?.id ?? ''}',
                        ),
                        child: _buildContent(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: ChukdooBottomNavBar(
              currentTab: _currentTab,
              collapsed: _navCollapsed,
              onTabSelected: _onTabSelected,
            ),
          );
        },
      ),
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

    // A floating panel, not an edge-to-edge sheet: same rounded, inset block
    // language as the quick-add dock, just coming in from the left.
    return Drawer(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      width: MediaQuery.of(context).size.width * 0.84,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppShapes.dockMargin,
          AppShapes.dockMargin,
          0,
          AppShapes.dockMargin,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppShapes.sheetTop),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
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
              count: todoState.inboxTodos.length,
              isSelected: currentView == 'all',
              isFirst: true,
              isLast: false,
              onTap: () => onViewSelected('all'),
              // Long-press to rename (no edit icon cluttering the row).
              onLongPress: () => _renameMainList(context, ref, settings.mainListName),
            ),
            _DrawerItem(
              icon: MdiIcons.calendarTodayOutline,
              iconColor: AppColors.green,
              label: 'Today',
              isFirst: false,
              isLast: false,
              count: todoState.todayTodos.length,
              isSelected: currentView == 'today',
              onTap: () => onViewSelected('today'),
            ),
            _DrawerItem(
              // Same calendar icon as the bottom nav's Calendar tab.
              icon: MdiIcons.calendarOutline,
              iconColor: AppColors.blue,
              label: 'Upcoming',
              isFirst: false,
              isLast: false,
              isSelected: currentView == 'upcoming',
              onTap: () => onViewSelected('upcoming'),
            ),
            _DrawerItem(
              icon: MdiIcons.checkCircleOutline,
              label: 'Completed',
              isFirst: false,
              isLast: false,
              isSelected: currentView == 'completed',
              onTap: () => onViewSelected('completed'),
            ),
            _DrawerItem(
              icon: MdiIcons.noteMultipleOutline,
              iconColor: AppColors.orange,
              label: 'Notes',
              isFirst: false,
              isLast: true,
              isSelected: currentView == 'notes',
              onTap: () => onViewSelected('notes'),
            ),

            const SizedBox(height: 14),
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
                children: [
                  for (var i = 0; i < projects.length; i++)
                    _DrawerProjectTile(
                      project: projects[i],
                      count: todoState.todos
                          .where(
                            (t) =>
                                !t.isCompleted &&
                                t.projectId == projects[i].id,
                          )
                          .length,
                      isFirst: i == 0,
                      isLast: i == projects.length - 1,
                      onTap: () => onProjectTap(projects[i]),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 6),
            // Same block shape as every other drawer row.
            Container(
              margin: const EdgeInsets.fromLTRB(
                AppShapes.listInset,
                0,
                AppShapes.listInset,
                AppShapes.groupGap,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppShapes.groupOuter),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                dense: true,
                leading: Icon(
                  MdiIcons.plusCircleOutline,
                  size: 20,
                  color: AppColors.primary,
                ),
                title: Text(
                  'New project',
                  style: TextStyle(fontSize: 15, color: AppColors.primary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ProjectEditDialog.show(context);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
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

  /// Position inside its rounded group — same grading as the task list.
  final bool isFirst;
  final bool isLast;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.iconColor,
    this.count,
    this.isFirst = true,
    this.isLast = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = AppShapes.row(isFirst: isFirst, isLast: isLast);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppShapes.listInset,
        0,
        AppShapes.listInset,
        AppShapes.groupGap,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.16)
            : AppColors.surface,
        borderRadius: radius,
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: radius),
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
  final bool isFirst;
  final bool isLast;

  const _DrawerProjectTile({
    required this.project,
    required this.count,
    required this.onTap,
    this.isFirst = true,
    this.isLast = true,
  });

  @override
  Widget build(BuildContext context) {
    final projectColor = Color(project.color);
    final radius = AppShapes.row(isFirst: isFirst, isLast: isLast);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppShapes.listInset,
        0,
        AppShapes.listInset,
        AppShapes.groupGap,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: radius,
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: radius),
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
