import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shapes.dart';
import '../../../../shared/widgets/picker_sheet.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../domain/markdown_preview.dart';
import '../../domain/models/note.dart';
import '../../domain/models/note_folder.dart';
import '../../providers/note_folder_provider.dart';
import '../../providers/note_provider.dart';
import '../widgets/note_card.dart';
import '../widgets/note_folder_picker.dart';
import 'note_editor_page.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../todos/presentation/widgets/quick_add_fab.dart';

/// The Notes overview — a masonry of note cards with long-press drag
/// reordering. Cards keep their intrinsic height, so the columns stagger. How
/// many columns there are, and in which order the cards come, is up to the
/// notes settings.
class NotesPage extends ConsumerStatefulWidget {
  /// True when rendered inside the home shell (bottom nav / drawer present).
  final bool embedded;

  /// Opens the app drawer (mobile hamburger). Null on desktop.
  final VoidCallback? onMenu;

  const NotesPage({super.key, this.embedded = false, this.onMenu});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  bool _searching = false;
  String _query = '';
  final _searchController = TextEditingController();
  String? _draggingId;

  /// Where each card sat when its drag began — a long press that ends without
  /// movement is a menu, one that moves is a reorder. Both gestures start the
  /// same way, so the distance travelled is what tells them apart.
  final Map<String, GlobalKey> _cardKeys = {};
  Offset? _dragOrigin;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _stopSearch() => setState(() {
    _searching = false;
    _query = '';
    _searchController.clear();
  });

