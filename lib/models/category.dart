// lib/models/category.dart

class Category {
  final int? id;
  final String name;
  final String? description;
  final int? isActive;
  final String? createdAt;

  Category({
    this.id,
    required this.name,
    this.description,
    this.isActive = 1,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'isActive': isActive,
      'createdAt': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'] ?? '',
      description: map['description'],
      isActive: map['isActive'],
      createdAt: map['createdAt'],
    );
  }

  Category copyWith({
    int? id,
    String? name,
    String? description,
    int? isActive,
    String? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => name;
}