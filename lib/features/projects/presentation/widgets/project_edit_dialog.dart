import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../shared/widgets/picker_sheet.dart';
import '../../../../shared/widgets/rounded_group.dart';
import '../../domain/models/project.dart';
import '../../domain/project_icons.dart';
import '../../providers/project_provider.dart';

/// Create or edit a project. It is a form, but it opens as the same
/// top-rounded bottom sheet every other choice in the app uses.
class ProjectEditDialog extends ConsumerStatefulWidget {
  final Project? project;

  const ProjectEditDialog({super.key, this.project});

  static Future<Project?> show(BuildContext context, {Project? project}) {
    return showModalBottomSheet<Project?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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

  /// One duration for every state change in this sheet.
  static const Duration _motion = Duration(milliseconds: 200);

  bool get _isEditing => widget.project != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project?.name ?? '');
    _descriptionController = TextEditingController(text: widget.project?.description ?? '');
    _selectedColor = widget.project?.color ?? AppColors.projectColors[0].toARGB32();
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

  /// Deleting is a confirmation, so it asks in a sheet like everything else.
  Future<void> _confirmDelete() async {
    final confirmed = await showPickerSheet<bool>(
      context: context,
      title: 'Delete project?',
      footnote: 'The project "${widget.project!.name}" will be deleted. '
          'Tasks stay in the inbox.',
      options: [
        PickerOption(
          value: true,
          label: 'Delete project',
          icon: MdiIcons.trashCanOutline,
          color: AppColors.error,
        ),
        PickerOption(
          value: false,
          label: 'Cancel',
          icon: MdiIcons.close,
        ),
      ],
    );

    if (confirmed != true || !mounted) return;
    ref.read(projectProvider.notifier).deleteProject(widget.project!.id);
    if (mounted) Navigator.pop(context, null);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Keep the form above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: PickerSheetScaffold(
        title: _isEditing ? 'Edit project' : 'New project',
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppShapes.listInset + 6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                autofocus: !_isEditing,
                decoration: const InputDecoration(hintText: 'Project name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  hintText: 'Description (optional)',
                ),
                maxLines: 3,
                minLines: 1,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 20),
              _buildLabel('Color'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppColors.projectColors.map((color) {
                  final isSelected = color.toARGB32() == _selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color.toARGB32()),
                    child: AnimatedContainer(
                      duration: _motion,
                      curve: Curves.easeOutCubic,
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        // Selection ring — the one border that carries meaning.
                        border: isSelected
                            ? Border.all(color: AppColors.textPrimary, width: 2.5)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              _buildLabel('Icon'),
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
                        child: AnimatedContainer(
                          duration: _motion,
                          curve: Curves.easeOutCubic,
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? tint.withValues(alpha: 0.18)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(AppShapes.dockChip),
                            // Selection ring, same as the colour swatches.
                            border: isSelected
                                ? Border.all(color: tint, width: 2)
                                : null,
                          ),
                          child: Icon(
                            e.value,
                            size: 20,
                            color: isSelected ? tint : AppColors.textSecondary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (_isEditing) ...[
                const SizedBox(height: 20),
                RoundedGroup(
                  inset: 0,
                  children: [
                    ListTile(
                      leading: Icon(
                        MdiIcons.trashCanOutline,
                        color: AppColors.error,
                      ),
                      title: Text(
                        'Delete project',
                        style: TextStyle(color: AppColors.error),
                      ),
                      onTap: _confirmDelete,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: Text(_isEditing ? 'Save' : 'Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}
