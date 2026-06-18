import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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
          Icon(MdiIcons.alertOutline, color: AppColors.warning),
          const SizedBox(width: 12),
          const Text('Sync Conflict'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This task was changed on another device.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              'Changed fields:',
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
              icon: MdiIcons.cellphone,
              label: 'Local (This Device)',
              todo: local,
              color: AppColors.blue,
            ),
            const SizedBox(height: 12),

            // Server version
            _buildVersionCard(
              icon: MdiIcons.cloudOutline,
              label: 'Server (Other Device)',
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
          icon: Icon(MdiIcons.cellphone, size: 18),
          label: const Text('Keep Local'),
        ),
        // Keep server
        TextButton.icon(
          onPressed: () => Navigator.pop(context, ConflictResolution.keepServer),
          icon: Icon(MdiIcons.cloudOutline, size: 18),
          label: const Text('Keep Server'),
        ),
        // Keep both
        TextButton.icon(
          onPressed: () => Navigator.pop(context, ConflictResolution.keepBoth),
          icon: Icon(MdiIcons.contentCopy, size: 18),
          label: const Text('Keep Both'),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
