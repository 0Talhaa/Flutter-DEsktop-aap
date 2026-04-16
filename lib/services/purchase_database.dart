import 'package:flutter/foundation.dart';
import 'package:medical_app/models/purchase.dart';
import 'database_helper.dart';

/// Repository for purchase-related database operations
class PurchaseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Add a new purchase to the database
  Future<int> addPurchase(Purchase purchase) async {
    final db = await _dbHelper.database;

    debugPrint('🔵 PURCHASE SAVE STARTED');

    final purchaseId = await db.insert('purchases', {
      'invoiceNumber': purchase.invoiceNumber,
      'date': purchase.date.toIso8601String(),
      'supplierName': purchase.supplierName,
      'totalAmount': purchase.totalAmount,
    });

    debugPrint('✅ Purchase entry saved with ID: $purchaseId');

    for (var item in purchase.items) {
      await db.insert('purchase_items', {
        'purchaseId': purchaseId,
        'productId': item.productId,
        'productName': item.productName,
        'packing': item.packing,
        'quantity': item.quantity,
        'tradePrice': item.tradePrice,
        'retailPrice': item.retailPrice ?? 0,
        'discount': item.discount ?? 0,
        'salesTax': item.salesTax ?? 0,
        'lineTotal': item.lineTotal,
        'unitType': item.unitType,
        'baseQuantity': item.baseQuantity,
        'expiryDate': item.expiryDate,
        'batchNumber': item.batchNumber,
      });

      // Update stock
      final stockToAdd = item.baseQuantity ?? item.quantity;
      await db.rawUpdate(
        'UPDATE products SET stock = stock + ? WHERE id = ?',
        [stockToAdd, item.productId],
      );
    }

    debugPrint('🎉 PURCHASE COMPLETED SUCCESSFULLY');
    return purchaseId;
  }

  /// Get purchases within a date range
  Future<List<Map<String, dynamic>>> getPurchasesInDateRange(String from, String to) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'purchases',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [from, '$to 23:59:59'],
      orderBy: 'date DESC',
    );

    List<Map<String, dynamic>> purchasesWithItems = [];
    for (var purchase in result) {
      final items = await db.query('purchase_items', where: 'purchaseId = ?', whereArgs: [purchase['id']]);
      purchasesWithItems.add({
        ...purchase,
        'items': items,
      });
    }
    return purchasesWithItems;
  }

  /// Get today's total purchases
  Future<double> getTodayPurchasesTotal() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final result = await db.rawQuery('''
      SELECT IFNULL(SUM(totalAmount), 0) as total
      FROM purchases
      WHERE date LIKE ?
    ''', ['$today%']);

    final total = result.first['total'] as num;
    return total.toDouble();
  }
}
