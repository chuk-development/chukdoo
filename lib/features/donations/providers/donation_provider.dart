import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/revenuecat_service.dart';

/// The donation products offered by Google Play, cheapest first.
final donationPackagesProvider = FutureProvider<List<Package>>((ref) async {
  return RevenueCatService.getDonationPackages();
});

/// How many donations this account has made. Used only to say thank you.
final donationCountProvider = FutureProvider<int>((ref) async {
  return RevenueCatService.donationCount();
});

/// Whether donating is possible at all (Play Billing available and configured).
final canDonateProvider = Provider<bool>((ref) {
  return RevenueCatService.isAvailable;
});
