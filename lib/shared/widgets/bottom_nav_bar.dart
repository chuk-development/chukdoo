import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/theme/app_colors.dart';

enum NavTab {
  inbox(0, 'Eingang', SolarIconsOutline.inbox, SolarIconsBold.inbox),
  today(1, 'Heute', SolarIconsOutline.calendar, SolarIconsBold.calendar),
  upcoming(2, 'Demnächst', SolarIconsOutline.calendarMark, SolarIconsBold.calendarMark),
  browse(3, 'Browsen', SolarIconsOutline.hamburgerMenu, SolarIconsBold.hamburgerMenu);

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
          padding: const EdgeInsets.symmetric(vertical: 8),
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
    final now = DateTime.now();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Container with fixed size for consistent alignment
            SizedBox(
              width: 28,
              height: 28,
              child: tab == NavTab.today
                  // Special handling for "Today" tab - show date number
                  ? Container(
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: !isSelected
                            ? Border.all(color: AppColors.textSecondary, width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${now.day}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        isSelected ? tab.activeIcon : tab.icon,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        size: 26,
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
