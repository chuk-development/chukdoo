import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/supabase_service.dart';
import '../services/sync_manager.dart';
import '../services/sync_service.dart';

/// State for sync manager
class SyncManagerState {
  final bool isRunning;
  final SyncStatus syncStatus;
  final DateTime? lastSyncTime;

  const SyncManagerState({
    this.isRunning = false,
    this.syncStatus = SyncStatus.idle,
    this.lastSyncTime,
  });

  SyncManagerState copyWith({
    bool? isRunning,
    SyncStatus? syncStatus,
    DateTime? lastSyncTime,
  }) {
    return SyncManagerState(
      isRunning: isRunning ?? this.isRunning,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

/// Notifier for sync manager - controls auto-sync lifecycle
class SyncManagerNotifier extends StateNotifier<SyncManagerState> {
  // ignore: unused_field - kept for future use (provider dependencies)
  SyncManagerNotifier(Ref ref) : super(const SyncManagerState()) {
    _initialize();
  }

  StreamSubscription<SyncStatus>? _statusSubscription;
  StreamSubscription<void>? _dataChangedSubscription;

  void _initialize() {
    // Listen to sync status changes
    _statusSubscription = SyncService.statusStream.listen((status) {
      state = state.copyWith(
        syncStatus: status,
        lastSyncTime: status == SyncStatus.idle ? DateTime.now() : state.lastSyncTime,
      );
    });

    // Listen to data changes and notify dependent providers
    _dataChangedSubscription = SyncManager.instance.onDataChanged.listen((_) {
      // Trigger a state change to notify listeners
      state = state.copyWith(lastSyncTime: DateTime.now());
    });
  }

  /// Start the sync manager (call when user is authenticated)
  Future<void> start() async {
    if (!SupabaseService.isAvailable || !SupabaseService.isAuthenticated) {
      return;
    }

    await SyncManager.instance.start();
    state = state.copyWith(isRunning: true);
  }

  /// Stop the sync manager
  void stop() {
    SyncManager.instance.stop();
    state = state.copyWith(isRunning: false);
  }

  /// Trigger an immediate sync
  Future<void> syncNow() async {
    await SyncManager.instance.syncNow();
  }

  /// Resubscribe to realtime (call after login)
  Future<void> onAuthChanged() async {
    if (SupabaseService.isAuthenticated) {
      await SyncManager.instance.resubscribeToRealtime();
      if (!state.isRunning) {
        await start();
      }
    } else {
      stop();
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _dataChangedSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for the sync manager
final syncManagerProvider = StateNotifierProvider<SyncManagerNotifier, SyncManagerState>((ref) {
  return SyncManagerNotifier(ref);
});

/// Provider that emits the last sync time - use this to trigger refreshes
final lastSyncTimeProvider = Provider<DateTime?>((ref) {
  return ref.watch(syncManagerProvider).lastSyncTime;
});
