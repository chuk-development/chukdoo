import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../core/theme/app_colors.dart';

enum NavTab {
  inbox(0, 'To-Do'),
  calendar(1, 'Calendar'),
  notes(2, 'Notes'),
  habits(3, 'Habits'),
  more(4, 'More');

  const NavTab(this.tabIndex, this.label);

  final int tabIndex;
  final String label;

  // MDI getters are non-const, so resolve icons at runtime.
  // Outline = unselected, filled = selected.
  IconData get icon => switch (this) {
        NavTab.inbox => MdiIcons.inboxOutline,
        NavTab.calendar => MdiIcons.calendarOutline,
        NavTab.notes => MdiIcons.noteMultipleOutline,
        NavTab.habits => MdiIcons.trophyOutline,
        NavTab.more => MdiIcons.cogOutline,
      };

  IconData get activeIcon => switch (this) {
        NavTab.inbox => MdiIcons.inboxFull,
        NavTab.calendar => MdiIcons.calendar,
        NavTab.notes => MdiIcons.noteMultiple,
        NavTab.habits => MdiIcons.trophy,
        NavTab.more => MdiIcons.cog,
      };
}

/// Floating glass nav bar: a rounded pill that hovers over the content with a
/// single highlight gliding between the tabs. Ported from the chuk-ui
/// ChukNavBar design onto the app's own colors.
class ChukdooBottomNavBar extends StatelessWidget {
  final NavTab currentTab;
  final ValueChanged<NavTab> onTabSelected;

  /// Scrolling down collapses the bar: labels fold away and it gets shorter.
  final bool collapsed;

  const ChukdooBottomNavBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
    this.collapsed = false,
  });

  static const _duration = Duration(milliseconds: 260);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final tabs = NavTab.values;
    final n = tabs.length;
    final index = currentTab.tabIndex;

    // Slot-centre alignment for the sliding highlight: -1 (first) … 1 (last).
    final alignX = n <= 1 ? 0.0 : -1 + 2 * index.clamp(0, n - 1) / (n - 1);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: AnimatedContainer(
              duration: _duration,
              curve: _curve,
              height: collapsed ? 52 : 64,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(999),
              ),
              padding: const EdgeInsets.all(4),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedAlign(
                    alignment: Alignment(alignX, 0),
                    duration: _duration,
                    curve: _curve,
                    child: FractionallySizedBox(
                      widthFactor: 1 / n,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (final tab in tabs)
                        Expanded(
                          child: _NavItem(
                            tab: tab,
                            isSelected: tab == currentTab,
                            collapsed: collapsed,
                            onTap: () => onTabSelected(tab),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final NavTab tab;
  final bool isSelected;
  final bool collapsed;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.isSelected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary : AppColors.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isSelected ? tab.activeIcon : tab.icon,
              key: ValueKey('${tab.name}-$isSelected-$collapsed'),
              size: collapsed ? 21 : 24,
              color: color,
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: collapsed
                ? const SizedBox(width: 0, height: 0)
                : Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: color,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
