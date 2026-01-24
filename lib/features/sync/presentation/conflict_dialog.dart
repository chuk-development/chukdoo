import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/models/sync_conflict.dart';

/// Shows a dialog for the user to resolve a sync conflict
Future<ConflictResolution?> showConflictDialog(
  BuildContext context,
  SyncConflict conflict,
) {
  return showDialog<ConflictResolution>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ConflictDialog(conflict: conflict),
  );
}

class ConflictDialog extends StatelessWidget {
  final SyncConflict conflict;

  const ConflictDialog({super.key, required this.conflict});

  @override
  Widget build(BuildContext context) {
    final local = conflict.localVersion;
    final server = conflict.serverVersion;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          Icon(SolarIconsOutline.dangerTriangle, color: AppColors.warning),
          const SizedBox(width: 12),
          const Text('Sync-Konflikt'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Diese Aufgabe wurde auf einem anderen Gerät geändert.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              'Geänderte Felder:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: conflict.changedFields.map((field) {
                return Chip(
                  label: Text(field, style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppColors.surfaceLight,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // Local version
            _buildVersionCard(
              icon: SolarIconsOutline.smartphone,
              label: 'Lokal (Dieses Gerät)',
              todo: local,
              color: AppColors.blue,
            ),
            const SizedBox(height: 12),

            // Server version
            _buildVersionCard(
              icon: SolarIconsOutline.cloud,
              label: 'Server (Anderes Gerät)',
              todo: server,
              color: AppColors.purple,
            ),
          ],
        ),
      ),
      actions: [
        // Keep local
        TextButton.icon(
          onPressed: () => Navigator.pop(context, ConflictResolution.keepLocal),
          icon: Icon(SolarIconsOutline.smartphone, size: 18),
          label: const Text('Lokal behalten'),
        ),
        // Keep server
        TextButton.icon(
          onPressed: () => Navigator.pop(context, ConflictResolution.keepServer),
          icon: Icon(SolarIconsOutline.cloud, size: 18),
          label: const Text('Server übernehmen'),
        ),
        // Keep both
        TextButton.icon(
          onPressed: () => Navigator.pop(context, ConflictResolution.keepBoth),
          icon: Icon(SolarIconsOutline.copy, size: 18),
          label: const Text('Beide behalten'),
        ),
      ],
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    );
  }

  Widget _buildVersionCard({
    required IconData icon,
    required String label,
    required dynamic todo,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            todo.title,
            style: const TextStyle(fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (todo.description != null && todo.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              todo.description!,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Version ${todo.version} - ${_formatDate(todo.updatedAt)}',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
