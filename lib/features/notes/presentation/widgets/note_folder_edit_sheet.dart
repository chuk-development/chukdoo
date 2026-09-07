import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/entity_edit_sheet.dart';
import '../../../../shared/widgets/picker_sheet.dart';
import '../../domain/models/note_folder.dart';
import '../../providers/note_folder_provider.dart';

/// Create, rename, recolour or delete a note folder — one sheet for all four,
/// so the drawer needs a single long-press action instead of a menu of menus.
///
/// The form is the shared [EntityEditSheet]; a folder simply has no icon set
/// and no second field, so those blocks are left out.
class NoteFolderEditSheet extends ConsumerStatefulWidget {
  final NoteFolder? folder;

  const NoteFolderEditSheet({super.key, this.folder});

  /// Returns the saved folder, or null when the sheet was dismissed or the
  /// folder was deleted.
  static Future<NoteFolder?> show(BuildContext context, {NoteFolder? folder}) {
    return showAppPicker<NoteFolder>(
      context: context,
      builder: (_) => NoteFolderEditSheet(folder: folder),
    );
  }

  @override
  ConsumerState<NoteFolderEditSheet> createState() =>
      _NoteFolderEditSheetState();
}

class _NoteFolderEditSheetState extends ConsumerState<NoteFolderEditSheet> {
  late int _color = widget.folder?.color ?? NoteFolder.defaultColor;

  bool get _isEditing => widget.folder != null;

  Future<void> _save(EntityEditValues values) async {
    final notifier = ref.read(noteFolderProvider.notifier);
    if (_isEditing) {
      final updated = widget.folder!.copyWith(name: values.name, color: _color);
      await notifier.updateFolder(updated);
      if (mounted) Navigator.pop(context, updated);
    } else {
      final created = await notifier.addFolder(name: values.name, color: _color);
      if (mounted) Navigator.pop(context, created);
    }
  }

  Future<void> _confirmDelete() async {
    final folder = widget.folder!;
    final confirmed = await showPickerSheet<bool>(
      context: context,
      title: 'Delete folder?',
      footnote:
          'The folder "${folder.name}" goes away. Its notes stay and move '
          'back to "All notes".',
      options: [
        PickerOption(
          value: true,
          label: 'Delete folder',
          icon: MdiIcons.trashCanOutline,
          color: AppColors.error,
        ),
        PickerOption(value: false, label: 'Cancel', icon: MdiIcons.close),
      ],
    );
    if (confirmed != true || !mounted) return;

    // Clear the filter first: staying on a folder that no longer exists would
    // show an empty grid with a dead title.
    if (ref.read(selectedNoteFolderProvider) == folder.id) {
      ref.read(selectedNoteFolderProvider.notifier).state = null;
    }
    await ref.read(noteFolderProvider.notifier).deleteFolder(folder.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return EntityEditSheet(
      title: _isEditing ? 'Edit folder' : 'New folder',
      nameHint: 'Folder name',
      initialName: widget.folder?.name ?? '',
      colors: AppColors.projectColors,
      selectedColor: _color,
      onColorChanged: (value) => setState(() => _color = value),
      deleteLabel: _isEditing ? 'Delete folder' : null,
      onDelete: _isEditing ? _confirmDelete : null,
      saveLabel: _isEditing ? 'Save' : 'Create',
      onSave: _save,
    );
  }
}
