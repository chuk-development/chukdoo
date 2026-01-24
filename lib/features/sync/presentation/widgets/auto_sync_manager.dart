import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/supabase_service.dart';
import '../../../projects/providers/project_provider.dart';
import '../../../todos/providers/todo_provider.dart';
import '../../services/adaptive_sync_manager.dart';

/// Widget that manages automatic sync and refreshes providers.
/// Uses AdaptiveSyncManager for battery-efficient sync with:
/// - Realtime-first strategy (5-min polling when Realtime active)
/// - Connectivity-aware (no polling when offline)
/// - Activity-based intervals (longer polling when idle)
class AutoSyncManager extends ConsumerStatefulWidget {
  const AutoSyncManager({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<AutoSyncManager> createState() => _AutoSyncManagerState();
}

class _AutoSyncManagerState extends ConsumerState<AutoSyncManager>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _dataChangedSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Start sync manager after a short delay to let providers initialize
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSyncManager();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dataChangedSubscription?.cancel();
    AdaptiveSyncManager.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground - start sync
        debugPrint('AutoSyncManager: App resumed, starting sync');
        _startSyncManager();
        // Do an immediate sync when coming back
        AdaptiveSyncManager.instance.syncNow();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App went to background - stop periodic sync (WorkManager handles background)
        debugPrint('AutoSyncManager: App paused, stopping sync');
        AdaptiveSyncManager.instance.stop();
        break;
    }
  }

  void _startSyncManager() {
    if (!SupabaseService.isAvailable || !SupabaseService.isAuthenticated) {
      debugPrint('AutoSyncManager: Supabase not available or not authenticated');
      return;
    }

    // Subscribe to data changes
    _dataChangedSubscription?.cancel();
    _dataChangedSubscription = AdaptiveSyncManager.instance.onDataChanged.listen((_) {
      _refreshProviders();
    });

    // Start the adaptive sync manager
    AdaptiveSyncManager.instance.start();
  }

  void _refreshProviders() {
    debugPrint('AutoSyncManager: Refreshing providers...');

    // Refresh todos
    try {
      ref.read(todoProvider.notifier).refresh();
    } catch (e) {
      debugPrint('AutoSyncManager: Error refreshing todos: $e');
    }

    // Refresh projects
    try {
      ref.read(projectProvider.notifier).refresh();
    } catch (e) {
      debugPrint('AutoSyncManager: Error refreshing projects: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Record user activity on any interaction
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => AdaptiveSyncManager.instance.recordUserActivity(),
      onPanDown: (_) => AdaptiveSyncManager.instance.recordUserActivity(),
      child: widget.child,
    );
  }
}
