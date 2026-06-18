import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class Project {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final Color color;
  final String icon;
  final bool isInbox;
  final bool isArchived;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Project({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.color = AppColors.primary,
    this.icon = 'folder',
    this.isInbox = false,
    this.isArchived = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a payload to be encrypted (sensitive data)
  Map<String, dynamic> toEncryptedPayload() {
    return {
      'name': name,
      'description': description,
    };
  }

  /// Creates a payload with non-sensitive data for Supabase
  Map<String, dynamic> toSupabaseRow(String encryptedName, String? encryptedDescription) {
    return {
      'id': id,
      'owner_id': ownerId,
      'encrypted_name': encryptedName,
      'encrypted_description': encryptedDescription,
      'color': '#${color.toARGB32().toRadixString(16).substring(2)}',
      'icon': icon,
      'is_inbox': isInbox,
      'is_archived': isArchived,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Creates a Project from Supabase row with decrypted name
  factory Project.fromSupabaseRow(
    Map<String, dynamic> row,
    String decryptedName,
    String? decryptedDescription,
  ) {
    Color color = AppColors.primary;
    if (row['color'] != null) {
      final colorStr = row['color'] as String;
      if (colorStr.startsWith('#') && colorStr.length == 7) {
        color = Color(int.parse('FF${colorStr.substring(1)}', radix: 16));
      }
    }

    return Project(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String,
      name: decryptedName,
      description: decryptedDescription,
      color: color,
      icon: row['icon'] as String? ?? 'folder',
      isInbox: row['is_inbox'] as bool? ?? false,
      isArchived: row['is_archived'] as bool? ?? false,
      sortOrder: row['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  /// For local cache
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'description': description,
      'color': '#${color.toARGB32().toRadixString(16).substring(2)}',
      'icon': icon,
      'is_inbox': isInbox,
      'is_archived': isArchived,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    Color color = AppColors.primary;
    if (json['color'] != null) {
      final colorStr = json['color'] as String;
      if (colorStr.startsWith('#') && colorStr.length == 7) {
        color = Color(int.parse('FF${colorStr.substring(1)}', radix: 16));
      }
    }

    return Project(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      color: color,
      icon: json['icon'] as String? ?? 'folder',
      isInbox: json['is_inbox'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Project copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    Color? color,
    String? icon,
    bool? isInbox,
    bool? isArchived,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearDescription = false,
  }) {
    return Project(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isInbox: isInbox ?? this.isInbox,
      isArchived: isArchived ?? this.isArchived,
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
