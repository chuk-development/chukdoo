import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';

/// The one input surface of the app: a filled block with an optional label.
///
/// No outline, ever — not at rest and not on focus. Fields that belong
/// together are stacked with [AppFieldGroup] so they read as one group with
/// strong outer and soft inner corners, exactly like a task list.
class AppField extends StatelessWidget {
  final String? label;
  final Widget child;
  final bool isFirst;
  final bool isLast;

  /// Row shown at the right edge of the label line (e.g. a small action).
  final Widget? trailing;

  const AppField({
    super.key,
    required this.child,
    this.label,
    this.isFirst = true,
    this.isLast = true,
    this.trailing,
  });

  /// Decoration every text field inside an [AppField] should use.
  static InputDecoration decoration(String hint, {TextStyle? hintStyle}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: hintStyle ?? TextStyle(color: AppColors.textTertiary),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      filled: false,
      isCollapsed: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppShapes.row(isFirst: isFirst, isLast: isLast),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    label!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }
}

/// Stacks [AppField]s (or any rows) into one rounded group.
class AppFieldGroup extends StatelessWidget {
  final List<Widget> children;

  const AppFieldGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppShapes.groupGap),
            child: children[i],
          ),
      ],
    );
  }
}
