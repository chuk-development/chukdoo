import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class BackupCodesPage extends ConsumerStatefulWidget {
  const BackupCodesPage({super.key});

  @override
  ConsumerState<BackupCodesPage> createState() => _BackupCodesPageState();
}

class _BackupCodesPageState extends ConsumerState<BackupCodesPage> {
  bool _hasSavedCodes = false;

  void _copyAllCodes(List<String> codes) {
    final text = codes.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Codes copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copySingleCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$code copied'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _handleContinue() {
    ref.read(authProvider.notifier).confirmBackupCodesSaved();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final codes = authState.pendingBackupCodes ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup codes'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        MdiIcons.keyOutline,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Save your backup codes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'These codes let you access your data if you forget your password. Each code can only be used once.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Codes list
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    ...codes.asMap().entries.map((entry) {
                      final index = entry.key;
                      final code = entry.value;
                      return _buildCodeRow(index + 1, code);
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Copy all button
              OutlinedButton.icon(
                onPressed: codes.isEmpty ? null : () => _copyAllCodes(codes),
                icon: Icon(MdiIcons.contentCopy),
                label: const Text('Copy all'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),

              const SizedBox(height: 24),

              // Warning
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      MdiIcons.alertOutline,
                      size: 20,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Store these codes somewhere safe. This is the only time you will see them!',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Checkbox
              CheckboxListTile(
                value: _hasSavedCodes,
                onChanged: (value) {
                  setState(() {
                    _hasSavedCodes = value ?? false;
                  });
                },
                title: const Text(
                  'I have saved the codes somewhere safe',
                  style: TextStyle(fontSize: 14),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 16),

              // Continue button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _hasSavedCodes ? _handleContinue : null,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeRow(int index, String code) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$index.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _copySingleCode(code),
            icon: Icon(
              MdiIcons.contentCopy,
              size: 18,
              color: AppColors.textSecondary,
            ),
            visualDensity: VisualDensity.compact,
            tooltip: 'Copy',
          ),
        ],
      ),
    );
  }
}
