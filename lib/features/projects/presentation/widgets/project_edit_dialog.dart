import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/project.dart';
import '../../domain/project_icons.dart';
import '../../providers/project_provider.dart';

class ProjectEditDialog extends ConsumerStatefulWidget {
  final Project? project;

  const ProjectEditDialog({super.key, this.project});

  static Future<Project?> show(BuildContext context, {Project? project}) {
    return showDialog<Project?>(
      context: context,
      builder: (_) => ProjectEditDialog(project: project),
    );
  }

  @override
  ConsumerState<ProjectEditDialog> createState() => _ProjectEditDialogState();
}

class _ProjectEditDialogState extends ConsumerState<ProjectEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late int _selectedColor;
  late String _selectedIcon;

  bool get _isEditing => widget.project != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project?.name ?? '');
    _descriptionController = TextEditingController(text: widget.project?.description ?? '');
    _selectedColor = widget.project?.color ?? AppColors.projectColors[0].value;
    _selectedIcon = widget.project?.icon ?? kDefaultProjectIcon;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final description = _descriptionController.text.trim();

    if (_isEditing) {
      final updated = widget.project!.copyWith(
        name: name,
        description: description.isEmpty ? null : description,
        clearDescription: description.isEmpty,
        color: _selectedColor,
        icon: _selectedIcon,
      );
      await ref.read(projectProvider.notifier).updateProject(updated);
      if (mounted) Navigator.pop(context, updated);
    } else {
      final project = await ref.read(projectProvider.notifier).addProject(
            name: name,
            description: description.isEmpty ? null : description,
            color: _selectedColor,
            icon: _selectedIcon,
          );
      if (mounted) Navigator.pop(context, project);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Projekt löschen?'),
        content: Text(
          'Das Projekt "${widget.project!.name}" wird gelöscht. '
          'Aufgaben bleiben im Eingang erhalten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(projectProvider.notifier).deleteProject(widget.project!.id);
              Navigator.pop(ctx);
              Navigator.pop(context, null);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Projekt bearbeiten' : 'Neues Projekt'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: !_isEditing,
              decoration: InputDecoration(
                hintText: 'Projektname',
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: 'Beschreibung (optional)',
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 3,
              minLines: 1,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            Text(
              'Farbe',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: AppColors.projectColors.map((color) {
                final isSelected = color.value == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: AppColors.textPrimary, width: 2.5) : null,
                    ),
                    child: isSelected ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'Symbol',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kProjectIcons.entries.map((e) {
                    final isSelected = e.key == _selectedIcon;
                    final tint = Color(_selectedColor);
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIcon = e.key),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected ? tint.withValues(alpha: 0.18) : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: isSelected ? Border.all(color: tint, width: 2) : null,
                        ),
                        child: Icon(e.value, size: 20, color: isSelected ? tint : AppColors.textSecondary),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 24),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _confirmDelete,
                icon: const Icon(SolarIconsOutline.trashBinTrash, size: 18),
                label: const Text('Projekt löschen'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: Text(_isEditing ? 'Speichern' : 'Erstellen'),
        ),
      ],
    );
  }
}
