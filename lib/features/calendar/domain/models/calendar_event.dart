class CalendarEvent {
  final String id;
  final String userId;
  final String? calendarId;
  // Encrypted fields
  final String title;
  final String? description;
  final String? location;
  // Plaintext queryable fields
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final int color;
  final String? recurrenceRule;
  final String? recurrenceId;
  final String? originalStartTime;
  final List<int> reminderMinutes;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? encryptionContext;
  final int version;

  const CalendarEvent({
    required this.id,
    required this.userId,
    this.calendarId,
    required this.title,
    this.description,
    this.location,
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
    this.color = 0,
    this.recurrenceRule,
    this.recurrenceId,
    this.originalStartTime,
    this.reminderMinutes = const [],
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.encryptionContext,
    this.version = 1,
  });

  /// Sensitive data to encrypt before sync
  Map<String, dynamic> toEncryptedPayload() {
    return {
      'title': title,
      'description': description,
      'location': location,
    };
  }

  /// Non-sensitive metadata for Supabase (with encrypted blob)
  Map<String, dynamic> toSupabaseRow(String encryptedPayload) {
    return {
      'id': id,
      'user_id': userId,
      'calendar_id': calendarId,
      'encrypted_payload': encryptedPayload,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'is_all_day': isAllDay,
      'color': color != 0 ? color.toString() : null,
      'recurrence_rule': recurrenceRule,
      'recurrence_id': recurrenceId,
      'original_start_time': originalStartTime,
      'reminder_minutes': reminderMinutes,
      'sort_order': sortOrder,
      'version': version,
      'encryption_context': encryptionContext,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CalendarEvent.fromSupabaseRow(
    Map<String, dynamic> row,
    Map<String, dynamic> decryptedPayload,
  ) {
    return CalendarEvent(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      calendarId: row['calendar_id'] as String?,
      title: decryptedPayload['title'] as String,
      description: decryptedPayload['description'] as String?,
      location: decryptedPayload['location'] as String?,
      startTime: DateTime.parse(row['start_time'] as String),
      endTime: DateTime.parse(row['end_time'] as String),
      isAllDay: row['is_all_day'] as bool? ?? false,
      color: row['color'] != null ? int.tryParse(row['color'] as String) ?? 0 : 0,
      recurrenceRule: row['recurrence_rule'] as String?,
      recurrenceId: row['recurrence_id'] as String?,
      originalStartTime: row['original_start_time'] as String?,
      reminderMinutes: (row['reminder_minutes'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      sortOrder: row['sort_order'] as int? ?? 0,
      version: row['version'] as int? ?? 1,
      encryptionContext: row['encryption_context'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  /// For local Hive storage (plaintext on-device)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'calendar_id': calendarId,
      'title': title,
      'description': description,
      'location': location,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'is_all_day': isAllDay,
      'color': color,
      'recurrence_rule': recurrenceRule,
      'recurrence_id': recurrenceId,
      'original_start_time': originalStartTime,
      'reminder_minutes': reminderMinutes,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'encryption_context': encryptionContext,
      'version': version,
    };
  }

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      calendarId: json['calendar_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      isAllDay: json['is_all_day'] as bool? ?? false,
      color: json['color'] as int? ?? 0,
      recurrenceRule: json['recurrence_rule'] as String?,
      recurrenceId: json['recurrence_id'] as String?,
      originalStartTime: json['original_start_time'] as String?,
      reminderMinutes: (json['reminder_minutes'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      encryptionContext: json['encryption_context'] as String?,
      version: json['version'] as int? ?? 1,
    );
  }

  CalendarEvent copyWith({
    String? id,
    String? userId,
    String? calendarId,
    String? title,
    String? description,
    String? location,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    int? color,
    String? recurrenceRule,
    String? recurrenceId,
    String? originalStartTime,
    List<int>? reminderMinutes,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? encryptionContext,
    int? version,
    bool clearCalendarId = false,
    bool clearDescription = false,
    bool clearLocation = false,
    bool clearRecurrenceRule = false,
    bool clearRecurrenceId = false,
    bool clearOriginalStartTime = false,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      calendarId: clearCalendarId ? null : (calendarId ?? this.calendarId),
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      location: clearLocation ? null : (location ?? this.location),
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      color: color ?? this.color,
      recurrenceRule: clearRecurrenceRule ? null : (recurrenceRule ?? this.recurrenceRule),
      recurrenceId: clearRecurrenceId ? null : (recurrenceId ?? this.recurrenceId),
      originalStartTime: clearOriginalStartTime ? null : (originalStartTime ?? this.originalStartTime),
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      encryptionContext: encryptionContext ?? this.encryptionContext,
      version: version ?? this.version,
    );
  }

  CalendarEvent incrementVersion() {
    return copyWith(
      version: version + 1,
      updatedAt: DateTime.now(),
    );
  }

  /// Duration of the event
  Duration get duration => endTime.difference(startTime);

  /// Whether this is a recurring event exception
  bool get isException => recurrenceId != null;

  /// Whether this is a recurring event (has RRULE)
  bool get isRecurring => recurrenceRule != null && recurrenceRule!.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalendarEvent && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
