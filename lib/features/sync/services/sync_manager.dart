import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/supabase_service.dart';
import 'sync_service.dart';

/// Callback type for when data changes are detected
typedef OnDataChangedCallback = Future<void> Function();

/// Manages automatic synchronization in the foreground.
///
/// Features:
/// - Periodic sync while app is open
/// - Supabase Realtime subscriptions for instant updates
/// - Notifies listeners when data changes
class SyncManager {
  SyncManager._();

  static final SyncManager instance = SyncManager._();

  Timer? _periodicTimer;
  RealtimeChannel? _todosChannel;
  RealtimeChannel? _projectsChannel;
  bool _isRunning = false;

  /// Callbacks to notify when data changes (providers should register here)
  final List<OnDataChangedCallback> _onDataChangedCallbacks = [];

  /// Stream controller for data change events
  final _dataChangedController = StreamController<void>.broadcast();

  /// Stream that emits when data has changed and UI should refresh
  Stream<void> get onDataChanged => _dataChangedController.stream;

  /// Whether the sync manager is running
  bool get isRunning => _isRunning;

  /// Register a callback to be called when data changes
  void addOnDataChangedCallback(OnDataChangedCallback callback) {
    _onDataChangedCallbacks.add(callback);
  }

  /// Remove a callback
  void removeOnDataChangedCallback(OnDataChangedCallback callback) {
    _onDataChangedCallbacks.remove(callback);
  }

  /// Start the sync manager
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    debugPrint('SyncManager: Starting...');

    // Start periodic sync (every 30 seconds)
    _startPeriodicSync();

    // Subscribe to Supabase Realtime if available
    if (SupabaseService.isAvailable && SupabaseService.isAuthenticated) {
      await _subscribeToRealtime();
    }

    // Do an initial sync
    await _performSync();

    debugPrint('SyncManager: Started');
  }

  /// Stop the sync manager
  void stop() {
    if (!_isRunning) return;

    debugPrint('SyncManager: Stopping...');

    _periodicTimer?.cancel();
    _periodicTimer = null;

    _unsubscribeFromRealtime();

    _isRunning = false;
    debugPrint('SyncManager: Stopped');
  }

  /// Start periodic sync timer
  void _startPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _performSync(),
    );
  }

  /// Perform a full sync and notify listeners
  Future<void> _performSync() async {
    if (!SupabaseService.isAvailable) {
      debugPrint('SyncManager: Supabase not available, skipping sync');
      return;
    }

    try {
      await SyncService.fullSync();
      await _notifyDataChanged();
    } catch (e) {
      debugPrint('SyncManager: Sync error: $e');
    }
  }

  /// Subscribe to Supabase Realtime for instant updates
  Future<void> _subscribeToRealtime() async {
    if (!SupabaseService.isAvailable) return;

    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    debugPrint('SyncManager: Subscribing to Realtime...');

    try {
      // Subscribe to todos table changes
      _todosChannel = SupabaseService.client
          .channel('todos_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'todos',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              debugPrint('SyncManager: Realtime todo change: ${payload.eventType}');
              _onRealtimeChange();
            },
          )
          .subscribe();

      // Subscribe to projects table changes
      _projectsChannel = SupabaseService.client
          .channel('projects_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'projects',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              debugPrint('SyncManager: Realtime project change: ${payload.eventType}');
              _onRealtimeChange();
            },
          )
          .subscribe();

      debugPrint('SyncManager: Subscribed to Realtime');
    } catch (e) {
      debugPrint('SyncManager: Failed to subscribe to Realtime: $e');
    }
  }

  /// Unsubscribe from Realtime
  void _unsubscribeFromRealtime() {
    _todosChannel?.unsubscribe();
    _projectsChannel?.unsubscribe();
    _todosChannel = null;
    _projectsChannel = null;
  }

  /// Called when a Realtime change is detected
  void _onRealtimeChange() {
    // Debounce: wait a short moment in case multiple changes come in
    Future.delayed(const Duration(milliseconds: 500), () async {
      await _performSync();
    });
  }

  /// Notify all listeners that data has changed
  Future<void> _notifyDataChanged() async {
    debugPrint('SyncManager: Notifying ${_onDataChangedCallbacks.length} listeners');

    // Emit to stream
    _dataChangedController.add(null);

    // Call all callbacks
    for (final callback in _onDataChangedCallbacks) {
      try {
        await callback();
      } catch (e) {
        debugPrint('SyncManager: Callback error: $e');
      }
    }
  }

  /// Force an immediate sync (for manual trigger)
  Future<void> syncNow() async {
    await _performSync();
  }

  /// Re-subscribe to Realtime (call after login)
  Future<void> resubscribeToRealtime() async {
    _unsubscribeFromRealtime();
    if (SupabaseService.isAvailable && SupabaseService.isAuthenticated) {
      await _subscribeToRealtime();
    }
  }

  /// Dispose resources
  void dispose() {
    stop();
    _dataChangedController.close();
    _onDataChangedCallbacks.clear();
  }
}
