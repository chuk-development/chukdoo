import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shapes.dart';
import '../providers/donation_provider.dart';
import '../services/revenuecat_service.dart';

/// "Support Chukdoo" — the app and cloud sync are free, donations are optional.
class DonationPage extends ConsumerStatefulWidget {
  const DonationPage({super.key});

  @override
  ConsumerState<DonationPage> createState() => _DonationPageState();
}

class _DonationPageState extends ConsumerState<DonationPage> {
  bool _busy = false;

  Future<void> _donate(Package package) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final done = await RevenueCatService.donate(package);
      if (done && mounted) {
        ref.invalidate(donationCountProvider);
        Navigator.pop(context, true);
        return;
      }
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError && mounted) {
        _toast('Payment failed: ${e.message}');
      }
    } catch (e) {
      if (mounted) _toast('Payment failed: $e');
    }

    if (mounted) setState(() => _busy = false);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final packages = ref.watch(donationPackagesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Support Chukdoo')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Icon(MdiIcons.heartOutline, size: 56, color: AppColors.primary),
          const SizedBox(height: 20),
          Text(
            'Chukdoo is free',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Every feature is included — cloud sync, end-to-end encryption, '
            'all devices. No subscription, no ads, no locked features.\n\n'
            'If the app helps you, you can pay what you want through Google '
            'Play. It changes nothing in the app. It only keeps the servers '
            'running.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          packages.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => _message('Donations are not available right now.'),
            data: (list) {
              if (list.isEmpty) {
                return _message('Donations are not available right now.');
              }
              return Column(
                children: [
                  for (var i = 0; i < list.length; i++)
                    _tile(
                      list[i],
                      isFirst: i == 0,
                      isLast: i == list.length - 1,
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'One-off payment via Google Play. Nothing is unlocked.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _tile(Package package, {required bool isFirst, required bool isLast}) {
    final product = package.storeProduct;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppShapes.groupGap),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppShapes.row(isFirst: isFirst, isLast: isLast),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _busy ? null : () => _donate(package),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title.replaceFirst(RegExp(r'\s*\(.*\)$'), ''),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (product.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          product.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  product.priceString,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
