// lib/models/product.dart

import 'dart:convert';

class Product {
  final int? id;
  final String itemName;
  final String? itemCode;
  final String? barcode;
  final String? category;
  final double tradePrice;
  final double retailPrice;
  final double taxPercent;
  final double discountPercent;
  final int parLevel;
  final String? issueUnit;
  final String? companyName;
  final String? description;
  final int stock;
  final int? isActive;
  final String? createdAt;
  final String? updatedAt;

  // ── Unit conversion fields ───────────────────────────────────
  final bool hasUnitConversion;
  final String? baseUnit;         // e.g. "Tablet" — the smallest unit (Tier 0)

  // Legacy fixed-tier fields (kept for backward compatibility)
  final int? unitsPerStrip;
  final int? stripsPerBox;
  final double? pricePerUnit;
  final double? pricePerStrip;
  final double? pricePerBox;

  // NEW: Dynamic tiers list — each map has:
  //   { 'name': 'Strip', 'quantity': 10, 'price': 50.0, 'containsUnit': 'Tablet' }
  // Stored as JSON text in the DB column `conversionTiersJson`.
  final List<Map<String, dynamic>>? conversionTiers;

  Product({
    this.id,
    required this.itemName,
    this.itemCode,
    this.barcode,
    this.category,
    required this.tradePrice,
    required this.retailPrice,
    this.taxPercent = 0.0,
    this.discountPercent = 0.0,
    this.parLevel = 0,
    this.issueUnit,
    this.companyName,
    this.description,
    this.stock = 0,
    this.isActive = 1,
    this.createdAt,
    this.updatedAt,
    // Unit conversion
    this.hasUnitConversion = false,
    this.baseUnit,
    this.unitsPerStrip,
    this.stripsPerBox,
    this.pricePerUnit,
    this.pricePerStrip,
    this.pricePerBox,
    this.conversionTiers,
  });

  // ============================================================
  //  COMPUTED GETTERS
  // ============================================================

  /// Total base-units in one of the LARGEST tier (legacy helper).
  int get unitsPerBox {
    if (unitsPerStrip == null || stripsPerBox == null) return 1;
    return unitsPerStrip! * stripsPerBox!;
  }

  /// All unit options in order: base unit first, then each tier.
  /// Works with both old fixed-tier and new dynamic-tier products.
  List<String> get availableUnits {
    if (!hasUnitConversion || baseUnit == null) {
      return [issueUnit ?? 'Piece'];
    }

    final units = <String>[baseUnit!];

    if (conversionTiers != null && conversionTiers!.isNotEmpty) {
      // Dynamic tiers
      for (final tier in conversionTiers!) {
        final name = tier['name'] as String?;
        if (name != null && name.isNotEmpty) units.add(name);
      }
    } else {
      // Legacy fallback
      if ((unitsPerStrip ?? 0) > 0) units.add('Strip');
      if ((stripsPerBox ?? 0) > 0) units.add('Box');
    }

    return units;
  }

  // ============================================================
  //  PRICE LOOKUP — supports dynamic tiers
  // ============================================================

  /// Returns the retail/sale price for the given unit name.
  double getPriceByUnit(String unitType) {
    if (!hasUnitConversion) return retailPrice;

    final key = unitType.toLowerCase();

    // Check if it matches the base unit name
    if (baseUnit != null && key == baseUnit!.toLowerCase()) {
      return pricePerUnit ?? retailPrice;
    }

    // Check dynamic tiers first
    if (conversionTiers != null) {
      for (final tier in conversionTiers!) {
        final name = (tier['name'] as String?)?.toLowerCase() ?? '';
        if (name == key) {
          return (tier['price'] as num?)?.toDouble() ?? retailPrice;
        }
      }
    }

    // Legacy fallback
    switch (key) {
      case 'unit':
      case 'tablet':
      case 'capsule':
      case 'piece':
        return pricePerUnit ?? retailPrice;
      case 'strip':
        return pricePerStrip ?? retailPrice;
      case 'box':
        return pricePerBox ?? retailPrice;
    }

    return retailPrice;
  }

  /// Returns the trade price for the given unit name.
  double getTradePriceByUnit(String unitType) {
    if (!hasUnitConversion) return tradePrice;

    // Trade price is stored per base unit; multiply by total base-units in
    // the selected tier to get the trade price for that tier.
    final multiplier = _baseUnitMultiplier(unitType);
    return tradePrice * multiplier;
  }

  // ============================================================
  //  QUANTITY CONVERSION — supports dynamic tiers
  // ============================================================

  /// Converts `qty` units of `unitType` into base-unit count.
  int convertToBaseUnits(int qty, String unitType) {
    return qty * _baseUnitMultiplier(unitType);
  }

