class Habit {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final int color; // hex color
  final String frequency; // 'daily' or 'weekly'
  final List<String> completions; // ISO date strings (yyyy-MM-dd)
  final int streak;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? encryptionContext;
  final int version;

  const Habit({
    required this.id,
    this.userId = '',
    required this.name,
    this.description,
    required this.color,
    this.frequency = 'daily',
    this.completions = const [],
    this.streak = 0,
    this.sortOrder = 0,
    required this.createdAt,
    DateTime? updatedAt,
    this.encryptionContext,
    this.version = 1,
  }) : updatedAt = updatedAt ?? createdAt;

  /// Sensitive data to encrypt before sync
  Map<String, dynamic> toEncryptedPayload() {
    return {'name': name, 'description': description};
  }

  /// Non-sensitive metadata for Supabase (with encrypted blob)
  Map<String, dynamic> toSupabaseRow(String encryptedPayload) {
    return {
      'id': id,
      'user_id': userId,
      'encrypted_payload': encryptedPayload,
      'color': '#${color.toRadixString(16).padLeft(8, '0')}',
      'frequency': frequency,
      'completions': completions,
      'streak': streak,
      'sort_order': sortOrder,
      'version': version,
      'encryption_context': encryptionContext,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Habit.fromSupabaseRow(
    Map<String, dynamic> row,
    Map<String, dynamic> decryptedPayload,
  ) {
    // Parse color from hex string back to int
    final colorStr = row['color'] as String? ?? '#FF00BFA5';
    final colorInt =
        int.tryParse(colorStr.replaceFirst('#', ''), radix: 16) ?? 0xFF00BFA5;

    return Habit(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      name: decryptedPayload['name'] as String,
      description: decryptedPayload['description'] as String?,
      color: colorInt,
      frequency: row['frequency'] as String? ?? 'daily',
      completions:
          (row['completions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      streak: row['streak'] as int? ?? 0,
      sortOrder: row['sort_order'] as int? ?? 0,
      version: row['version'] as int? ?? 1,
      encryptionContext: row['encryption_context'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'color': color,
      'frequency': frequency,
      'completions': completions,
      'streak': streak,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'encryption_context': encryptionContext,
      'version': version,
    };
  }

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      name: json['name'] as String,
      description: json['description'] as String?,
      color: json['color'] as int,
      frequency: json['frequency'] as String? ?? 'daily',
      completions:
          (json['completions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      streak: json['streak'] as int? ?? 0,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      encryptionContext: json['encryption_context'] as String?,
      version: json['version'] as int? ?? 1,
    );
  }

  Habit copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    int? color,
    String? frequency,
    List<String>? completions,
    int? streak,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? encryptionContext,
    int? version,
    bool clearDescription = false,
  }) {
    return Habit(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      color: color ?? this.color,
      frequency: frequency ?? this.frequency,
      completions: completions ?? this.completions,
      streak: streak ?? this.streak,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      encryptionContext: encryptionContext ?? this.encryptionContext,
      version: version ?? this.version,
    );
  }

  Habit incrementVersion() {
    return copyWith(version: version + 1, updatedAt: DateTime.now());
  }

  bool isCompletedOn(DateTime date) {
    final dateStr = _dateToString(date);
    return completions.contains(dateStr);
  }

  static String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Calculate streak from completions list
  int calculateStreak() {
    if (completions.isEmpty) return 0;

    final completed = completions.toSet();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(today.year, today.month, today.day - 1);

    // Must have completed today or yesterday to have an active streak
    if (!completed.contains(_dateToString(today)) &&
        !completed.contains(_dateToString(yesterday))) {
      return 0;
    }

    int streak = 0;
    // Step by calendar day (DateTime(y, m, d - 1)) rather than subtracting a
    // fixed 24h Duration, which can skip/repeat a day across DST transitions.
    var checkDate = completed.contains(_dateToString(today))
        ? today
        : yesterday;
    while (completed.contains(_dateToString(checkDate))) {
      streak++;
      checkDate = DateTime(checkDate.year, checkDate.month, checkDate.day - 1);
    }

    return streak;
  }
}
