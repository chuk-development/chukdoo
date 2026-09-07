import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/config/env_config.dart';
import '../../../core/utils/native_io.dart' as native_io;
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/rounded_group.dart';
import '../../../shared/services/encryption_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/backup_codes_provider.dart';
import '../../donations/presentation/donation_page.dart';
import '../../donations/providers/donation_provider.dart';
import '../../sync/presentation/widgets/sync_status_indicator.dart';
import '../../sync/services/sync_service.dart';
import '../../todos/providers/todo_provider.dart';
import '../../projects/providers/project_provider.dart';
import '../providers/settings_provider.dart';
import '../services/export_service.dart';
import '../../integrations/sunrise_export_service.dart';
import 'import_preview_page.dart';
import 'licenses_page.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../core/theme/app_shapes.dart';

class SettingsPage extends ConsumerWidget {
  /// Opens the app drawer. Set by the shell, like every other tab.
  final VoidCallback? onMenu;

  const SettingsPage({super.key, this.onMenu});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isLocalOnlyMode = EnvConfig.isLocalOnlyMode;
    final isInLocalMode = authState.status == AuthStatus.localMode;

    return AppScaffold(
      onMenu: onMenu,
      title: 'Settings',
      body: ListView(
        padding: EdgeInsets.only(bottom: AppShapes.contentBottom(context)),
        children: [
          // Account section
          _buildSectionHeader('Account'),
          RoundedGroup(
            children: [
              if (isInLocalMode) ...[
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
              ] else if (!isLocalOnlyMode && authState.user != null)
                _buildInfoTile(
                  icon: MdiIcons.emailOutline,
                  label: 'Email',
                  value: authState.user!.email ?? 'No email',
                )
              else if (isLocalOnlyMode)
                _buildInfoTile(
                  icon: MdiIcons.cellphone,
                  label: 'Mode',
                  value: 'Local only (offline)',
                ),
            ],
          ),

          // Support section — the app is free, donations are optional.
          if (ref.watch(canDonateProvider)) ...[
            _buildSectionHeader('Support'),
            RoundedGroup(children: [_buildDonationTile(context, ref)]),
          ],

          // Sync section
          if (!isLocalOnlyMode) ...[
            _buildSectionHeader('Sync'),
            RoundedGroup(children: _buildSyncTiles(context, ref)),

            // Security section (only for cloud users)
            if (!isInLocalMode) ...[
              _buildSectionHeader('Security'),
              RoundedGroup(children: [_buildBackupCodesTile(context, ref)]),
            ],
          ],

          // Appearance section
          _buildSectionHeader('Appearance'),
          RoundedGroup(children: [_buildMaterialYouTile(ref)]),

          // Behavior section
          _buildSectionHeader('Behavior'),
          RoundedGroup(children: [_buildCheckboxSizeTile(ref)]),

          // Integrations section
          _buildSectionHeader('Integrations'),
          const RoundedGroup(children: [_SunriseToggleTile()]),

          // Data section - Export/Import
          _buildSectionHeader('Data'),
          RoundedGroup(
            children: [
              ListTile(
                leading: Icon(MdiIcons.export, color: AppColors.textPrimary),
                title: const Text('Export data'),
                subtitle: const Text('Save all tasks and projects as JSON'),
                trailing: Icon(
                  MdiIcons.chevronRight,
                  color: AppColors.textSecondary,
                ),
                onTap: () => _exportData(context),
              ),
              ListTile(
                leading: Icon(MdiIcons.import, color: AppColors.textPrimary),
                title: const Text('Import data'),
                subtitle: const Text('Import data from a JSON file'),
                trailing: Icon(
                  MdiIcons.chevronRight,
                  color: AppColors.textSecondary,
                ),
                onTap: () => _importData(context),
              ),
            ],
          ),

          // About section
          _buildSectionHeader('About'),
          RoundedGroup(
            children: [
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LicensesPage()),
                ),
              ),
            ],
          ),

