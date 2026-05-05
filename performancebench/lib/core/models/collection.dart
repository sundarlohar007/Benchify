// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// Collection model — matches `collections` table in Appendix C exactly.
/// Named groups of sessions with optional color coding.
class Collection {
  final String id; // UUID
  final String name;
  final String? description;
  final String? color;
  final int createdAt; // Unix ms

  const Collection({
    required this.id,
    required this.name,
    this.description,
    this.color,
    this.createdAt = 0,
  });

  factory Collection.fromMap(Map<String, dynamic> map) {
    return Collection(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      color: map['color'] as String?,
      createdAt: (map['created_at'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
      'created_at': createdAt,
    };
  }
}
