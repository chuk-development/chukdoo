import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../shared/widgets/app_field.dart';
import '../../domain/models/note.dart';
import '../../providers/note_provider.dart';

/// Full-screen note editor. The note already exists in the provider before this
/// page opens; edits are saved when the page is popped. An untouched, empty
/// note is discarded automatically.
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
  bool _deleted = false;

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
    );

    if (updated.isEmpty) {
      // Nothing worth keeping — drop it silently.
      ref.read(noteProvider.notifier).deleteNote(note.id);
      return;
    }

    final unchanged = updated.title == note.title &&
        updated.content == note.content &&
        updated.isPinned == note.isPinned &&
        updated.color == note.color;
    if (unchanged) return;

    ref.read(noteProvider.notifier).updateNote(updated);
  }

  void _togglePin() => setState(() => _isPinned = !_isPinned);

  void _pickColor() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppShapes.sheetTop)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: NoteEditorPage.palette.map((c) {
              final selected = c == _color;
              final swatch = c != null ? Color(c) : AppColors.background;
              return GestureDetector(
                onTap: () {
                  setState(() => _color = c);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.divider,
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                  child: c == null
                      ? Icon(MdiIcons.formatColorMarkerCancel,
                          size: 20, color: AppColors.textSecondary)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete note?'),
        content: const Text('This note will be permanently deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      _deleted = true;
      final id = _note?.id;
      if (id != null) ref.read(noteProvider.notifier).deleteNote(id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _color != null ? Color(_color!) : AppColors.background;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) => _save(),
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(MdiIcons.chevronLeft),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
          actions: [
            IconButton(
              icon: Icon(_isPinned ? MdiIcons.pin : MdiIcons.pinOutline),
              color: _isPinned ? AppColors.primary : null,
              onPressed: _togglePin,
              tooltip: _isPinned ? 'Unpin' : 'Pin',
            ),
            IconButton(
              icon: Icon(MdiIcons.palette),
              onPressed: _pickColor,
              tooltip: 'Color',
            ),
            IconButton(
              icon: Icon(MdiIcons.trashCanOutline),
              onPressed: _confirmDelete,
              tooltip: 'Delete',
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
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
                    child: TextField(
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
                      decoration: AppField.decoration('Note…'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
