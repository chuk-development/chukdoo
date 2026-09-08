import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';

/// THE snack of the app — a short message, optionally with one action.
///
/// A themed `SnackBar` alone was not enough: with a floating snack Flutter
/// lifts it over the Scaffold's FAB, which this app already lifts over the nav
/// bar, so the bar ended up beside the plus button with its text cut off. This
/// places it itself, clear of the bar, across the full width.
void showAppSnack(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceLight,
        elevation: 0,
        duration: duration,
        dismissDirection: DismissDirection.horizontal,
        // Above the nav bar, not above the FAB: the FAB carries its own lift.
        margin: EdgeInsets.fromLTRB(
          AppShapes.listInset,
          0,
          AppShapes.listInset,
          AppShapes.contentBottom(context) + AppShapes.dockMargin,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.dockField),
        ),
        content: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
        ),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: AppColors.primary,
                onPressed: onAction,
              ),
      ),
    );
}
