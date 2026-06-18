import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // Primary accent — neutral, premium, minimal "platinum" (no green/teal).
  static const Color primary = Color(0xFFE7E7EC);
  static const Color primaryLight = Color(0xFFF5F5F8);
  static const Color primaryDark = Color(0xFFCFCFD8);

  /// Dark foreground to sit on the light accent (buttons, FAB, checkmarks).
  static const Color onPrimary = Color(0xFF121218);

  // Background colors - Darker, more blue-tinted
  static const Color background = Color(0xFF121218);
  static const Color surface = Color(0xFF1E1E26);
  static const Color surfaceLight = Color(0xFF2A2A36);

  // Text colors
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF9898A6);
  static const Color textTertiary = Color(0xFF5C5C6E);

  // Priority colors - Distinct from Todoist
  static const Color priority1 = Color(0xFFFF5252);  // Bright red
  static const Color priority2 = Color(0xFFFFB74D);  // Amber
  static const Color priority3 = Color(0xFF64B5F6);  // Light blue
  static const Color priority4 = Color(0xFF5C5C6E);  // Grey

  // Status colors
  static const Color success = Color(0xFF66BB6A);
  static const Color warning = Color(0xFFFFB74D);
  static const Color error = Color(0xFFFF5252);
  static const Color info = Color(0xFF64B5F6);

  // Accent colors
  static const Color purple = Color(0xFFB388FF);
  // "green"/"teal" kept as names for compatibility but mapped to a neutral
  // cool-grey so completion/today states read minimal instead of green.
  static const Color green = Color(0xFF8C90A0);
  static const Color blue = Color(0xFF64B5F6);
  static const Color orange = Color(0xFFFFB74D);
  static const Color teal = Color(0xFFE7E7EC);
  static const Color pink = Color(0xFFFF80AB);
  static const Color cyan = Color(0xFF18FFFF);
  static const Color lime = Color(0xFFC6FF00);

  // Other
  static const Color divider = Color(0xFF2A2A36);
  static const Color shimmer = Color(0xFF2A2A36);

  // Project colors (for user selection)
  static const List<Color> projectColors = [
    Color(0xFF7C82E0), // Indigo
    Color(0xFFFF5252), // Red
    Color(0xFFFFB74D), // Amber
    Color(0xFFC9A66B), // Sand
    Color(0xFF8C90A0), // Slate
    Color(0xFF64B5F6), // Blue
    Color(0xFFB388FF), // Purple
    Color(0xFFFF80AB), // Pink
    Color(0xFFE7E7EC), // Platinum
    Color(0xFF78909C), // Blue Grey
  ];

  static Color getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return priority1;
      case 2:
        return priority2;
      case 3:
        return priority3;
      default:
        return priority4;
    }
  }
}
