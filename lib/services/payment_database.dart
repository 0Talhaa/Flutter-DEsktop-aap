import 'database_helper.dart';

/// Repository for payment-related database operations
class PaymentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Add a new payment to the database
  Future<int> addPayment(Map<String, dynamic> paymentMap) async {
    final db = await _dbHelper.database;
    return await db.insert('payments', paymentMap);
  }

  /// Get payments within a date range
  Future<List<Map<String, dynamic>>> getPaymentsInDateRange(String from, String to) async {
    final db = await _dbHelper.database;
    return await db.query(
      'payments',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [from, '$to 23:59:59'],
      orderBy: 'date DESC',
    );
  }
}