import 'package:flutter/foundation.dart';

import '../../../shared/services/supabase_service.dart';
import '../domain/models/subscription_status.dart';

/// Service to load subscription status from Supabase
///
/// SECURITY: This is READ-ONLY. Subscription updates come only from
/// RevenueCat webhooks via the secure Edge Function.
///
/// Cross-platform flow:
/// 1. User purchases on mobile via RevenueCat
/// 2. RevenueCat sends webhook to Supabase Edge Function
/// 3. Edge Function verifies webhook signature and updates database
/// 4. Desktop apps read subscription status from database
class SubscriptionSyncService {
  const SubscriptionSyncService._();

  static const _tableName = 'user_subscriptions';

  /// Load subscription status from Supabase
  /// Used on all platforms to get the authoritative subscription status
  /// (which is set only by verified RevenueCat webhooks)
  static Future<SubscriptionStatus> loadFromSupabase() async {
    if (!SupabaseService.isAvailable) {
      debugPrint('SubscriptionSync: Supabase not available');
      return const SubscriptionStatus();
    }

    final user = SupabaseService.currentUser;
    if (user == null) {
      debugPrint('SubscriptionSync: No authenticated user');
      return const SubscriptionStatus();
    }

    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) {
        debugPrint('SubscriptionSync: No subscription record found');
        return const SubscriptionStatus();
      }

      final tier = response['tier'] == 'pro'
          ? SubscriptionTier.pro
          : SubscriptionTier.free;
      final isActive = response['is_active'] as bool? ?? false;
      final expiresAtStr = response['expires_at'] as String?;
      final productIdentifier = response['product_identifier'] as String?;

      DateTime? expiresAt;
      if (expiresAtStr != null) {
        expiresAt = DateTime.tryParse(expiresAtStr);
      }

      // Check if subscription is expired
      final effectivelyActive = isActive &&
          (expiresAt == null || expiresAt.isAfter(DateTime.now()));

      final status = SubscriptionStatus(
        tier: tier,
        isActive: effectivelyActive,
        expiresAt: expiresAt,
        productIdentifier: productIdentifier,
      );

      debugPrint('SubscriptionSync: Loaded from Supabase - $status');
      return status;
    } catch (e) {
      debugPrint('SubscriptionSync: Failed to load: $e');
      return const SubscriptionStatus();
    }
  }

  /// Check if there's a subscription record in Supabase
  static Future<bool> hasSubscriptionRecord() async {
    if (!SupabaseService.isAvailable) return false;

    final user = SupabaseService.currentUser;
    if (user == null) return false;

    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('SubscriptionSync: Failed to check record: $e');
      return false;
    }
  }
}
