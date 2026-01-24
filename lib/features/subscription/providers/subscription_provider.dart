import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env_config.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/models/subscription_status.dart';
import '../services/revenuecat_service.dart';
import '../services/subscription_sync_service.dart';

/// State for subscription management
class SubscriptionState {
  final SubscriptionStatus status;
  final bool isLoading;
  final String? error;

  const SubscriptionState({
    this.status = const SubscriptionStatus(),
    this.isLoading = false,
    this.error,
  });

  bool get canSync => status.canSync;
  bool get isPro => status.tier == SubscriptionTier.pro && status.isActive;
  bool get isLocalOnlyMode => EnvConfig.isLocalOnlyMode;

  SubscriptionState copyWith({
    SubscriptionStatus? status,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SubscriptionState(
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Notifier for subscription state management
class SubscriptionNotifier extends StateNotifier<SubscriptionState>
    with WidgetsBindingObserver {
  SubscriptionNotifier() : super(const SubscriptionState()) {
    _init();
  }

  StreamSubscription? _customerInfoSubscription;

  Future<void> _init() async {
    // Add lifecycle observer to refresh on app resume
    WidgetsBinding.instance.addObserver(this);

    // Listen to customer info updates from RevenueCat
    _customerInfoSubscription =
        RevenueCatService.customerInfoStream.listen((_) {
      refresh();
    });

    // Initial fetch
    await refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
    }
  }

  /// Refresh subscription status
  /// - On mobile (Android/iOS): Uses RevenueCat, then syncs to Supabase
  /// - On desktop (Linux/Windows/macOS): Loads from Supabase
  Future<void> refresh() async {
    // Check if we're on a desktop platform (no RevenueCat)
    final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    if (isDesktop) {
      // Desktop: Load subscription from Supabase
      await _refreshFromSupabase();
      return;
    }

    // Mobile: Use RevenueCat
    if (!RevenueCatService.isAvailable) {
      // RevenueCat not available, try Supabase as fallback
      if (SupabaseService.isAvailable) {
        await _refreshFromSupabase();
        return;
      }

      // Local-only mode, no subscription needed
      state = const SubscriptionState(
        status: SubscriptionStatus(
          tier: SubscriptionTier.free,
          isActive: false,
        ),
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final status = await RevenueCatService.getSubscriptionStatus();
      state = state.copyWith(status: status, isLoading: false);
      // NOTE: Subscription is synced to Supabase via RevenueCat webhooks (server-side)
      // No client-side sync needed - this prevents subscription spoofing
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to check subscription: $e',
      );
    }
  }

  /// Load subscription status from Supabase (for desktop platforms)
  Future<void> _refreshFromSupabase() async {
    if (!SupabaseService.isAvailable || !SupabaseService.isAuthenticated) {
      state = const SubscriptionState(
        status: SubscriptionStatus(
          tier: SubscriptionTier.free,
          isActive: false,
        ),
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final status = await SubscriptionSyncService.loadFromSupabase();
      state = state.copyWith(status: status, isLoading: false);
      debugPrint('SubscriptionProvider: Loaded from Supabase - canSync=${status.canSync}');
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load subscription: $e',
      );
    }
  }

  /// Restore purchases
  Future<void> restorePurchases() async {
    if (!RevenueCatService.isAvailable) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final status = await RevenueCatService.restorePurchases();
      state = state.copyWith(status: status, isLoading: false);
      // NOTE: Restored purchases trigger RevenueCat webhook automatically
      // No client-side sync needed - this prevents subscription spoofing
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to restore purchases: $e',
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _customerInfoSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for subscription state
final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier();
});

/// Convenience provider for checking if user can sync
final canSyncProvider = Provider<bool>((ref) {
  final subscriptionState = ref.watch(subscriptionProvider);
  // In local-only mode, sync is never available
  if (subscriptionState.isLocalOnlyMode) return false;
  return subscriptionState.canSync;
});

/// Convenience provider for checking if user is pro
final isProProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionProvider).isPro;
});