  /// How many base units are in ONE unit of [unitType].
  int _baseUnitMultiplier(String unitType) {
    if (!hasUnitConversion) return 1;

    final key = unitType.toLowerCase();

    // Base unit itself
    if (baseUnit != null && key == baseUnit!.toLowerCase()) return 1;
    if (key == 'unit' || key == 'tablet' || key == 'capsule' || key == 'piece') {
      return 1;
    }

    // ── Dynamic tiers: walk the chain and accumulate the multiplier ──
    if (conversionTiers != null && conversionTiers!.isNotEmpty) {
      int multiplier = 1;
      for (final tier in conversionTiers!) {
        final name = (tier['name'] as String?)?.toLowerCase() ?? '';
        final qty2 = (tier['quantity'] as num?)?.toInt() ?? 1;
        multiplier *= qty2;
        if (name == key) return multiplier;
      }
    }

    // ── Legacy fallback (Strip / Box only) ──────────────────────
    switch (key) {
      case 'strip':
        return unitsPerStrip ?? 1;
      case 'box':
        return unitsPerBox;
    }

    return 1;
  }

  // ============================================================
  //  SERIALIZATION
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemName': itemName,
      'itemCode': itemCode,
      'barcode': barcode,
      'category': category,
      'tradePrice': tradePrice,
      'retailPrice': retailPrice,
      'taxPercent': taxPercent,
      'discountPercent': discountPercent,
      'parLevel': parLevel,
      'issueUnit': issueUnit,
      'companyName': companyName,
      'description': description,
      'stock': stock,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      // Unit conversion
      'hasUnitConversion': hasUnitConversion ? 1 : 0,
      'baseUnit': baseUnit,
      'unitsPerStrip': unitsPerStrip,
      'stripsPerBox': stripsPerBox,
      'pricePerUnit': pricePerUnit,
      'pricePerStrip': pricePerStrip,
      'pricePerBox': pricePerBox,
      // Dynamic tiers — serialised as JSON text
      'conversionTiersJson': conversionTiers != null
          ? jsonEncode(conversionTiers)
          : null,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    // Decode dynamic tiers from JSON text
    List<Map<String, dynamic>>? tiers;
    final tiersRaw = map['conversionTiersJson'];
    if (tiersRaw != null && tiersRaw is String && tiersRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(tiersRaw);
        if (decoded is List) {
          tiers = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {
        tiers = null;
      }
    }

    return Product(
      id: map['id'] as int?,
      itemName: map['itemName'] as String? ?? '',
      itemCode: map['itemCode'] as String?,
      barcode: map['barcode'] as String?,
      category: map['category'] as String?,
      tradePrice: (map['tradePrice'] as num?)?.toDouble() ?? 0.0,
      retailPrice: (map['retailPrice'] as num?)?.toDouble() ?? 0.0,
      taxPercent: (map['taxPercent'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (map['discountPercent'] as num?)?.toDouble() ?? 0.0,
      parLevel: map['parLevel'] as int? ?? 0,
      issueUnit: map['issueUnit'] as String?,
      companyName: map['companyName'] as String?,
      description: map['description'] as String?,
      stock: map['stock'] as int? ?? 0,
      isActive: map['isActive'] as int?,
      createdAt: map['createdAt'] as String?,
      updatedAt: map['updatedAt'] as String?,
      // Unit conversion
      hasUnitConversion: map['hasUnitConversion'] == 1,
      baseUnit: map['baseUnit'] as String?,
      unitsPerStrip: map['unitsPerStrip'] as int?,
      stripsPerBox: map['stripsPerBox'] as int?,
      pricePerUnit: (map['pricePerUnit'] as num?)?.toDouble(),
      pricePerStrip: (map['pricePerStrip'] as num?)?.toDouble(),
      pricePerBox: (map['pricePerBox'] as num?)?.toDouble(),
      conversionTiers: tiers,
    );
  }

  Product copyWith({
    int? id,
    String? itemName,
    String? itemCode,
    String? barcode,
    String? category,
    double? tradePrice,
    double? retailPrice,
    double? taxPercent,
    double? discountPercent,
    int? parLevel,
    String? issueUnit,
    String? companyName,
    String? description,
    int? stock,
    int? isActive,
    String? createdAt,
    String? updatedAt,
    bool? hasUnitConversion,
    String? baseUnit,
    int? unitsPerStrip,
    int? stripsPerBox,
    double? pricePerUnit,
    double? pricePerStrip,
    double? pricePerBox,
    List<Map<String, dynamic>>? conversionTiers,
  }) {
    return Product(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      itemCode: itemCode ?? this.itemCode,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      tradePrice: tradePrice ?? this.tradePrice,
      retailPrice: retailPrice ?? this.retailPrice,
      taxPercent: taxPercent ?? this.taxPercent,
      discountPercent: discountPercent ?? this.discountPercent,
      parLevel: parLevel ?? this.parLevel,
      issueUnit: issueUnit ?? this.issueUnit,
      companyName: companyName ?? this.companyName,
      description: description ?? this.description,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hasUnitConversion: hasUnitConversion ?? this.hasUnitConversion,
      baseUnit: baseUnit ?? this.baseUnit,
      unitsPerStrip: unitsPerStrip ?? this.unitsPerStrip,
      stripsPerBox: stripsPerBox ?? this.stripsPerBox,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      pricePerStrip: pricePerStrip ?? this.pricePerStrip,
      pricePerBox: pricePerBox ?? this.pricePerBox,
      conversionTiers: conversionTiers ?? this.conversionTiers,
    );
  }

  @override
  String toString() {
    return 'Product(id: $id, itemName: $itemName, stock: $stock, '
        'hasUnitConversion: $hasUnitConversion, '
        'tiers: ${conversionTiers?.length ?? 0})';
  }
}