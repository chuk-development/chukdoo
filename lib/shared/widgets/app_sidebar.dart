import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../features/projects/domain/models/project.dart';
import '../../features/projects/domain/project_icons.dart';
import '../../features/projects/providers/project_provider.dart';
import '../../features/sync/services/sync_service.dart';
import '../../features/todos/domain/models/todo.dart';
import '../../features/todos/providers/todo_provider.dart';

/// Desktop section selected via the icon rail
enum SidebarSection {
  tasks,
  calendar,
  habits,
  kanban,
}

class AppSidebar extends ConsumerStatefulWidget {
  final String currentView;
  final ValueChanged<String> onViewSelected;
  final VoidCallback onAddTodo;
  final void Function(dynamic project) onProjectTap;

  const AppSidebar({
    super.key,
    required this.currentView,
    required this.onViewSelected,
    required this.onAddTodo,
    required this.onProjectTap,
  });

  @override
  ConsumerState<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends ConsumerState<AppSidebar> {
  SidebarSection _section = SidebarSection.tasks;

  /// Map currentView back to the right section
  SidebarSection get _activeSection {
    switch (widget.currentView) {
      case 'inbox':
      case 'today':
      case 'upcoming':
      case 'completed':
      case 'all':
      case 'filters':
      case 'project':
        return SidebarSection.tasks;
      case 'calendar':
        return SidebarSection.calendar;
      case 'habits':
        return SidebarSection.habits;
      case 'kanban':
        return SidebarSection.kanban;
      case 'settings':
        return _section; // Stay in current section when settings is selected
      default:
        return _section;
    }
  }

  void _selectSection(SidebarSection section) {
    setState(() => _section = section);
    // Navigate to the default view for this section
    switch (section) {
      case SidebarSection.tasks:
        widget.onViewSelected('all');
      case SidebarSection.calendar:
        widget.onViewSelected('calendar');
      case SidebarSection.habits:
        widget.onViewSelected('habits');
      case SidebarSection.kanban:
        widget.onViewSelected('kanban');
    }
  }

  @override
  Widget build(BuildContext context) {
    final section = _activeSection;

    return Row(
      children: [
        // ── Icon Rail (narrow left bar) ──
        _IconRail(
          activeSection: section,
          onSectionSelected: _selectSection,
        ),
        Container(width: 1, color: AppColors.divider),

        // ── Sub-Panel (contextual navigation) ──
        SizedBox(
          width: 264,
          child: _SubPanel(
            section: section,
            currentView: widget.currentView,
            onViewSelected: widget.onViewSelected,
            onProjectTap: widget.onProjectTap,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
// Icon Rail — narrow vertical strip
// ═══════════════════════════════════════════════

class _IconRail extends StatelessWidget {
  final SidebarSection activeSection;
  final ValueChanged<SidebarSection> onSectionSelected;

  const _IconRail({
    required this.activeSection,
    required this.onSectionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      color: AppColors.background,
      child: Column(
        children: [
          const SizedBox(height: 14),
          // Logo
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: const Text(
              'C',
              style: TextStyle(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Section icons
          _RailIcon(
            icon: SolarIconsOutline.checkSquare,
            activeIcon: SolarIconsBold.checkSquare,
            isActive: activeSection == SidebarSection.tasks,
            onTap: () => onSectionSelected(SidebarSection.tasks),
          ),
          _RailIcon(
            icon: SolarIconsOutline.calendar,
            activeIcon: SolarIconsBold.calendar,
            isActive: activeSection == SidebarSection.calendar,
            onTap: () => onSectionSelected(SidebarSection.calendar),
          ),
          _RailIcon(
            icon: SolarIconsOutline.target,
            activeIcon: SolarIconsBold.target,
            isActive: activeSection == SidebarSection.habits,
            onTap: () => onSectionSelected(SidebarSection.habits),
          ),
          _RailIcon(
            icon: SolarIconsOutline.widgetAdd,
            activeIcon: SolarIconsBold.widgetAdd,
            isActive: activeSection == SidebarSection.kanban,
            onTap: () => onSectionSelected(SidebarSection.kanban),
          ),

          const Spacer(),

          // Sync
          const _SyncRailIcon(),

          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _RailIcon extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final VoidCallback onTap;

  const _RailIcon({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: IconButton(
        icon: Icon(
          isActive ? activeIcon : icon,
          size: 24,
          color: isActive ? AppColors.primary : AppColors.textSecondary,
        ),
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: isActive ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          fixedSize: const Size(46, 46),
        ),
      ),
    );
  }
}

class _SyncRailIcon extends StatelessWidget {
  const _SyncRailIcon();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: SyncService.statusStream,
      initialData: SyncService.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? SyncStatus.idle;
        IconData icon;
        Color color;

        switch (status) {
          case SyncStatus.syncing:
            icon = SolarIconsOutline.refresh;
            color = AppColors.primary;
          case SyncStatus.error:
            icon = SolarIconsOutline.dangerCircle;
            color = AppColors.error;
          case SyncStatus.offline:
            icon = SolarIconsOutline.cloudCross;
            color = AppColors.textTertiary;
          case SyncStatus.idle:
            icon = SolarIconsOutline.refresh;
            color = AppColors.textSecondary;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: IconButton(
            icon: Icon(icon, size: 22, color: color),
            onPressed: () => SyncService.fullSync(),
            style: IconButton.styleFrom(
              fixedSize: const Size(46, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            ),
            tooltip: status == SyncStatus.syncing ? 'Syncing…' : 'Sync',
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════
// Sub-Panel — contextual navigation
// ═══════════════════════════════════════════════

class _SubPanel extends ConsumerWidget {
  final SidebarSection section;
  final String currentView;
  final ValueChanged<String> onViewSelected;
  final void Function(dynamic project) onProjectTap;

  const _SubPanel({
    required this.section,
    required this.currentView,
    required this.onViewSelected,
    required this.onProjectTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.surface,
      child: switch (section) {
        SidebarSection.tasks => _TasksSubPanel(
            currentView: currentView,
            onViewSelected: onViewSelected,
            onProjectTap: onProjectTap,
          ),
        SidebarSection.calendar => _SimpleSubPanel(
            title: 'Calendar',
            icon: SolarIconsOutline.calendar,
            currentView: currentView,
            onViewSelected: onViewSelected,
            section: SidebarSection.calendar,
          ),
        SidebarSection.habits => _SimpleSubPanel(
            title: 'Habits',
            icon: SolarIconsOutline.target,
            currentView: currentView,
            onViewSelected: onViewSelected,
            section: SidebarSection.habits,
          ),
        SidebarSection.kanban => _SimpleSubPanel(
            title: 'Kanban Board',
            icon: SolarIconsOutline.widgetAdd,
            currentView: currentView,
            onViewSelected: onViewSelected,
            section: SidebarSection.kanban,
          ),
      },
    );
  }
}

// ── Tasks Sub-Panel ──

class _TasksSubPanel extends ConsumerWidget {
  final String currentView;
  final ValueChanged<String> onViewSelected;
  final void Function(dynamic project) onProjectTap;

  const _TasksSubPanel({
    required this.currentView,
    required this.onViewSelected,
    required this.onProjectTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todoState = ref.watch(todoProvider);
    final projectState = ref.watch(projectProvider);
    final projects = projectState.sortedProjects;
    final allCount = todoState.todos.where((t) => !t.isCompleted).length;

    return Column(
      children: [
        // Header
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 16, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tasks',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ),

        // Smart views
        _SubNavItem(
          icon: SolarIconsOutline.inbox,
          label: 'All',
          count: allCount,
          isSelected: currentView == 'all',
          onTap: () => onViewSelected('all'),
          // Drop a task here to pull it out of its project (back to no-project).
          onAcceptTodo: (todo) {
            if (todo.projectId == null) return;
            ref.read(todoProvider.notifier).moveToProject(todo.id, null);
          },
        ),
        _SubNavItem(
          icon: SolarIconsOutline.calendar,
          label: 'Today',
          count: todoState.todayTodos.length,
          isSelected: currentView == 'today',
          onTap: () => onViewSelected('today'),
          iconColor: AppColors.green,
        ),
        _SubNavItem(
          icon: SolarIconsOutline.calendarMark,
          label: 'Next 7 Days',
          isSelected: currentView == 'upcoming',
          onTap: () => onViewSelected('upcoming'),
          iconColor: AppColors.blue,
        ),

        const SizedBox(height: 4),
        const Divider(color: AppColors.divider, height: 1),

        // Projects section
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 10, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'PROJECTS',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16, color: AppColors.textSecondary),
                onPressed: () => onViewSelected('add_project'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'New project',
              ),
            ],
          ),
        ),

        // Project list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              final count = todoState.todos
                  .where((t) => !t.isCompleted && t.projectId == project.id)
                  .length;
              return _ProjectItem(
                project: project,
                count: count,
                onTap: () => onProjectTap(project),
                onAcceptTodo: (todo) {
                  if (todo.projectId == project.id) return;
                  ref.read(todoProvider.notifier).moveToProject(todo.id, project.id);
                },
              );
            },
          ),
        ),

        const Divider(color: AppColors.divider, height: 1),

        // Bottom items
        _SubNavItem(
          icon: SolarIconsOutline.checkCircle,
          label: 'Completed',
          isSelected: currentView == 'completed',
          onTap: () => onViewSelected('completed'),
        ),
        _SubNavItem(
          icon: SolarIconsOutline.settings,
          label: 'Settings',
          isSelected: currentView == 'settings',
          onTap: () => onViewSelected('settings'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Simple Sub-Panel (Calendar, Habits, Kanban) ──

class _SimpleSubPanel extends StatelessWidget {
  final String title;
  final IconData icon;
  final String currentView;
  final ValueChanged<String> onViewSelected;
  final SidebarSection section;

  const _SimpleSubPanel({
    required this.title,
    required this.icon,
    required this.currentView,
    required this.onViewSelected,
    this.section = SidebarSection.tasks,
  });

  List<Widget> _buildSectionItems() {
    switch (section) {
      case SidebarSection.calendar:
        return [
          _SubNavItem(
            icon: SolarIconsOutline.calendarMinimalistic,
            label: 'Day View',
            isSelected: currentView == 'calendar',
            onTap: () => onViewSelected('calendar'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
            child: Text(
              'The calendar shows tasks with a due date in a day, week or month view.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textTertiary,
                height: 1.4,
              ),
            ),
          ),
        ];
      case SidebarSection.habits:
        return [
          _SubNavItem(
            icon: SolarIconsOutline.target,
            label: 'Habits',
            isSelected: currentView == 'habits',
            onTap: () => onViewSelected('habits'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
            child: Text(
              'Track daily habits and build streaks.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textTertiary,
                height: 1.4,
              ),
            ),
          ),
        ];
      case SidebarSection.kanban:
        return [
          _SubNavItem(
            icon: SolarIconsOutline.widgetAdd,
            label: 'Board',
            isSelected: currentView == 'kanban',
            onTap: () => onViewSelected('kanban'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
            child: Text(
              'Kanban board for visual task management via drag & drop.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textTertiary,
                height: 1.4,
              ),
            ),
          ),
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 16, 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: AppColors.divider, height: 1),
        const SizedBox(height: 8),

        // Section-specific sub-navigation
        ..._buildSectionItems(),

        // Settings always at bottom
        const Spacer(),
        const Divider(color: AppColors.divider, height: 1),
        _SubNavItem(
          icon: SolarIconsOutline.settings,
          label: 'Settings',
          isSelected: currentView == 'settings',
          onTap: () => onViewSelected('settings'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
// Shared Widgets
// ═══════════════════════════════════════════════

class _SubNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? iconColor;
  final void Function(Todo todo)? onAcceptTodo;

  const _SubNavItem({
    required this.icon,
    required this.label,
    this.count,
    required this.isSelected,
    required this.onTap,
    this.iconColor,
    this.onAcceptTodo,
  });

  @override
  State<_SubNavItem> createState() => _SubNavItemState();
}

class _SubNavItemState extends State<_SubNavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final icon = widget.icon;
    final label = widget.label;
    final count = widget.count;
    final isSelected = widget.isSelected;
    final iconColor = widget.iconColor;

    // Margin lives OUTSIDE the ink area and the Material is clipped to the
    // rounded shape, so the hover/selected highlight matches the tile exactly
    // (the InkWell hover overlay no longer overflows into the side margins).
    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: _hovering
            ? AppColors.primary.withValues(alpha: 0.18)
            : isSelected
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: isSelected ? AppColors.primary : (iconColor ?? AppColors.textSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (count != null && count > 0)
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? AppColors.primary : AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.onAcceptTodo == null) return tile;
    return DragTarget<Todo>(
      onWillAcceptWithDetails: (_) => true,
      onMove: (_) {
        if (!_hovering) setState(() => _hovering = true);
      },
      onLeave: (_) {
        if (_hovering) setState(() => _hovering = false);
      },
      onAcceptWithDetails: (d) {
        setState(() => _hovering = false);
        widget.onAcceptTodo!(d.data);
      },
      builder: (context, cand, rej) => tile,
    );
  }
}

class _ProjectItem extends StatefulWidget {
  final Project project;
  final int count;
  final VoidCallback onTap;
  final void Function(Todo todo)? onAcceptTodo;

  const _ProjectItem({
    required this.project,
    required this.count,
    required this.onTap,
    this.onAcceptTodo,
  });

  @override
  State<_ProjectItem> createState() => _ProjectItemState();
}

class _ProjectItemState extends State<_ProjectItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final count = widget.count;
    final projectColor = Color(project.color);

    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: _hovering ? AppColors.primary.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(projectIconFor(project.icon), size: 18, color: projectColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    project.name,
                    style: TextStyle(
                      fontSize: 14,
                      color: _hovering ? AppColors.primary : AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (count > 0)
                  Text(
                    '$count',
                    style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.onAcceptTodo == null) return tile;
    return DragTarget<Todo>(
      onWillAcceptWithDetails: (_) => true,
      onMove: (_) {
        if (!_hovering) setState(() => _hovering = true);
      },
      onLeave: (_) {
        if (_hovering) setState(() => _hovering = false);
      },
      onAcceptWithDetails: (d) {
        setState(() => _hovering = false);
        widget.onAcceptTodo!(d.data);
      },
      builder: (context, cand, rej) => tile,
    );
  }
}
