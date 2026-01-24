import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../../core/theme/app_colors.dart';

class QuickAddFab extends StatelessWidget {
  final VoidCallback onPressed;

  const QuickAddFab({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: AppColors.primary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          SolarIconsBold.addCircle,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
