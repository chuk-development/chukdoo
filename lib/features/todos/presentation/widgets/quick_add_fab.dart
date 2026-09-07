import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The app's only add button. Every screen uses this one so the plus looks
/// identical in tasks, notes, habits, projects and the calendar.
class QuickAddFab extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;

  const QuickAddFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.add,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 3,
      // Material 3 Expressive: a squircle, not a circle.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, size: 28),
    );
  }
}
