import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import 'calendar_style.dart';

/// The palette a calendar, a feed or an event can be painted with, drawn as
/// one filled block of swatches.
///
/// Events, calendars and subscribed feeds all pick from the same swatches, so
/// a colour means the same thing wherever it shows up.
class ColorSwatchGrid extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onPick;

  const ColorSwatchGrid({
    super.key,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppShapes.listInset),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppShapes.groupOuter),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          alignment: WrapAlignment.center,
          children: [
            for (final color in CalendarStyle.eventColors)
              ColorSwatchDot(
                color: color,
                isSelected: selected == color.toARGB32(),
                onTap: () => onPick(color.toARGB32()),
              ),
          ],
        ),
      ),
    );
  }
}

/// One swatch of [ColorSwatchGrid].
class ColorSwatchDot extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const ColorSwatchDot({
    super.key,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: CalendarStyle.motion,
        curve: Curves.easeOutCubic,
        width: 46,
        height: 46,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: isSelected
            ? Icon(
                MdiIcons.check,
                size: 22,
                color: CalendarStyle.onEventColor(color),
              )
            : null,
      ),
    );
  }
}
