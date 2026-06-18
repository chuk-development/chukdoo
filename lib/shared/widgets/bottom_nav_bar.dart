import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/theme/app_colors.dart';

enum NavTab {
  inbox(0, 'Inbox', SolarIconsOutline.inbox, SolarIconsBold.inbox),
  calendar(1, 'Calendar', SolarIconsOutline.calendar, SolarIconsBold.calendar),
  habits(3, 'Habits', SolarIconsOutline.target, SolarIconsBold.target),
  more(4, 'More', SolarIconsOutline.settings, SolarIconsBold.settings);

  const NavTab(this.tabIndex, this.label, this.icon, this.activeIcon);

  final int tabIndex;
  final String label;
  final IconData icon;
  final IconData activeIcon;
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
                  // Always the filled (Bold) glyph — fatter, easier to read.
                  // Color carries the selected/unselected distinction.
                  tab.activeIcon,
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
