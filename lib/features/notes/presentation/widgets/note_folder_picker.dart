import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../shared/widgets/picker_sheet.dart';
import '../../domain/models/note.dart';
import '../../providers/note_folder_provider.dart';
import '../../providers/note_provider.dart';
import 'note_folder_edit_sheet.dart';

/// Result of [showNoteFolderPicker]. A class, not a bare `String?`, because
/// "no folder" and "dismissed" are both null otherwise.
class NoteFolderChoice {
  final String? folderId;

  const NoteFolderChoice(this.folderId);
}

/// Ask which folder something belongs to. Offers "No folder", every folder,
/// and a way out to create one.
Future<NoteFolderChoice?> showNoteFolderPicker(
  BuildContext context,
  WidgetRef ref, {
  String? currentId,
}) async {
  final folders = ref.read(noteFolderProvider).folders;

  // Sentinels, so a dismissed sheet (null) never reads as "No folder".
  const noneValue = '__none__';
  const newFolderValue = '__new__';

  final picked = await showPickerSheet<String>(
    context: context,
    title: 'Move to folder',
    options: [
      PickerOption(
        value: noneValue,
        label: 'No folder',
        icon: MdiIcons.folderRemoveOutline,
        selected: currentId == null,
      ),
      for (final folder in folders)
        PickerOption(
          value: folder.id,
          label: folder.name,
          icon: MdiIcons.folderOutline,
          color: Color(folder.color),
          selected: folder.id == currentId,
        ),
      PickerOption(
        value: newFolderValue,
        label: 'New folder…',
        icon: MdiIcons.folderPlusOutline,
      ),
    ],
  );

  if (picked == null) return null;
  if (picked == noneValue) return const NoteFolderChoice(null);
  if (picked == newFolderValue) {
    if (!context.mounted) return null;
    final created = await NoteFolderEditSheet.show(context);
    return created == null ? null : NoteFolderChoice(created.id);
  }
  return NoteFolderChoice(picked);
}

/// Move [note] to a folder the user picks, and write it straight away.
Future<void> pickNoteFolder(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  final choice = await showNoteFolderPicker(
    context,
    ref,
    currentId: note.folderId,
  );
  if (choice == null) return;
  await ref.read(noteProvider.notifier).moveToFolder(note.id, choice.folderId);
}
