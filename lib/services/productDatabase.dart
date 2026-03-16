import 'package:medical_app/models/product.dart';
import 'database_helper.dart';

/// Repository for product-related database operations
class ProductRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Add a new product to the database
  Future<int> addProduct(Product product) async {
    final db = await _dbHelper.database;
    final id = await db.insert('products', product.toMap());
    return id;
  }

  /// Get all products (active only by default)
  Future<List<Product>> getAllProducts({bool activeOnly = true}) async {
    final db = await _dbHelper.database;

    String? where;
    if (activeOnly) {
      where = 'isActive = 1 OR isActive IS NULL';
    }

    final result = await db.query(
      'products',
      where: where,
      orderBy: 'itemName ASC',
    );
    return result.map((json) => Product.fromMap(json)).toList();
  }

  /// Search products by name, code, or barcode
  Future<List<Product>> searchProducts(String query) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'products',
      where: '(itemName LIKE ? OR itemCode LIKE ? OR barcode LIKE ?) AND (isActive = 1 OR isActive IS NULL)',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'itemName ASC',
      limit: 50,
    );
    return result.map((json) => Product.fromMap(json)).toList();
  }

  /// Get product by barcode
  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Product.fromMap(result.first);
  }

  /// Get product by ID
  Future<Map<String, dynamic>?> getProductById(int id) async {
    final db = await _dbHelper.database;
    final result = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  /// Update an existing product
  Future<int> updateProduct(Product product) async {
    final db = await _dbHelper.database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  /// Soft delete a product (set isActive to 0)
  Future<int> deleteProduct(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'products',
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update product stock level
  Future<void> updateProductStock(int id, int newStock) async {
    final db = await _dbHelper.database;
    await db.update(
      'products',
      {'stock': newStock},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get products with low stock (below par level)
  Future<List<Product>> getLowStockProducts({int threshold = 10}) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'products',
      where: 'stock <= parLevel AND (isActive = 1 OR isActive IS NULL)',
      orderBy: 'stock ASC',
    );
    return result.map((json) => Product.fromMap(json)).toList();
  }

  /// Get count of low stock products
  Future<int> getLowStockCount({int threshold = 10}) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM products
      WHERE stock <= parLevel AND (isActive = 1 OR isActive IS NULL)
    ''');
    return result.first['count'] as int;
  }
}