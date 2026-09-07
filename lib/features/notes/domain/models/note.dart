/// A free-form note (Google-Keep / Xiaomi-Notes style).
///
/// Local-first: persisted in the `notes` Hive box. Sensitive fields are kept
/// on-device only (no Supabase sync yet), so [toJson]/[fromJson] round-trip the
/// full object.
class Note {
  final String id;
  final String userId;
  final String title;
  final String content;

  /// Optional card tint (ARGB int). Null = default surface color.
  final int? color;

  /// Manual ordering. Lower = earlier. Reorder rewrites this for every note.
  final int sortOrder;

  /// Pinned notes stick to the top regardless of [sortOrder].
  final bool isPinned;

  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  const Note({
    required this.id,
    required this.userId,
    this.title = '',
    this.content = '',
    this.color,
    this.sortOrder = 0,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  });

  /// True when there is nothing worth keeping (used to auto-discard on close).
  bool get isEmpty => title.trim().isEmpty && content.trim().isEmpty;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': content,
      'color': color,
      'sort_order': sortOrder,
      'is_pinned': isPinned,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'version': version,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      color: json['color'] as int?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isPinned: json['is_pinned'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      version: json['version'] as int? ?? 1,
    );
  }

  Note copyWith({
    String? id,
    String? userId,
    String? title,
    String? content,
    int? color,
    int? sortOrder,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    bool clearColor = false,
  }) {
    return Note(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      color: clearColor ? null : (color ?? this.color),
      sortOrder: sortOrder ?? this.sortOrder,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Note && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
