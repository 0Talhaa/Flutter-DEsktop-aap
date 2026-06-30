// lib/models/supplier.dart

class Supplier {
  final int? id;
  final String name;
  final String phone;
  final String? email;
  final String? company;
  final String? teleNumber;
  final String? address;
  final String? city;

  Supplier({
    this.id,
    required this.name,
    required this.phone,
    this.email,
    this.company,
    this.teleNumber,
    this.address,
    this.city,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'company': company,
      'teleNumber': teleNumber,
      'address': address,
      'city': city,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String,
      email: map['email'] as String?,
      company: map['company'] as String?,
      teleNumber: map['teleNumber'] as String?,
      address: map['address'] as String?,
      city: map['city'] as String?,
    );
  }

  Supplier copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? company,
    String? teleNumber,
    String? address,
    String? city,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      company: company ?? this.company,
      teleNumber: teleNumber ?? this.teleNumber,
      address: address ?? this.address,
      city: city ?? this.city,
    );
  }
}