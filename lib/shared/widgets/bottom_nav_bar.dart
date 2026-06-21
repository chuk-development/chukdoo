import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../core/theme/app_colors.dart';

enum NavTab {
  inbox(0, 'Inbox'),
  calendar(1, 'Calendar'),
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
        NavTab.habits => MdiIcons.trophyOutline,
        NavTab.more => MdiIcons.cogOutline,
      };

  IconData get activeIcon => switch (this) {
        NavTab.inbox => MdiIcons.inboxFull,
        NavTab.calendar => MdiIcons.calendar,
        NavTab.habits => MdiIcons.trophy,
        NavTab.more => MdiIcons.cog,
      };
}

class ChukdooBottomNavBar extends StatelessWidget {
  final NavTab currentTab;
  final ValueChanged<NavTab> onTabSelected;

  const ChukdooBottomNavBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.divider,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: NavTab.values.map((tab) {
              final isSelected = tab == currentTab;
              return _NavItem(
                tab: tab,
                isSelected: isSelected,
                onTap: () => onTabSelected(tab),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final NavTab tab;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Center(
                child: Icon(
                  // Outline when inactive, filled when selected. No animation.
                  isSelected ? tab.activeIcon : tab.icon,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
