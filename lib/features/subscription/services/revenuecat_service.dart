import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../../../core/config/env_config.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/models/subscription_status.dart';

/// Service for interacting with RevenueCat for subscription management
class RevenueCatService {
  const RevenueCatService._();

  static bool _initialized = false;
  static final _customerInfoController =
      StreamController<CustomerInfo>.broadcast();

  /// Whether RevenueCat has been initialized
  static bool get isInitialized => _initialized;

  /// Whether RevenueCat is available (initialized and configured)
  static bool get isAvailable => _initialized && EnvConfig.hasValidRevenueCatConfig;

  /// Stream of customer info updates
  static Stream<CustomerInfo> get customerInfoStream =>
      _customerInfoController.stream;

  /// Initialize RevenueCat SDK
  static Future<bool> initialize() async {
    if (!EnvConfig.hasValidRevenueCatConfig) {
      debugPrint('RevenueCat: No API key configured, skipping initialization');
      return false;
    }

    try {
      await Purchases.setLogLevel(LogLevel.debug);

      final configuration = PurchasesConfiguration(EnvConfig.revenueCatApiKey);
      await Purchases.configure(configuration).timeout(
        const Duration(seconds: 5),
      );

      // Listen for customer info updates
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _customerInfoController.add(customerInfo);
      });

      _initialized = true;
      debugPrint('RevenueCat: Initialized successfully');
      return true;
    } catch (e) {
      debugPrint('RevenueCat: Init failed (offline?): $e');
      _initialized = false;
      return false;
    }
  }

  /// Login user to RevenueCat (links purchases to user ID)
  static Future<void> login(String userId) async {
    if (!isAvailable) return;

    try {
      await Purchases.logIn(userId);
      debugPrint('RevenueCat: Logged in user $userId');
    } catch (e) {
      debugPrint('RevenueCat: Login failed: $e');
    }
  }

  /// Logout user from RevenueCat
  static Future<void> logout() async {
    if (!isAvailable) return;

    try {
      await Purchases.logOut();
      debugPrint('RevenueCat: Logged out');
    } catch (e) {
      debugPrint('RevenueCat: Logout failed: $e');
    }
  }

  /// Get current subscription status
  static Future<SubscriptionStatus> getSubscriptionStatus() async {
    if (!isAvailable) {
      return const SubscriptionStatus();
    }

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return _parseCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('RevenueCat: Failed to get subscription status: $e');
      return const SubscriptionStatus();
    }
  }

  /// Parse CustomerInfo into SubscriptionStatus
  static SubscriptionStatus _parseCustomerInfo(CustomerInfo customerInfo) {
    final entitlement =
        customerInfo.entitlements.all[AppConstants.proEntitlementId];

    if (entitlement != null && entitlement.isActive) {
      return SubscriptionStatus(
        tier: SubscriptionTier.pro,
        isActive: true,
        expiresAt: entitlement.expirationDate != null
            ? DateTime.parse(entitlement.expirationDate!)
            : null,
        productIdentifier: entitlement.productIdentifier,
      );
    }

    return const SubscriptionStatus(
      tier: SubscriptionTier.free,
      isActive: false,
    );
  }

  /// Present the RevenueCat paywall
  static Future<PaywallResult> presentPaywall() async {
    if (!isAvailable) {
      return PaywallResult.cancelled;
    }

    try {
      final result = await RevenueCatUI.presentPaywall();
      debugPrint('RevenueCat: Paywall result: $result');
      return result;
    } catch (e) {
      debugPrint('RevenueCat: Failed to present paywall: $e');
      return PaywallResult.error;
    }
  }

  /// Present the RevenueCat paywall if the user doesn't have pro access
  static Future<PaywallResult> presentPaywallIfNeeded() async {
    if (!isAvailable) {
      return PaywallResult.cancelled;
    }

    try {
      final result = await RevenueCatUI.presentPaywallIfNeeded(
        AppConstants.proEntitlementId,
      );
      debugPrint('RevenueCat: Paywall if needed result: $result');
      return result;
    } catch (e) {
      debugPrint('RevenueCat: Failed to present paywall if needed: $e');
      return PaywallResult.error;
    }
  }

  /// Present the customer center for subscription management
  static Future<void> presentCustomerCenter() async {
    if (!isAvailable) return;

    try {
      await RevenueCatUI.presentCustomerCenter();
    } catch (e) {
      debugPrint('RevenueCat: Failed to present customer center: $e');
    }
  }

  /// Restore purchases
  static Future<SubscriptionStatus> restorePurchases() async {
    if (!isAvailable) {
      return const SubscriptionStatus();
    }

    try {
      final customerInfo = await Purchases.restorePurchases();
      debugPrint('RevenueCat: Purchases restored');
      return _parseCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('RevenueCat: Failed to restore purchases: $e');
      return const SubscriptionStatus();
    }
  }

  /// Get available packages/offerings
  static Future<Offerings?> getOfferings() async {
    if (!isAvailable) return null;

    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('RevenueCat: Failed to get offerings: $e');
      return null;
    }
  }

  /// Dispose resources
  static void dispose() {
    _customerInfoController.close();
  }
}
