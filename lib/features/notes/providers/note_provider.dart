import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/services/supabase_service.dart';
import '../domain/models/note.dart';
import '../../sync/services/sync_service.dart';

class NoteState {
  final List<Note> notes;
  final bool isLoading;
  final String? error;

  const NoteState({this.notes = const [], this.isLoading = false, this.error});

  NoteState copyWith({
    List<Note>? notes,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return NoteState(
      notes: notes ?? this.notes,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class NoteNotifier extends StateNotifier<NoteState> {
  NoteNotifier() : super(const NoteState()) {
    _load();
  }

  Box<Map>? _box;
  final _uuid = const Uuid();

  Box<Map> get _notesBox {
    _box ??= Hive.box<Map>(AppConstants.hiveNotesBox);
    return _box!;
  }

  /// Pinned first, then by manual sortOrder, then newest edit first.
  void _sort(List<Note> list) {
    list.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final orderCompare = a.sortOrder.compareTo(b.sortOrder);
      if (orderCompare != 0) return orderCompare;
      return b.updatedAt.compareTo(a.updatedAt);
    });
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    try {
      final notes = _notesBox.values
          .map((m) => Note.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      _sort(notes);
      state = state.copyWith(notes: notes, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => _load();

  /// Create a note and return it (caller opens it in the editor).
  Future<Note> addNote({
    String title = '',
    String content = '',
    int? color,
    String? folderId,
  }) async {
    final now = DateTime.now();
    // New notes go to the very top of the unpinned section.
    final minOrder = state.notes.isEmpty
        ? 0
        : state.notes.map((n) => n.sortOrder).reduce((a, b) => a < b ? a : b);

    final note = Note(
      id: _uuid.v4(),
      userId: SupabaseService.currentUser?.id ?? 'local',
      title: title,
      content: content,
      color: color,
      folderId: folderId,
      sortOrder: minOrder - 1,
      createdAt: now,
      updatedAt: now,
    );

    await _notesBox.put(note.id, note.toJson());
    final notes = [note, ...state.notes];
    _sort(notes);
    state = state.copyWith(notes: notes);

    await SyncService.queueOperation(
      entityType: SyncEntityType.note,
      operation: SyncOperation.create,
      entityId: note.id,
      data: note.toJson(),
    );
    return note;
  }

  Future<void> updateNote(Note note) async {
    final updated = note.copyWith(
      updatedAt: DateTime.now(),
      version: note.version + 1,
    );
    await _notesBox.put(updated.id, updated.toJson());
    final notes = state.notes
        .map((n) => n.id == updated.id ? updated : n)
        .toList();
    _sort(notes);
    state = state.copyWith(notes: notes);

    await SyncService.queueOperation(
      entityType: SyncEntityType.note,
      operation: SyncOperation.update,
      entityId: updated.id,
      data: updated.toJson(),
    );
  }

  Future<void> togglePin(String noteId) async {
    final idx = state.notes.indexWhere((n) => n.id == noteId);
    if (idx == -1) return;
    final note = state.notes[idx];
    await updateNote(note.copyWith(isPinned: !note.isPinned));
  }

  Future<void> setColor(String noteId, int? color) async {
    final idx = state.notes.indexWhere((n) => n.id == noteId);
    if (idx == -1) return;
    final note = state.notes[idx];
    await updateNote(note.copyWith(color: color, clearColor: color == null));
  }

  /// Move a note into [folderId], or out of every folder when it is null.
  Future<void> moveToFolder(String noteId, String? folderId) async {
    final idx = state.notes.indexWhere((n) => n.id == noteId);
    if (idx == -1) return;
    final note = state.notes[idx];
    if (note.folderId == folderId) return;
    await updateNote(
      note.copyWith(folderId: folderId, clearFolder: folderId == null),
    );
  }

  /// Drop [folderId] from every note that carries it. Called when the folder
  /// is deleted: the folder goes, the notes stay.
  Future<void> clearFolder(String folderId) async {
    final affected = state.notes.where((n) => n.folderId == folderId).toList();
    for (final note in affected) {
      await updateNote(note.copyWith(clearFolder: true));
    }
  }

  Future<void> deleteNote(String noteId) async {
    await _notesBox.delete(noteId);
    final notes = state.notes.where((n) => n.id != noteId).toList();
    state = state.copyWith(notes: notes);

    await SyncService.queueOperation(
      entityType: SyncEntityType.note,
      operation: SyncOperation.delete,
      entityId: noteId,
    );
  }

  /// Re-insert a deleted note (swipe-to-delete undo).
  Future<void> restoreNote(Note note) async {
    await _notesBox.put(note.id, note.toJson());
    final notes = [note, ...state.notes.where((n) => n.id != note.id)];
    _sort(notes);
    state = state.copyWith(notes: notes);

    await SyncService.queueOperation(
      entityType: SyncEntityType.note,
      operation: SyncOperation.create,
      entityId: note.id,
      data: note.toJson(),
    );
  }

  /// Move [noteId] so it sits at [targetIndex] in the current visual order,
  /// then rewrite sortOrder for the whole list. Pins are kept ahead of unpinned
  /// automatically by [_sort].
  Future<void> reorder(String noteId, int targetIndex) async {
    final notes = List<Note>.from(state.notes);
    final from = notes.indexWhere((n) => n.id == noteId);
    if (from == -1) return;

    final moved = notes.removeAt(from);
    // Dropping onto the target card means "sit before it". Removing the dragged
    // item first shifts everything after it down one, so compensate.
    var insertAt = from < targetIndex ? targetIndex - 1 : targetIndex;
    insertAt = insertAt.clamp(0, notes.length);
    notes.insert(insertAt, moved);

    for (var i = 0; i < notes.length; i++) {
      if (notes[i].sortOrder != i) {
        notes[i] = notes[i].copyWith(sortOrder: i);
        await _notesBox.put(notes[i].id, notes[i].toJson());
      }
    }
    _sort(notes);
    state = state.copyWith(notes: notes);
  }
}

final noteProvider = StateNotifierProvider<NoteNotifier, NoteState>(
  (ref) => NoteNotifier(),
);
