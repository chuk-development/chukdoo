import 'package:flutter/material.dart';

enum TodoPriority {
  p1(1, 'P1'),
  p2(2, 'P2'),
  p3(3, 'P3'),
  p4(4, 'P4');

  const TodoPriority(this.value, this.label);
  final int value;
  final String label;

  static TodoPriority fromValue(int value) {
    return TodoPriority.values.firstWhere(
      (p) => p.value == value,
      orElse: () => TodoPriority.p4,
    );
  }
}

enum TodoStatus {
  todo('todo'),
  inProgress('in_progress'),
  done('done');

  const TodoStatus(this.value);
  final String value;

  static TodoStatus fromValue(String value) {
    return TodoStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => TodoStatus.todo,
    );
  }
}

class Todo {
  final String id;
  final String userId;
  final String? projectId;
  final String title;
  final String? description;
  final TodoPriority priority;
  final DateTime? dueDate;
  final TimeOfDay? dueTime;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? recurrenceRule;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? encryptionContext;
  final List<String> labelIds;
  final DateTime? reminderAt; // When to show reminder notification
  final int version; // Incremented on each update for conflict detection
  final TodoStatus status; // Kanban status: todo, in_progress, done
  final bool isPinned; // Pinned to top (local-only preference)

  const Todo({
    required this.id,
    required this.userId,
    this.projectId,
    required this.title,
    this.description,
    this.priority = TodoPriority.p4,
    this.dueDate,
    this.dueTime,
    this.isCompleted = false,
    this.completedAt,
    this.recurrenceRule,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.encryptionContext,
    this.labelIds = const [],
    this.reminderAt,
    this.version = 1,
    this.status = TodoStatus.todo,
    this.isPinned = false,
  });

  /// Creates a payload to be encrypted (sensitive data)
  Map<String, dynamic> toEncryptedPayload() {
    return {
      'title': title,
      'description': description,
    };
  }

  /// Creates a payload with non-sensitive data for Supabase
  Map<String, dynamic> toSupabaseRow(String encryptedPayload) {
    return {
      'id': id,
      'user_id': userId,
      'project_id': projectId,
      'encrypted_payload': encryptedPayload,
      'priority': priority.value,
      'due_date': dueDate?.toIso8601String().split('T')[0],
      'due_time': dueTime != null
          ? '${dueTime!.hour.toString().padLeft(2, '0')}:${dueTime!.minute.toString().padLeft(2, '0')}:00'
          : null,
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
      'recurrence_rule': recurrenceRule,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'encryption_context': encryptionContext,
      'status': status.value,
    };
  }

  /// Creates a Todo from Supabase row with decrypted payload
  factory Todo.fromSupabaseRow(
    Map<String, dynamic> row,
    Map<String, dynamic> decryptedPayload,
  ) {
    TimeOfDay? dueTime;
    if (row['due_time'] != null) {
      final timeParts = (row['due_time'] as String).split(':');
      dueTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );
    }

    return Todo(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      projectId: row['project_id'] as String?,
      title: decryptedPayload['title'] as String,
      description: decryptedPayload['description'] as String?,
      priority: TodoPriority.fromValue(row['priority'] as int? ?? 4),
      dueDate: row['due_date'] != null
          ? DateTime.parse(row['due_date'] as String)
          : null,
      dueTime: dueTime,
      isCompleted: row['is_completed'] as bool? ?? false,
      completedAt: row['completed_at'] != null
          ? DateTime.parse(row['completed_at'] as String)
          : null,
      recurrenceRule: row['recurrence_rule'] as String?,
      sortOrder: row['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      encryptionContext: row['encryption_context'] as String?,
      labelIds: const [],
      status: TodoStatus.fromValue(row['status'] as String? ?? 'todo'),
    );
  }

  /// For local cache (stores everything serialized)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'project_id': projectId,
      'title': title,
      'description': description,
      'priority': priority.value,
      'due_date': dueDate?.toIso8601String(),
      'due_time': dueTime != null
          ? '${dueTime!.hour}:${dueTime!.minute}'
          : null,
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
      'recurrence_rule': recurrenceRule,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'encryption_context': encryptionContext,
      'label_ids': labelIds,
      'reminder_at': reminderAt?.toIso8601String(),
      'version': version,
      'status': status.value,
      'is_pinned': isPinned,
    };
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    TimeOfDay? dueTime;
    if (json['due_time'] != null) {
      final timeParts = (json['due_time'] as String).split(':');
      dueTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );
    }

    return Todo(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      projectId: json['project_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      priority: TodoPriority.fromValue(json['priority'] as int? ?? 4),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      dueTime: dueTime,
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      recurrenceRule: json['recurrence_rule'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      encryptionContext: json['encryption_context'] as String?,
      labelIds: (json['label_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      reminderAt: json['reminder_at'] != null
          ? DateTime.parse(json['reminder_at'] as String)
          : null,
      version: json['version'] as int? ?? 1,
      status: TodoStatus.fromValue(json['status'] as String? ?? 'todo'),
      isPinned: json['is_pinned'] as bool? ?? false,
    );
  }

  Todo copyWith({
    String? id,
    String? userId,
    String? projectId,
    String? title,
    String? description,
    TodoPriority? priority,
    DateTime? dueDate,
    TimeOfDay? dueTime,
    bool? isCompleted,
    DateTime? completedAt,
    String? recurrenceRule,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? encryptionContext,
    List<String>? labelIds,
    DateTime? reminderAt,
    int? version,
    TodoStatus? status,
    bool? isPinned,
    bool clearDueDate = false,
    bool clearDueTime = false,
    bool clearDescription = false,
    bool clearProjectId = false,
    bool clearReminder = false,
  }) {
    // Keep status and isCompleted consistent
    final resolvedIsCompleted = isCompleted ?? this.isCompleted;
    var resolvedStatus = status ?? this.status;

    if (isCompleted == true) {
      // When toggling isCompleted to true, status becomes done
      resolvedStatus = TodoStatus.done;
    } else if (status == TodoStatus.done) {
      // When status is set to done, isCompleted becomes true
      // (handled below via resolvedIsCompleted override)
    }

    final effectiveIsCompleted =
        (status == TodoStatus.done) ? true : resolvedIsCompleted;

    return Todo(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      projectId: clearProjectId ? null : (projectId ?? this.projectId),
      title: title ?? this.title,
      description:
          clearDescription ? null : (description ?? this.description),
      priority: priority ?? this.priority,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      dueTime: clearDueTime ? null : (dueTime ?? this.dueTime),
      isCompleted: effectiveIsCompleted,
      completedAt: completedAt ?? this.completedAt,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      encryptionContext: encryptionContext ?? this.encryptionContext,
      labelIds: labelIds ?? this.labelIds,
      reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
      version: version ?? this.version,
      status: resolvedStatus,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  /// Create a new version with incremented version number
  Todo incrementVersion() {
    return copyWith(
      version: version + 1,
      updatedAt: DateTime.now(),
    );
  }

  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year &&
        dueDate!.month == now.month &&
        dueDate!.day == now.day;
  }

  bool get isOverdue {
    if (dueDate == null || isCompleted) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.isBefore(today);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Todo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
