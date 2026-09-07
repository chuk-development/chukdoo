import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/bottom_nav_bar.dart';
import '../../../../shared/widgets/sync_error_banner.dart';
import '../../../../shared/widgets/app_sidebar.dart';
import '../../../sync/presentation/widgets/auto_sync_manager.dart';
import '../../../calendar/presentation/pages/calendar_page.dart';
import '../../../habits/presentation/pages/habits_page.dart';
import '../../../notes/presentation/pages/notes_page.dart';
import '../../../settings/presentation/settings_page.dart';
import '../../../projects/domain/models/project.dart';
import '../../../projects/presentation/pages/project_page.dart';
import '../../../projects/presentation/widgets/project_edit_dialog.dart';
import '../../domain/models/todo.dart';
import '../../providers/todo_provider.dart';
import '../../../kanban/presentation/pages/kanban_page.dart';
import '../widgets/todo_drawer.dart';
import '../../../calendar/presentation/widgets/calendar_drawer.dart';
import '../../../notes/presentation/widgets/notes_drawer.dart';
import '../../../habits/presentation/widgets/habits_drawer.dart';
import 'inbox_page.dart';
import 'todo_detail_page.dart';
import 'today_page.dart';
import 'upcoming_page.dart';
import 'completed_tasks_page.dart';
import '../../../../core/theme/app_shapes.dart';

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

  /// The side panel of the current section. Settings gets none — there is
  /// nothing to navigate there.
  Widget? _drawerForTab() {
    switch (_currentTab) {
      case NavTab.calendar:
        return const CalendarDrawer();
      case NavTab.notes:
        return const NotesDrawer();
      case NavTab.habits:
        return const HabitsDrawer();
      case NavTab.more:
        return null;
      case NavTab.inbox:
        return TodoDrawer(
          currentView: _currentView,
          onViewSelected: (view) {
            Navigator.pop(context);
            _handleSidebarViewSelected(view);
          },
          onProjectTap: (project) {
            Navigator.pop(context);
            _handleProjectTap(project);
          },
        );
    }
  }

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
                    const SizedBox(width: AppShapes.groupGap),
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
                        width: (constraints.maxWidth * 0.32).clamp(
                          420.0,
                          620.0,
                        ),
                        todo: selectedTodo,
                        onClose: () =>
                            ref.read(selectedTodoProvider.notifier).state =
                                null,
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
              // Each section brings its own panel; settings has none, so
              // its page shows no hamburger either.
              drawer: _drawerForTab(),
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
                  } else if (notification.direction ==
                          ScrollDirection.forward &&
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
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
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
        const SizedBox(width: AppShapes.groupGap),
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
