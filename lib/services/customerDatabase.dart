import 'package:medical_app/models/customer.dart';
import 'database_helper.dart';

/// Repository for customer-related database operations
class CustomerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Add a new customer to the database
  Future<int> addCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    return await db.insert('customers', customer.toMap());
  }

  /// Get all customers (active only by default)
  Future<List<Customer>> getAllCustomers({bool activeOnly = true}) async {
    final db = await _dbHelper.database;

    String? where;
    if (activeOnly) {
      where = 'isActive = 1 OR isActive IS NULL';
    }

    final result = await db.query(
      'customers',
      where: where,
      orderBy: 'name ASC',
    );
    return result.map((json) => Customer.fromMap(json)).toList();
  }

  /// Update an existing customer
  Future<int> updateCustomer(Customer customer) async {
    final db = await _dbHelper.database;
    return await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  /// Soft delete a customer (set isActive to 0)
  Future<int> deleteCustomer(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'customers',
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update customer's opening balance
  Future<void> updateCustomerBalance(int customerId, double newBalance) async {
    final db = await _dbHelper.database;
    await db.update(
      'customers',
      {'openingBalance': newBalance},
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  /// Get total count of active customers
  Future<int> getTotalCustomers() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM customers WHERE isActive = 1 OR isActive IS NULL');
    return result.first['count'] as int;
  }
}