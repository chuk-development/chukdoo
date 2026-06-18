import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/config/env_config.dart';
import '../../../core/utils/native_io.dart' as native_io;
import '../../../core/utils/platform_utils.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/services/encryption_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/backup_codes_provider.dart';
import '../../subscription/presentation/paywall_helper.dart';
import '../../subscription/providers/subscription_provider.dart';
import '../../sync/presentation/widgets/sync_status_indicator.dart';
import '../../sync/services/sync_service.dart';
import '../../todos/providers/todo_provider.dart';
import '../../projects/providers/project_provider.dart';
import '../providers/settings_provider.dart';
import '../services/export_service.dart';
import '../../integrations/sunrise_export_service.dart';
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
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Account section
          _buildSectionHeader('Account'),
          if (isInLocalMode) ...[
            // User is in local mode - show connect option
            _buildInfoTile(
              icon: MdiIcons.cellphone,
              label: 'Mode',
              value: 'Local only',
            ),
            ListTile(
              leading: Icon(
                MdiIcons.cloudUploadOutline,
                color: AppColors.primary,
              ),
              title: const Text('Connect to cloud'),
              subtitle: const Text(
                'Sign in to sync your data across devices',
              ),
              trailing: Icon(
                MdiIcons.chevronRight,
                color: AppColors.textSecondary,
              ),
              onTap: () => _connectToCloud(context, ref),
            ),
          ] else if (!isLocalOnlyMode && authState.user != null) ...[
            _buildInfoTile(
              icon: MdiIcons.emailOutline,
              label: 'Email',
              value: authState.user!.email ?? 'No email',
            ),
          ] else if (isLocalOnlyMode) ...[
            _buildInfoTile(
              icon: MdiIcons.cellphone,
              label: 'Mode',
              value: 'Local only (offline)',
            ),
          ],

          const Divider(height: 32),

          // Subscription section (only if RevenueCat is available)
          if (!isLocalOnlyMode) ...[
            _buildSectionHeader('Subscription'),
            _buildSubscriptionTile(context, ref, subscriptionState),
            if (subscriptionState.isPro) ...[
              Builder(
                builder: (context) {
                  final isDesktop = PlatformUtils.isDesktop;
                  return ListTile(
                    leading: Icon(
                      MdiIcons.cogOutline,
                      color: AppColors.textPrimary,
                    ),
                    title: const Text('Manage subscription'),
                    subtitle: Text(
                      isDesktop
                          ? 'Available in the mobile app only'
                          : 'View, cancel or change your subscription',
                    ),
                    trailing: isDesktop
                        ? Icon(
                            MdiIcons.cellphone,
                            color: AppColors.textSecondary,
                          )
                        : Icon(
                            MdiIcons.chevronRight,
                            color: AppColors.textSecondary,
                          ),
                    onTap: isDesktop
                        ? null
                        : () => PaywallHelper.showCustomerCenter(context),
                  );
                },
              ),
            ] else ...[
              ListTile(
                leading: Icon(
                  MdiIcons.refresh,
                  color: AppColors.textPrimary,
                ),
                title: const Text('Restore purchases'),
                subtitle: const Text('Restore previous purchases'),
                trailing: Icon(
                  MdiIcons.chevronRight,
                  color: AppColors.textSecondary,
                ),
                onTap: () => _restorePurchases(context, ref),
              ),
            ],

            const Divider(height: 32),

            // Sync section
            _buildSectionHeader('Sync'),
            _buildSyncTile(context, ref, subscriptionState),

            const Divider(height: 32),

            // Security section (only for cloud users)
            if (!isInLocalMode) ...[
              _buildSectionHeader('Security'),
              _buildBackupCodesTile(context, ref),
              const Divider(height: 32),
            ],
          ],

          // Behavior section
          _buildSectionHeader('Behavior'),
          _buildCheckboxSizeTile(ref),

          const Divider(height: 32),

          // Integrations section
          _buildSectionHeader('Integrations'),
          const _SunriseToggleTile(),

          const Divider(height: 32),

          // Data section - Export/Import
          _buildSectionHeader('Data'),
          ListTile(
            leading: Icon(
              MdiIcons.export,
              color: AppColors.textPrimary,
            ),
            title: const Text('Export data'),
            subtitle: const Text(
              'Save all tasks and projects as JSON',
            ),
            trailing: Icon(
              MdiIcons.chevronRight,
              color: AppColors.textSecondary,
            ),
            onTap: () => _exportData(context),
          ),
          ListTile(
            leading: Icon(
              MdiIcons.import,
              color: AppColors.textPrimary,
            ),
            title: const Text('Import data'),
            subtitle: const Text('Import data from a JSON file'),
            trailing: Icon(
              MdiIcons.chevronRight,
              color: AppColors.textSecondary,
            ),
            onTap: () => _importData(context),
          ),

          const Divider(height: 32),

          // About section
          _buildSectionHeader('About'),
          _buildInfoTile(
            icon: MdiIcons.informationOutline,
            label: 'Version',
            value: AppConstants.appVersion,
          ),
          ListTile(
            leading: Icon(
              MdiIcons.fileDocumentOutline,
              color: AppColors.textPrimary,
            ),
            title: const Text('Licenses'),
            trailing: Icon(
              MdiIcons.chevronRight,
              color: AppColors.textSecondary,
            ),
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
              leading: Icon(MdiIcons.logout, color: AppColors.error),
              title: Text('Sign out', style: TextStyle(color: AppColors.error)),
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
      trailing: Text(value, style: TextStyle(color: AppColors.textSecondary)),
    );
  }

  Widget _buildCheckboxSizeTile(WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isLarge = settings.checkboxSize == CheckboxSize.large;

    return SwitchListTile(
      secondary: Icon(
        MdiIcons.checkCircleOutline,
        color: AppColors.textPrimary,
      ),
      title: const Text('Large checkbox'),
      subtitle: Text(
        isLarge ? 'Bigger circle for easier tapping' : 'Normal circle',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      value: isLarge,
      onChanged: (value) {
        ref
            .read(settingsProvider.notifier)
            .setCheckboxSize(value ? CheckboxSize.large : CheckboxSize.normal);
      },
      activeThumbColor: AppColors.primary,
    );
  }

  Widget _buildSubscriptionTile(
    BuildContext context,
    WidgetRef ref,
    SubscriptionState state,
  ) {
    final isPro = state.isPro;
    final status = state.status;
    final isDesktop = PlatformUtils.isDesktop;

    return ListTile(
      leading: Icon(
        isPro ? MdiIcons.crown : MdiIcons.crownOutline,
        color: isPro ? AppColors.warning : AppColors.textPrimary,
      ),
      title: Text(isPro ? 'Chukdoo Pro' : 'Free'),
      subtitle: isPro
          ? Text(
              status.expiresAt != null
                  ? 'Valid until ${_formatDate(status.expiresAt!)}'
                  : 'Active',
            )
          : Text(
              isDesktop
                  ? 'Upgrade in the mobile app'
                  : 'Local storage only',
            ),
      trailing: isPro
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DefaultTextStyle(
                style: TextStyle(color: AppColors.warning),
                child: const Text('PRO',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            )
          : isDesktop
          ? Icon(MdiIcons.cellphone, color: AppColors.textSecondary)
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
    final isDesktop = PlatformUtils.isDesktop;

    if (!canSync) {
      return ListTile(
        leading: Icon(
          MdiIcons.cloudOffOutline,
          color: AppColors.textSecondary,
        ),
        title: const Text('Cloud sync'),
        subtitle: Text(
          isDesktop
              ? 'Upgrade in the mobile app for cloud sync'
              : 'Upgrade to Pro for cloud sync',
        ),
        trailing: isDesktop
            ? Icon(MdiIcons.cellphone, color: AppColors.textSecondary)
            : TextButton(
                onPressed: () => _showPaywall(context, ref),
                child: const Text('Upgrade'),
              ),
      );
    }

    return Column(
      children: [
        ListTile(
          leading: Icon(MdiIcons.cloudCheckOutline, color: AppColors.success),
          title: const Text('Cloud sync'),
          subtitle: const Text('Enabled'),
          trailing: const SyncStatusIndicator(),
        ),
        ListTile(
          leading: Icon(
            MdiIcons.refresh,
            color: AppColors.textPrimary,
          ),
          title: const Text('Sync now'),
          subtitle: Text(
            SyncService.lastSyncTime != null
                ? 'Last: ${_formatDateTime(SyncService.lastSyncTime!)}'
                : 'Never synced',
          ),
          trailing: Icon(
            MdiIcons.chevronRight,
            color: AppColors.textSecondary,
          ),
          onTap: () => _manualSync(context, ref),
        ),
      ],
    );
  }

  Widget _buildBackupCodesTile(BuildContext context, WidgetRef ref) {
    final availableCodes = ref.watch(availableBackupCodesProvider);
    final hasMasterKey = ref.watch(hasMasterKeySetupProvider);

    return hasMasterKey.when(
      data: (hasSetup) {
        if (!hasSetup) {
          // Legacy user without Master Key - show migration option
          return ListTile(
            leading: Icon(MdiIcons.keyOutline, color: AppColors.textPrimary),
            title: const Text('Backup codes'),
            subtitle: const Text('Not set up yet'),
            trailing: TextButton(
              onPressed: () => _showMigrationDialog(context, ref),
              child: const Text('Set up'),
            ),
          );
        }

        return availableCodes.when(
          data: (count) => ListTile(
            leading: Icon(MdiIcons.keyOutline, color: AppColors.textPrimary),
            title: const Text('Backup codes'),
            subtitle: Text(
              '$count of ${AppConstants.backupCodeCount} codes available',
            ),
            trailing: TextButton(
              onPressed: () => _regenerateBackupCodes(context, ref),
              child: const Text('Regenerate'),
            ),
          ),
          loading: () => ListTile(
            leading: Icon(MdiIcons.keyOutline, color: AppColors.textPrimary),
            title: const Text('Backup codes'),
            subtitle: const Text('Loading...'),
          ),
          error: (_, _) => ListTile(
            leading: Icon(MdiIcons.keyOutline, color: AppColors.textPrimary),
            title: const Text('Backup codes'),
            subtitle: const Text('Failed to load'),
          ),
        );
      },
      loading: () => ListTile(
        leading: Icon(MdiIcons.keyOutline, color: AppColors.textPrimary),
        title: const Text('Backup codes'),
        subtitle: const Text('Loading...'),
      ),
      error: (_, _) => ListTile(
        leading: Icon(MdiIcons.keyOutline, color: AppColors.textPrimary),
        title: const Text('Backup codes'),
        subtitle: const Text('Failed to load'),
      ),
    );
  }

  Future<void> _showMigrationDialog(BuildContext context, WidgetRef ref) async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user signed in.')),
      );
      return;
    }

    final passwordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set up backup codes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backup codes let you access your account if you forget your password.\n\n'
              'Enter your current password to generate backup codes.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Set up'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Setting up backup codes...'),
          ],
        ),
      ),
    );

    final result = await EncryptionService.migrateToMasterKeyArchitecture(
      userId: user.id,
      password: passwordController.text,
    );

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (result.success && result.codes.isNotEmpty) {
      // Refresh the providers
      ref.invalidate(hasMasterKeySetupProvider);
      ref.invalidate(availableBackupCodesProvider);

      // Show the new codes
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _ShowNewBackupCodesPage(codes: result.codes),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Migration failed.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _regenerateBackupCodes(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final passwordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate new backup codes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'All existing codes will become invalid. Enter your password to continue.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Generating codes...'),
          ],
        ),
      ),
    );

    final newCodes = await ref
        .read(authProvider.notifier)
        .regenerateBackupCodes(passwordController.text);

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (newCodes != null && newCodes.isNotEmpty) {
      // Refresh the providers
      ref.invalidate(availableBackupCodesProvider);

      // Show the new codes
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _ShowNewBackupCodesPage(codes: newCodes),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wrong password or failed to generate.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
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
          const SnackBar(content: Text('Welcome to Chukdoo Pro!')),
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
          const SnackBar(content: Text('Purchases restored successfully!')),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No purchases found.')));
      }
    }
  }

  Future<void> _manualSync(BuildContext context, WidgetRef ref) async {
    await SyncService.fullSync();

    // Refresh providers to show new data from sync
    await ref.read(todoProvider.notifier).refresh();
    await ref.read(projectProvider.notifier).refresh();

    if (context.mounted) {
      final status = SyncService.status;
      if (status == SyncStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: ${SyncService.lastError}'),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync complete')),
        );
      }
    }
  }

  void _signOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Pop settings page
              ref.read(authProvider.notifier).signOut();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  void _connectToCloud(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect to cloud'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Connect your account to the cloud to sync your data across all devices.\n\n'
              'Your local data stays intact and is synced after you sign in.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Pop settings page
              ref.read(authProvider.notifier).goToLogin();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Sign in'),
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
            Text('Exporting data...'),
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
          title: const Text('Export successful'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${result.todoCount} tasks and ${result.projectCount} projects were exported.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ExportService.shareExport(result.filePath!);
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Share'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Export failed: ${result.error ?? "Unknown error"}',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _importData(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.single.bytes;
      final filePath = result.files.single.path;
      final String content;
      if (bytes != null) {
        content = String.fromCharCodes(bytes);
      } else if (filePath != null) {
        // On native platforms, read from file path via conditional import
        content = await native_io.readFileAsString(filePath);
      } else {
        throw Exception('Could not read file');
      }

      final preview = ExportService.previewImport(content);

      if (!context.mounted) return;

      if (!preview.isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(preview.error ?? 'Invalid file'),
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
          content: Text('Failed to read file: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

/// Helper page to show newly generated backup codes
class _ShowNewBackupCodesPage extends StatefulWidget {
  final List<String> codes;

  const _ShowNewBackupCodesPage({required this.codes});

  @override
  State<_ShowNewBackupCodesPage> createState() =>
      _ShowNewBackupCodesPageState();
}

class _ShowNewBackupCodesPageState extends State<_ShowNewBackupCodesPage> {
  bool _hasSaved = false;

  void _copyAllCodes() {
    final text = widget.codes
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Codes copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New backup codes'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      MdiIcons.alertOutline,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your old backup codes are now invalid. Store the new codes somewhere safe!',
                        style: TextStyle(color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: widget.codes.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${entry.key + 1}.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _copyAllCodes,
                icon: Icon(MdiIcons.contentCopy),
                label: const Text('Copy all'),
              ),
              const SizedBox(height: 24),
              CheckboxListTile(
                value: _hasSaved,
                onChanged: (value) {
                  setState(() {
                    _hasSaved = value ?? false;
                  });
                },
                title: const Text(
                  'I have stored the codes safely',
                  style: TextStyle(fontSize: 14),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _hasSaved ? () => Navigator.pop(context) : null,
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SunriseToggleTile extends StatefulWidget {
  const _SunriseToggleTile();

  @override
  State<_SunriseToggleTile> createState() => _SunriseToggleTileState();
}

class _SunriseToggleTileState extends State<_SunriseToggleTile> {
  bool _enabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await SunriseExportService.isEnabled();
    if (mounted) {
      setState(() {
        _enabled = v;
        _loading = false;
      });
    }
  }

  Future<void> _toggle(bool v) async {
    setState(() => _enabled = v);
    await SunriseExportService.setEnabled(v);
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(MdiIcons.weatherSunny, color: AppColors.textPrimary),
      title: const Text('Connect Sunrise'),
      subtitle: const Text(
          'Show today\'s tasks in the Sunrise app (this device only, unencrypted).'),
      value: _loading ? false : _enabled,
      onChanged: _loading ? null : _toggle,
    );
  }
}
