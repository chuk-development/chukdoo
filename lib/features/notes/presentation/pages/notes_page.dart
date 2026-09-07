import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/note.dart';
import '../../providers/note_provider.dart';
import '../widgets/note_card.dart';
import 'note_editor_page.dart';

/// The Notes grid — a 2-column masonry of note cards with long-press drag
/// reordering. Cards keep their intrinsic height, so the two columns stagger.
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
    final note = await ref.read(noteProvider.notifier).addNote();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NoteEditorPage(noteId: note.id)),
    );
  }

  void _openNote(Note note) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NoteEditorPage(noteId: note.id)),
    );
  }

  List<Note> _filtered(List<Note> notes) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return notes;
    return notes
        .where((n) =>
            n.title.toLowerCase().contains(q) ||
            n.content.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(noteProvider);
    final notes = _filtered(state.notes);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : notes.isEmpty
              ? _buildEmpty()
              : _buildGrid(notes),
      floatingActionButton: _searching
          ? null
          : FloatingActionButton(
              onPressed: _createNote,
              backgroundColor: AppColors.primary,
              elevation: 3,
              shape: const CircleBorder(),
              child: Icon(Icons.add, color: AppColors.onPrimary, size: 30),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: _searching
          ? IconButton(
              icon: Icon(MdiIcons.chevronLeft),
              onPressed: _stopSearch,
              tooltip: 'Back',
            )
          : (widget.onMenu != null
              ? IconButton(
                  icon: Icon(MdiIcons.menu),
                  onPressed: widget.onMenu,
                  tooltip: 'Menu',
                )
              : null),
      titleSpacing: _searching ? 0 : null,
      title: _searching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Search notes…',
                hintStyle:
                    TextStyle(color: AppColors.textSecondary, fontSize: 18),
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _query = v),
            )
          : const Text('Notes'),
      actions: _searching
          ? [
              if (_query.isNotEmpty)
                IconButton(
                  icon: Icon(MdiIcons.closeCircle),
                  onPressed: () => setState(() {
                    _query = '';
                    _searchController.clear();
                  }),
                  tooltip: 'Clear',
                ),
            ]
          : [
              IconButton(
                icon: Icon(MdiIcons.magnify),
                onPressed: () => setState(() => _searching = true),
                tooltip: 'Search',
              ),
            ],
    );
  }

  Widget _buildGrid(List<Note> notes) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        const outer = 12.0;
        // Wider screens get more columns; phones get 2 (matching the mock).
        final columns = (constraints.maxWidth / 260).floor().clamp(2, 4);
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
              child: _reorderableCard(note, i, colWidth),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(outer, outer, outer, 96),
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

  /// Wrap a card as both a drag source (long-press) and a drop target so notes
  /// can be reordered by dragging one onto another.
  Widget _reorderableCard(Note note, int flatIndex, double width) {
    final card = NoteCard(
      note: note,
      isDragging: _draggingId == note.id,
      onTap: () => _openNote(note),
    );

    // Reorder maps visual index → provider index, which only holds when the
    // list isn't filtered. Disable dragging during search.
    if (_query.trim().isNotEmpty) return card;

    return DragTarget<Note>(
      onWillAcceptWithDetails: (d) => d.data.id != note.id,
      onAcceptWithDetails: (d) {
        ref.read(noteProvider.notifier).reorder(d.data.id, flatIndex);
      },
      builder: (context, candidate, rejected) {
        final highlighted = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: LongPressDraggable<Note>(
            data: note,
            onDragStarted: () => setState(() => _draggingId = note.id),
            onDragEnd: (_) => setState(() => _draggingId = null),
            onDraggableCanceled: (_, _) => setState(() => _draggingId = null),
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: width,
                child: Opacity(
                  opacity: 0.95,
                  child: NoteCard(note: note, onTap: () {}),
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

  /// Rough card-height estimate to balance the masonry columns. Exact layout
  /// height isn't known ahead of paint, so approximate from text length.
  double _estimateHeight(Note note) {
    var h = 70.0; // padding + date row
    if (note.title.trim().isNotEmpty) {
      h += 24 * ((note.title.trim().length / 22).ceil().clamp(1, 3));
    }
    final content = note.content.trim();
    final contentLen = content.isEmpty ? 6 : content.length;
    h += 20 * ((contentLen / 26).ceil().clamp(1, 9));
    if (note.isPinned) h += 20;
    return h;
  }

  Widget _buildEmpty() {
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
              searching ? 'No matching notes' : 'No notes yet',
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
