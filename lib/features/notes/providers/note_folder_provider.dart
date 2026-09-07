import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/services/supabase_service.dart';
import '../../sync/services/sync_service.dart';
import '../domain/models/note_folder.dart';
import 'note_provider.dart';

class NoteFolderState {
  final List<NoteFolder> folders;
  final bool isLoading;
  final String? error;

  const NoteFolderState({
    this.folders = const [],
    this.isLoading = false,
    this.error,
  });

  NoteFolderState copyWith({
    List<NoteFolder>? folders,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return NoteFolderState(
      folders: folders ?? this.folders,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  NoteFolder? byId(String? id) {
    if (id == null) return null;
    for (final f in folders) {
      if (f.id == id) return f;
    }
    return null;
  }
}

class NoteFolderNotifier extends StateNotifier<NoteFolderState> {
  NoteFolderNotifier(this._ref) : super(const NoteFolderState()) {
    _load();
  }

  final Ref _ref;
  Box<Map>? _box;
  final _uuid = const Uuid();

  /// The box is opened here instead of in `main`, so the folders cost nothing
  /// until the notes tab is first opened.
  Future<Box<Map>> _openBox() async {
    _box ??= Hive.isBoxOpen(NoteFolder.hiveBox)
        ? Hive.box<Map>(NoteFolder.hiveBox)
        : await Hive.openBox<Map>(NoteFolder.hiveBox);
    return _box!;
  }

  void _sort(List<NoteFolder> list) {
    list.sort((a, b) {
      final orderCompare = a.sortOrder.compareTo(b.sortOrder);
      if (orderCompare != 0) return orderCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    try {
      final box = await _openBox();
      final folders = box.values
          .map((m) => NoteFolder.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      _sort(folders);
      state = state.copyWith(folders: folders, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => _load();

  Future<NoteFolder> addFolder({
    required String name,
    int color = NoteFolder.defaultColor,
  }) async {
    final now = DateTime.now();
    final box = await _openBox();
    final maxOrder = state.folders.isEmpty
        ? -1
        : state.folders.map((f) => f.sortOrder).reduce((a, b) => a > b ? a : b);

    final folder = NoteFolder(
      id: _uuid.v4(),
      userId: SupabaseService.currentUser?.id ?? 'local',
      name: name,
      color: color,
      sortOrder: maxOrder + 1,
      createdAt: now,
      updatedAt: now,
    );

    await box.put(folder.id, folder.toJson());
    final folders = [...state.folders, folder];
    _sort(folders);
    state = state.copyWith(folders: folders);

    await SyncService.queueOperation(
      entityType: SyncEntityType.noteFolder,
      operation: SyncOperation.create,
      entityId: folder.id,
      data: folder.toJson(),
    );
    return folder;
  }

  Future<void> updateFolder(NoteFolder folder) async {
    final box = await _openBox();
    final updated = folder.copyWith(
      updatedAt: DateTime.now(),
      version: folder.version + 1,
    );
    await box.put(updated.id, updated.toJson());
    final folders = state.folders
        .map((f) => f.id == updated.id ? updated : f)
        .toList();
    _sort(folders);
    state = state.copyWith(folders: folders);

    await SyncService.queueOperation(
      entityType: SyncEntityType.noteFolder,
      operation: SyncOperation.update,
      entityId: updated.id,
      data: updated.toJson(),
    );
  }

  /// Delete a folder. Its notes survive and fall back to "no folder".
  Future<void> deleteFolder(String folderId) async {
    final box = await _openBox();
    await _ref.read(noteProvider.notifier).clearFolder(folderId);

    await box.delete(folderId);
    state = state.copyWith(
      folders: state.folders.where((f) => f.id != folderId).toList(),
    );

    await SyncService.queueOperation(
      entityType: SyncEntityType.noteFolder,
      operation: SyncOperation.delete,
      entityId: folderId,
    );
  }
}

final noteFolderProvider =
    StateNotifierProvider<NoteFolderNotifier, NoteFolderState>(
      (ref) => NoteFolderNotifier(ref),
    );

/// Folder the notes grid is filtered to. Null = "All notes".
final selectedNoteFolderProvider = StateProvider<String?>((ref) => null);

/// True once the notes tab has seeded [selectedNoteFolderProvider] from the
/// default-folder setting.
///
/// It lives next to the selection instead of in the page's state: leaving the
/// tab and coming back must not overrule a folder the user picked by hand.
final noteFolderSeededProvider = StateProvider<bool>((ref) => false);
