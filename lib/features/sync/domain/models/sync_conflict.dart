import '../../../todos/domain/models/todo.dart';

/// Represents a conflict between local and server versions of a todo
class SyncConflict {
  final String todoId;
  final Todo localVersion;
  final Todo serverVersion;
  final DateTime detectedAt;

  const SyncConflict({
    required this.todoId,
    required this.localVersion,
    required this.serverVersion,
    required this.detectedAt,
  });

  /// Check if there are meaningful differences (not just version number)
  bool get hasMeaningfulDifferences {
    if (localVersion.title != serverVersion.title) return true;
    if (localVersion.description != serverVersion.description) return true;
    if (localVersion.dueDate != serverVersion.dueDate) return true;
    if (localVersion.dueTime?.hour != serverVersion.dueTime?.hour) return true;
    if (localVersion.dueTime?.minute != serverVersion.dueTime?.minute) return true;
    if (localVersion.priority != serverVersion.priority) return true;
    if (localVersion.isCompleted != serverVersion.isCompleted) return true;
    if (localVersion.projectId != serverVersion.projectId) return true;
    return false;
  }

  /// Get a list of changed fields
  List<String> get changedFields {
    final changes = <String>[];
    if (localVersion.title != serverVersion.title) changes.add('Titel');
    if (localVersion.description != serverVersion.description) changes.add('Beschreibung');
    if (localVersion.dueDate != serverVersion.dueDate) changes.add('Fälligkeitsdatum');
    if (localVersion.dueTime?.hour != serverVersion.dueTime?.hour ||
        localVersion.dueTime?.minute != serverVersion.dueTime?.minute) {
      changes.add('Uhrzeit');
    }
    if (localVersion.priority != serverVersion.priority) changes.add('Priorität');
    if (localVersion.isCompleted != serverVersion.isCompleted) changes.add('Status');
    if (localVersion.projectId != serverVersion.projectId) changes.add('Projekt');
    return changes;
  }
}

/// How to resolve a sync conflict
enum ConflictResolution {
  keepLocal,    // Keep local version, overwrite server
  keepServer,   // Keep server version, discard local changes
  keepBoth,     // Create a copy for both versions
  merge,        // Automatically merge (use newer values)
}
