import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/calendar_event_provider.dart';

/// Google-Calendar-style view switcher: a compact rounded pill row.
class ViewModeSelector extends StatelessWidget {
  final CalendarViewMode currentMode;
  final ValueChanged<CalendarViewMode> onChanged;

  const ViewModeSelector({
    super.key,
    required this.currentMode,
    required this.onChanged,
  });

  static const _modes = [
    (CalendarViewMode.day, 'Tag'),
    (CalendarViewMode.week, 'Woche'),
    (CalendarViewMode.month, 'Monat'),
    (CalendarViewMode.agenda, 'Agenda'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _modes.map((m) {
          final selected = m.$1 == currentMode;
          return GestureDetector(
            onTap: () => onChanged(m.$1),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                m.$2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.onPrimary : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