          // Sign out (show for authenticated cloud users)
          if (!isLocalOnlyMode && !isInLocalMode) ...[
            const SizedBox(height: 8),
            RoundedGroup(
              children: [
                ListTile(
                  leading: Icon(MdiIcons.logout, color: AppColors.error),
                  title: Text(
                    'Sign out',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () => _signOut(context, ref),
                ),
              ],
            ),
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

  Widget _buildMaterialYouTile(WidgetRef ref) {
    final enabled = ref.watch(settingsProvider.select((s) => s.materialYou));

    return SwitchListTile(
      secondary: Icon(MdiIcons.palette, color: AppColors.primary),
      title: const Text('Material You colors'),
      subtitle: Text(
        enabled
            ? 'Accent & surfaces follow your system wallpaper'
            : 'Use the default platinum theme',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      value: enabled,
      onChanged: (value) {
        ref.read(settingsProvider.notifier).setMaterialYou(value);
      },
    );
  }

  Widget _buildCheckboxSizeTile(WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final size = settings.checkboxSize;

    // A three-step slider instead of a yes/no switch: small fits more tasks on
    // screen, large gives a bigger tap target, medium is the default look.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(MdiIcons.checkCircleOutline, color: AppColors.textPrimary),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Task row size',
                  style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
                ),
              ),
              Text(
                size.label,
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
          Slider(
            value: size.index.toDouble(),
            min: 0,
            max: 2,
            divisions: 2,
            label: size.label,
            onChanged: (value) => ref
                .read(settingsProvider.notifier)
                .setCheckboxSize(CheckboxSize.values[value.round()]),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationTile(BuildContext context, WidgetRef ref) {
    final donations = ref.watch(donationCountProvider);
    final count = donations.asData?.value ?? 0;

    return ListTile(
      leading: Icon(
        count > 0 ? MdiIcons.heart : MdiIcons.heartOutline,
        color: count > 0 ? AppColors.error : AppColors.textPrimary,
      ),
      title: Text(count > 0 ? 'Thanks for your support' : 'Donate'),
      subtitle: Text(
        count > 0
            ? 'The app stays free either way'
            : 'Everything is free. Pay what you want via Google Play.',
      ),
      trailing: Icon(MdiIcons.chevronRight, color: AppColors.textSecondary),
      onTap: () => _showDonationPage(context, ref),
    );
  }

  List<Widget> _buildSyncTiles(BuildContext context, WidgetRef ref) {
    // Read the same session the sync layer uses, so the two can never tell the
    // user different stories.
    final hasSession = SupabaseService.isAuthenticated;

    return [
      ListTile(
        leading: Icon(
          hasSession ? MdiIcons.cloudCheckOutline : MdiIcons.cloudClockOutline,
          color: hasSession ? AppColors.success : AppColors.textSecondary,
        ),
        title: const Text('Cloud sync'),
        subtitle: Text(hasSession ? 'Enabled' : 'Waiting for session'),
        trailing: const SyncStatusIndicator(),
      ),
      ListTile(
        leading: Icon(MdiIcons.refresh, color: AppColors.textPrimary),
        title: const Text('Sync now'),
        subtitle: Text(
          SyncService.lastSyncTime != null
              ? 'Last: ${_formatDateTime(SyncService.lastSyncTime!)}'
              : 'Never synced',
        ),
        trailing: Icon(MdiIcons.chevronRight, color: AppColors.textSecondary),
        onTap: () => _manualSync(context, ref),
      ),
    ];
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No user signed in.')));
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}.${dateTime.month}.${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showDonationPage(BuildContext context, WidgetRef ref) async {
    final donated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const DonationPage(),
        fullscreenDialog: true,
      ),
    );

    if (donated == true) {
      ref.invalidate(donationCountProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Thank you!')));
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
      } else if (status == SyncStatus.offline) {
        // No usable session or no network - say so instead of claiming success.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offline - changes stay queued and sync later'),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sync complete')));
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
          content: Text('Export failed: ${result.error ?? "Unknown error"}'),
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
                    Icon(MdiIcons.alertOutline, color: AppColors.warning),
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
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: TextStyle(
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
  /// Remembered across rebuilds so re-opening settings does not show the
  /// switch as off for a frame and then flip it on.
  static bool? _lastKnown;

  late bool _enabled = _lastKnown ?? false;
  late bool _loading = _lastKnown == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await SunriseExportService.isEnabled();
    _lastKnown = v;
    if (mounted) {
      setState(() {
        _enabled = v;
        _loading = false;
      });
    }
  }

  Future<void> _toggle(bool v) async {
    setState(() => _enabled = v);
    _lastKnown = v;
    await SunriseExportService.setEnabled(v);
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(MdiIcons.weatherSunny, color: AppColors.textPrimary),
      title: const Text('Connect Sunrise'),
      subtitle: const Text(
        'Show today\'s tasks in the Sunrise app (this device only, unencrypted).',
      ),
      value: _enabled,
      onChanged: _loading ? null : _toggle,
    );
  }
}
