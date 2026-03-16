// lib/models/issue_unit.dart

class IssueUnit {
  final int? id;
  final String name;
  final String? abbreviation;
  final String? description;
  final int? isActive;
  final String? createdAt;

  IssueUnit({
    this.id,
    required this.name,
    this.abbreviation,
    this.description,
    this.isActive = 1,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'abbreviation': abbreviation,
      'description': description,
      'isActive': isActive,
      'createdAt': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory IssueUnit.fromMap(Map<String, dynamic> map) {
    return IssueUnit(
      id: map['id'],
      name: map['name'] ?? '',
      abbreviation: map['abbreviation'],
      description: map['description'],
      isActive: map['isActive'],
      createdAt: map['createdAt'],
    );
  }

  IssueUnit copyWith({
    int? id,
    String? name,
    String? abbreviation,
    String? description,
    int? isActive,
    String? createdAt,
  }) {
    return IssueUnit(
      id: id ?? this.id,
      name: name ?? this.name,
      abbreviation: abbreviation ?? this.abbreviation,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => name;
}