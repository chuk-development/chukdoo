import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // ── Platinum defaults (the app's hand-tuned dark theme) ───────────────────
  // Kept as const so they can also seed const widgets and the reset path.
  static const Color _platinumPrimary = Color(0xFFE7E7EC);
  static const Color _platinumPrimaryLight = Color(0xFFF5F5F8);
  static const Color _platinumPrimaryDark = Color(0xFFCFCFD8);
  static const Color _platinumOnPrimary = Color(0xFF121218);
  static const Color _platinumBackground = Color(0xFF121218);
  static const Color _platinumSurface = Color(0xFF1E1E26);
  static const Color _platinumSurfaceLight = Color(0xFF2A2A36);
  static const Color _platinumTextPrimary = Color(0xFFF0F0F5);
  static const Color _platinumTextSecondary = Color(0xFF9898A6);
  static const Color _platinumTextTertiary = Color(0xFF5C5C6E);
  static const Color _platinumDivider = Color(0xFF2A2A36);

  // ── Live theme colors ─────────────────────────────────────────────────────
  // Mutable so "Material You" can recolor accent + surfaces app-wide at
  // runtime (see [applyMaterialYou] / [resetToPlatinum]). Widgets read these
  // statics directly, so a tree rebuild is required after changing them.
  static Color primary = _platinumPrimary;
  static Color primaryLight = _platinumPrimaryLight;
  static Color primaryDark = _platinumPrimaryDark;

  /// Foreground that sits on the accent (buttons, FAB, checkmarks).
  static Color onPrimary = _platinumOnPrimary;

  // Background / surfaces
  static Color background = _platinumBackground;
  static Color surface = _platinumSurface;
  static Color surfaceLight = _platinumSurfaceLight;

  // Text colors
  static Color textPrimary = _platinumTextPrimary;
  static Color textSecondary = _platinumTextSecondary;
  static Color textTertiary = _platinumTextTertiary;

  /// True while a dynamic (Material You) palette is active.
  static bool isMaterialYou = false;

  /// Recolor accent + surfaces from a dynamic [ColorScheme] (wallpaper-based on
  /// Android 12+, or a seeded scheme elsewhere). Semantic colors (priority,
  /// status, project) are intentionally left untouched.
  static void applyMaterialYou(ColorScheme s) {
    primary = s.primary;
    primaryLight = s.primaryContainer;
    primaryDark = s.primary;
    onPrimary = s.onPrimary;

    // The whole UI is built from filled blocks on a darker ground, so the
    // dynamic palette must keep a visible step between the two. Wallpaper
    // schemes sometimes put surface and surfaceContainerHigh almost on top of
    // each other, which made every card disappear.
    background = s.surfaceContainerLowest;
    surface = s.surfaceContainerHigh;
    surfaceLight = s.surfaceContainerHighest;

    const minStep = 0.035;
    if ((surface.computeLuminance() - background.computeLuminance()).abs() <
        minStep) {
      surface = Color.alphaBlend(
        Colors.white.withValues(alpha: 0.08),
        background,
      );
      surfaceLight = Color.alphaBlend(
        Colors.white.withValues(alpha: 0.14),
        background,
      );
    }
    textPrimary = s.onSurface;
    textSecondary = s.onSurfaceVariant;
    textTertiary = s.outline;
    divider = s.outlineVariant;
    isMaterialYou = true;
  }

  /// Restore the hand-tuned platinum palette.
  static void resetToPlatinum() {
    primary = _platinumPrimary;
    primaryLight = _platinumPrimaryLight;
    primaryDark = _platinumPrimaryDark;
    onPrimary = _platinumOnPrimary;
    background = _platinumBackground;
    surface = _platinumSurface;
    surfaceLight = _platinumSurfaceLight;
    textPrimary = _platinumTextPrimary;
    textSecondary = _platinumTextSecondary;
    textTertiary = _platinumTextTertiary;
    divider = _platinumDivider;
    isMaterialYou = false;
  }

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
  static Color divider = _platinumDivider;
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
