import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../features/projects/domain/models/project.dart';
import '../../features/projects/providers/project_provider.dart';
import '../../features/sync/services/sync_service.dart';
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
  final VoidCallback onSearch;
  final void Function(dynamic project) onProjectTap;

  const AppSidebar({
    super.key,
    required this.currentView,
    required this.onViewSelected,
    required this.onAddTodo,
    required this.onSearch,
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
        widget.onViewSelected('inbox');
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
          onSearch: widget.onSearch,
        ),
        Container(width: 1, color: AppColors.divider),

        // ── Sub-Panel (contextual navigation) ──
        SizedBox(
          width: 220,
          child: _SubPanel(
            section: section,
            currentView: widget.currentView,
            onViewSelected: widget.onViewSelected,
            onAddTodo: widget.onAddTodo,
            onProjectTap: widget.onProjectTap,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
// Icon Rail — narrow vertical strip (~56px)
// ═══════════════════════════════════════════════

class _IconRail extends StatelessWidget {
  final SidebarSection activeSection;
  final ValueChanged<SidebarSection> onSectionSelected;
  final VoidCallback onSearch;

  const _IconRail({
    required this.activeSection,
    required this.onSectionSelected,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      color: AppColors.background,
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Logo
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Text(
              'C',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 16),

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

          // Search
          _RailIcon(
            icon: SolarIconsOutline.magnifier,
            activeIcon: SolarIconsBold.magnifier,
            isActive: false,
            onTap: onSearch,
          ),

          // Sync
          const _SyncRailIcon(),

          const SizedBox(height: 12),
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: IconButton(
        icon: Icon(
          isActive ? activeIcon : icon,
          size: 22,
          color: isActive ? AppColors.primary : AppColors.textSecondary,
        ),
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: isActive ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          fixedSize: const Size(42, 42),
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
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: IconButton(
            icon: Icon(icon, size: 20, color: color),
            onPressed: () => SyncService.fullSync(),
            style: IconButton.styleFrom(
              fixedSize: const Size(42, 42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            tooltip: status == SyncStatus.syncing ? 'Synchronisiere...' : 'Synchronisieren',
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════
// Sub-Panel — contextual navigation (220px)
// ═══════════════════════════════════════════════

class _SubPanel extends ConsumerWidget {
  final SidebarSection section;
  final String currentView;
  final ValueChanged<String> onViewSelected;
  final VoidCallback onAddTodo;
  final void Function(dynamic project) onProjectTap;

  const _SubPanel({
    required this.section,
    required this.currentView,
    required this.onViewSelected,
    required this.onAddTodo,
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
            onAddTodo: onAddTodo,
            onProjectTap: onProjectTap,
          ),
        SidebarSection.calendar => _SimpleSubPanel(
            title: 'Kalender',
            icon: SolarIconsOutline.calendar,
            currentView: currentView,
            onViewSelected: onViewSelected,
            section: SidebarSection.calendar,
          ),
        SidebarSection.habits => _SimpleSubPanel(
            title: 'Gewohnheiten',
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
  final VoidCallback onAddTodo;
  final void Function(dynamic project) onProjectTap;

  const _TasksSubPanel({
    required this.currentView,
    required this.onViewSelected,
    required this.onAddTodo,
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Aufgaben',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18, color: AppColors.textSecondary),
                onPressed: onAddTodo,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              ),
            ],
          ),
        ),

        // Smart views
        _SubNavItem(
          icon: SolarIconsOutline.inbox,
          label: 'Alle',
          count: allCount,
          isSelected: currentView == 'all',
          onTap: () => onViewSelected('all'),
        ),
        _SubNavItem(
          icon: SolarIconsOutline.calendar,
          label: 'Heute',
          count: todoState.todayTodos.length,
          isSelected: currentView == 'today',
          onTap: () => onViewSelected('today'),
          iconColor: AppColors.green,
        ),
        _SubNavItem(
          icon: SolarIconsOutline.calendarMark,
          label: 'Nächste 7 Tage',
          isSelected: currentView == 'upcoming',
          onTap: () => onViewSelected('upcoming'),
          iconColor: AppColors.blue,
        ),
        _SubNavItem(
          icon: SolarIconsOutline.inbox,
          label: 'Eingang',
          count: todoState.inboxTodos.length,
          isSelected: currentView == 'inbox',
          onTap: () => onViewSelected('inbox'),
        ),

        const SizedBox(height: 4),
        const Divider(color: AppColors.divider, height: 1),

        // Projects section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'PROJEKTE',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 14, color: AppColors.textSecondary),
                onPressed: () => onViewSelected('add_project'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
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
              );
            },
          ),
        ),

        const Divider(color: AppColors.divider, height: 1),

        // Bottom items
        _SubNavItem(
          icon: SolarIconsOutline.checkCircle,
          label: 'Erledigt',
          isSelected: currentView == 'completed',
          onTap: () => onViewSelected('completed'),
        ),
        _SubNavItem(
          icon: SolarIconsOutline.settings,
          label: 'Einstellungen',
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
            label: 'Tagesansicht',
            isSelected: currentView == 'calendar',
            onTap: () => onViewSelected('calendar'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 16, 4),
            child: Text(
              'Kalender zeigt Aufgaben mit Fälligkeitsdatum in einer Tages-, Wochen- oder Monatsansicht.',
              style: TextStyle(
                fontSize: 12,
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
            label: 'Gewohnheiten',
            isSelected: currentView == 'habits',
            onTap: () => onViewSelected('habits'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 16, 4),
            child: Text(
              'Verfolge tägliche Gewohnheiten und baue Streaks auf.',
              style: TextStyle(
                fontSize: 12,
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
            padding: const EdgeInsets.fromLTRB(18, 12, 16, 4),
            child: Text(
              'Kanban-Board für visuelle Aufgabenverwaltung per Drag & Drop.',
              style: TextStyle(
                fontSize: 12,
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
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
          label: 'Einstellungen',
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

class _SubNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? iconColor;

  const _SubNavItem({
    required this.icon,
    required this.label,
    this.count,
    required this.isSelected,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.primary : (iconColor ?? AppColors.textSecondary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (count != null && count! > 0)
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? AppColors.primary : AppColors.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectItem extends StatelessWidget {
  final Project project;
  final int count;
  final VoidCallback onTap;

  const _ProjectItem({
    required this.project,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final projectColor = Color(project.color);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: projectColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  project.name,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count > 0)
                Text(
                  '$count',
                  style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
