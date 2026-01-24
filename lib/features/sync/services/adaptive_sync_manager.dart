import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/services/supabase_service.dart';
import '../../notifications/notification_service.dart';
import 'connectivity_service.dart';
import 'sync_service.dart';

/// Sync interval configuration based on conditions
class SyncIntervals {
  /// When Realtime is active and working - polling is just a backup
  static const Duration realtimeActive = Duration(minutes: 5);

  /// When user is actively using the app but no Realtime
  static const Duration userActive = Duration(minutes: 2);

  /// When app is idle (no user activity for a while)
  static const Duration idle = Duration(minutes: 10);

  /// Fallback when Realtime fails and we need more aggressive polling
  static const Duration realtimeFallback = Duration(seconds: 30);
}

/// Callback type for when data changes are detected
typedef OnDataChangedCallback = Future<void> Function();

/// Manages adaptive synchronization based on:
/// - Network connectivity
/// - Realtime subscription status
/// - User activity
///
/// This significantly reduces battery/CPU usage compared to fixed 30s polling.
class AdaptiveSyncManager {
  AdaptiveSyncManager._();

  static final AdaptiveSyncManager instance = AdaptiveSyncManager._();

  Timer? _periodicTimer;
  RealtimeChannel? _todosChannel;
  RealtimeChannel? _projectsChannel;

  bool _isRunning = false;
  bool _isRealtimeConnected = false;
  bool _isUserActive = true;
  DateTime _lastUserActivity = DateTime.now();
  DateTime? _lastSyncTime;

  StreamSubscription<bool>? _connectivitySubscription;

  final List<OnDataChangedCallback> _onDataChangedCallbacks = [];
  final _dataChangedController = StreamController<void>.broadcast();

  /// Stream that emits when data has changed
  Stream<void> get onDataChanged => _dataChangedController.stream;

  /// Whether the sync manager is running
  bool get isRunning => _isRunning;

  /// Whether Realtime is connected
  bool get isRealtimeConnected => _isRealtimeConnected;

  /// Last sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Current polling interval
  Duration get currentInterval {
    if (!ConnectivityService.instance.isConnected) {
      return Duration.zero; // No polling when offline
    }
    if (_isRealtimeConnected) {
      return SyncIntervals.realtimeActive;
    }
    if (_isUserActive) {
      return SyncIntervals.userActive;
    }
    return SyncIntervals.idle;
  }

  /// Register a callback to be called when data changes
  void addOnDataChangedCallback(OnDataChangedCallback callback) {
    _onDataChangedCallbacks.add(callback);
  }

  /// Remove a callback
  void removeOnDataChangedCallback(OnDataChangedCallback callback) {
    _onDataChangedCallbacks.remove(callback);
  }

  /// Start adaptive sync
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    debugPrint('AdaptiveSyncManager: Starting...');

    // Listen to connectivity changes
    _connectivitySubscription = ConnectivityService.instance
        .onConnectivityChanged
        .listen(_onConnectivityChanged);

    // Only proceed if we have network
    if (!ConnectivityService.instance.isConnected) {
      debugPrint('AdaptiveSyncManager: No network, waiting for connection...');
      return;
    }

    // Subscribe to Realtime
    if (SupabaseService.isAvailable && SupabaseService.isAuthenticated) {
      await _subscribeToRealtime();
    }

    // Start with appropriate polling interval
    _updatePollingInterval();

    // Initial sync
    await _performSync();

