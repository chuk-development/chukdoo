import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../services/revenuecat_service.dart';

class PaywallPage extends ConsumerStatefulWidget {
  const PaywallPage({super.key});

  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends ConsumerState<PaywallPage> {
  bool _isLoading = false;
  Package? _yearlyPackage;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() => _isLoading = true);

    try {
      final offerings = await RevenueCatService.getOfferings();
      if (offerings != null && offerings.current != null) {
        _yearlyPackage = offerings.current!.annual;
      }
    } catch (e) {
      _error = e.toString();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _purchase() async {
    if (_yearlyPackage == null) return;

    setState(() => _isLoading = true);

    try {
      final customerInfo = await Purchases.purchasePackage(_yearlyPackage!);
      final isPro = customerInfo.entitlements.all['Chukdoo Pro']?.isActive ?? false;

      if (isPro && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kauf fehlgeschlagen: $e')),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _restore() async {
    setState(() => _isLoading = true);

    try {
      final status = await RevenueCatService.restorePurchases();
      if (status.canSync && mounted) {
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Käufe gefunden')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),

              // Crown icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  SolarIconsBold.crownStar,
                  size: 40,
                  color: AppColors.warning,
                ),
              ),

              const SizedBox(height: 24),

              // Title
              const Text(
                'Chukdoo Pro',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Synchronisiere deine Aufgaben überall',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 40),

              // Features
              _buildFeature(
                icon: SolarIconsOutline.cloudCheck,
                title: 'Cloud-Sync',
                description: 'Alle Geräte synchron',
              ),
              _buildFeature(
                icon: SolarIconsOutline.shield,
                title: 'Ende-zu-Ende verschlüsselt',
                description: 'Nur du kannst deine Daten lesen',
              ),
              _buildFeature(
                icon: SolarIconsOutline.infinity,
                title: 'Unbegrenzte Projekte',
                description: 'Keine Limits, volle Kontrolle',
              ),

              const Spacer(),

              // Price
              if (_yearlyPackage != null) ...[
                Text(
                  _yearlyPackage!.storeProduct.priceString,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'pro Jahr',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else if (_isLoading) ...[
                const CircularProgressIndicator(),
              ] else ...[
                const Text(
                  '19,99 €',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'pro Jahr',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Purchase button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _purchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Jetzt upgraden',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Restore button
              TextButton(
                onPressed: _isLoading ? null : _restore,
                child: Text(
                  'Käufe wiederherstellen',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Terms
              Text(
                'Es gelten die AGB und Datenschutzrichtlinien.\nDas Abo verlängert sich automatisch.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeature({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle,
            color: AppColors.success,
          ),
        ],
      ),
    );
  }
}
