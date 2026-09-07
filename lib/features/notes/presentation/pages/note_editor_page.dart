import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../widgets/note_format_bar.dart';
import '../widgets/note_markdown_view.dart';

/// Full-screen note editor: one writing surface, no save button.
///
/// Two things it must never do, because both were reported as broken:
///
/// * **Type into nothing.** The body used to be only as tall as its text, so a
///   tap under the last line hit no field at all and the keyboard stayed shut
///   until the title was tapped. The whole surface below the title is now one
///   tap target that drops the caret at the end of the text.
/// * **Lose writing.** There is no save button; the note is written 600 ms
///   after the last keystroke, when the page is left, when the app goes to the
///   background and when the preview is toggled. The header says which of the
///   two states it is in.
///
/// A note is Markdown. The body has two states — write and read — because
/// editing rendered Markdown in place is a text field with the marks hidden,
/// which is worse at both jobs.
class NoteEditorPage extends ConsumerStatefulWidget {
  final String noteId;

  const NoteEditorPage({super.key, required this.noteId});

  /// Optional note tints — muted so they read on the dark theme.
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

/// What the header says about the note's state.
enum _SaveStatus { untouched, saving, saved }

class _NoteEditorPageState extends ConsumerState<NoteEditorPage>
    with WidgetsBindingObserver {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  final _bodyFocus = FocusNode();
  final _titleFocus = FocusNode();

  Timer? _debounce;
  _SaveStatus _status = _SaveStatus.untouched;

  bool _isPinned = false;
  int? _color;
  String? _folderId;
  bool _deleted = false;
  bool _preview = false;

  /// Time the editor waits after the last keystroke before it writes. Long
  /// enough that a sentence is one save, short enough to survive a swipe out
  /// of the app.
  static const _saveDelay = Duration(milliseconds: 600);

  Note? get _note {
    for (final n in ref.read(noteProvider).notes) {
      if (n.id == widget.noteId) return n;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final note = _note;
    _titleController = TextEditingController(text: note?.title ?? '');
    _contentController = TextEditingController(text: note?.content ?? '');
    _isPinned = note?.isPinned ?? false;
    _color = note?.color;
    _folderId = note?.folderId;
    // The note opens in the state the settings ask for. A note with nothing in
    // it is the exception: there is nothing to render, so it opens for writing
    // whatever the setting says.
    _preview =
        ref.read(settingsProvider).noteOpenMode == NoteOpenMode.preview &&
        !(note?.isEmpty ?? true);

    // The formatting bar belongs to the body, so it appears and goes with it.
    _bodyFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _bodyFocus.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app is the one exit the page never sees as a pop.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _save();
    }
  }

  // ── Saving ────────────────────────────────────────────────────────────────

  /// A keystroke: show "Saving…" and restart the timer.
  void _onEdited() {
    _debounce?.cancel();
    if (_status != _SaveStatus.saving) {
      setState(() => _status = _SaveStatus.saving);
    }
    _debounce = Timer(_saveDelay, _save);
  }

  /// Write the note. [exiting] allows the one destructive case: a note that
  /// never got a title or a body is dropped instead of kept as an empty ghost.
  void _save({bool exiting = false}) {
    _debounce?.cancel();
    if (_deleted) return;

    final note = _note;
    if (note == null) return;

    final updated = note.copyWith(
      title: _titleController.text,
      content: _contentController.text,
      isPinned: _isPinned,
      color: _color,
      clearColor: _color == null,
      folderId: _folderId,
      clearFolder: _folderId == null,
    );

    if (updated.isEmpty) {
      // Mid-edit an empty note is simply not written: deleting it here would
      // pull the record out from under the editor while the user is still in
      // it, and every later save would then have nothing to write to.
      if (exiting) {
        _deleted = true;
        ref.read(noteProvider.notifier).deleteNote(note.id);
      }
      return;
    }

    final unchanged =
        updated.title == note.title &&
        updated.content == note.content &&
        updated.isPinned == note.isPinned &&
        updated.color == note.color &&
        updated.folderId == note.folderId;

    if (!unchanged) ref.read(noteProvider.notifier).updateNote(updated);
    if (mounted && _status != _SaveStatus.untouched) {
      setState(() => _status = _SaveStatus.saved);
    }
  }

  String? get _statusLabel => switch (_status) {
    _SaveStatus.untouched => null,
    _SaveStatus.saving => 'Saving…',
    _SaveStatus.saved => 'Saved',
  };

  // ── Body focus ────────────────────────────────────────────────────────────

  /// Put the caret at the end of the body and open the keyboard.
  ///
  /// This is what the empty space under the text does. From the preview it
  /// also switches back to writing — a tap on the page is the gesture people
  /// try first, and refusing it is what "typing into nothing" felt like.
  void _writeAtEnd() {
    void caretToEnd() {
      _contentController.selection = TextSelection.collapsed(
        offset: _contentController.text.length,
      );
      _bodyFocus.requestFocus();
    }

    if (_preview) {
      _save();
      setState(() => _preview = false);
      // The body field does not exist yet in this frame — a focus request on
      // an unmounted node is dropped, so wait for the rebuild.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) caretToEnd();
      });
      return;
    }
    caretToEnd();
  }

  void _togglePreview() {
    _save();
    setState(() => _preview = !_preview);
    if (_preview) FocusScope.of(context).unfocus();
  }

  /// A checkbox was ticked in the preview: the rewritten source goes straight
  /// back into the field, so read and write mode never disagree.
  void _onPreviewSourceChanged(String source) {
    // The preview reads the controller, so the rebuild is what redraws the
    // ticked box — the debounce alone would not repaint it.
    setState(() {
      _contentController.text = source;
    });
    _onEdited();
  }

  // ── Note properties ───────────────────────────────────────────────────────

  void _togglePin() {
    setState(() => _isPinned = !_isPinned);
    _save();
  }

  Future<void> _moveToFolder() async {
    final choice = await showNoteFolderPicker(
      context,
      ref,
      currentId: _folderId,
    );
    if (choice == null || !mounted) return;
    setState(() => _folderId = choice.folderId);
    _save();
  }

  /// Stands in for "no colour" so a dismissed sheet stays distinguishable.
  static const int _noColour = 0;

  Future<void> _pickColor() async {
    final picked = await showAppPicker<int?>(
      context: context,
      builder: (ctx) => PickerSheetScaffold(
        title: 'Note colour',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppShapes.listInset + 8,
            0,
            AppShapes.listInset + 8,
            8,
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
    _save();
  }

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
    if (ok != true || !mounted) return;

    _debounce?.cancel();
    _deleted = true;
    final id = _note?.id;
    if (id != null) ref.read(noteProvider.notifier).deleteNote(id);
    if (mounted) Navigator.pop(context);
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final folder = ref.watch(noteFolderProvider).byId(_folderId);
    final showFormatBar = !_preview && _bodyFocus.hasFocus;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) => _save(exiting: true),
      // A pushed route paints no shell behind it, so the page carries the
      // app background itself. The note's own tint stays on the writing
      // surface, not on the whole screen — the header must not change colour.
      child: ColoredBox(
        color: AppColors.background,
        child: AppScaffold(
          onBack: () => Navigator.pop(context),
          titleWidget: _buildStatus(folder?.name, folder?.color),
          actions: [
            AppHeaderAction(
              icon: _preview ? MdiIcons.pencilOutline : MdiIcons.eyeOutline,
              onPressed: _togglePreview,
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
          body: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppShapes.listInset,
                  ),
                  child: _buildSurface(),
                ),
              ),
              if (showFormatBar)
                NoteFormatBar(
                  controller: _contentController,
                  focusNode: _bodyFocus,
                )
              else
                SizedBox(
                  height:
                      AppShapes.dockMargin +
                      MediaQuery.viewPaddingOf(context).bottom,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Folder and save state, in the title slot: the only thing the header says
  /// about the note besides its three buttons.
  Widget _buildStatus(String? folderName, int? folderColor) {
    final label = _statusLabel;
    // Before the first keystroke a note outside every folder has nothing to
    // report; the header would otherwise be a row of buttons around a hole.
    if (folderName == null && label == null) {
      return Text(
        'Note',
        style: TextStyle(fontSize: 15, color: AppColors.textTertiary),
      );
    }

    return Row(
      children: [
        if (folderName != null && folderColor != null) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Color(folderColor),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              folderName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: 8),
            Text('·', style: TextStyle(color: AppColors.textTertiary)),
          ],
        ],
        if (label != null) ...[
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ],
      ],
    );
  }

  /// The writing surface: one filled block that runs to the bottom of the
  /// page, with the title on top and the body under it.
  Widget _buildSurface() {
    final surfaceColor = _color != null ? Color(_color!) : AppColors.surface;

    return Material(
      color: surfaceColor,
      // One block, so the radii are the outer ones of a group.
      borderRadius: AppShapes.row(isFirst: true, isLast: true),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const padding = EdgeInsets.fromLTRB(18, 16, 18, 24);
          return GestureDetector(
            // Every point of the surface that no field claims writes at the
            // end of the note. This is the fix for "typing into nothing".
            behavior: HitTestBehavior.opaque,
            onTap: _writeAtEnd,
            child: SingleChildScrollView(
              padding: padding,
              child: ConstrainedBox(
                // Fill the surface even when the note is two words long, so
                // the empty area belongs to the tap target above.
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - padding.vertical).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitleField(),
                    const SizedBox(height: 10),
                    _preview ? _buildPreview() : _buildBodyField(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      focusNode: _titleFocus,
      style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: AppColors.textPrimary,
      ),
      minLines: 1,
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => _writeAtEnd(),
      onChanged: (_) => _onEdited(),
      decoration: AppField.decoration(
        'Title',
        hintStyle: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _buildBodyField() {
    return TextField(
      controller: _contentController,
      focusNode: _bodyFocus,
      // A new note opens ready to be written in; an existing one waits for a
      // tap, so reading it does not throw the keyboard up.
      autofocus: _note?.isEmpty ?? true,
      style: TextStyle(fontSize: 16, color: AppColors.textPrimary, height: 1.5),
      // The field grows with its text and the surface around it scrolls —
      // a field that scrolls inside a scroll view fights every drag.
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (_) => _onEdited(),
      decoration: AppField.decoration('Start writing… Markdown works'),
    );
  }

  Widget _buildPreview() {
    final text = _contentController.text.trim();
    if (text.isEmpty) {
      return Text(
        'Nothing to preview yet',
        style: TextStyle(fontSize: 16, color: AppColors.textTertiary),
      );
    }

    return NoteMarkdownView(
      source: _contentController.text,
      onSourceChanged: _onPreviewSourceChanged,
      style: TextStyle(fontSize: 16, height: 1.5, color: AppColors.textPrimary),
    );
  }
}
