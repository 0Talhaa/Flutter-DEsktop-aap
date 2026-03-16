import 'package:medical_app/models/supplier.dart';
import 'database_helper.dart';

/// Repository for supplier-related database operations
class SupplierRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Add a new supplier to the database
  Future<int> addSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    return await db.insert('suppliers', supplier.toMap());
  }

  /// Get all suppliers (active only by default)
  Future<List<Supplier>> getAllSuppliers({bool activeOnly = true}) async {
    final db = await _dbHelper.database;

    String? where;
    if (activeOnly) {
      where = 'isActive = 1 OR isActive IS NULL';
    }

    final result = await db.query(
      'suppliers',
      where: where,
      orderBy: 'name ASC',
    );
    return result.map((json) => Supplier.fromMap(json)).toList();
  }

  /// Update an existing supplier
  Future<int> updateSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    return await db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  /// Soft delete a supplier (set isActive to 0)
  Future<int> deleteSupplier(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'suppliers',
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}