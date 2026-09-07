import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/services/encryption_service.dart';
import '../../../shared/services/supabase_service.dart';
import '../../notifications/notification_service.dart';
import '../../todos/domain/models/todo.dart';
import '../domain/models/sync_conflict.dart';
import '../repositories/todo_sync_repository.dart';
import '../repositories/project_sync_repository.dart';
import '../repositories/calendar_sync_repository.dart';
import '../repositories/calendar_event_sync_repository.dart';
import '../repositories/habit_sync_repository.dart';
import '../repositories/note_sync_repository.dart';
import '../../calendar/domain/models/calendar_event.dart';
import '../../habits/domain/models/habit.dart';
import '../../notes/domain/models/note.dart';

/// Operation types for sync queue
enum SyncOperation { create, update, delete }

/// Entity types for sync
enum SyncEntityType { todo, project, calendar, calendarEvent, habit, note }

/// A queued sync operation
class SyncQueueItem {
  final String id;
  final SyncEntityType entityType;
  final SyncOperation operation;
  final String entityId;
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  SyncQueueItem({
    required this.id,
    required this.entityType,
    required this.operation,
    required this.entityId,
    this.data,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'entityType': entityType.name,
        'operation': operation.name,
        'entityId': entityId,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    Map<String, dynamic>? data;
    if (rawData != null) {
      data = Map<String, dynamic>.from(rawData as Map);
    }
    return SyncQueueItem(
      id: json['id'] as String,
      entityType: SyncEntityType.values.byName(json['entityType'] as String),
      operation: SyncOperation.values.byName(json['operation'] as String),
      entityId: json['entityId'] as String,
      data: data,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Sync status
enum SyncStatus { idle, syncing, error, offline }

/// Service for managing data synchronization
class SyncService {
  const SyncService._();

  static Box<Map>? _queueBox;
  static SyncStatus _status = SyncStatus.idle;
  static String? _lastError;
  static DateTime? _lastSyncTime;
  // In-flight guard shared by processQueue() and fullSync() so overlapping
  // sync triggers (periodic timer, realtime, connectivity) don't interleave.
  static bool _isSyncing = false;

  static final _statusController = StreamController<SyncStatus>.broadcast();
  static final _conflictController = StreamController<SyncConflict>.broadcast();

  /// Pending conflicts awaiting resolution
  static final List<SyncConflict> _pendingConflicts = [];

  /// Current sync status
  static SyncStatus get status => _status;

  /// Last error message
  static String? get lastError => _lastError;

  /// Last successful sync time
  static DateTime? get lastSyncTime => _lastSyncTime;

  /// Stream of sync status changes
  static Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Stream of sync conflicts for UI to handle
  static Stream<SyncConflict> get conflictStream => _conflictController.stream;

  /// Get pending conflicts
  static List<SyncConflict> get pendingConflicts => List.unmodifiable(_pendingConflicts);

  /// Check if there are pending conflicts
  static bool get hasConflicts => _pendingConflicts.isNotEmpty;

  /// Initialize the sync service
  static Future<void> initialize() async {
    _queueBox = await Hive.openBox<Map>(AppConstants.hivePendingBox);
  }

  static Box<Map> get _queue {
    if (_queueBox == null) {
      throw StateError('SyncService not initialized. Call initialize() first.');
    }
    return _queueBox!;
  }

  /// Queue an operation for sync
  static Future<void> queueOperation({
    required SyncEntityType entityType,
    required SyncOperation operation,
    required String entityId,
    Map<String, dynamic>? data,
  }) async {
    final item = SyncQueueItem(
      id: '${entityType.name}_${entityId}_${DateTime.now().millisecondsSinceEpoch}',
      entityType: entityType,
      operation: operation,
      entityId: entityId,
      data: data,
    );

    await _queue.put(item.id, item.toJson());
    debugPrint('SyncService: Queued ${operation.name} for ${entityType.name} $entityId');

    // Auto-process queue after adding new operation
    unawaited(processQueue());
  }

  /// Get all pending operations
  static List<SyncQueueItem> getPendingOperations() {
    return _queue.values.map((m) {
      final map = Map<String, dynamic>.from(m);
      return SyncQueueItem.fromJson(map);
    }).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Process the sync queue
  static Future<void> processQueue() async {
    // Same source of truth as the UI: a session must exist and its access
    // token must be fresh. Refreshes here so an expired JWT never reaches
    // PostgREST as "not authenticated".
    if (!await SupabaseService.ensureSyncSession()) {
      _status = SyncStatus.offline;
      _statusController.add(_status);
      return;
    }

    if (_isSyncing) {
      return; // Already syncing
    }

    _isSyncing = true;
    _status = SyncStatus.syncing;
    _statusController.add(_status);

    try {
      await _drainQueue();

      _lastSyncTime = DateTime.now();
      _lastError = null;
      _status = SyncStatus.idle;
    } catch (e) {
      _lastError = e.toString();
      _status = SyncStatus.error;
      debugPrint('SyncService: Error processing queue: $e');
    } finally {
      _isSyncing = false;
    }

    _statusController.add(_status);
  }

  /// Upload and clear all pending queue items. Caller owns the in-flight
  /// guard and status reporting.
  static Future<void> _drainQueue() async {
    final items = getPendingOperations();
    debugPrint('SyncService: Processing ${items.length} pending operations');

    for (final item in items) {
      await _processItem(item);
      await _queue.delete(item.id);
    }
  }

  /// Process a single sync item
  static Future<void> _processItem(SyncQueueItem item) async {
    final tableName = switch (item.entityType) {
      SyncEntityType.todo => 'todos',
      SyncEntityType.project => 'projects',
      SyncEntityType.calendar => 'calendars',
      SyncEntityType.calendarEvent => 'calendar_events',
      SyncEntityType.habit => 'habits',
      SyncEntityType.note => 'notes',
    };

    // Notes carry presentation columns (colour, order, pin) next to the
    // encrypted blob, so they go through their repository instead of the
    // generic payload-only upsert.
    if (item.entityType == SyncEntityType.note) {
      switch (item.operation) {
        case SyncOperation.create:
        case SyncOperation.update:
          if (item.data != null) {
            await NoteSyncRepository.uploadNote(
              Note.fromJson(Map<String, dynamic>.from(item.data!)),
            );
          }
        case SyncOperation.delete:
          await NoteSyncRepository.deleteNote(item.entityId);
      }
      return;
    }

    switch (item.operation) {
      case SyncOperation.create:
      case SyncOperation.update:
        if (item.data != null) {
          // Encrypt the data before sending
          final encryptedPayload = await EncryptionService.encryptJson(item.data!);
          final userId = item.data!['user_id'] as String?;

          await SupabaseService.client.from(tableName).upsert({
            'id': item.entityId,
            'user_id': userId,
            'encrypted_payload': encryptedPayload,
            'updated_at': DateTime.now().toIso8601String(),
          });
          debugPrint('SyncService: Uploaded ${item.entityType.name} ${item.entityId}');
        }
        break;
      case SyncOperation.delete:
        await SupabaseService.client
            .from(tableName)
            .delete()
            .eq('id', item.entityId);
        debugPrint('SyncService: Deleted ${item.entityType.name} ${item.entityId}');
        break;
    }
  }

  /// Perform a full sync (upload pending + download from server)
  static Future<void> fullSync() async {
    // See processQueue(): refresh the token before any request goes out.
    if (!await SupabaseService.ensureSyncSession()) {
      _status = SyncStatus.offline;
      _statusController.add(_status);
      return;
    }

    if (_isSyncing) {
      return; // Already syncing
    }

    _isSyncing = true;
    _status = SyncStatus.syncing;
    _statusController.add(_status);

    try {
      // First, upload any pending changes. Call the drain directly: going
      // through processQueue() would hit the in-flight guard and skip uploads.
      await _drainQueue();

      // Then download latest from server
      await _downloadFromServer();

      debugPrint('SyncService: Full sync completed');

      _lastSyncTime = DateTime.now();
      _lastError = null;
      _status = SyncStatus.idle;
    } catch (e) {
      _lastError = e.toString();
      _status = SyncStatus.error;
      debugPrint('SyncService: Full sync error: $e');
    } finally {
      _isSyncing = false;
    }

    _statusController.add(_status);
  }

  /// Download all data from server and merge with local
  static Future<void> _downloadFromServer() async {
    final todosBox = Hive.box<Map>(AppConstants.hiveTodosBox);
    final projectsBox = Hive.box<Map>(AppConstants.hiveProjectsBox);

    // Track new todos for notification
    int newTodoCount = 0;
    String? firstNewTodoTitle;

    // Download todos
    try {
      final serverTodos = await TodoSyncRepository.downloadTodos();
      debugPrint('SyncService: Downloaded ${serverTodos.length} todos from server');

      for (final serverTodo in serverTodos) {
        final localData = todosBox.get(serverTodo.id);

        if (localData == null) {
          // New todo from server - add locally
          newTodoCount++;
          firstNewTodoTitle ??= serverTodo.title;
          await todosBox.put(serverTodo.id, serverTodo.toJson());
          debugPrint('SyncService: Added new todo from server: ${serverTodo.id}');
        } else {
          // Existing todo - compare versions
          final localTodo = Todo.fromJson(Map<String, dynamic>.from(localData));

          // Server wins if it has a newer version or later update time
          if (serverTodo.version > localTodo.version ||
              (serverTodo.version == localTodo.version &&
               serverTodo.updatedAt.isAfter(localTodo.updatedAt))) {
            await todosBox.put(serverTodo.id, serverTodo.toJson());
            debugPrint('SyncService: Updated todo from server: ${serverTodo.id}');
          }
        }
      }

      // Show notification for new todos (if any)
      if (newTodoCount > 0) {
        await NotificationService.instance.showNewTodoNotification(
          count: newTodoCount,
          firstTodoTitle: firstNewTodoTitle,
        );
      }
    } catch (e) {
      debugPrint('SyncService: Error downloading todos: $e');
      rethrow;
    }

    // Download calendars
    try {
      final calendarsBox = Hive.box<Map>(AppConstants.hiveCalendarsBox);
      final serverCalendars = await CalendarSyncRepository.downloadCalendars();
      debugPrint('SyncService: Downloaded ${serverCalendars.length} calendars from server');

      for (final serverCalendar in serverCalendars) {
        final localData = calendarsBox.get(serverCalendar.id);

        if (localData == null) {
          await calendarsBox.put(serverCalendar.id, serverCalendar.toJson());
        } else {
          final localUpdatedAt = DateTime.tryParse(localData['updated_at'] as String? ?? '');
          if (localUpdatedAt == null || serverCalendar.updatedAt.isAfter(localUpdatedAt)) {
            await calendarsBox.put(serverCalendar.id, serverCalendar.toJson());
          }
        }
      }
    } catch (e) {
      debugPrint('SyncService: Error downloading calendars: $e');
    }

    // Download calendar events
    try {
      final calendarEventsBox = Hive.box<Map>(AppConstants.hiveCalendarEventsBox);
      final serverEvents = await CalendarEventSyncRepository.downloadEvents();
      debugPrint('SyncService: Downloaded ${serverEvents.length} calendar events from server');

      for (final serverEvent in serverEvents) {
        final localData = calendarEventsBox.get(serverEvent.id);

        if (localData == null) {
          await calendarEventsBox.put(serverEvent.id, serverEvent.toJson());
        } else {
          final localEvent = CalendarEvent.fromJson(Map<String, dynamic>.from(localData));
          if (serverEvent.version > localEvent.version ||
              (serverEvent.version == localEvent.version &&
               serverEvent.updatedAt.isAfter(localEvent.updatedAt))) {
            await calendarEventsBox.put(serverEvent.id, serverEvent.toJson());
          }
        }
      }
    } catch (e) {
      debugPrint('SyncService: Error downloading calendar events: $e');
    }

    // Download habits
    try {
      final habitsBox = Hive.box<Map>(AppConstants.hiveHabitsBox);
      final serverHabits = await HabitSyncRepository.downloadHabits();
      debugPrint('SyncService: Downloaded ${serverHabits.length} habits from server');

      for (final serverHabit in serverHabits) {
        final localData = habitsBox.get(serverHabit.id);

        if (localData == null) {
          await habitsBox.put(serverHabit.id, serverHabit.toJson());
          debugPrint('SyncService: Added new habit from server: ${serverHabit.id}');
        } else {
          final localHabit = Habit.fromJson(Map<String, dynamic>.from(localData));
          if (serverHabit.version > localHabit.version ||
              (serverHabit.version == localHabit.version &&
               serverHabit.updatedAt.isAfter(localHabit.updatedAt))) {
            await habitsBox.put(serverHabit.id, serverHabit.toJson());
            debugPrint('SyncService: Updated habit from server: ${serverHabit.id}');
          }
        }
      }
    } catch (e) {
      debugPrint('SyncService: Error downloading habits: $e');
    }

    // Download notes
    try {
      final notesBox = Hive.box<Map>(AppConstants.hiveNotesBox);
      final serverNotes = await NoteSyncRepository.downloadNotes();
      debugPrint('SyncService: Downloaded ${serverNotes.length} notes from server');

      for (final serverNote in serverNotes) {
        final localData = notesBox.get(serverNote.id);

        if (localData == null) {
          await notesBox.put(serverNote.id, serverNote.toJson());
        } else {
          final localNote = Note.fromJson(Map<String, dynamic>.from(localData));
          if (serverNote.version > localNote.version ||
              (serverNote.version == localNote.version &&
                  serverNote.updatedAt.isAfter(localNote.updatedAt))) {
            await notesBox.put(serverNote.id, serverNote.toJson());
          }
        }
      }
    } catch (e) {
      debugPrint('SyncService: Error downloading notes: $e');
    }

    // Download projects
    try {
      final serverProjects = await ProjectSyncRepository.downloadProjects();
      debugPrint('SyncService: Downloaded ${serverProjects.length} projects from server');

      for (final serverProject in serverProjects) {
        final localData = projectsBox.get(serverProject.id);

        if (localData == null) {
          // New project from server - add locally
          await projectsBox.put(serverProject.id, serverProject.toJson());
          debugPrint('SyncService: Added new project from server: ${serverProject.id}');
        } else {
          // For projects, use server version if newer
          final localUpdatedAt = DateTime.tryParse(localData['updated_at'] as String? ?? '');

          if (localUpdatedAt == null || serverProject.updatedAt.isAfter(localUpdatedAt)) {
            await projectsBox.put(serverProject.id, serverProject.toJson());
            debugPrint('SyncService: Updated project from server: ${serverProject.id}');
          }
        }
      }
    } catch (e) {
      debugPrint('SyncService: Error downloading projects: $e');
      // Don't rethrow - continue with partial sync
    }
  }

  /// Clear the sync queue
  static Future<void> clearQueue() async {
    await _queue.clear();
    debugPrint('SyncService: Queue cleared');
  }

  /// Get queue size
  static int get queueSize => _queue.length;

  /// Check for conflicts before syncing a todo
  static Future<SyncConflict?> checkForConflict(Todo localTodo) async {
    if (!SupabaseService.isAvailable) return null;

    try {
      final response = await SupabaseService.client
          .from('todos')
          .select('id, version, encrypted_payload, updated_at')
          .eq('id', localTodo.id)
          .maybeSingle();

      if (response == null) return null; // No server version

      final serverVersion = response['version'] as int? ?? 1;
      final serverUpdatedAt = DateTime.parse(response['updated_at'] as String);

      // Check if server version is newer than what we based our changes on
      if (serverVersion > localTodo.version) {
        // Decrypt server payload to get server todo
        final encryptedPayload = response['encrypted_payload'] as String;
        final decryptedPayload = await EncryptionService.decryptJson(encryptedPayload);

        // Create a minimal server todo for comparison
        final serverTodo = Todo(
          id: localTodo.id,
          userId: localTodo.userId,
          title: decryptedPayload['title'] as String? ?? '',
          description: decryptedPayload['description'] as String?,
          version: serverVersion,
          createdAt: localTodo.createdAt,
          updatedAt: serverUpdatedAt,
        );

        final conflict = SyncConflict(
          todoId: localTodo.id,
          localVersion: localTodo,
          serverVersion: serverTodo,
          detectedAt: DateTime.now(),
        );

        // Only flag as conflict if there are meaningful differences
        if (conflict.hasMeaningfulDifferences) {
          _pendingConflicts.add(conflict);
          _conflictController.add(conflict);
          debugPrint('SyncService: Conflict detected for todo ${localTodo.id}');
          return conflict;
        }
      }
    } catch (e) {
      debugPrint('SyncService: Error checking for conflict: $e');
    }

    return null;
  }

  /// Resolve a conflict with the chosen resolution
  static Future<void> resolveConflict(
    SyncConflict conflict,
    ConflictResolution resolution,
  ) async {
    try {
      final todosBox = Hive.box<Map>(AppConstants.hiveTodosBox);

      switch (resolution) {
        case ConflictResolution.keepLocal:
          // Force upload local version with incremented version
          final updated = conflict.localVersion.incrementVersion();
          await todosBox.put(updated.id, updated.toJson());
          await queueOperation(
            entityType: SyncEntityType.todo,
            operation: SyncOperation.update,
            entityId: updated.id,
            data: updated.toJson(),
          );
          break;

        case ConflictResolution.keepServer:
          // Use server version, discard local changes
          await todosBox.put(conflict.serverVersion.id, conflict.serverVersion.toJson());
          break;

        case ConflictResolution.keepBoth:
          // Keep server version and create a copy of local version
          await todosBox.put(conflict.serverVersion.id, conflict.serverVersion.toJson());

          // Create a copy with new ID
          final copyId = '${conflict.localVersion.id}_copy_${DateTime.now().millisecondsSinceEpoch}';
          final copy = conflict.localVersion.copyWith(
            id: copyId,
            title: '${conflict.localVersion.title} (Kopie)',
            version: 1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await todosBox.put(copyId, copy.toJson());
          await queueOperation(
            entityType: SyncEntityType.todo,
            operation: SyncOperation.create,
            entityId: copyId,
            data: copy.toJson(),
          );
          break;

        case ConflictResolution.merge:
          // Use the newer value for each field
          final merged = _mergeTodos(conflict.localVersion, conflict.serverVersion);
          await todosBox.put(merged.id, merged.toJson());
          await queueOperation(
            entityType: SyncEntityType.todo,
            operation: SyncOperation.update,
            entityId: merged.id,
            data: merged.toJson(),
          );
          break;
      }

      // Remove from pending conflicts
      _pendingConflicts.removeWhere((c) => c.todoId == conflict.todoId);
      debugPrint('SyncService: Conflict resolved for todo ${conflict.todoId} with $resolution');
    } catch (e) {
      debugPrint('SyncService: Error resolving conflict: $e');
    }
  }

  /// Merge two todos using the newer value for each field
  static Todo _mergeTodos(Todo local, Todo server) {
    // Use the version with the later updatedAt for each field
    final useLocal = local.updatedAt.isAfter(server.updatedAt);

    return Todo(
      id: local.id,
      userId: local.userId,
      projectId: useLocal ? local.projectId : server.projectId,
      title: useLocal ? local.title : server.title,
      description: useLocal ? local.description : server.description,
      priority: useLocal ? local.priority : server.priority,
      dueDate: useLocal ? local.dueDate : server.dueDate,
      dueTime: useLocal ? local.dueTime : server.dueTime,
      isCompleted: useLocal ? local.isCompleted : server.isCompleted,
      completedAt: useLocal ? local.completedAt : server.completedAt,
      recurrenceRule: useLocal ? local.recurrenceRule : server.recurrenceRule,
      sortOrder: useLocal ? local.sortOrder : server.sortOrder,
      createdAt: local.createdAt,
      updatedAt: DateTime.now(),
      encryptionContext: local.encryptionContext,
      labelIds: useLocal ? local.labelIds : server.labelIds,
      reminderAt: useLocal ? local.reminderAt : server.reminderAt,
      version: (local.version > server.version ? local.version : server.version) + 1,
    );
  }

  /// Dispose resources
  static void dispose() {
    _statusController.close();
    _conflictController.close();
    _pendingConflicts.clear();
  }
}
