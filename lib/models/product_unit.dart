// lib/models/product_unit.dart

class ProductUnit {
  final int? id;
  final int productId;
  final String unitName;     // e.g., "Tablet", "Strip", "Box"
  final int quantity;        // e.g., 10 tablets in 1 strip
  final double price;        // Price for this unit
  final String? parentUnit;  // e.g., "Strip" is parent of "Tablet"
  final int conversionFactor; // How many of this unit in parent

  ProductUnit({
    this.id,
    required this.productId,
    required this.unitName,
    required this.quantity,
    required this.price,
    this.parentUnit,
    required this.conversionFactor,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'unitName': unitName,
      'quantity': quantity,
      'price': price,
      'parentUnit': parentUnit,
      'conversionFactor': conversionFactor,
    };
  }

  factory ProductUnit.fromMap(Map<String, dynamic> map) {
    return ProductUnit(
      id: map['id'],
      productId: map['productId'],
      unitName: map['unitName'],
      quantity: map['quantity'],
      price: map['price'],
      parentUnit: map['parentUnit'],
      conversionFactor: map['conversionFactor'] ?? 1,
    );
  }
}