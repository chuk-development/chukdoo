import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../theme/app_colors.dart';
import 'error_provider.dart';

/// Overlay widget that displays errors at the top of the screen
class ErrorOverlay extends ConsumerWidget {
  final Widget child;

  const ErrorOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errorState = ref.watch(errorProvider);

    return Stack(
      children: [
        child,
        if (errorState.hasError)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: ErrorBanner(
                errorState: errorState,
                onDismiss: () => ref.read(errorProvider.notifier).clearError(),
                onRetry: errorState.canRetry
                    ? () {
                        // Retry logic will be handled by the feature that caused the error
                        ref.read(errorProvider.notifier).clearError();
                      }
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// Banner widget that displays error information
class ErrorBanner extends StatelessWidget {
  final AppErrorState errorState;
  final VoidCallback? onDismiss;
  final VoidCallback? onRetry;

  const ErrorBanner({
    super.key,
    required this.errorState,
    this.onDismiss,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: errorState.hasError ? Offset.zero : const Offset(0, -1),
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.error.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _buildIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          errorState.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (errorState.canRetry)
                          const Text(
                            'Tap to retry',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (onDismiss != null)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: onDismiss,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    switch (errorState.errorType) {
      case ErrorType.sync:
        icon = MdiIcons.cloudOffOutline;
        break;
      case ErrorType.encryption:
        icon = MdiIcons.lockOutline;
        break;
      case ErrorType.network:
        icon = MdiIcons.cloudOffOutline;
        break;
      case ErrorType.storage:
        icon = MdiIcons.databaseOutline;
        break;
      case ErrorType.general:
      case null:
        icon = MdiIcons.alertCircleOutline;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}
