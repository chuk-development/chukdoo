import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/supabase_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../projects/providers/project_provider.dart';
import '../../../todos/providers/todo_provider.dart';
import '../../../integrations/sunrise_export_service.dart';
import '../../services/adaptive_sync_manager.dart';
import '../../../notes/providers/note_provider.dart';
import '../../../notes/providers/note_folder_provider.dart';
import '../../../calendar/providers/calendar_provider.dart';
import '../../../calendar/providers/calendar_event_provider.dart';
import '../../../habits/providers/habit_provider.dart';

/// Widget that manages automatic sync and refreshes providers.
/// Uses AdaptiveSyncManager for battery-efficient sync with:
/// - Realtime-first strategy (5-min polling when Realtime active)
/// - Connectivity-aware (no polling when offline)
/// - Activity-based intervals (longer polling when idle)
class AutoSyncManager extends ConsumerStatefulWidget {
  const AutoSyncManager({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AutoSyncManager> createState() => _AutoSyncManagerState();
}

class _AutoSyncManagerState extends ConsumerState<AutoSyncManager>
    with WidgetsBindingObserver {
  StreamSubscription<void>? _dataChangedSubscription;
  StreamSubscription<void>? _sunriseObserverSubscription;
  Timer? _startRetryTimer;
  bool _applyingSunrise = false;

  /// How long to keep retrying the start while Supabase is still initializing.
  static const _startRetryInterval = Duration(seconds: 5);
  static const _maxStartRetries = 12;
  int _startRetries = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Start sync manager after a short delay to let providers initialize
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSyncManager();
      // Apply todos completed by Sunrise while Chukdoo was closed
      _applySunrisePending();
    });

    // Live updates whenever any companion app mutates the shared URI.
    _sunriseObserverSubscription = SunriseExportService.changes().listen((_) {
      debugPrint('AutoSyncManager: sunrise URI changed, applying pending');
      _applySunrisePending();
    });
  }

  Future<void> _applySunrisePending() async {
    if (_applyingSunrise) return;
    _applyingSunrise = true;
    try {
      await SunriseExportService.processPending();
      if (!mounted) return;
      await ref.read(todoProvider.notifier).refresh();
      debugPrint('AutoSyncManager: applied pending + refreshed');
    } finally {
      _applyingSunrise = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dataChangedSubscription?.cancel();
    _sunriseObserverSubscription?.cancel();
    _startRetryTimer?.cancel();
    AdaptiveSyncManager.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground - refresh the token first, then sync.
        // The SDK auto-refresh ticker may not have run yet, and a sync with a
        // stale JWT is exactly what looks like "not authenticated".
        debugPrint('AutoSyncManager: App resumed, refreshing session');
        _resumeSync();
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

  /// Resume path: refresh the access token, then sync.
  Future<void> _resumeSync() async {
    await ref.read(authProvider.notifier).onAppResumed();
    if (!mounted) return;
    _startSyncManager();
    await AdaptiveSyncManager.instance.syncNow();
    if (!mounted) return;
    // Process any todos that Sunrise marked complete while we were away
    await SunriseExportService.processPending();
    if (!mounted) return;
    await ref.read(todoProvider.notifier).refresh();
  }

  void _startSyncManager() {
    if (!SupabaseService.isAvailable || !SupabaseService.isAuthenticated) {
      // Supabase may still be initializing, or the session is not restored
      // yet. Keep retrying instead of disabling sync for the whole app run.
      debugPrint('AutoSyncManager: No session yet, will retry');
      _scheduleStartRetry();
      return;
    }

    _startRetryTimer?.cancel();
    _startRetryTimer = null;
    _startRetries = 0;

    // Subscribe to data changes
    _dataChangedSubscription?.cancel();
    _dataChangedSubscription = AdaptiveSyncManager.instance.onDataChanged
        .listen((_) {
          _refreshProviders();
        });

    // Start the adaptive sync manager
    AdaptiveSyncManager.instance.start();
  }

  void _scheduleStartRetry() {
    if (_startRetryTimer != null) return;
    if (_startRetries >= _maxStartRetries) return;

    _startRetryTimer = Timer(_startRetryInterval, () {
      _startRetryTimer = null;
      _startRetries++;
      if (!mounted) return;
      _startSyncManager();
    });
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

    // Everything else that syncs. Without this a pulled note, folder,
    // calendar or habit only appeared after the next app start.
    for (final entry in <String, void Function()>{
      'notes': () => ref.read(noteProvider.notifier).refresh(),
      'note folders': () => ref.read(noteFolderProvider.notifier).refresh(),
      'calendars': () => ref.read(calendarContainerProvider.notifier).refresh(),
      'events': () => ref.read(calendarEventProvider.notifier).refresh(),
      'habits': () => ref.read(habitProvider.notifier).refresh(),
    }.entries) {
      try {
        entry.value();
      } catch (e) {
        debugPrint('AutoSyncManager: Error refreshing ${entry.key}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Start or stop sync the moment the auth state changes, so the sync layer
    // follows the same source of truth the UI shows.
    ref.listen(authProvider, (previous, next) {
      if (previous?.status == next.status) return;
      if (next.status == AuthStatus.authenticated) {
        _startSyncManager();
      } else if (next.status == AuthStatus.unauthenticated) {
        AdaptiveSyncManager.instance.stop();
      }
    });

    // Record user activity on any interaction
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => AdaptiveSyncManager.instance.recordUserActivity(),
      onPanDown: (_) => AdaptiveSyncManager.instance.recordUserActivity(),
      child: widget.child,
    );
  }
}
