import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../shared/widgets/app_field.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/picker_sheet.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/models/note.dart';
import '../../providers/note_folder_provider.dart';
import '../../providers/note_provider.dart';
import '../widgets/note_folder_picker.dart';

/// Full-screen note editor. The note already exists in the provider before this
/// page opens; edits are saved when the page is popped. An untouched, empty
/// note is discarded automatically.
///
/// A note is Markdown. The body has two states — write and read — because
/// editing rendered Markdown in place is a text field with the marks hidden,
/// which is worse at both jobs.
class NoteEditorPage extends ConsumerStatefulWidget {
  final String noteId;

  const NoteEditorPage({super.key, required this.noteId});

  /// Optional card tints — muted so they read on the dark theme.
  static const List<int?> palette = [
    null,
    0xFF4A3B2A, // amber
    0xFF2E4A3B, // green
    0xFF2A3B4A, // blue
    0xFF3B2A4A, // purple
    0xFF4A2A38, // pink
  ];

  @override
  ConsumerState<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends ConsumerState<NoteEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  bool _isPinned = false;
  int? _color;
  String? _folderId;
  bool _deleted = false;
  bool _preview = false;

  Note? get _note {
    final notes = ref.read(noteProvider).notes;
    for (final n in notes) {
      if (n.id == widget.noteId) return n;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final note = _note;
    _titleController = TextEditingController(text: note?.title ?? '');
    _contentController = TextEditingController(text: note?.content ?? '');
    _isPinned = note?.isPinned ?? false;
    _color = note?.color;
    _folderId = note?.folderId;
    // The note opens in the state the settings ask for. A note with nothing
    // in it is the exception: there is nothing to render, so it opens for
    // writing whatever the setting says.
    _preview =
        ref.read(settingsProvider).noteOpenMode == NoteOpenMode.preview &&
        !(note?.isEmpty ?? true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _save() {
    if (_deleted) return;
    final note = _note;
    if (note == null) return;

    final title = _titleController.text;
    final content = _contentController.text;
    final updated = note.copyWith(
      title: title,
      content: content,
      isPinned: _isPinned,
      color: _color,
      clearColor: _color == null,
      folderId: _folderId,
      clearFolder: _folderId == null,
    );

    if (updated.isEmpty) {
      // Nothing worth keeping — drop it silently.
      ref.read(noteProvider.notifier).deleteNote(note.id);
      return;
    }

    final unchanged =
        updated.title == note.title &&
        updated.content == note.content &&
        updated.isPinned == note.isPinned &&
        updated.color == note.color &&
        updated.folderId == note.folderId;
    if (unchanged) return;

    ref.read(noteProvider.notifier).updateNote(updated);
  }

  void _togglePin() => setState(() => _isPinned = !_isPinned);

  Future<void> _moveToFolder() async {
    final choice = await showNoteFolderPicker(
      context,
      ref,
      currentId: _folderId,
    );
    if (choice == null || !mounted) return;
    setState(() => _folderId = choice.folderId);
  }

  Future<void> _pickColor() async {
    final picked = await showAppPicker<int?>(
      context: context,
      builder: (ctx) => PickerSheetScaffold(
        title: 'Note colour',
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppShapes.listInset + 8,
          ),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: NoteEditorPage.palette.map((c) {
              final selected = c == _color;
              final swatch = c != null ? Color(c) : AppColors.surfaceLight;
              return GestureDetector(
                // The sheet carries no "no colour" sentinel: it closes with the
                // value itself, so the caller checks whether it was dismissed.
                onTap: () => Navigator.pop(ctx, c ?? _noColour),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                  ),
                  child: selected
                      ? Icon(
                          MdiIcons.check,
                          size: 20,
                          color: AppColors.textPrimary,
                        )
                      : (c == null
                            ? Icon(
                                MdiIcons.formatColorMarkerCancel,
                                size: 20,
                                color: AppColors.textSecondary,
                              )
                            : null),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );

    if (picked == null || !mounted) return;
    setState(() => _color = picked == _noColour ? null : picked);
  }

  /// Stands in for "no colour" so a dismissed sheet stays distinguishable.
  static const int _noColour = 0;

  Future<void> _confirmDelete() async {
    final ok = await showPickerSheet<bool>(
      context: context,
      title: 'Delete note?',
      footnote: 'This note will be permanently deleted.',
      options: [
        PickerOption(
          value: true,
          label: 'Delete note',
          icon: MdiIcons.trashCanOutline,
          color: AppColors.error,
        ),
        PickerOption(value: false, label: 'Cancel', icon: MdiIcons.close),
      ],
    );
    if (ok == true && mounted) {
      _deleted = true;
      final id = _note?.id;
      if (id != null) ref.read(noteProvider.notifier).deleteNote(id);
      if (mounted) Navigator.pop(context);
    }
  }

  /// Everything that does not fit the header: folder, colour, delete.
  Future<void> _showMore() async {
    final action = await showPickerSheet<String>(
      context: context,
      title: 'Note',
      options: [
        PickerOption(
          value: 'folder',
          label: 'Move to folder…',
          icon: MdiIcons.folderMoveOutline,
        ),
        PickerOption(value: 'colour', label: 'Colour…', icon: MdiIcons.palette),
        PickerOption(
          value: 'delete',
          label: 'Delete note',
          icon: MdiIcons.trashCanOutline,
          color: AppColors.error,
        ),
      ],
    );
    if (action == null || !mounted) return;

    switch (action) {
      case 'folder':
        await _moveToFolder();
      case 'colour':
        await _pickColor();
      case 'delete':
        await _confirmDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _color != null ? Color(_color!) : AppColors.background;
    final folder = ref.watch(noteFolderProvider).byId(_folderId);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) => _save(),
      // The page owns its background so a tinted note keeps its tint; the
      // frame itself is the same header every other page uses.
      child: ColoredBox(
        color: bg,
        child: AppScaffold(
          title: folder?.name ?? 'Note',
          onBack: () => Navigator.pop(context),
          actions: [
            AppHeaderAction(
              icon: _preview ? MdiIcons.pencilOutline : MdiIcons.eyeOutline,
              onPressed: () => setState(() => _preview = !_preview),
              tooltip: _preview ? 'Edit' : 'Preview',
            ),
            AppHeaderAction(
              icon: _isPinned ? MdiIcons.pin : MdiIcons.pinOutline,
              color: _isPinned ? AppColors.primary : null,
              onPressed: _togglePin,
              tooltip: _isPinned ? 'Unpin' : 'Pin',
            ),
            AppHeaderAction(
              icon: MdiIcons.dotsVertical,
              onPressed: _showMore,
              tooltip: 'More',
            ),
          ],
          body: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppShapes.listInset,
              0,
              AppShapes.listInset,
              AppShapes.listInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and body are two filled blocks of one group — no
                // outlines anywhere, same language as the task detail page.
                AppField(
                  isFirst: true,
                  isLast: false,
                  child: TextField(
                    controller: _titleController,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: AppField.decoration(
                      'Title',
                      hintStyle: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppShapes.groupGap),
                Expanded(
                  child: AppField(
                    isFirst: false,
                    isLast: true,
                    child: _preview ? _buildPreview() : _buildEditor(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return TextField(
      controller: _contentController,
      autofocus: (_note?.isEmpty ?? true),
      style: TextStyle(
        fontSize: 16,
        color: AppColors.textPrimary,
        height: 1.45,
      ),
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      decoration: AppField.decoration('Note… (Markdown supported)'),
    );
  }

  Widget _buildPreview() {
    final text = _contentController.text.trim();
    if (text.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          'Nothing to preview',
          style: TextStyle(fontSize: 16, color: AppColors.textTertiary),
        ),
      );
    }

    return SingleChildScrollView(
      child: SizedBox(
        width: double.infinity,
        // Same renderer and metrics as the task description, so a note and a
        // task read identically.
        child: GptMarkdown(
          text,
          style: TextStyle(
            fontSize: 16,
            height: 1.45,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
