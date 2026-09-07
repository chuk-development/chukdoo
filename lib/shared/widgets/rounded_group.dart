import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';

/// A list section drawn as one rounded group: strong outer corners, soft
/// corners between two rows, a hairline-free filled surface.
///
/// This is the shape every list in the app uses — task lists, settings,
/// pickers, the browse page — so a section always reads the same way.
class RoundedGroup extends StatelessWidget {
  final List<Widget> children;

  /// Horizontal inset from the screen edge.
  final double inset;

  const RoundedGroup({
    super.key,
    required this.children,
    this.inset = AppShapes.listInset,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppShapes.groupGap),
              child: Material(
                color: AppColors.surface,
                borderRadius: AppShapes.row(
                  isFirst: i == 0,
                  isLast: i == children.length - 1,
                ),
                clipBehavior: Clip.antiAlias,
                child: children[i],
              ),
            ),
        ],
      ),
    );
  }
}
