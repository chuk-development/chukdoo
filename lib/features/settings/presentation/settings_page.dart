import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/config/env_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../subscription/presentation/paywall_helper.dart';
import '../../subscription/providers/subscription_provider.dart';
import '../../sync/presentation/widgets/sync_status_indicator.dart';
import '../../sync/services/sync_service.dart';
import '../providers/settings_provider.dart';
import '../services/export_service.dart';
import 'import_preview_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final subscriptionState = ref.watch(subscriptionProvider);
    final isLocalOnlyMode = EnvConfig.isLocalOnlyMode;
    final isInLocalMode = authState.status == AuthStatus.localMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: ListView(
        children: [
          // Account section
          _buildSectionHeader('Konto'),
          if (isInLocalMode) ...[
            // User is in local mode - show connect option
            _buildInfoTile(
              icon: SolarIconsOutline.smartphone,
              label: 'Modus',
              value: 'Nur lokal',
            ),
            ListTile(
              leading: Icon(SolarIconsOutline.cloudUpload, color: AppColors.primary),
              title: const Text('Mit Cloud verbinden'),
              subtitle: const Text('Anmelden um Daten geräteübergreifend zu synchronisieren'),
              trailing: Icon(SolarIconsOutline.altArrowRight, color: AppColors.textSecondary),
              onTap: () => _connectToCloud(context, ref),
            ),
          ] else if (!isLocalOnlyMode && authState.user != null) ...[
            _buildInfoTile(
              icon: SolarIconsOutline.letter,
              label: 'E-Mail',
              value: authState.user!.email ?? 'Keine E-Mail',
            ),
          ] else if (isLocalOnlyMode) ...[
            _buildInfoTile(
              icon: SolarIconsOutline.smartphone,
              label: 'Modus',
              value: 'Nur lokal (Offline)',
            ),
          ],

          const Divider(height: 32),

          // Subscription section (only if RevenueCat is available)
          if (!isLocalOnlyMode) ...[
            _buildSectionHeader('Abonnement'),
            _buildSubscriptionTile(context, ref, subscriptionState),
            if (subscriptionState.isPro) ...[
              ListTile(
                leading: Icon(SolarIconsOutline.settings, color: AppColors.textPrimary),
                title: const Text('Abo verwalten'),
                subtitle: const Text('Abo ansehen, kündigen oder ändern'),
                trailing: Icon(SolarIconsOutline.altArrowRight, color: AppColors.textSecondary),
                onTap: () => PaywallHelper.showCustomerCenter(context),
              ),
            ] else ...[
              ListTile(
                leading: Icon(SolarIconsOutline.refresh, color: AppColors.textPrimary),
                title: const Text('Käufe wiederherstellen'),
                subtitle: const Text('Frühere Käufe wiederherstellen'),
                trailing: Icon(SolarIconsOutline.altArrowRight, color: AppColors.textSecondary),
                onTap: () => _restorePurchases(context, ref),
              ),
            ],

            const Divider(height: 32),

            // Sync section
            _buildSectionHeader('Synchronisation'),
            _buildSyncTile(context, ref, subscriptionState),

            const Divider(height: 32),
          ],

          // Behavior section
          _buildSectionHeader('Verhalten'),
          _buildCheckboxSizeTile(ref),

          const Divider(height: 32),

          // Data section - Export/Import
          _buildSectionHeader('Daten'),
          ListTile(
            leading: Icon(SolarIconsOutline.export, color: AppColors.textPrimary),
            title: const Text('Daten exportieren'),
            subtitle: const Text('Alle Aufgaben und Projekte als JSON speichern'),
            trailing: Icon(SolarIconsOutline.altArrowRight, color: AppColors.textSecondary),
            onTap: () => _exportData(context),
          ),
          ListTile(
            leading: Icon(SolarIconsOutline.import, color: AppColors.textPrimary),
            title: const Text('Daten importieren'),
            subtitle: const Text('Daten aus JSON-Datei importieren'),
            trailing: Icon(SolarIconsOutline.altArrowRight, color: AppColors.textSecondary),
            onTap: () => _importData(context),
          ),

          const Divider(height: 32),

          // About section
          _buildSectionHeader('Info'),
          _buildInfoTile(
            icon: SolarIconsOutline.infoCircle,
            label: 'Version',
            value: AppConstants.appVersion,
          ),
          ListTile(
            leading: Icon(SolarIconsOutline.documentText, color: AppColors.textPrimary),
            title: const Text('Lizenzen'),
            trailing: Icon(SolarIconsOutline.altArrowRight, color: AppColors.textSecondary),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: AppConstants.appName,
                applicationVersion: AppConstants.appVersion,
              );
            },
          ),

          const Divider(height: 32),

          // Sign out (show for authenticated cloud users)
          if (!isLocalOnlyMode && !isInLocalMode) ...[
            ListTile(
              leading: Icon(SolarIconsOutline.logout_2, color: AppColors.error),
              title: Text('Abmelden', style: TextStyle(color: AppColors.error)),
              onTap: () => _signOut(context, ref),
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(label),
      trailing: Text(
        value,
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildCheckboxSizeTile(WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isLarge = settings.checkboxSize == CheckboxSize.large;

    return SwitchListTile(
      secondary: Icon(SolarIconsOutline.checkCircle, color: AppColors.textPrimary),
      title: const Text('Großer Abhak-Kreis'),
      subtitle: Text(
        isLarge
            ? 'Größerer Kreis für einfacheres Tippen'
            : 'Normaler Kreis',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      value: isLarge,
      onChanged: (value) {
        ref.read(settingsProvider.notifier).setCheckboxSize(
          value ? CheckboxSize.large : CheckboxSize.normal,
        );
      },
      activeColor: AppColors.primary,
    );
  }

  Widget _buildSubscriptionTile(
    BuildContext context,
    WidgetRef ref,
    SubscriptionState state,
  ) {
    final isPro = state.isPro;
    final status = state.status;

    return ListTile(
      leading: Icon(
        isPro ? SolarIconsBold.crownStar : SolarIconsOutline.crownStar,
        color: isPro ? AppColors.warning : AppColors.textPrimary,
      ),
      title: Text(isPro ? 'Chukdoo Pro' : 'Kostenlos'),
      subtitle: isPro
          ? Text(
              status.expiresAt != null
                  ? 'Gültig bis ${_formatDate(status.expiresAt!)}'
                  : 'Aktiv',
            )
          : const Text('Nur lokale Speicherung'),
      trailing: isPro
          ? Chip(
              label: const Text('PRO'),
              backgroundColor: AppColors.warning.withOpacity(0.2),
              labelStyle: TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            )
          : TextButton(
              onPressed: () => _showPaywall(context, ref),
              child: const Text('Upgrade'),
            ),
    );
  }

  Widget _buildSyncTile(
    BuildContext context,
    WidgetRef ref,
    SubscriptionState subscriptionState,
  ) {
    final canSync = subscriptionState.canSync;

    if (!canSync) {
      return ListTile(
        leading: Icon(SolarIconsOutline.cloudCross, color: AppColors.textSecondary),
        title: const Text('Cloud-Sync'),
        subtitle: const Text('Upgrade auf Pro für Cloud-Sync'),
        trailing: TextButton(
          onPressed: () => _showPaywall(context, ref),
          child: const Text('Upgrade'),
        ),
      );
    }

    return Column(
      children: [
        ListTile(
          leading: Icon(SolarIconsOutline.cloudCheck, color: AppColors.success),
          title: const Text('Cloud-Sync'),
          subtitle: const Text('Aktiviert'),
          trailing: const SyncStatusIndicator(),
        ),
        ListTile(
          leading: Icon(SolarIconsOutline.refresh, color: AppColors.textPrimary),
          title: const Text('Jetzt synchronisieren'),
          subtitle: Text(
            SyncService.lastSyncTime != null
                ? 'Zuletzt: ${_formatDateTime(SyncService.lastSyncTime!)}'
                : 'Noch nie synchronisiert',
          ),
          trailing: Icon(SolarIconsOutline.altArrowRight, color: AppColors.textSecondary),
          onTap: () => _manualSync(context),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}.${dateTime.month}.${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showPaywall(BuildContext context, WidgetRef ref) async {
    final purchased = await PaywallHelper.showPaywall(context);
    if (purchased) {
      ref.read(subscriptionProvider.notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Willkommen bei Chukdoo Pro!')),
        );
      }
    }
  }

  Future<void> _restorePurchases(BuildContext context, WidgetRef ref) async {
    await ref.read(subscriptionProvider.notifier).restorePurchases();
    final state = ref.read(subscriptionProvider);
    if (context.mounted) {
      if (state.isPro) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Käufe erfolgreich wiederhergestellt!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Käufe gefunden.')),
        );
      }
    }
  }

  Future<void> _manualSync(BuildContext context) async {
    await SyncService.processQueue();
    if (context.mounted) {
      final status = SyncService.status;
      if (status == SyncStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync-Fehler: ${SyncService.lastError}'),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Synchronisation abgeschlossen')),
        );
      }
    }
  }

  void _signOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abmelden'),
        content: const Text('Möchtest du dich wirklich abmelden?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Pop settings page
              ref.read(authProvider.notifier).signOut();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );
  }

  void _connectToCloud(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mit Cloud verbinden'),
        content: const Text(
          'Verbinde dein Konto mit der Cloud, um deine Daten auf allen Geräten zu synchronisieren.\n\n'
          'Deine lokalen Daten bleiben erhalten und werden nach dem Login synchronisiert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Pop settings page
              ref.read(authProvider.notifier).goToLogin();
            },
            child: const Text('Zur Anmeldung'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Exportiere Daten...'),
          ],
        ),
      ),
    );

    final result = await ExportService.exportData();

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (result.success && result.filePath != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export erfolgreich'),
          content: Text(
            '${result.todoCount} Aufgaben und ${result.projectCount} Projekte wurden exportiert.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ExportService.shareExport(result.filePath!);
              },
              child: const Text('Teilen'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export fehlgeschlagen: ${result.error ?? "Unbekannter Fehler"}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _importData(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();

      final preview = ExportService.previewImport(content);

      if (!context.mounted) return;

      if (!preview.isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(preview.error ?? 'Ungültige Datei'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Navigate to preview page
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImportPreviewPage(preview: preview),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Lesen der Datei: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
