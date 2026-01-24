import 'package:flutter/material.dart';

import '../services/revenuecat_service.dart';
import 'paywall_page.dart';

/// Helper class for presenting paywalls and managing subscription UI
class PaywallHelper {
  const PaywallHelper._();

  /// Present the custom in-app paywall to the user
  /// Returns true if a purchase was made
  static Future<bool> showPaywall(BuildContext context) async {
    if (!RevenueCatService.isAvailable) {
      _showUnavailableDialog(context);
      return false;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const PaywallPage(),
        fullscreenDialog: true,
      ),
    );

    return result ?? false;
  }

  /// Present the paywall only if the user doesn't have pro access
  /// Returns true if a purchase was made or user already had access
  static Future<bool> showPaywallIfNeeded(BuildContext context) async {
    if (!RevenueCatService.isAvailable) {
      _showUnavailableDialog(context);
      return false;
    }

    // Check if user already has access
    final status = await RevenueCatService.getSubscriptionStatus();
    if (status.canSync) {
      return true; // Already has access
    }

    return showPaywall(context);
  }

  /// Present the RevenueCat customer center for subscription management
  static Future<void> showCustomerCenter(BuildContext context) async {
    if (!RevenueCatService.isAvailable) {
      _showUnavailableDialog(context);
      return;
    }

    await RevenueCatService.presentCustomerCenter();
  }

  /// Show a dialog when RevenueCat is unavailable
  static void _showUnavailableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nicht verfügbar'),
        content: const Text(
          'In-App-Käufe sind in dieser Version nicht verfügbar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
