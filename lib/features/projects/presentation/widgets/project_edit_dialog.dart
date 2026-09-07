import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/entity_edit_sheet.dart';
import '../../../../shared/widgets/picker_sheet.dart';
import '../../domain/models/project.dart';
import '../../domain/project_icons.dart';
import '../../providers/project_provider.dart';

/// Create or edit a project.
///
/// It used to be a hand-built form and therefore looked nothing like "New
/// calendar". Now it is the shared [EntityEditSheet] with a project's data:
/// the project palette, the project icon set and a delete row.
class ProjectEditDialog extends ConsumerStatefulWidget {
  final Project? project;

  const ProjectEditDialog({super.key, this.project});

  static Future<Project?> show(BuildContext context, {Project? project}) {
    return showAppPicker<Project?>(
      context: context,
      builder: (_) => ProjectEditDialog(project: project),
    );
  }

  @override
  ConsumerState<ProjectEditDialog> createState() => _ProjectEditDialogState();
}

class _ProjectEditDialogState extends ConsumerState<ProjectEditDialog> {
  late int _color =
      widget.project?.color ?? AppColors.projectColors.first.toARGB32();
  late String _icon = widget.project?.icon ?? kDefaultProjectIcon;

  bool get _isEditing => widget.project != null;

  Future<void> _save(EntityEditValues values) async {
    final description = values.description;

    if (_isEditing) {
      final updated = widget.project!.copyWith(
        name: values.name,
        description: description.isEmpty ? null : description,
        clearDescription: description.isEmpty,
        color: _color,
        icon: _icon,
      );
      await ref.read(projectProvider.notifier).updateProject(updated);
      if (mounted) Navigator.pop(context, updated);
    } else {
      final project = await ref
          .read(projectProvider.notifier)
          .addProject(
            name: values.name,
            description: description.isEmpty ? null : description,
            color: _color,
            icon: _icon,
          );
      if (mounted) Navigator.pop(context, project);
    }
  }

  /// Deleting is a confirmation, so it asks in a sheet like everything else.
  Future<void> _confirmDelete() async {
    final confirmed = await showPickerSheet<bool>(
      context: context,
      title: 'Delete project?',
      footnote:
          'The project "${widget.project!.name}" will be deleted. '
          'Tasks stay in the inbox.',
      options: [
        PickerOption(
          value: true,
          label: 'Delete project',
          icon: MdiIcons.trashCanOutline,
          color: AppColors.error,
        ),
        PickerOption(value: false, label: 'Cancel', icon: MdiIcons.close),
      ],
    );

    if (confirmed != true || !mounted) return;
    ref.read(projectProvider.notifier).deleteProject(widget.project!.id);
    if (mounted) Navigator.pop(context, null);
  }

  @override
  Widget build(BuildContext context) {
    return EntityEditSheet(
      title: _isEditing ? 'Edit project' : 'New project',
      nameHint: 'Project name',
      initialName: widget.project?.name ?? '',
      secondLabel: 'Description',
      secondHint: 'Optional',
      initialSecond: widget.project?.description ?? '',
      colors: AppColors.projectColors,
      selectedColor: _color,
      onColorChanged: (value) => setState(() => _color = value),
      icons: kProjectIcons,
      selectedIcon: _icon,
      onIconChanged: (key) => setState(() => _icon = key),
      deleteLabel: _isEditing ? 'Delete project' : null,
      onDelete: _isEditing ? _confirmDelete : null,
      saveLabel: _isEditing ? 'Save' : 'Create',
      onSave: _save,
    );
  }
}
