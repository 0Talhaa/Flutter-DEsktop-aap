import 'package:flutter/foundation.dart';
import 'package:medical_app/models/sale_item.dart';
import 'database_helper.dart';

/// Repository for sales-related database operations
class SalesRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Add a new sale to the database
  Future<int> addSale(Map<String, dynamic> saleMap) async {
    final db = await _dbHelper.database;
    return await db.insert('sales', saleMap);
  }

  /// Add sale items and update product stock
  Future<void> addSaleItems(int saleId, List<SaleItem> items) async {
    final db = await _dbHelper.database;

    for (var item in items) {
      var itemMap = item.toMap();
      itemMap['saleId'] = saleId;
      await db.insert('sale_items', itemMap);

      // Decrease stock
      await db.rawUpdate(
        'UPDATE products SET stock = stock - ? WHERE id = ?',
        [item.quantity, item.productId],
      );
    }
  }

  /// Update an existing sale
  Future<int> updateSale(int id, Map<String, dynamic> saleMap) async {
    final db = await _dbHelper.database;
    saleMap.remove('id');
    return await db.update(
      'sales',
      saleMap,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update sale items (restore old stock, then add new items)
  Future<void> updateSaleItems(int saleId, List<SaleItem> items) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // Get old items to restore stock
      final oldItems = await txn.query('sale_items', where: 'saleId = ?', whereArgs: [saleId]);

      // Restore old stock
      for (var oldItem in oldItems) {
        await txn.rawUpdate(
          'UPDATE products SET stock = stock + ? WHERE id = ?',
          [oldItem['quantity'], oldItem['productId']],
        );
      }

      // Delete old items
      await txn.delete('sale_items', where: 'saleId = ?', whereArgs: [saleId]);

      // Insert new items and decrease stock
      for (var item in items) {
        await txn.insert('sale_items', {
          'saleId': saleId,
          'productId': item.productId,
          'productName': item.productName,
          'packing': item.packing,
          'price': item.price,
          'tradePrice': item.tradePrice ?? 0,
          'discount': item.discount ?? 0,
          'salesTax': item.salesTax ?? 0,
          'quantity': item.quantity,
          'lineTotal': item.lineTotal,
        });

        await txn.rawUpdate(
          'UPDATE products SET stock = stock - ? WHERE id = ?',
          [item.quantity, item.productId],
        );
      }
    });
  }

  /// Get sale by invoice ID
  Future<Map<String, dynamic>?> getSaleByInvoiceId(String invoiceId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'sales',
      where: 'invoiceId = ?',
      whereArgs: [invoiceId],
    );

    if (results.isEmpty) return null;
    return results.first;
  }

  /// Get all items for a specific sale
  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    final db = await _dbHelper.database;
    return await db.query(
      'sale_items',
      where: 'saleId = ?',
      whereArgs: [saleId],
    );
  }

  /// Get all sales with their items
  Future<List<Map<String, dynamic>>> getAllSalesWithItems() async {
    final db = await _dbHelper.database;
    final salesResult = await db.query('sales', orderBy: 'dateTime DESC');

    List<Map<String, dynamic>> salesWithItems = [];

    for (var sale in salesResult) {
      final itemsResult = await db.query('sale_items', where: 'saleId = ?', whereArgs: [sale['id']]);
      final items = itemsResult.map((itemMap) => SaleItem.fromMap(itemMap)).toList();

      salesWithItems.add({
        ...sale,
        'items': items,
      });
    }
    return salesWithItems;
  }

  /// Get sales within a date range
  Future<List<Map<String, dynamic>>> getSalesInDateRange(String from, String to) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'sales',
      where: 'dateTime BETWEEN ? AND ?',
      whereArgs: [from, '$to 23:59:59'],
      orderBy: 'dateTime DESC',
    );

    List<Map<String, dynamic>> salesWithItems = [];
    for (var sale in result) {
      final items = await db.query('sale_items', where: 'saleId = ?', whereArgs: [sale['id']]);
      final saleItems = items.map((i) => SaleItem.fromMap(i)).toList();
      salesWithItems.add({
        ...sale,
        'items': saleItems,
      });
    }
    return salesWithItems;
  }

  /// Get customer credit sales within date range
  Future<List<Map<String, dynamic>>> getCustomerCreditSales(
      int customerId, String from, String to) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'sales',
      where: 'customerId = ? AND balance > 0 AND dateTime BETWEEN ? AND ?',
      whereArgs: [customerId, from, '$to 23:59:59'],
      orderBy: 'dateTime ASC',
    );

    List<Map<String, dynamic>> salesWithItems = [];
    for (var sale in result) {
      final items = await db.query('sale_items', where: 'saleId = ?', whereArgs: [sale['id']]);
      final saleItems = items.map((i) => SaleItem.fromMap(i)).toList();
      salesWithItems.add({
        ...sale,
        'items': saleItems,
      });
    }
    return salesWithItems;
  }

  /// Get today's total sales
  Future<double> getTodaySalesTotal() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final result = await db.rawQuery('''
      SELECT IFNULL(SUM(total), 0) as total
      FROM sales
      WHERE dateTime LIKE ?
    ''', ['$today%']);

    final total = result.first['total'] as num;
    return total.toDouble();
  }

  /// Get today's order count
  Future<int> getTodayOrdersCount() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM sales
      WHERE dateTime LIKE '$today%'
    ''');

    return result.first['count'] as int;
  }
}