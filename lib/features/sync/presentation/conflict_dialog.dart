import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shapes.dart';
import '../../../shared/widgets/picker_sheet.dart';
import '../../../shared/widgets/rounded_group.dart';
import '../domain/models/sync_conflict.dart';

/// Shows the sheet for the user to resolve a sync conflict.
///
/// Like every other choice in the app this is a bottom sheet, not a dialog.
/// It cannot be dismissed by tapping outside — the caller needs an answer.
Future<ConflictResolution?> showConflictDialog(
  BuildContext context,
  SyncConflict conflict,
) {
  return showModalBottomSheet<ConflictResolution>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
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

    return PickerSheetScaffold(
      title: 'Sync conflict',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppShapes.listInset + 6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(MdiIcons.alertOutline, size: 20, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This task was changed on another device.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
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
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Local version
                _buildVersionBlock(
                  icon: MdiIcons.cellphone,
                  label: 'Local (this device)',
                  todo: local,
                  color: AppColors.blue,
                ),
                const SizedBox(height: AppShapes.groupGap),

                // Server version
                _buildVersionBlock(
                  icon: MdiIcons.cloudOutline,
                  label: 'Server (other device)',
                  todo: server,
                  color: AppColors.purple,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // The three answers as one rounded group of rows
          RoundedGroup(
            children: [
              _buildChoiceRow(
                context,
                icon: MdiIcons.cellphone,
                label: 'Keep local',
                resolution: ConflictResolution.keepLocal,
              ),
              _buildChoiceRow(
                context,
                icon: MdiIcons.cloudOutline,
                label: 'Keep server',
                resolution: ConflictResolution.keepServer,
              ),
              _buildChoiceRow(
                context,
                icon: MdiIcons.contentCopy,
                label: 'Keep both',
                resolution: ConflictResolution.keepBoth,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required ConflictResolution resolution,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, resolution),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionBlock({
    required IconData icon,
    required String label,
    required dynamic todo,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppShapes.dockField),
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
