import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// THE tick control of the app.
///
/// The task list draws a ring that fills and shows a check when it is ticked;
/// everything else that can be ticked — a habit day, a calendar's visibility —
/// must look and measure the same, so this is the only implementation.
///
/// [diameter] defaults to the medium task-row size.
class AppCheck extends StatelessWidget {
  final bool checked;
  final VoidCallback? onTap;

  /// Ring colour when unchecked and fill colour when checked.
  final Color? color;

  /// Outer size of the ring. The tap target is padded to 44 either way.
  final double diameter;

  const AppCheck({
    super.key,
    required this.checked,
    this.onTap,
    this.color,
    this.diameter = medium,
  });

  /// Same three steps the task rows use.
  static const double small = 20;
  static const double medium = 23;
  static const double large = 28;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.primary;
    final fill = checked ? tint : Colors.transparent;

    final ring = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: tint, width: 2),
      ),
      child: checked
          ? Icon(
              Icons.check,
              size: diameter * 0.6,
              color: AppColors.onPrimary,
            )
          : null,
    );

    if (onTap == null) return ring;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(child: ring),
      ),
    );
  }
}
