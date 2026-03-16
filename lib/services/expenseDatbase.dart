import 'package:flutter/foundation.dart';
import 'database_helper.dart';

/// Repository for expense-related database operations
class ExpenseRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Add a new expense to the database
  Future<int> addExpense(Map<String, dynamic> expenseMap) async {
    final db = await _dbHelper.database;

    // Build a safe map with only existing columns
    final safeMap = <String, dynamic>{
      'date': expenseMap['date'],
      'category': expenseMap['category'],
      'amount': expenseMap['amount'],
      'description': expenseMap['description'] ?? '',
    };

    // Check which optional columns exist
    try {
      final columns = await db.rawQuery('PRAGMA table_info(expenses)');
      final columnNames = columns.map((c) => c['name'] as String).toSet();

      if (columnNames.contains('paymentMethod') && expenseMap['paymentMethod'] != null) {
        safeMap['paymentMethod'] = expenseMap['paymentMethod'];
      }
      if (columnNames.contains('reference') && expenseMap['reference'] != null) {
        safeMap['reference'] = expenseMap['reference'];
      }
    } catch (e) {
      debugPrint('Could not check expense columns: $e');
    }

    final id = await db.insert('expenses', safeMap);
    debugPrint('✅ Expense saved with ID: $id');
    return id;
  }

  /// Get expenses within a date range
  Future<List<Map<String, dynamic>>> getExpensesInDateRange(String from, String to) async {
    final db = await _dbHelper.database;
    return await db.query(
      'expenses',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [from, '$to 23:59:59'],
      orderBy: 'date DESC',
    );
  }

  /// Get all expenses
  Future<List<Map<String, dynamic>>> getAllExpenses() async {
    final db = await _dbHelper.database;
    return await db.query('expenses', orderBy: 'date DESC');
  }

  /// Get today's total expenses
  Future<double> getTodayExpensesTotal() async {
    final db = await _dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final result = await db.rawQuery('''
      SELECT IFNULL(SUM(amount), 0) as total
      FROM expenses
      WHERE date LIKE ?
    ''', ['$today%']);

    final total = result.first['total'] as num;
    return total.toDouble();
  }
}