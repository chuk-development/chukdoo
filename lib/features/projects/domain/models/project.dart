class Project {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final int color;

  /// Selectable project icon key (see kProjectIcons). Null = default folder.
  final String? icon;
  final bool isInbox;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Project({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.color = 0xFF808080,
    this.icon,
    this.isInbox = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'color': color,
      'icon': icon,
      'is_inbox': isInbox,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      color: json['color'] as int? ?? 0xFF808080,
      icon: json['icon'] as String?,
      isInbox: json['is_inbox'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Project copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    bool clearDescription = false,
    int? color,
    String? icon,
    bool? isInbox,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isInbox: isInbox ?? this.isInbox,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Project && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
