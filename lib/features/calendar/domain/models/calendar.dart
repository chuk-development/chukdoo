/// What a calendar is for.
///
/// The app seeds two of them on first start. `birthdays` is not a plain
/// calendar: everything in it is all-day and repeats every year, so the
/// editor pre-sets those two fields when this calendar is picked.
enum CalendarKind { general, birthdays }

class Calendar {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final int color;
  final bool isDefault;
  final bool isVisible;
  final int sortOrder;
  final CalendarKind kind;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Calendar({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.color = 0xFF4285F4,
    this.isDefault = false,
    this.isVisible = true,
    this.sortOrder = 0,
    this.kind = CalendarKind.general,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Sensitive data to encrypt before sync
  Map<String, dynamic> toEncryptedPayload() {
    return {
      'name': name,
      'description': description,
      // The kind rides in the encrypted blob so a synced calendar keeps its
      // meaning without a new column on the server.
      'kind': kind.name,
    };
  }

  /// Non-sensitive metadata for Supabase (with encrypted blob)
  Map<String, dynamic> toSupabaseRow(String encryptedPayload) {
    return {
      'id': id,
      'user_id': userId,
      'encrypted_payload': encryptedPayload,
      'color': '#${color.toRadixString(16).padLeft(8, '0').substring(2)}',
      'is_default': isDefault,
      'is_visible': isVisible,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Calendar.fromSupabaseRow(
    Map<String, dynamic> row,
    Map<String, dynamic> decryptedPayload,
  ) {
    return Calendar(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      name: decryptedPayload['name'] as String,
      description: decryptedPayload['description'] as String?,
      color: _parseColor(row['color'] as String?),
      isDefault: row['is_default'] as bool? ?? false,
      isVisible: row['is_visible'] as bool? ?? true,
      sortOrder: row['sort_order'] as int? ?? 0,
      kind: _parseKind(decryptedPayload['kind']),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  /// For local Hive storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'color': color,
      'is_default': isDefault,
      'is_visible': isVisible,
      'sort_order': sortOrder,
      'kind': kind.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Calendar.fromJson(Map<String, dynamic> json) {
    return Calendar(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      color: json['color'] as int? ?? 0xFF4285F4,
      isDefault: json['is_default'] as bool? ?? false,
      isVisible: json['is_visible'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      kind: _parseKind(json['kind']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Calendar copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    int? color,
    bool? isDefault,
    bool? isVisible,
    int? sortOrder,
    CalendarKind? kind,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearDescription = false,
  }) {
    return Calendar(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      isVisible: isVisible ?? this.isVisible,
      sortOrder: sortOrder ?? this.sortOrder,
      kind: kind ?? this.kind,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static CalendarKind _parseKind(Object? raw) {
    return CalendarKind.values
            .where((k) => k.name == raw)
            .firstOrNull ??
        CalendarKind.general;
  }

  static int _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return 0xFF4285F4;
    final clean = hex.replaceAll('#', '');
    return int.tryParse('FF$clean', radix: 16) ?? 0xFF4285F4;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Calendar && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
