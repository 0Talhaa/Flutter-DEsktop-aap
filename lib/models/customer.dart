// lib/models/customer.dart

class Customer {
  final int? id;
  final String name;
  final String phone;
  final double openingBalance;
  final String? address;
  final String? city;
  final String? email;
  final String? cnic;
  final bool isActive;

  Customer({
    this.id,
    required this.name,
    required this.phone,
    this.openingBalance = 0.0,
    this.address,
    this.city,
    this.email,
    this.cnic,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'openingBalance': openingBalance,
      'address': address,
      'city': city,
      'email': email,
      'cnic': cnic,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: map['phone'] as String,
      openingBalance: (map['openingBalance'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] as String?,
      city: map['city'] as String?,
      email: map['email'] as String?,
      cnic: map['cnic'] as String?,
      isActive: map['isActive'] == null || map['isActive'] == 1,
    );
  }

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    double? openingBalance,
    String? address,
    String? city,
    String? email,
    String? cnic,
    bool? isActive,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      openingBalance: openingBalance ?? this.openingBalance,
      address: address ?? this.address,
      city: city ?? this.city,
      email: email ?? this.email,
      cnic: cnic ?? this.cnic,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'Customer(id: $id, name: $name, phone: $phone, balance: $openingBalance)';
  }
}