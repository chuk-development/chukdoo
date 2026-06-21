import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

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
      if (kReleaseMode && EnvConfig.isRevenueCatTestKey) {
        debugPrint(
          'RevenueCat: test_ key in release build — skipping init to avoid '
          'the SDK force-closing the app. Use a production key for release.',
        );
      } else {
        debugPrint('RevenueCat: disabled or no API key, skipping init');
      }
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
