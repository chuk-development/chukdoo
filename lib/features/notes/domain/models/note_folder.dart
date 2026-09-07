/// A folder that groups notes.
///
/// Local-first, exactly like [Note]: persisted in its own Hive box and synced
/// to Supabase with the name encrypted end-to-end. Only the presentation
/// metadata (colour, order) stays in clear columns.
class NoteFolder {
  /// Hive box holding the folders.
  ///
  /// The box lives in this feature instead of `AppConstants` because the
  /// notes provider opens it on demand — the folder list is not needed before
  /// the notes tab is first built.
  static const String hiveBox = 'note_folders';

  /// Fallback tint of a new folder (the indigo of `AppColors.projectColors`).
  /// Kept as a literal so the domain layer stays free of the theme.
  static const int defaultColor = 0xFF7C82E0;

  final String id;
  final String userId;
  final String name;

  /// Folder tint (ARGB int) — drawn on the drawer row and the note cards.
  final int color;

  /// Manual ordering. Lower = earlier.
  final int sortOrder;

  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  const NoteFolder({
    required this.id,
    required this.userId,
    this.name = '',
    this.color = defaultColor,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  });

  /// Sensitive data to encrypt before sync.
  Map<String, dynamic> toEncryptedPayload() => {'name': name};

  /// Non-sensitive metadata for Supabase (with the encrypted blob).
  Map<String, dynamic> toSupabaseRow(String encryptedPayload) {
    return {
      'id': id,
      'user_id': userId,
      'encrypted_payload': encryptedPayload,
      'color': '#${color.toRadixString(16).padLeft(8, '0')}',
      'sort_order': sortOrder,
      'version': version,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory NoteFolder.fromSupabaseRow(
    Map<String, dynamic> row,
    Map<String, dynamic> decryptedPayload,
  ) {
    final colorStr = row['color'] as String?;
    return NoteFolder(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      name: decryptedPayload['name'] as String? ?? '',
      color: colorStr == null
          ? defaultColor
          : (int.tryParse(colorStr.replaceFirst('#', ''), radix: 16) ??
                defaultColor),
      sortOrder: row['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      version: row['version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'color': color,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'version': version,
    };
  }

  factory NoteFolder.fromJson(Map<String, dynamic> json) {
    return NoteFolder(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? '',
      color: json['color'] as int? ?? defaultColor,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      version: json['version'] as int? ?? 1,
    );
  }

  NoteFolder copyWith({
    String? id,
    String? userId,
    String? name,
    int? color,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) {
    return NoteFolder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NoteFolder && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