  Future<void> _createNote() async {
    // A note made inside a folder belongs to it.
    final note = await ref
        .read(noteProvider.notifier)
        .addNote(folderId: ref.read(selectedNoteFolderProvider));
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => NoteEditorPage(noteId: note.id)));
  }

  void _openNote(Note note) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => NoteEditorPage(noteId: note.id)));
  }

  List<Note> _filtered(List<Note> notes, String? folderId) {
    var list = notes;
    if (folderId != null) {
      list = list.where((n) => n.folderId == folderId).toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where(
          (n) =>
              n.title.toLowerCase().contains(q) ||
              n.content.toLowerCase().contains(q),
        )
        .toList();
  }

  /// Order of the grid: pinned notes stay on top, then the order the user
  /// chose in the settings, and the manual drag order breaks the ties.
  List<Note> _sorted(List<Note> notes, NoteSort sort) {
    final list = [...notes];
    list.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final byChoice = switch (sort) {
        NoteSort.updated => b.updatedAt.compareTo(a.updatedAt),
        NoteSort.created => b.createdAt.compareTo(a.createdAt),
        NoteSort.title => _titleKey(a).compareTo(_titleKey(b)),
      };
      return byChoice != 0 ? byChoice : a.sortOrder.compareTo(b.sortOrder);
    });
    return list;
  }

  /// Sort key of a title. A note without one goes last instead of clumping at
  /// the top, where an alphabetical list would look broken.
  String _titleKey(Note note) {
    final title = note.title.trim().toLowerCase();
    return title.isEmpty ? '\uffff' : title;
  }

  /// Opens the notes tab on the folder from the settings.
  ///
  /// Runs once, and only after the folders are loaded — a folder id can only
  /// be checked against a list that exists. A folder that was deleted (or has
  /// not reached this device) falls back to "all notes" instead of filtering
  /// every note away.
  void _seedDefaultFolder(NoteFolderState folderState) {
    if (folderState.isLoading || ref.read(noteFolderSeededProvider)) return;
    ref.read(noteFolderSeededProvider.notifier).state = true;

    final wanted = ref.read(settingsProvider).noteDefaultFolderId;
    if (wanted == null || folderState.byId(wanted) == null) return;
    ref.read(selectedNoteFolderProvider.notifier).state = wanted;
  }

  /// Long-press menu of a card: everything that acts on one note without
  /// opening it.
  Future<void> _showNoteMenu(Note note) async {
    final action = await showPickerSheet<String>(
      context: context,
      title: note.title.trim().isEmpty ? 'Note' : note.title.trim(),
      options: [
        PickerOption(
          value: 'folder',
          label: 'Move to folder…',
          icon: MdiIcons.folderMoveOutline,
        ),
        PickerOption(
          value: 'pin',
          label: note.isPinned ? 'Unpin' : 'Pin',
          icon: note.isPinned ? MdiIcons.pinOffOutline : MdiIcons.pinOutline,
        ),
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
        await pickNoteFolder(context, ref, note);
      case 'pin':
        await ref.read(noteProvider.notifier).togglePin(note.id);
      case 'delete':
        await ref.read(noteProvider.notifier).deleteNote(note.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(noteProvider);
    final folderState = ref.watch(noteFolderProvider);
    final settings = ref.watch(settingsProvider);
    final selectedFolderId = ref.watch(selectedNoteFolderProvider);
    final selectedFolder = folderState.byId(selectedFolderId);
    final notes = _sorted(
      _filtered(state.notes, selectedFolderId),
      settings.noteSort,
    );

    // A provider cannot be written while the tree builds, so the seed runs
    // right after this frame.
    if (!folderState.isLoading && !ref.read(noteFolderSeededProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _seedDefaultFolder(ref.read(noteFolderProvider));
      });
    }

    return AppScaffold(
      onMenu: _searching ? null : widget.onMenu,
      onBack: _searching ? _stopSearch : null,
      title: selectedFolder?.name ?? 'Notes',
      titleWidget: _searching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Search notes…',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 18,
                ),
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _query = v),
            )
          : null,
      actions: _searching
          ? [
              if (_query.isNotEmpty)
                AppHeaderAction(
                  icon: MdiIcons.closeCircle,
                  onPressed: () => setState(() {
                    _query = '';
                    _searchController.clear();
                  }),
                  tooltip: 'Clear',
                ),
            ]
          : [
              AppHeaderAction(
                icon: MdiIcons.magnify,
                onPressed: () => setState(() => _searching = true),
                tooltip: 'Search',
              ),
            ],
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : notes.isEmpty
          ? _buildEmpty(selectedFolder?.name)
          : _buildGrid(
              notes,
              folderState,
              showFolder: selectedFolderId == null,
              layout: settings.noteLayout,
            ),
      floatingActionButton: _searching
          ? null
          : QuickAddFab(onPressed: _createNote),
    );
  }

  Widget _buildGrid(
    List<Note> notes,
    NoteFolderState folderState, {
    required bool showFolder,
    required NoteLayout layout,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        const outer = 12.0;
        // The list layout is the same masonry with one column: a card keeps
        // its height, so a single column is exactly a list.
        final columns = layout == NoteLayout.list
            ? 1
            : (constraints.maxWidth / 260).floor().clamp(2, 4);
        final colWidth =
            (constraints.maxWidth - outer * 2 - gap * (columns - 1)) / columns;

        // Masonry fill: place each note into the currently shortest column.
        final colHeights = List<double>.filled(columns, 0);
        final colChildren = List.generate(columns, (_) => <Widget>[]);

        for (var i = 0; i < notes.length; i++) {
          final note = notes[i];
          var target = 0;
          for (var c = 1; c < columns; c++) {
            if (colHeights[c] < colHeights[target]) target = c;
          }
          colHeights[target] += _estimateHeight(note);
          colChildren[target].add(
            Padding(
              padding: const EdgeInsets.only(bottom: gap),
              child: _reorderableCard(
                note,
                colWidth,
                showFolder ? folderState.byId(note.folderId) : null,
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            outer,
            outer,
            outer,
            AppShapes.contentBottom(context),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) const SizedBox(width: gap),
                SizedBox(
                  width: colWidth,
                  child: Column(children: colChildren[c]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Wrap a card as both a drag source (long press) and a drop target so
  /// notes can be reordered by dragging one onto another. A long press that
  /// ends where it started opens the note menu instead.
  Widget _reorderableCard(Note note, double width, NoteFolder? folder) {
    final key = _cardKeys.putIfAbsent(note.id, GlobalKey.new);
    final card = NoteCard(
      key: key,
      note: note,
      folder: folder,
      isDragging: _draggingId == note.id,
      onTap: () => _openNote(note),
    );

    // Search rebuilds the grid on every keystroke, which fights a drag.
    // The menu stays reachable.
    if (_query.trim().isNotEmpty) {
      return GestureDetector(
        onLongPress: () => _showNoteMenu(note),
        child: card,
      );
    }

    return DragTarget<Note>(
      onWillAcceptWithDetails: (d) => d.data.id != note.id,
      onAcceptWithDetails: (d) {
        // Drop position is expressed as "sit where this card sits", looked up
        // in the provider's own order — the grid may show a folder subset, so
        // its visual index means nothing to the provider.
        final target = ref
            .read(noteProvider)
            .notes
            .indexWhere((n) => n.id == note.id);
        if (target == -1) return;
        ref.read(noteProvider.notifier).reorder(d.data.id, target);
      },
      builder: (context, candidate, rejected) {
        final highlighted = candidate.isNotEmpty;
        return AnimatedScale(
          duration: const Duration(milliseconds: 120),
          // A drop target grows a little instead of drawing a ring — the
          // design system has no borders.
          scale: highlighted ? 1.04 : 1,
          child: LongPressDraggable<Note>(
            data: note,
            onDragStarted: () {
              _dragOrigin = _cardOrigin(key);
              setState(() => _draggingId = note.id);
            },
            onDragEnd: (details) {
              setState(() => _draggingId = null);
              final origin = _dragOrigin;
              _dragOrigin = null;
              if (details.wasAccepted || origin == null) return;
              // Pressed and let go without moving: that is a menu, not a
              // failed reorder.
              if ((details.offset - origin).distance < 12) _showNoteMenu(note);
            },
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: width,
                child: Opacity(
                  opacity: 0.95,
                  child: NoteCard(note: note, folder: folder, onTap: () {}),
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: card),
            child: card,
          ),
        );
      },
    );
  }

  /// Global position of a card, taken when its drag begins.
  Offset? _cardOrigin(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    return box?.localToGlobal(Offset.zero);
  }

  /// Rough card-height estimate to balance the masonry columns. Exact layout
  /// height isn't known ahead of paint, so approximate from text length.
  double _estimateHeight(Note note) {
    var h = 70.0; // padding + date row
    if (note.title.trim().isNotEmpty) {
      h += 24 * ((note.title.trim().length / 22).ceil().clamp(1, 3));
    }
    // The card shows the stripped text, so estimate from that.
    final content = markdownToPlainText(note.content);
    final contentLen = content.isEmpty ? 6 : content.length;
    h += 20 * ((contentLen / 26).ceil().clamp(1, 9));
    if (note.isPinned) h += 20;
    return h;
  }

  Widget _buildEmpty(String? folderName) {
    final searching = _query.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              searching ? MdiIcons.magnify : MdiIcons.noteTextOutline,
              size: 80,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              searching
                  ? 'No matching notes'
                  : folderName == null
                  ? 'No notes yet'
                  : 'Nothing in $folderName',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              searching ? 'Try a different search' : 'Tap + to write one',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
