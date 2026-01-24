import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sync/services/sync_service.dart';

/// Widget that listens to sync status but displays nothing
/// Sync happens silently in the background - users are not bothered with errors
class SyncErrorBanner extends ConsumerStatefulWidget {
  const SyncErrorBanner({super.key});

  @override
  ConsumerState<SyncErrorBanner> createState() => _SyncErrorBannerState();
}

class _SyncErrorBannerState extends ConsumerState<SyncErrorBanner> {
  StreamSubscription<SyncStatus>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = SyncService.statusStream.listen((_) {
      // Sync status changes are handled silently
      // When online again, sync will automatically retry
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No UI - sync is completely silent
    return const SizedBox.shrink();
  }
}
