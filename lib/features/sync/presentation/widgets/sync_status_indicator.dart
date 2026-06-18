import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../services/sync_service.dart';

/// Widget that shows the current sync status
class SyncStatusIndicator extends StatefulWidget {
  const SyncStatusIndicator({super.key});

  @override
  State<SyncStatusIndicator> createState() => _SyncStatusIndicatorState();
}

class _SyncStatusIndicatorState extends State<SyncStatusIndicator> {
  StreamSubscription<SyncStatus>? _subscription;
  SyncStatus _status = SyncService.status;

  @override
  void initState() {
    super.initState();
    _subscription = SyncService.statusStream.listen((status) {
      if (mounted) {
        setState(() => _status = status);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildStatusWidget();
  }

  Widget _buildStatusWidget() {
    switch (_status) {
      case SyncStatus.idle:
        final queueSize = SyncService.queueSize;
        if (queueSize > 0) {
          return _buildChip(
            icon: Icons.cloud_upload_outlined,
            label: '$queueSize pending',
            color: AppColors.warning,
          );
        }
        return _buildChip(
          icon: Icons.cloud_done_outlined,
          label: 'Synced',
          color: AppColors.success,
        );

      case SyncStatus.syncing:
        return _buildChip(
          icon: Icons.sync,
          label: 'Syncing…',
          color: AppColors.primary,
          isAnimated: true,
        );

      case SyncStatus.error:
        return _buildChip(
          icon: Icons.cloud_off_outlined,
          label: 'Error',
          color: AppColors.error,
        );

      case SyncStatus.offline:
        return _buildChip(
          icon: Icons.cloud_off_outlined,
          label: 'Offline',
          color: AppColors.textSecondary,
        );
    }
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
    bool isAnimated = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAnimated)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            )
          else
            Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact sync status indicator for app bar
class SyncStatusIcon extends StatefulWidget {
  const SyncStatusIcon({super.key});

  @override
  State<SyncStatusIcon> createState() => _SyncStatusIconState();
}

class _SyncStatusIconState extends State<SyncStatusIcon>
    with SingleTickerProviderStateMixin {
  StreamSubscription<SyncStatus>? _subscription;
  SyncStatus _status = SyncService.status;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _subscription = SyncService.statusStream.listen((status) {
      if (mounted) {
        setState(() => _status = status);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case SyncStatus.idle:
        final queueSize = SyncService.queueSize;
        if (queueSize > 0) {
          return _buildBadge(
            icon: Icons.cloud_upload_outlined,
            count: queueSize,
          );
        }
        return const SizedBox.shrink();

      case SyncStatus.syncing:
        return RotationTransition(
          turns: _animationController,
          child: Icon(Icons.sync, color: AppColors.primary, size: 20),
        );

      case SyncStatus.error:
        return Icon(Icons.cloud_off, color: AppColors.error, size: 20);

      case SyncStatus.offline:
        return Icon(Icons.cloud_off_outlined, color: AppColors.textSecondary, size: 20);
    }
  }

  Widget _buildBadge({required IconData icon, required int count}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: AppColors.warning, size: 20),
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.warning,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(
              minWidth: 14,
              minHeight: 14,
            ),
            child: Text(
              count > 9 ? '9+' : count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
