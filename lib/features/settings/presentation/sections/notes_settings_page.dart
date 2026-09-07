import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../shared/widgets/picker_sheet.dart';
import '../../../../shared/widgets/rounded_group.dart';
import '../../../notes/providers/note_folder_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/settings_tiles.dart';

/// How the notes section opens: its order, its shape and what a tap does.
class NotesSettingsPage extends ConsumerWidget {
  const NotesSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return SettingsSubPage(
      title: 'Notes',
      children: [
        const SettingsSectionHeader('List'),
        RoundedGroup(
          children: [
            SettingsNavTile(
              icon: MdiIcons.sortVariant,
              title: 'Sort by',
              value: settings.noteSort.label,
              onTap: () async {
                final picked = await showPickerSheet<NoteSort>(
                  context: context,
                  title: 'Sort notes by',
                  options: [
                    for (final sort in NoteSort.values)
                      PickerOption(
                        value: sort,
                        label: sort.label,
                        icon: _sortIcon(sort),
                        selected: sort == settings.noteSort,
                      ),
                  ],
                  footnote: 'Pinned notes always stay on top.',
                );
                if (picked != null) notifier.setNoteSort(picked);
              },
            ),
            SettingsNavTile(
              icon: MdiIcons.folderOutline,
              title: 'Opens with',
              value: _folderName(ref, settings.noteDefaultFolderId),
              onTap: () =>
                  _pickFolder(context, ref, settings.noteDefaultFolderId),
            ),
            SettingsNavTile(
              icon: MdiIcons.viewGridOutline,
              title: 'Default view',
              value: settings.noteLayout.label,
              onTap: () async {
                final picked = await showPickerSheet<NoteLayout>(
                  context: context,
                  title: 'Default view',
                  options: [
                    for (final layout in NoteLayout.values)
                      PickerOption(
                        value: layout,
                        label: layout.label,
                        icon: layout == NoteLayout.grid
                            ? MdiIcons.viewGridOutline
                            : MdiIcons.viewSequentialOutline,
                        selected: layout == settings.noteLayout,
                      ),
                  ],
                );
                if (picked != null) notifier.setNoteLayout(picked);
              },
            ),
          ],
        ),

        const SettingsSectionHeader('Editor'),
        RoundedGroup(
          children: [
            SettingsNavTile(
              icon: MdiIcons.textBoxOutline,
              title: 'Open notes in',
              value: settings.noteOpenMode.label,
              onTap: () async {
                final picked = await showPickerSheet<NoteOpenMode>(
                  context: context,
                  title: 'Open notes in',
                  options: [
                    for (final mode in NoteOpenMode.values)
                      PickerOption(
                        value: mode,
                        label: mode.label,
                        icon: mode == NoteOpenMode.preview
                            ? MdiIcons.eyeOutline
                            : MdiIcons.pencilOutline,
                        selected: mode == settings.noteOpenMode,
                      ),
                  ],
                  footnote:
                      'Preview renders Markdown; edit puts the cursor in the '
                      'text right away.',
                );
                if (picked != null) notifier.setNoteOpenMode(picked);
              },
            ),
          ],
        ),
      ],
    );
  }

  /// Name of the stored folder, or "All notes" when none is set. A folder
  /// that was deleted meanwhile also reads as "All notes".
  static String _folderName(WidgetRef ref, String? folderId) {
    if (folderId == null) return 'All notes';
    final folder = ref.watch(noteFolderProvider).byId(folderId);
    return folder?.name.isNotEmpty == true ? folder!.name : 'All notes';
  }

  Future<void> _pickFolder(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    // A sentinel instead of null, so a dismissed sheet stays different from
    // picking "All notes".
    const allNotes = '';
    final folders = ref.read(noteFolderProvider).folders;

    final picked = await showPickerSheet<String>(
      context: context,
      title: 'Notes open with',
      options: [
        PickerOption(
          value: allNotes,
          label: 'All notes',
          icon: MdiIcons.noteMultipleOutline,
          selected: current == null,
        ),
        for (final folder in folders)
          PickerOption(
            value: folder.id,
            label: folder.name.isEmpty ? 'Unnamed folder' : folder.name,
            icon: MdiIcons.folderOutline,
            color: Color(folder.color),
            selected: folder.id == current,
          ),
      ],
    );
    if (picked == null) return;

    await ref
        .read(settingsProvider.notifier)
        .setNoteDefaultFolderId(picked == allNotes ? null : picked);
  }

  static IconData _sortIcon(NoteSort sort) => switch (sort) {
    NoteSort.updated => MdiIcons.clockEditOutline,
    NoteSort.created => MdiIcons.calendarPlus,
    NoteSort.title => MdiIcons.sortAlphabeticalAscending,
  };
}
