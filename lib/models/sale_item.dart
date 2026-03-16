// lib/models/sale_item.dart

class SaleItem {
  final int productId;
  final String productName;
  final double price;
  final int quantity;
  final String? packing;
  final double? tradePrice;
  final double? discount;
  final double? salesTax;
  
  // Unit conversion fields
  final String? unitType;      // e.g., "Tablet", "Strip", "Box"
  final int? baseQuantity;     // Quantity in base units (e.g., total tablets)

  SaleItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.packing,
    this.tradePrice,
    this.discount,
    this.salesTax,
    this.unitType,
    this.baseQuantity,
  });

  double get lineTotal {
    double baseAmount = price * quantity;
    final discountAmount = baseAmount * ((discount ?? 0) / 100);
    double taxAmount = salesTax ?? 0;
    return baseAmount - discountAmount + taxAmount;
  }

  /// Get display string for unit (e.g., "2 Strips (20 Tablets)")
  String get unitDisplayString {
    if (unitType == null || baseQuantity == null) {
      return '$quantity';
    }
    
    if (quantity == baseQuantity) {
      return '$quantity $unitType${quantity > 1 ? 's' : ''}';
    }
    
    return '$quantity $unitType${quantity > 1 ? 's' : ''} ($baseQuantity units)';
  }

  SaleItem copyWith({
    int? productId,
    String? productName,
    double? price,
    int? quantity,
    String? packing,
    double? tradePrice,
    double? discount,
    double? salesTax,
    String? unitType,
    int? baseQuantity,
  }) {
    return SaleItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      packing: packing ?? this.packing,
      tradePrice: tradePrice ?? this.tradePrice,
      discount: discount ?? this.discount,
      salesTax: salesTax ?? this.salesTax,
      unitType: unitType ?? this.unitType,
      baseQuantity: baseQuantity ?? this.baseQuantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'packing': packing,
      'tradePrice': tradePrice ?? 0,
      'discount': discount ?? 0,
      'salesTax': salesTax ?? 0,
      'lineTotal': lineTotal,
      'unitType': unitType,
      'baseQuantity': baseQuantity,
    };
  }

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: map['productId'] as int,
      productName: map['productName'] as String,
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      packing: map['packing'] as String?,
      tradePrice: (map['tradePrice'] as num?)?.toDouble(),
      discount: (map['discount'] as num?)?.toDouble(),
      salesTax: (map['salesTax'] as num?)?.toDouble(),
      unitType: map['unitType'] as String?,
      baseQuantity: map['baseQuantity'] as int?,
    );
  }

  @override
  String toString() {
    return 'SaleItem(productId: $productId, productName: $productName, price: $price, quantity: $quantity, unitType: $unitType, baseQuantity: $baseQuantity, lineTotal: $lineTotal)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SaleItem &&
        other.productId == productId &&
        other.unitType == unitType;
  }

  @override
  int get hashCode => productId.hashCode ^ (unitType?.hashCode ?? 0);
}