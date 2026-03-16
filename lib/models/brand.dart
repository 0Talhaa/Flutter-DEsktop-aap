// lib/models/brand.dart

class Brand {
  final int? id;
  final String name;
  final String? description;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final int? isActive;
  final String? createdAt;

  Brand({
    this.id,
    required this.name,
    this.description,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.isActive = 1,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'contactPerson': contactPerson,
      'phone': phone,
      'email': email,
      'address': address,
      'isActive': isActive,
      'createdAt': createdAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory Brand.fromMap(Map<String, dynamic> map) {
    return Brand(
      id: map['id'],
      name: map['name'] ?? '',
      description: map['description'],
      contactPerson: map['contactPerson'],
      phone: map['phone'],
      email: map['email'],
      address: map['address'],
      isActive: map['isActive'],
      createdAt: map['createdAt'],
    );
  }

  Brand copyWith({
    int? id,
    String? name,
    String? description,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    int? isActive,
    String? createdAt,
  }) {
    return Brand(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => name;
}