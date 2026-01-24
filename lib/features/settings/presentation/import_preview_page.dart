import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../services/export_service.dart';

class ImportPreviewPage extends ConsumerStatefulWidget {
  final ImportPreview preview;

  const ImportPreviewPage({super.key, required this.preview});

  @override
  ConsumerState<ImportPreviewPage> createState() => _ImportPreviewPageState();
}

class _ImportPreviewPageState extends ConsumerState<ImportPreviewPage> {
  bool _replaceExisting = false;
  bool _isImporting = false;

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
            'Import erfolgreich: ${widget.preview.todoCount} Aufgaben, ${widget.preview.projectCount} Projekte',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import fehlgeschlagen'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Vorschau'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary card
          Card(
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          SolarIconsOutline.import,
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
                                'Exportiert am ${_formatDate(preview.exportedAt!)}',
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
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  // Stats
                  _buildStatRow(
                    SolarIconsOutline.checklistMinimalistic,
                    'Aufgaben',
                    preview.todoCount.toString(),
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow(
                    SolarIconsOutline.folder,
                    'Projekte',
                    preview.projectCount.toString(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Import options
          Text(
            'Import Optionen',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: AppColors.surface,
            child: Column(
              children: [
                SwitchListTile(
                  value: _replaceExisting,
                  onChanged: (value) {
                    setState(() => _replaceExisting = value);
                  },
                  title: const Text('Bestehende Daten ersetzen'),
                  subtitle: Text(
                    _replaceExisting
                        ? 'Alle lokalen Daten werden gelöscht'
                        : 'Neue Daten werden hinzugefügt',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  secondary: Icon(
                    _replaceExisting
                        ? SolarIconsOutline.trashBinTrash
                        : SolarIconsOutline.addCircle,
                    color: _replaceExisting ? AppColors.warning : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          if (_replaceExisting) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(SolarIconsOutline.dangerTriangle, color: AppColors.warning, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Achtung: Alle bestehenden Aufgaben und Projekte werden gelöscht!',
                      style: TextStyle(color: AppColors.warning, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Todo preview
          if (preview.todos.isNotEmpty) ...[
            Text(
              'Aufgaben Vorschau',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: AppColors.surface,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: preview.todos.take(5).length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final todo = preview.todos[index];
                  return ListTile(
                    leading: Icon(
                      SolarIconsOutline.checkCircle,
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
                  );
                },
              ),
            ),
            if (preview.todos.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '... und ${preview.todos.length - 5} weitere',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
          ],

          const SizedBox(height: 32),

          // Import button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isImporting ? null : _import,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
              ),
              child: _isImporting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Importieren',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: AppColors.textSecondary)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}
