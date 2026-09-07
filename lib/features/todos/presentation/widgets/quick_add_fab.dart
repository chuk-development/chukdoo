import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class QuickAddFab extends StatelessWidget {
  final VoidCallback onPressed;

  const QuickAddFab({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: AppColors.primary,
      elevation: 3,
      shape: const CircleBorder(),
      child: Icon(
        Icons.add,
        color: AppColors.onPrimary,
        size: 30,
      ),
    );
  }
}
