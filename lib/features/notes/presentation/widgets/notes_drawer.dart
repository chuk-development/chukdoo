import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../shared/widgets/app_drawer_panel.dart';
import '../../providers/note_folder_provider.dart';
import '../../providers/note_provider.dart';
import 'note_folder_edit_sheet.dart';

/// Side panel of the notes section: "All notes" on top, the folders under it,
/// and the way to make a new one at the bottom — the same shape the to-do and
/// calendar panels have.
class NotesDrawer extends ConsumerWidget {
  const NotesDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(noteFolderProvider).folders;
    final notes = ref.watch(noteProvider).notes;
    final selected = ref.watch(selectedNoteFolderProvider);

    void select(String? folderId) {
      ref.read(selectedNoteFolderProvider.notifier).state = folderId;
      Navigator.pop(context);
    }

    return AppDrawerPanel(
      title: 'Notes',
      header: [
        AppDrawerTile(
          icon: MdiIcons.noteMultipleOutline,
          label: 'All notes',
          count: notes.length,
          isSelected: selected == null,
          onTap: () => select(null),
        ),
        if (folders.isNotEmpty) const AppDrawerSection(label: 'Folders'),
      ],
      footer: AppDrawerActionTile(
        icon: MdiIcons.folderPlusOutline,
        label: 'New folder',
        onTap: () => NoteFolderEditSheet.show(context),
      ),
      children: [
        for (var i = 0; i < folders.length; i++)
          AppDrawerTile(
            icon: selected == folders[i].id
                ? MdiIcons.folderOpen
                : MdiIcons.folderOutline,
            iconColor: Color(folders[i].color),
            label: folders[i].name,
            count: notes.where((n) => n.folderId == folders[i].id).length,
            isSelected: selected == folders[i].id,
            isFirst: i == 0,
            isLast: i == folders.length - 1,
            onTap: () => select(folders[i].id),
            // Long-press edits the folder — no edit icon cluttering the row,
            // exactly like the to-do panel renames its main list.
            onLongPress: () =>
                NoteFolderEditSheet.show(context, folder: folders[i]),
          ),
      ],
    );
  }
}
