import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';

/// One segment of a [ConnectedButtonGroup].
class ConnectedItem {
  final String label;
  final IconData? icon;

  const ConnectedItem({required this.label, this.icon});
}

/// A row of connected segments: the outer corners of the group are strongly
/// rounded, the corners between two segments stay soft, and the selected
/// segment fills with the accent.
///
/// This is the app's segmented control — the same grading as a list group, so
/// a switcher reads like everything else.
class ConnectedButtonGroup extends StatelessWidget {
  final List<ConnectedItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Height of the whole group. Keep it slim; 40 reads as a control, not a bar.
  final double height;

  const ConnectedButtonGroup({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: AppShapes.groupGap),
            Expanded(
              child: _Segment(
              item: items[i],
              selected: i == selectedIndex,
              radius: BorderRadius.horizontal(
                left: Radius.circular(
                  i == 0 ? AppShapes.groupOuter : AppShapes.groupInner,
                ),
                right: Radius.circular(
                  i == items.length - 1
                      ? AppShapes.groupOuter
                      : AppShapes.groupInner,
                ),
              ),
                onTap: () => onSelected(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final ConnectedItem item;
  final bool selected;
  final BorderRadius radius;
  final VoidCallback onTap;

  const _Segment({
    required this.item,
    required this.selected,
    required this.radius,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: radius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.icon != null) ...[
              Icon(
                item.icon,
                size: 17,
                color: selected ? AppColors.onPrimary : AppColors.textSecondary,
              ),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                item.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.onPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
