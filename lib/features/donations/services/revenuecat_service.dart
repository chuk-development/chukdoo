import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/config/env_config.dart';
import '../../../core/constants/app_constants.dart';

/// RevenueCat wrapper.
///
/// The app itself is free and cloud sync is free too — RevenueCat is only used
/// to sell one-off donations (consumable in-app products) through Google Play.
class RevenueCatService {
  const RevenueCatService._();

  static bool _initialized = false;
  static final _customerInfoController =
      StreamController<CustomerInfo>.broadcast();

  /// Whether RevenueCat has been initialized
  static bool get isInitialized => _initialized;

  /// Whether RevenueCat is available (initialized and configured)
  static bool get isAvailable =>
      _initialized && EnvConfig.hasValidRevenueCatConfig;

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
      await Purchases.configure(
        configuration,
      ).timeout(const Duration(seconds: 5));

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

  /// The donation packages, cheapest first.
  ///
  /// Looks for the offering named [AppConstants.donationOfferingId] and falls
  /// back to the current offering, so a single default offering also works.
  static Future<List<Package>> getDonationPackages() async {
    if (!isAvailable) return const [];

    try {
      final offerings = await Purchases.getOfferings();
      final offering =
          offerings.all[AppConstants.donationOfferingId] ?? offerings.current;
      if (offering == null) return const [];

      final packages = [...offering.availablePackages];
      packages.sort(
        (a, b) => a.storeProduct.price.compareTo(b.storeProduct.price),
      );
      return packages;
    } catch (e) {
      debugPrint('RevenueCat: Failed to get donation offerings: $e');
      return const [];
    }
  }

  /// Buy one donation product. Returns true when the purchase went through.
  ///
  /// Donations are consumables, so there is nothing to unlock and nothing to
  /// restore — Google Play handles the payment, the app only says thank you.
  static Future<bool> donate(Package package) async {
    if (!isAvailable) return false;

    final result = await Purchases.purchase(PurchaseParams.package(package));
    _customerInfoController.add(result.customerInfo);
    return true;
  }

  /// How many donations this account has made (across devices).
  static Future<int> donationCount() async {
    if (!isAvailable) return 0;

    try {
      final info = await Purchases.getCustomerInfo();
      return info.nonSubscriptionTransactions.length;
    } catch (e) {
      debugPrint('RevenueCat: Failed to read customer info: $e');
      return 0;
    }
  }

  /// Dispose resources
  static void dispose() {
    _customerInfoController.close();
  }
}
