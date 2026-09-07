import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../shared/widgets/app_field.dart';
import '../../../../shared/widgets/picker_sheet.dart';
import '../../domain/models/note_folder.dart';
import '../../providers/note_folder_provider.dart';

/// Create, rename, recolour or delete a note folder — one sheet for all four,
/// so the drawer needs a single long-press action instead of a menu of menus.
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
  late final TextEditingController _nameController;
  late int _color;

  bool get _isEditing => widget.folder != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.folder?.name ?? '');
    _color = widget.folder?.color ?? NoteFolder.defaultColor;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final notifier = ref.read(noteFolderProvider.notifier);
    if (_isEditing) {
      final updated = widget.folder!.copyWith(name: name, color: _color);
      await notifier.updateFolder(updated);
      if (mounted) Navigator.pop(context, updated);
    } else {
      final created = await notifier.addFolder(name: name, color: _color);
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
    return PickerSheetScaffold(
      title: _isEditing ? 'Edit folder' : 'New folder',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppShapes.listInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppField(
              label: 'Name',
              child: TextField(
                controller: _nameController,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
                decoration: AppField.decoration('Folder name'),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(height: AppShapes.groupGap),
            AppField(
              label: 'Colour',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppColors.projectColors.map((color) {
                  final value = color.toARGB32();
                  final selected = value == _color;
                  return GestureDetector(
                    onTap: () => setState(() => _color = value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: selected
                          // A tick, not a ring: rings are borders, and the
                          // design system has none.
                          ? Icon(
                              MdiIcons.check,
                              size: 18,
                              color: AppColors.background,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: AppShapes.groupGap),
              Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppShapes.groupOuter),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _confirmDelete,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          MdiIcons.trashCanOutline,
                          size: 22,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Delete folder',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
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
    );
  }
}
