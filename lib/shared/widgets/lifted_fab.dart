import 'package:flutter/material.dart';

import '../../core/theme/app_shapes.dart';

/// Lifts a floating action button clear of the floating nav bar.
///
/// Pages inside the shell run their own Scaffold, which places its FAB against
/// the screen edge and knows nothing about the shell's bar. The lift is the
/// bar's footprint plus the gesture inset, minus the FAB's own 16 margin, plus
/// a small gap so the button never touches the pill.
class LiftedFab extends StatelessWidget {
  final Widget? child;

  const LiftedFab({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (child == null) return const SizedBox.shrink();

    final gestureInset = MediaQuery.viewPaddingOf(context).bottom;
    // Clear of the pill, not touching it: the FAB's own 16 margin plus this
    // puts its bottom edge a good 24 above the bar.
    final lift = (gestureInset + AppShapes.navBarHeight + 8).clamp(0.0, 180.0);

    return Padding(
      padding: EdgeInsets.only(bottom: lift),
      child: child!,
    );
  }
}
