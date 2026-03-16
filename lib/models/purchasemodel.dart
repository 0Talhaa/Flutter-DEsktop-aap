class PurchaseItemData {
  final int productId;
  final String productName;
  final double tradePrice;
  final int quantity;
  final String? packing;
  final double? discount;
  final double? salesTax;

  PurchaseItemData({
    required this.productId,
    required this.productName,
    required this.tradePrice,
    required this.quantity,
    this.packing,
    this.discount,
    this.salesTax,
  });

  double get lineTotal {
    double base = tradePrice * quantity;
    double disc = discount ?? 0;
    double tax = salesTax ?? 0;
    return base - disc + tax;
  }

  PurchaseItemData copyWith({
    int? productId,
    String? productName,
    double? tradePrice,
    int? quantity,
    String? packing,
    double? discount,
    double? salesTax,
  }) {
    return PurchaseItemData(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      tradePrice: tradePrice ?? this.tradePrice,
      quantity: quantity ?? this.quantity,
      packing: packing ?? this.packing,
      discount: discount ?? this.discount,
      salesTax: salesTax ?? this.salesTax,
    );
  }
}