    debugPrint('AdaptiveSyncManager: Started');
  }

  /// Stop adaptive sync
  void stop() {
    if (!_isRunning) return;

    debugPrint('AdaptiveSyncManager: Stopping...');

    _periodicTimer?.cancel();
    _periodicTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _unsubscribeFromRealtime();

    _isRunning = false;
  }

  /// Record user activity (call from UI interactions)
  void recordUserActivity() {
    _lastUserActivity = DateTime.now();
    if (!_isUserActive) {
      _isUserActive = true;
      debugPrint('AdaptiveSyncManager: User became active');
      _updatePollingInterval();
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(bool isConnected) {
    debugPrint('AdaptiveSyncManager: Network ${isConnected ? "connected" : "disconnected"}');

    if (isConnected) {
      // Reconnect Realtime and sync
      _subscribeToRealtime();
      _performSync();
      _updatePollingInterval();
    } else {
      // Disconnect Realtime, stop polling
      _unsubscribeFromRealtime();
      _periodicTimer?.cancel();
      _periodicTimer = null;
    }
  }

  /// Calculate and set the appropriate polling interval
  void _updatePollingInterval() {
    _periodicTimer?.cancel();
    _periodicTimer = null;

    if (!ConnectivityService.instance.isConnected) {
      debugPrint('AdaptiveSyncManager: No network, polling disabled');
      return;
    }

    Duration interval;
    String reason;

    if (_isRealtimeConnected) {
      // Realtime is working - use longer polling as backup
      interval = SyncIntervals.realtimeActive;
      reason = 'Realtime active';
    } else if (_isUserActive) {
      // No Realtime but user is active - poll more frequently
      interval = SyncIntervals.userActive;
      reason = 'User active, no Realtime';
    } else {
      // Idle - use longer interval
      interval = SyncIntervals.idle;
      reason = 'Idle';
    }

    debugPrint('AdaptiveSyncManager: Polling interval: ${interval.inSeconds}s ($reason)');

    _periodicTimer = Timer.periodic(interval, (_) {
      _checkUserActivity();
      _performSync();
    });
  }

  /// Check if user has been idle
  void _checkUserActivity() {
    final idleTime = DateTime.now().difference(_lastUserActivity);
    final wasActive = _isUserActive;
    _isUserActive = idleTime.inMinutes < 2;

    if (wasActive != _isUserActive) {
      debugPrint('AdaptiveSyncManager: User activity changed: ${_isUserActive ? "active" : "idle"}');
      _updatePollingInterval();
    }
  }

  /// Subscribe to Supabase Realtime
  Future<void> _subscribeToRealtime() async {
    if (!SupabaseService.isAvailable) return;

    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    _unsubscribeFromRealtime();

    debugPrint('AdaptiveSyncManager: Subscribing to Realtime...');

    try {
      // Subscribe to todos table changes
      _todosChannel = SupabaseService.client
          .channel('todos_realtime')
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
              debugPrint('AdaptiveSyncManager: Realtime todo change: ${payload.eventType}');
              _onRealtimeChange();
            },
          )
          .subscribe((status, [error]) {
            _handleRealtimeStatus('todos', status);
          });

      // Subscribe to projects table changes
      _projectsChannel = SupabaseService.client
          .channel('projects_realtime')
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
              debugPrint('AdaptiveSyncManager: Realtime project change: ${payload.eventType}');
              _onRealtimeChange();
            },
          )
          .subscribe((status, [error]) {
            _handleRealtimeStatus('projects', status);
          });
    } catch (e) {
      debugPrint('AdaptiveSyncManager: Realtime subscription failed: $e');
      _isRealtimeConnected = false;
      _updatePollingInterval();
    }
  }

  /// Handle Realtime connection status changes
  void _handleRealtimeStatus(String channel, RealtimeSubscribeStatus status) {
    debugPrint('AdaptiveSyncManager: Realtime $channel status: $status');

    final wasConnected = _isRealtimeConnected;
    _isRealtimeConnected = status == RealtimeSubscribeStatus.subscribed;

    if (wasConnected != _isRealtimeConnected) {
      debugPrint('AdaptiveSyncManager: Realtime connected: $_isRealtimeConnected');
      _updatePollingInterval();
    }
  }

  /// Unsubscribe from Realtime
  void _unsubscribeFromRealtime() {
    _todosChannel?.unsubscribe();
    _projectsChannel?.unsubscribe();
    _todosChannel = null;
    _projectsChannel = null;
    _isRealtimeConnected = false;
  }

  /// Handle Realtime data change - debounced
  Timer? _realtimeDebounceTimer;
  void _onRealtimeChange() {
    // Debounce multiple rapid changes
    _realtimeDebounceTimer?.cancel();
    _realtimeDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await _performSync();
    });
  }

  /// Perform sync operation
  Future<void> _performSync() async {
    if (!SupabaseService.isAvailable) return;
    if (!ConnectivityService.instance.isConnected) return;

    try {
      await SyncService.fullSync();
      _lastSyncTime = DateTime.now();
      await _notifyDataChanged();
    } catch (e) {
      debugPrint('AdaptiveSyncManager: Sync error: $e');

      // Show notification on persistent errors (only if we haven't shown recently)
      await NotificationService.instance.showInstantNotification(
        title: 'Sync-Fehler',
        body: 'Synchronisierung fehlgeschlagen. Wird erneut versucht.',
      );
    }
  }

  /// Notify all listeners that data has changed
  Future<void> _notifyDataChanged() async {
    debugPrint('AdaptiveSyncManager: Notifying ${_onDataChangedCallbacks.length} listeners');

    // Emit to stream
    _dataChangedController.add(null);

    // Call all callbacks
    for (final callback in _onDataChangedCallbacks) {
      try {
        await callback();
      } catch (e) {
        debugPrint('AdaptiveSyncManager: Callback error: $e');
      }
    }
  }

  /// Trigger immediate sync (for manual sync button)
  Future<void> syncNow() async {
    recordUserActivity();
    await _performSync();
  }

  /// Resubscribe after auth change
  Future<void> onAuthChanged() async {
    if (SupabaseService.isAuthenticated) {
      await _subscribeToRealtime();
      _updatePollingInterval();
      await _performSync();
    } else {
      stop();
    }
  }

  void dispose() {
    stop();
    _realtimeDebounceTimer?.cancel();
    _dataChangedController.close();
    _onDataChangedCallbacks.clear();
  }
}
