import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shapes.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/rounded_group.dart';
import '../services/export_service.dart';
import 'widgets/settings_tiles.dart';

class ImportPreviewPage extends ConsumerStatefulWidget {
  final ImportPreview preview;

  const ImportPreviewPage({super.key, required this.preview});

  @override
  ConsumerState<ImportPreviewPage> createState() => _ImportPreviewPageState();
}

class _ImportPreviewPageState extends ConsumerState<ImportPreviewPage> {
  bool _replaceExisting = false;
  bool _isImporting = false;

  /// One duration for every state change on this page.
  static const Duration _motion = Duration(milliseconds: 220);

  Future<void> _import() async {
    setState(() => _isImporting = true);

    final success = await ExportService.importData(
      widget.preview,
      replace: _replaceExisting,
    );

    if (!mounted) return;

    setState(() => _isImporting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Import successful: ${widget.preview.todoCount} tasks, ${widget.preview.projectCount} projects',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    final previewTodos = preview.todos.take(5).toList();

    // A pushed page owns its background; [AppScaffold] paints none.
    return ColoredBox(
      color: AppColors.background,
      child: AppScaffold(
        title: 'Import preview',
        onBack: () => Navigator.pop(context),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            0,
            8,
            0,
            AppShapes.contentBottom(context),
          ),
          children: [
            // Summary: header row and the two stat rows are one group.
            RoundedGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            AppShapes.dockField,
                          ),
                        ),
                        child: Icon(
                          MdiIcons.import,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Chukdoo Export',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (preview.exportedAt != null)
                              Text(
                                'Exported on ${_formatDate(preview.exportedAt!)}',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatRow(
                  MdiIcons.formatListChecks,
                  'Tasks',
                  preview.todoCount.toString(),
                ),
                _buildStatRow(
                  MdiIcons.folderOutline,
                  'Projects',
                  preview.projectCount.toString(),
                ),
              ],
            ),

            // Import options
            const SettingsSectionHeader('Import options'),
            RoundedGroup(
              children: [
                SwitchListTile(
                  value: _replaceExisting,
                  onChanged: (value) {
                    setState(() => _replaceExisting = value);
                  },
                  title: const Text('Replace existing data'),
                  subtitle: Text(
                    _replaceExisting
                        ? 'All local data will be deleted'
                        : 'New data will be added',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  secondary: Icon(
                    _replaceExisting
                        ? MdiIcons.trashCanOutline
                        : MdiIcons.plusCircleOutline,
                    color: _replaceExisting
                        ? AppColors.warning
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            // Warning grows in when the switch is turned on.
            AnimatedSize(
              duration: _motion,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !_replaceExisting
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppShapes.listInset,
                        12,
                        AppShapes.listInset,
                        0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(
                            AppShapes.dockField,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              MdiIcons.alertOutline,
                              color: AppColors.warning,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Warning: all existing tasks and projects will be deleted!',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            // Todo preview
            if (previewTodos.isNotEmpty) ...[
              const SettingsSectionHeader('Task preview'),
              RoundedGroup(
                children: [
                  for (final todo in previewTodos)
                    ListTile(
                      leading: Icon(
                        MdiIcons.checkCircleOutline,
                        color: AppColors.textSecondary,
                      ),
                      title: Text(
                        todo.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: todo.dueDate != null
                          ? Text(
                              _formatDate(todo.dueDate!),
                              style: TextStyle(color: AppColors.textSecondary),
                            )
                          : null,
                    ),
                ],
              ),
              if (preview.todos.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '... and ${preview.todos.length - 5} more',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],

            const SizedBox(height: 32),

            // Import button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppShapes.listInset,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isImporting ? null : _import,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isImporting
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Text(
                          'Import',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}
