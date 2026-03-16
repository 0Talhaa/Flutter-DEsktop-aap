// lib/models/supplier.dart

class Supplier {
  final int? id;
  final String name;
  final String phone;
  final String? email;
  final String? company;
  final String? teleNumber;
  final double openingBalance;

  Supplier({
    this.id,
    required this.name,
    required this.phone,
    this.email,
    this.company,
    this.teleNumber,
    this.openingBalance = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'company': company,
      'teleNumber': teleNumber,
      'openingBalance': openingBalance,
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
      openingBalance: (map['openingBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // ←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←
  // یہ copyWith method add کریں
  Supplier copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? company,
    String? teleNumber,
    double? openingBalance,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      company: company ?? this.company,
      teleNumber: teleNumber ?? this.teleNumber,
      openingBalance: openingBalance ?? this.openingBalance,
    );
  }
  // ←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←←
}