// lib/models/purchase.dart

class Purchase {
  final int? id;
  final String invoiceNumber;
  final DateTime date;
  final String supplierName;
  final double totalAmount;
  final double amountPaid;
  final List<PurchaseItem> items;

  Purchase({
    this.id,
    required this.invoiceNumber,
    required this.date,
    required this.supplierName,
    required this.totalAmount,
    required this.amountPaid,
    required this.items,
  });

  double get balance => totalAmount - amountPaid;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'date': date.toIso8601String(),
      'supplierName': supplierName,
      'totalAmount': totalAmount,
      'amountPaid': amountPaid,
    };
  }

  factory Purchase.fromMap(Map<String, dynamic> map, List<PurchaseItem> items) {
    return Purchase(
      id: map['id'],
      invoiceNumber: map['invoiceNumber'] ?? '',
      date: DateTime.parse(map['date']),
      supplierName: map['supplierName'] ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0.0,
      items: items,
    );
  }
}

class PurchaseItem {
  final int? id;
  final int productId;
  final String productName;
  final int quantity;
  final double tradePrice;
  final double? retailPrice; // ← NEW
  final String? packing;
  final double? discount;
  final double? salesTax;
  final String? unitType;
  final int? baseQuantity;
  final String? expiryDate;
  final String? batchNumber;

  PurchaseItem({
    this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.tradePrice,
    this.retailPrice, // ← NEW
    this.packing,
    this.discount,
    this.salesTax,
    this.unitType,
    this.baseQuantity,
    this.expiryDate,
    this.batchNumber,
  });

  double get lineTotal {
    double base = tradePrice * quantity;
    double disc = discount ?? 0;
    double tax = salesTax ?? 0;
    return base - disc + tax;
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'tradePrice': tradePrice,
      'retailPrice': retailPrice ?? 0, // ← NEW
      'packing': packing,
      'discount': discount ?? 0,
      'salesTax': salesTax ?? 0,
      'lineTotal': lineTotal,
      'unitType': unitType,
      'baseQuantity': baseQuantity,
      'expiryDate': expiryDate,
      'batchNumber': batchNumber,
    };
  }

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'],
      productId: map['productId'] as int,
      productName: map['productName'] as String,
      quantity: map['quantity'] as int,
      tradePrice: (map['tradePrice'] as num).toDouble(),
      retailPrice: (map['retailPrice'] as num?)?.toDouble(), // ← NEW
      packing: map['packing'] as String?,
      discount: (map['discount'] as num?)?.toDouble(),
      salesTax: (map['salesTax'] as num?)?.toDouble(),
      unitType: map['unitType'] as String?,
      baseQuantity: map['baseQuantity'] as int?,
      expiryDate: map['expiryDate'] as String?,
      batchNumber: map['batchNumber'] as String?,
    );
  }

  PurchaseItem copyWith({
    int? id,
    int? productId,
    String? productName,
    int? quantity,
    double? tradePrice,
    double? retailPrice, // ← NEW
    String? packing,
    double? discount,
    double? salesTax,
    String? unitType,
    int? baseQuantity,
    String? expiryDate,
    String? batchNumber,
  }) {
    return PurchaseItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      tradePrice: tradePrice ?? this.tradePrice,
      retailPrice: retailPrice ?? this.retailPrice, // ← NEW
      packing: packing ?? this.packing,
      discount: discount ?? this.discount,
      salesTax: salesTax ?? this.salesTax,
      unitType: unitType ?? this.unitType,
      baseQuantity: baseQuantity ?? this.baseQuantity,
      expiryDate: expiryDate ?? this.expiryDate,
      batchNumber: batchNumber ?? this.batchNumber,
    );
  }
}

/// PurchaseItemData - Used for cart/UI before saving to database
class PurchaseItemData {
  final int productId;
  final String productName;
  final double tradePrice;
  final double? retailPrice; // ← NEW
  final int quantity;
  final String? packing;
  final double? discount;
  final double? salesTax;
  final String? unitType;
  final int? baseQuantity;

  PurchaseItemData({
    required this.productId,
    required this.productName,
    required this.tradePrice,
    this.retailPrice, // ← NEW
    required this.quantity,
    this.packing,
    this.discount,
    this.salesTax,
    this.unitType,
    this.baseQuantity,
  });

  double get lineTotal {
    double base = tradePrice * quantity;
    double disc = discount ?? 0;
    double tax = salesTax ?? 0;
    return base - disc + tax;
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

  PurchaseItemData copyWith({
    int? productId,
    String? productName,
    double? tradePrice,
    double? retailPrice, // ← NEW
    int? quantity,
    String? packing,
    double? discount,
    double? salesTax,
    String? unitType,
    int? baseQuantity,
  }) {
    return PurchaseItemData(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      tradePrice: tradePrice ?? this.tradePrice,
      retailPrice: retailPrice ?? this.retailPrice, // ← NEW
      quantity: quantity ?? this.quantity,
      packing: packing ?? this.packing,
      discount: discount ?? this.discount,
      salesTax: salesTax ?? this.salesTax,
      unitType: unitType ?? this.unitType,
      baseQuantity: baseQuantity ?? this.baseQuantity,
    );
  }

  /// Convert to PurchaseItem for saving to database
  PurchaseItem toPurchaseItem() {
    return PurchaseItem(
      productId: productId,
      productName: productName,
      quantity: quantity,
      tradePrice: tradePrice,
      retailPrice: retailPrice, // ← NEW
      packing: packing,
      discount: discount,
      salesTax: salesTax,
      unitType: unitType,
      baseQuantity: baseQuantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'tradePrice': tradePrice,
      'retailPrice': retailPrice ?? 0, // ← NEW
      'quantity': quantity,
      'packing': packing,
      'discount': discount ?? 0,
      'salesTax': salesTax ?? 0,
      'lineTotal': lineTotal,
      'unitType': unitType,
      'baseQuantity': baseQuantity,
    };
  }

  factory PurchaseItemData.fromMap(Map<String, dynamic> map) {
    return PurchaseItemData(
      productId: map['productId'] as int,
      productName: map['productName'] as String,
      tradePrice: (map['tradePrice'] as num).toDouble(),
      retailPrice: (map['retailPrice'] as num?)?.toDouble(), // ← NEW
      quantity: map['quantity'] as int,
      packing: map['packing'] as String?,
      discount: (map['discount'] as num?)?.toDouble(),
      salesTax: (map['salesTax'] as num?)?.toDouble(),
      unitType: map['unitType'] as String?,
      baseQuantity: map['baseQuantity'] as int?,
    );
  }

  /// Create from Product
  factory PurchaseItemData.fromProduct(
    dynamic product, {
    int quantity = 1,
    String? unitType,
    int? baseQuantity,
  }) {
    return PurchaseItemData(
      productId: product.id!,
      productName: product.itemName,
      tradePrice: product.tradePrice,
      retailPrice: product.retailPrice, // ← NEW
      quantity: quantity,
      packing: product.issueUnit,
      discount: 0,
      salesTax: 0,
      unitType: unitType ?? product.baseUnit ?? product.issueUnit,
      baseQuantity: baseQuantity ?? quantity,
    );
  }

  @override
  String toString() {
    return 'PurchaseItemData(productId: $productId, productName: $productName, '
        'quantity: $quantity, tradePrice: $tradePrice, retailPrice: $retailPrice, '
        'unitType: $unitType, baseQuantity: $baseQuantity)';
  }
}