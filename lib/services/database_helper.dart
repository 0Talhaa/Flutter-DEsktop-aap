// lib/services/database_helper.dart

import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;
import 'package:medical_app/models/brand.dart';
import 'package:medical_app/models/issue_unit.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/customer.dart';
import '../models/product.dart';
import '../models/purchase.dart';
import '../models/sale_item.dart';
import '../models/supplier.dart';
import '../models/product_unit.dart';
import '../models/category.dart';

/// ============================================================================
/// DATABASE HELPER CLASS
/// ============================================================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // ============================================================================
  // DATABASE INITIALIZATION
  // ============================================================================

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('medical_store.db');
    return _database!;
  }

Future<Database> _initDB(String fileName) async {
  final appDataPath = Platform.environment['LOCALAPPDATA'];

  final dbDir = Directory(join(appDataPath!, 'MedicalPOS'));

  // Folder create agar exist na ho
  if (!await dbDir.exists()) {
    await dbDir.create(recursive: true);
  }

  final path = join(dbDir.path, fileName);

  debugPrint('📁 FIXED Database Path: $path');

  return await openDatabase(
    path,
    version: 11,
    onCreate: _createDB,
    onUpgrade: _onUpgrade,
  );
}

  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'medical_store.db');
    return path;
  }

  Future<void> printDatabaseLocation() async {
    final path = await getDatabasePath();
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('📁 DATABASE LOCATION');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('Full Path: $path');
    debugPrint('═══════════════════════════════════════════════════════════');
  }

  // ============================================================================
  // TABLE CREATION
  // ============================================================================

  Future<void> _insertDefaultData(Database db) async {
    final categoryCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM categories'),
    );
    if (categoryCount != null && categoryCount > 0) {
      debugPrint('✅ Default data already exists, skipping insertion');
      return;
    }

    final defaultCategories = [
      'Tablets', 'Capsules', 'Syrups', 'Injections', 'Creams & Ointments',
      'Drops', 'Surgical Items', 'Baby Care', 'Personal Care', 'Other',
    ];

    for (var category in defaultCategories) {
      await db.insert('categories', {
        'name': category,
        'isActive': 1,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }

    final defaultBrands = [
      'GlaxoSmithKline (GSK)', 'Pfizer', 'Getz Pharma', 'Searle Pakistan',
      'Abbott Laboratories', 'Sanofi', 'Martin Dow', 'Hilton Pharma',
      'Sami Pharmaceuticals', 'Bosch Pharmaceuticals', 'High-Q Pharmaceuticals', 'Other',
    ];

    for (var brand in defaultBrands) {
      await db.insert('brands', {
        'name': brand,
        'isActive': 1,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }

    final defaultUnits = [
      {'name': 'Piece', 'abbreviation': 'Pc'},
      {'name': 'Strip', 'abbreviation': 'Str'},
      {'name': 'Box', 'abbreviation': 'Box'},
      {'name': 'Bottle', 'abbreviation': 'Btl'},
      {'name': 'Tube', 'abbreviation': 'Tb'},
      {'name': 'Vial', 'abbreviation': 'Vl'},
      {'name': 'Ampule', 'abbreviation': 'Amp'},
      {'name': 'Pack', 'abbreviation': 'Pk'},
      {'name': 'Tablet', 'abbreviation': 'Tab'},
      {'name': 'Capsule', 'abbreviation': 'Cap'},
    ];

    for (var unit in defaultUnits) {
      await db.insert('issue_units', {
        'name': unit['name'],
        'abbreviation': unit['abbreviation'],
        'isActive': 1,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }

    debugPrint('✅ Default data inserted');
  }

  Future<void> _createDB(Database db, int version) async {
    debugPrint('🔨 Creating database tables...');

    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    // PRODUCTS TABLE - WITH conversionTiersJson column
    await db.execute('''
      CREATE TABLE products (
        id $idType,
        itemName $textType,
        itemCode TEXT,
        barcode TEXT,
        category TEXT,
        tradePrice $realType,
        retailPrice $realType,
        taxPercent REAL DEFAULT 0,
        discountPercent REAL DEFAULT 0,
        parLevel INTEGER DEFAULT 0,
        issueUnit TEXT,
        companyName TEXT,
        description TEXT,
        stock INTEGER DEFAULT 0,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT,
        updatedAt TEXT,
        baseUnit TEXT,
        unitsPerStrip INTEGER,
        stripsPerBox INTEGER,
        pricePerUnit REAL,
        pricePerStrip REAL,
        pricePerBox REAL,
        hasUnitConversion INTEGER DEFAULT 0,
        conversionTiersJson TEXT
      )
    ''');

    // CUSTOMERS TABLE
    await db.execute('''
      CREATE TABLE customers (
        id $idType,
        name $textType,
        phone $textType,
        openingBalance REAL DEFAULT 0,
        address TEXT,
        city TEXT,
        email TEXT,
        cnic TEXT,
        isActive INTEGER DEFAULT 1
      )
    ''');

    // SUPPLIERS TABLE
    await db.execute('''
      CREATE TABLE suppliers (
        id $idType,
        name $textType,
        phone $textType,
        email TEXT,
        company TEXT,
        teleNumber TEXT,
        address TEXT,
        city TEXT,
        openingBalance REAL DEFAULT 0,
        isActive INTEGER DEFAULT 1
      )
    ''');

        // SALES TABLE
        await db.execute('''
          CREATE TABLE sales (
            id $idType,
            invoiceId TEXT,
            dateTime $textType,
            customerId INTEGER,
            customerName TEXT,
            subtotal $realType,
            discount REAL DEFAULT 0,
            tax REAL DEFAULT 0,
            total $realType,
            previousBalance REAL DEFAULT 0,
            totalDue REAL DEFAULT 0,
            amountPaid REAL DEFAULT 0,
            balance REAL DEFAULT 0,
            paymentMethod TEXT,
            status TEXT DEFAULT 'completed',
            notes TEXT
          )
        ''');

    // SALE ITEMS TABLE
    await db.execute('''
      CREATE TABLE sale_items (
        id $idType,
        saleId $integerType,
        productId $integerType,
        productName $textType,
        packing TEXT,
        price $realType,
        tradePrice REAL DEFAULT 0,
        discount REAL DEFAULT 0,
        salesTax REAL DEFAULT 0,
        quantity $integerType,
        lineTotal $realType,
        unitType TEXT,
        baseQuantity INTEGER,
        FOREIGN KEY (saleId) REFERENCES sales(id)
      )
    ''');

    // PURCHASES TABLE
    await db.execute('''
      CREATE TABLE purchases (
        id $idType,
        invoiceNumber $textType,
        date $textType,
        supplierId INTEGER,
        supplierName $textType,
        totalAmount $realType,
        amountPaid REAL DEFAULT 0,
        balance REAL DEFAULT 0,
        status TEXT DEFAULT 'completed',
        notes TEXT,
        createdAt TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // PURCHASE ITEMS TABLE
    await db.execute('''
      CREATE TABLE purchase_items (
        id $idType,
        purchaseId $integerType,
        productId $integerType,
        productName $textType,
        packing TEXT,
        quantity $integerType,
        tradePrice $realType,
        discount REAL DEFAULT 0,
        salesTax REAL DEFAULT 0,
        lineTotal $realType,
        expiryDate TEXT,
        batchNumber TEXT,
        unitType TEXT,
        baseQuantity INTEGER,
        FOREIGN KEY (purchaseId) REFERENCES purchases(id)
      )
    ''');

    // SUPPLIER PAYMENTS TABLE
    await db.execute('''
      CREATE TABLE supplier_payments (
        id $idType,
        supplierId INTEGER NOT NULL,
        supplierName TEXT NOT NULL,
        date TEXT NOT NULL,
        amount REAL NOT NULL,
        paymentMethod TEXT DEFAULT 'Cash',
        reference TEXT,
        notes TEXT,
        createdAt TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (supplierId) REFERENCES suppliers(id)
      )
    ''');

    // CUSTOMER PAYMENTS TABLE
    await db.execute('''
      CREATE TABLE customer_payments (
        id $idType,
        customerId INTEGER NOT NULL,
        customerName TEXT NOT NULL,
        date TEXT NOT NULL,
        amount REAL NOT NULL,
        paymentMethod TEXT DEFAULT 'Cash',
        reference TEXT,
        notes TEXT,
        createdAt TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customerId) REFERENCES customers(id)
      )
    ''');

    // EXPENSES TABLE
    await db.execute('''
      CREATE TABLE expenses (
        id $idType,
        date $textType,
        category $textType,
        amount $realType,
        description TEXT,
        paymentMethod TEXT,
        reference TEXT
      )
    ''');

    // PAYMENTS TABLE
    await db.execute('''
      CREATE TABLE payments (
        id $idType,
        type TEXT NOT NULL,
        date $textType,
        partyId INTEGER,
        partyName TEXT,
        amount $realType,
        paymentMethod TEXT,
        reference TEXT,
        notes TEXT
      )
    ''');

    // DAILY CLOSING TABLE
    await db.execute('''
      CREATE TABLE daily_closing (
        id $idType,
        date TEXT UNIQUE,
        openingCash REAL DEFAULT 0,
        totalSales REAL DEFAULT 0,
        totalPurchases REAL DEFAULT 0,
        totalExpenses REAL DEFAULT 0,
        totalReceipts REAL DEFAULT 0,
        totalPayments REAL DEFAULT 0,
        closingCash REAL DEFAULT 0,
        notes TEXT,
        closedBy TEXT
      )
    ''');

    // SETTINGS TABLE
    await db.execute('''
      CREATE TABLE settings (
        id $idType,
        key TEXT UNIQUE,
        value TEXT
      )
    ''');

    // CATEGORIES TABLE
    await db.execute('''
      CREATE TABLE categories (
        id $idType,
        name $textType,
        description TEXT,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT
      )
    ''');

    // BRANDS TABLE
    await db.execute('''
      CREATE TABLE brands (
        id $idType,
        name $textType,
        description TEXT,
        contactPerson TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT
      )
    ''');

    // ISSUE UNITS TABLE
    await db.execute('''
      CREATE TABLE issue_units (
        id $idType,
        name $textType,
        abbreviation TEXT,
        description TEXT,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT
      )
    ''');

    await _insertDefaultData(db);

    debugPrint('✅ All database tables created successfully');
  }

  // ============================================================================
  // DATABASE UPGRADE/MIGRATION
  // ============================================================================

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('🔄 Upgrading database from v$oldVersion to v$newVersion');

    if (oldVersion < 5) {
      await _createSuppliersTableIfMissing(db);
    }

    await _addMissingColumns(db);

    if (oldVersion < 8) {
      await _createPaymentTablesIfMissing(db);
    }

    if (oldVersion < 9) {
      await _createCategoriesTableIfMissing(db);
      await _createBrandsTableIfMissing(db);
      await _createIssueUnitsTableIfMissing(db);
      await _insertDefaultData(db);
    }

    await _createMissingTables(db);

    debugPrint('✅ Database upgrade completed to v$newVersion');
  }

  Future<void> _createSuppliersTableIfMissing(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS suppliers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT NOT NULL,
          email TEXT,
          company TEXT,
          teleNumber TEXT,
          address TEXT,
          city TEXT,
          openingBalance REAL DEFAULT 0,
          isActive INTEGER DEFAULT 1
        )
      ''');
      debugPrint('✅ Suppliers table created/verified');
    } catch (e) {
      debugPrint('⚠️ Suppliers table might already exist: $e');
    }
  }

  Future<void> _createCategoriesTableIfMissing(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT,
          isActive INTEGER DEFAULT 1,
          createdAt TEXT
        )
      ''');
      debugPrint('✅ Categories table created/verified');
    } catch (e) {
      debugPrint('⚠️ Categories table might already exist: $e');
    }
  }

  Future<void> _createBrandsTableIfMissing(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS brands (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT,
          contactPerson TEXT,
          phone TEXT,
          email TEXT,
          address TEXT,
          isActive INTEGER DEFAULT 1,
          createdAt TEXT
        )
      ''');
      debugPrint('✅ Brands table created/verified');
    } catch (e) {
      debugPrint('⚠️ Brands table might already exist: $e');
    }
  }

  Future<void> _createIssueUnitsTableIfMissing(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS issue_units (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          abbreviation TEXT,
          description TEXT,
          isActive INTEGER DEFAULT 1,
          createdAt TEXT
        )
      ''');
      debugPrint('✅ Issue Units table created/verified');
    } catch (e) {
      debugPrint('⚠️ Issue Units table might already exist: $e');
    }
  }

  Future<void> _addMissingColumns(Database db) async {
    // Products table columns
    await _safeAddColumn(db, 'products', 'barcode', 'TEXT');
    await _safeAddColumn(db, 'products', 'category', 'TEXT');
    await _safeAddColumn(db, 'products', 'description', 'TEXT');
    await _safeAddColumn(db, 'products', 'isActive', 'INTEGER DEFAULT 1');
    await _safeAddColumn(db, 'products', 'createdAt', 'TEXT');
    await _safeAddColumn(db, 'products', 'updatedAt', 'TEXT');

    // Unit conversion columns for products
    await _safeAddColumn(db, 'products', 'baseUnit', 'TEXT');
    await _safeAddColumn(db, 'products', 'unitsPerStrip', 'INTEGER');
    await _safeAddColumn(db, 'products', 'stripsPerBox', 'INTEGER');
    await _safeAddColumn(db, 'products', 'pricePerUnit', 'REAL');
    await _safeAddColumn(db, 'products', 'pricePerStrip', 'REAL');
    await _safeAddColumn(db, 'products', 'pricePerBox', 'REAL');
    await _safeAddColumn(db, 'products', 'hasUnitConversion', 'INTEGER DEFAULT 0');
    
    // ★★★ NEW: Add conversionTiersJson column for dynamic tiers ★★★
    await _safeAddColumn(db, 'products', 'conversionTiersJson', 'TEXT');

    // Customers table columns
    await _safeAddColumn(db, 'customers', 'email', 'TEXT');
    await _safeAddColumn(db, 'customers', 'cnic', 'TEXT');
    await _safeAddColumn(db, 'customers', 'isActive', 'INTEGER DEFAULT 1');

    // Suppliers table columns
    await _safeAddColumn(db, 'suppliers', 'address', 'TEXT');
    await _safeAddColumn(db, 'suppliers', 'city', 'TEXT');
    await _safeAddColumn(db, 'suppliers', 'isActive', 'INTEGER DEFAULT 1');

    // Sales table columns
    await _safeAddColumn(db, 'sales', 'status', 'TEXT DEFAULT "completed"');
    await _safeAddColumn(db, 'sales', 'notes', 'TEXT');
    await _safeAddColumn(db, 'sales', 'previousBalance', 'REAL DEFAULT 0');  // ADD THIS
    await _safeAddColumn(db, 'sales', 'totalDue', 'REAL DEFAULT 0');         // ADD THIS
    // Sale items columns
    await _safeAddColumn(db, 'sale_items', 'unitType', 'TEXT');
    await _safeAddColumn(db, 'sale_items', 'baseQuantity', 'INTEGER');

    // Purchases table columns
    await _safeAddColumn(db, 'purchases', 'supplierId', 'INTEGER');
    await _safeAddColumn(db, 'purchases', 'amountPaid', 'REAL DEFAULT 0');
    await _safeAddColumn(db, 'purchases', 'balance', 'REAL DEFAULT 0');
    await _safeAddColumn(db, 'purchases', 'status', 'TEXT DEFAULT "completed"');
    await _safeAddColumn(db, 'purchases', 'notes', 'TEXT');
    await _safeAddColumn(db, 'purchases', 'createdAt', 'TEXT');

    // Purchase items columns
    await _safeAddColumn(db, 'purchase_items', 'packing', 'TEXT');
    await _safeAddColumn(db, 'purchase_items', 'discount', 'REAL DEFAULT 0');
    await _safeAddColumn(db, 'purchase_items', 'salesTax', 'REAL DEFAULT 0');
    await _safeAddColumn(db, 'purchase_items', 'expiryDate', 'TEXT');
    await _safeAddColumn(db, 'purchase_items', 'batchNumber', 'TEXT');
    await _safeAddColumn(db, 'purchase_items', 'unitType', 'TEXT');
    await _safeAddColumn(db, 'purchase_items', 'baseQuantity', 'INTEGER');

    // Expenses columns
    await _safeAddColumn(db, 'expenses', 'paymentMethod', 'TEXT');
    await _safeAddColumn(db, 'expenses', 'reference', 'TEXT');
  }

  Future<void> _createPaymentTablesIfMissing(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS supplier_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          supplierId INTEGER NOT NULL,
          supplierName TEXT NOT NULL,
          date TEXT NOT NULL,
          amount REAL NOT NULL,
          paymentMethod TEXT DEFAULT 'Cash',
          reference TEXT,
          notes TEXT,
          createdAt TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS customer_payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customerId INTEGER NOT NULL,
          customerName TEXT NOT NULL,
          date TEXT NOT NULL,
          amount REAL NOT NULL,
          paymentMethod TEXT DEFAULT 'Cash',
          reference TEXT,
          notes TEXT,
          createdAt TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      debugPrint('✅ Payment tables created/verified');
    } catch (e) {
      debugPrint('⚠️ Payment tables might already exist: $e');
    }
  }

  Future<void> _createMissingTables(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          date TEXT NOT NULL,
          partyId INTEGER,
          partyName TEXT,
          amount REAL NOT NULL,
          paymentMethod TEXT,
          reference TEXT,
          notes TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_closing (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT UNIQUE,
          openingCash REAL DEFAULT 0,
          totalSales REAL DEFAULT 0,
          totalPurchases REAL DEFAULT 0,
          totalExpenses REAL DEFAULT 0,
          totalReceipts REAL DEFAULT 0,
          totalPayments REAL DEFAULT 0,
          closingCash REAL DEFAULT 0,
          notes TEXT,
          closedBy TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          key TEXT UNIQUE,
          value TEXT
        )
      ''');

      debugPrint('✅ All missing tables created');
    } catch (e) {
      debugPrint('⚠️ Some tables might already exist: $e');
    }
  }

  Future<void> _safeAddColumn(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    try {
      final result = await db.rawQuery('PRAGMA table_info($table)');
      final columnExists = result.any((row) => row['name'] == column);

      if (!columnExists) {
        await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
        debugPrint('✅ Added column $column to $table');
      }
    } catch (e) {
      debugPrint('❌ Error adding column $column to $table: $e');
    }
  }

  Future<void> runManualMigration() async {
    final db = await instance.database;
    debugPrint('🔄 Running manual migration...');
    await _addMissingColumns(db);
    await _createPaymentTablesIfMissing(db);
    await _createCategoriesTableIfMissing(db);
    await _createBrandsTableIfMissing(db);
    await _createIssueUnitsTableIfMissing(db);
    await _insertDefaultData(db);
    debugPrint('✅ Manual migration completed');
  }

  // ============================================================================
  // PRODUCTS CRUD OPERATIONS
  // ============================================================================

  Future<int> addProduct(Product product) async {
    final db = await instance.database;
    final id = await db.insert('products', product.toMap());
    debugPrint('✅ Product added with ID: $id');
    return id;
  }

  Future<List<Product>> getAllProducts({bool activeOnly = true}) async {
    final db = await instance.database;

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

  Future<List<Product>> searchProducts(String query) async {
    final db = await instance.database;
    final result = await db.query(
      'products',
      where:
          '(itemName LIKE ? OR itemCode LIKE ? OR barcode LIKE ?) AND (isActive = 1 OR isActive IS NULL)',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'itemName ASC',
      limit: 50,
    );
    return result.map((json) => Product.fromMap(json)).toList();
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await instance.database;
    final result = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Product.fromMap(result.first);
  }

  Future<Product?> getProductById(int id) async {
    final db = await instance.database;
    final result = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Product.fromMap(result.first);
  }

  Future<Map<String, dynamic>?> getProductMapById(int id) async {
    final db = await instance.database;
    final result = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateProduct(Product product) async {
    final db = await instance.database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    return await db.update(
      'products',
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateProductStock(int id, int newStock) async {
    final db = await instance.database;
    await db.update(
      'products',
      {'stock': newStock},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Product>> getLowStockProducts({int threshold = 10}) async {
    final db = await instance.database;
    final result = await db.query(
      'products',
      where: 'stock <= parLevel AND (isActive = 1 OR isActive IS NULL)',
      orderBy: 'stock ASC',
    );
    return result.map((json) => Product.fromMap(json)).toList();
  }

  Future<List<Product>> getProductsWithUnitConversion() async {
    final db = await instance.database;
    final result = await db.query(
      'products',
      where: 'hasUnitConversion = 1 AND (isActive = 1 OR isActive IS NULL)',
      orderBy: 'itemName ASC',
    );
    return result.map((json) => Product.fromMap(json)).toList();
  }

  // ============================================================================
  // CUSTOMERS CRUD OPERATIONS
  // ============================================================================

  Future<int> addCustomer(Customer customer) async {
    final db = await instance.database;
    return await db.insert('customers', customer.toMap());
  }

  Future<List<Customer>> getAllCustomers({bool activeOnly = true}) async {
    final db = await instance.database;

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

  Future<Customer?> getCustomerById(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Customer.fromMap(result.first);
  }

  Future<int> updateCustomer(Customer customer) async {
    final db = await instance.database;
    return await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> deleteCustomer(int id) async {
    final db = await instance.database;
    return await db.update(
      'customers',
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateCustomerBalance(int customerId, double newBalance) async {
    final db = await instance.database;
    await db.update(
      'customers',
      {'openingBalance': newBalance},
      where: 'id = ?',
      whereArgs: [customerId],
    );
    debugPrint('✅ Customer $customerId balance updated to $newBalance');
  }

  // ============================================================================
  // SUPPLIERS CRUD OPERATIONS
  // ============================================================================

  Future<int> addSupplier(Supplier supplier) async {
    final db = await instance.database;
    return await db.insert('suppliers', supplier.toMap());
  }

  Future<List<Supplier>> getAllSuppliers({bool activeOnly = true}) async {
    final db = await instance.database;

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

  Future<Supplier?> getSupplierById(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Supplier.fromMap(result.first);
  }

  Future<Supplier?> getSupplierByName(String name) async {
    final db = await instance.database;
    final result = await db.query(
      'suppliers',
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Supplier.fromMap(result.first);
  }

  Future<int> updateSupplier(Supplier supplier) async {
    final db = await instance.database;
    final result = await db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
    debugPrint(
      '✅ Supplier ${supplier.name} updated. Balance: ${supplier.openingBalance}',
    );
    return result;
  }

  Future<int> deleteSupplier(int id) async {
    final db = await instance.database;
    return await db.update(
      'suppliers',
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateSupplierBalance(int supplierId, double newBalance) async {
    final db = await instance.database;
    await db.update(
      'suppliers',
      {'openingBalance': newBalance},
      where: 'id = ?',
      whereArgs: [supplierId],
    );
    debugPrint('✅ Supplier $supplierId balance updated to $newBalance');
  }

  // ============================================================================
  // SALES OPERATIONS
  // ============================================================================

  Future<int> addSale(Map<String, dynamic> saleMap) async {
    final db = await instance.database;
    return await db.insert('sales', saleMap);
  }

  Future<void> addSaleItems(int saleId, List<SaleItem> items) async {
    final db = await instance.database;

    for (var item in items) {
      var itemMap = item.toMap();
      itemMap['saleId'] = saleId;
      await db.insert('sale_items', itemMap);

      int stockToDeduct = item.quantity;
      if (item.unitType != null && item.baseQuantity != null) {
        stockToDeduct = item.baseQuantity!;
      }

      await db.rawUpdate('UPDATE products SET stock = stock - ? WHERE id = ?', [
        stockToDeduct,
        item.productId,
      ]);
    }
  }

  Future<int> updateSale(int id, Map<String, dynamic> saleMap) async {
    final db = await database;
    saleMap.remove('id');
    return await db.update('sales', saleMap, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateSaleItems(int saleId, List<SaleItem> items) async {
    final db = await database;

    await db.transaction((txn) async {
      final oldItems = await txn.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [saleId],
      );

      for (var oldItem in oldItems) {
        int stockToRestore = oldItem['quantity'] as int;
        if (oldItem['baseQuantity'] != null) {
          stockToRestore = oldItem['baseQuantity'] as int;
        }
        await txn.rawUpdate(
          'UPDATE products SET stock = stock + ? WHERE id = ?',
          [stockToRestore, oldItem['productId']],
        );
      }

      await txn.delete('sale_items', where: 'saleId = ?', whereArgs: [saleId]);

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
          'unitType': item.unitType,
          'baseQuantity': item.baseQuantity,
        });

        int stockToDeduct = item.quantity;
        if (item.baseQuantity != null) {
          stockToDeduct = item.baseQuantity!;
        }

        await txn.rawUpdate(
          'UPDATE products SET stock = stock - ? WHERE id = ?',
          [stockToDeduct, item.productId],
        );
      }
    });
  }

  Future<Map<String, dynamic>?> getSaleByInvoiceId(String invoiceId) async {
    final db = await database;
    final results = await db.query(
      'sales',
      where: 'invoiceId = ?',
      whereArgs: [invoiceId],
    );

    if (results.isEmpty) return null;
    return results.first;
  }

  Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    final db = await database;
    return await db.query(
      'sale_items',
      where: 'saleId = ?',
      whereArgs: [saleId],
    );
  }

  Future<List<Map<String, dynamic>>> getAllSalesWithItems() async {
    final db = await instance.database;
    final salesResult = await db.query('sales', orderBy: 'dateTime DESC');

    List<Map<String, dynamic>> salesWithItems = [];

    for (var sale in salesResult) {
      final itemsResult = await db.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [sale['id']],
      );
      final items = itemsResult
          .map((itemMap) => SaleItem.fromMap(itemMap))
          .toList();

      salesWithItems.add({...sale, 'items': items});
    }
    return salesWithItems;
  }

  Future<List<Map<String, dynamic>>> getSalesInDateRange(
    String from,
    String to,
  ) async {
    final db = await instance.database;
    final result = await db.query(
      'sales',
      where: 'dateTime BETWEEN ? AND ?',
      whereArgs: [from, '$to 23:59:59'],
      orderBy: 'dateTime DESC',
    );

    List<Map<String, dynamic>> salesWithItems = [];
    for (var sale in result) {
      final items = await db.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [sale['id']],
      );
      final saleItems = items.map((i) => SaleItem.fromMap(i)).toList();
      salesWithItems.add({...sale, 'items': saleItems});
    }
    return salesWithItems;
  }

  Future<List<Map<String, dynamic>>> getCustomerCreditSales(
    int customerId,
    String from,
    String to,
  ) async {
    final db = await instance.database;
    final result = await db.query(
      'sales',
      where: 'customerId = ? AND balance > 0 AND dateTime BETWEEN ? AND ?',
      whereArgs: [customerId, from, '$to 23:59:59'],
      orderBy: 'dateTime ASC',
    );

    List<Map<String, dynamic>> salesWithItems = [];
    for (var sale in result) {
      final items = await db.query(
        'sale_items',
        where: 'saleId = ?',
        whereArgs: [sale['id']],
      );
      final saleItems = items.map((i) => SaleItem.fromMap(i)).toList();
      salesWithItems.add({...sale, 'items': saleItems});
    }
    return salesWithItems;
  }

  // ============================================================================
  // PURCHASES OPERATIONS
  // ============================================================================

  Future<int> addPurchase(Purchase purchase) async {
    final db = await instance.database;

    final double amountPaidValue = purchase.amountPaid;
    final double totalAmount = purchase.totalAmount;
    final double balance = totalAmount - amountPaidValue;

    final purchaseId = await db.insert('purchases', {
      'invoiceNumber': purchase.invoiceNumber,
      'date': purchase.date.toIso8601String(),
      'supplierName': purchase.supplierName,
      'totalAmount': totalAmount,
      'amountPaid': amountPaidValue,
      'balance': balance,
      'status': balance <= 0 ? 'paid' : 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    });

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

      final stockToAdd = item.baseQuantity ?? item.quantity;
      await db.rawUpdate('UPDATE products SET stock = stock + ? WHERE id = ?', [
        stockToAdd,
        item.productId,
      ]);
    }

    return purchaseId;
  }

 Future<int> addPurchaseWithDetails({
  required String invoiceNumber,
  required DateTime date,
  required int supplierId,
  required String supplierName,
  required double totalAmount,
  required double amountPaid,
  required List<PurchaseItem> items,
  String? notes,
}) async {
  final db = await instance.database;
  
  try {
    // ✅ Use transaction for atomic operation
    return await db.transaction((txn) async {
      final balance = totalAmount - amountPaid;

      final purchaseId = await txn.insert('purchases', {
        'invoiceNumber': invoiceNumber,
        'date': date.toIso8601String(),
        'supplierId': supplierId,
        'supplierName': supplierName,
        'totalAmount': totalAmount,
        'amountPaid': amountPaid,
        'balance': balance,
        'status': balance <= 0 ? 'paid' : 'pending',
        'notes': notes,
        'createdAt': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Purchase entry saved with ID: $purchaseId');

      for (var item in items) {
        await txn.insert('purchase_items', {
          'purchaseId': purchaseId,
          'productId': item.productId,
          'productName': item.productName,
          'packing': item.packing,
          'quantity': item.quantity,
          'tradePrice': item.tradePrice,
          'discount': item.discount ?? 0,
          'salesTax': item.salesTax ?? 0,
          'lineTotal': item.lineTotal,
          'unitType': item.unitType,
          'baseQuantity': item.baseQuantity ?? item.quantity, // ✅ Fallback
        });

        final stockToAdd = item.baseQuantity ?? item.quantity;
        
        debugPrint('📦 Adding stock: $stockToAdd to product ${item.productId}');
        
        // ✅ Update stock
        final updateCount = await txn.rawUpdate(
          'UPDATE products SET stock = stock + ? WHERE id = ?',
          [stockToAdd, item.productId],
        );
        
        if (updateCount == 0) {
          debugPrint('⚠️ Warning: Product ${item.productId} not found');
        } else {
          debugPrint('✅ Stock updated for product ${item.productId}');
        }
      }

      debugPrint('🎉 Purchase transaction completed successfully');
      return purchaseId;
    });
  } catch (e) {
    debugPrint('❌ Purchase transaction failed: $e');
    rethrow; // ✅ Propagate error to UI
  }
}

  Future<List<Map<String, dynamic>>> getPurchasesInDateRange(
    String from,
    String to,
  ) async {
    final db = await instance.database;
    final result = await db.query(
      'purchases',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [from, '$to 23:59:59'],
      orderBy: 'date DESC',
    );

    List<Map<String, dynamic>> purchasesWithItems = [];
    for (var purchase in result) {
      final items = await db.query(
        'purchase_items',
        where: 'purchaseId = ?',
        whereArgs: [purchase['id']],
      );
      purchasesWithItems.add({...purchase, 'items': items});
    }
    return purchasesWithItems;
  }

  Future<List<Map<String, dynamic>>> getSupplierPurchases({
    required String supplierName,
    required String fromDate,
    required String toDate,
  }) async {
    final db = await instance.database;
    final result = await db.query(
      'purchases',
      where: 'supplierName = ? AND date BETWEEN ? AND ?',
      whereArgs: [supplierName, fromDate, '$toDate 23:59:59'],
      orderBy: 'date ASC',
    );

    return result;
  }

  Future<List<Map<String, dynamic>>> getSupplierLedgerData({
    required int supplierId,
    required String supplierName,
    required String fromDate,
    required String toDate,
  }) async {
    final db = await instance.database;

    final purchases = await db.query(
      'purchases',
      where: 'supplierName = ? AND date BETWEEN ? AND ?',
      whereArgs: [supplierName, fromDate, '$toDate 23:59:59'],
      orderBy: 'date ASC',
    );

    return purchases;
  }

  // ============================================================================
  // SUPPLIER BALANCE CALCULATIONS
  // ============================================================================

  Future<double> getSupplierBalanceAtDate({
    required String supplierName,
    required double initialOpeningBalance,
    required String beforeDate,
  }) async {
    final db = await instance.database;

    final purchaseResult = await db.rawQuery(
      '''
      SELECT 
        COALESCE(SUM(totalAmount), 0) as totalPurchased,
        COALESCE(SUM(amountPaid), 0) as totalPaidWithPurchase
      FROM purchases 
      WHERE supplierName = ? AND date < ?
    ''',
      [supplierName, beforeDate],
    );

    double totalPurchased = 0.0;
    double totalPaidWithPurchase = 0.0;

    if (purchaseResult.isNotEmpty) {
      totalPurchased =
          (purchaseResult.first['totalPurchased'] as num?)?.toDouble() ?? 0.0;
      totalPaidWithPurchase =
          (purchaseResult.first['totalPaidWithPurchase'] as num?)?.toDouble() ??
          0.0;
    }

    double separatePayments = 0.0;
    try {
      final paymentResult = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(amount), 0) as totalPayments
        FROM supplier_payments 
        WHERE supplierName = ? AND date < ?
      ''',
        [supplierName, beforeDate],
      );

      if (paymentResult.isNotEmpty) {
        separatePayments =
            (paymentResult.first['totalPayments'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      debugPrint('⚠️ supplier_payments table might not exist: $e');
    }

    double balanceAtDate =
        initialOpeningBalance +
        totalPurchased -
        totalPaidWithPurchase -
        separatePayments;

    return balanceAtDate;
  }

  Future<double> getCurrentSupplierBalance(String supplierName) async {
    final db = await instance.database;

    final supplierResult = await db.query(
      'suppliers',
      where: 'name = ?',
      whereArgs: [supplierName],
      limit: 1,
    );

    if (supplierResult.isEmpty) return 0.0;

    double openingBalance =
        (supplierResult.first['openingBalance'] as num?)?.toDouble() ?? 0.0;

    final purchaseResult = await db.rawQuery(
      '''
      SELECT 
        COALESCE(SUM(totalAmount), 0) as totalPurchased,
        COALESCE(SUM(amountPaid), 0) as totalPaid
      FROM purchases 
      WHERE supplierName = ?
    ''',
      [supplierName],
    );

    double totalPurchased = 0.0;
    double totalPaid = 0.0;

    if (purchaseResult.isNotEmpty) {
      totalPurchased =
          (purchaseResult.first['totalPurchased'] as num?)?.toDouble() ?? 0.0;
      totalPaid =
          (purchaseResult.first['totalPaid'] as num?)?.toDouble() ?? 0.0;
    }

    double separatePayments = 0.0;
    try {
      final paymentResult = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(amount), 0) as totalPayments
        FROM supplier_payments 
        WHERE supplierName = ?
      ''',
        [supplierName],
      );

      if (paymentResult.isNotEmpty) {
        separatePayments =
            (paymentResult.first['totalPayments'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      debugPrint('⚠️ supplier_payments table might not exist: $e');
    }

    return openingBalance + totalPurchased - totalPaid - separatePayments;
  }

  // ============================================================================
  // CUSTOMER BALANCE CALCULATIONS
  // ============================================================================

  Future<double> getCustomerBalanceAtDate({
    required String customerName,
    required double initialOpeningBalance,
    required String beforeDate,
  }) async {
    final db = await instance.database;

    final salesResult = await db.rawQuery(
      '''
      SELECT 
        COALESCE(SUM(total), 0) as totalSales,
        COALESCE(SUM(amountPaid), 0) as totalPaidWithSale
      FROM sales 
      WHERE customerName = ? AND dateTime < ?
    ''',
      [customerName, beforeDate],
    );

    double totalSales = 0.0;
    double totalPaidWithSale = 0.0;

    if (salesResult.isNotEmpty) {
      totalSales = (salesResult.first['totalSales'] as num?)?.toDouble() ?? 0.0;
      totalPaidWithSale =
          (salesResult.first['totalPaidWithSale'] as num?)?.toDouble() ?? 0.0;
    }

    double separatePayments = 0.0;
    try {
      final paymentResult = await db.rawQuery(
        '''
        SELECT COALESCE(SUM(amount), 0) as totalPayments
        FROM customer_payments 
        WHERE customerName = ? AND date < ?
      ''',
        [customerName, beforeDate],
      );

      if (paymentResult.isNotEmpty) {
        separatePayments =
            (paymentResult.first['totalPayments'] as num?)?.toDouble() ?? 0.0;
      }
    } catch (e) {
      debugPrint('⚠️ customer_payments table might not exist: $e');
    }

    return initialOpeningBalance +
        totalSales -
        totalPaidWithSale -
        separatePayments;
  }

  // ============================================================================
  // SUPPLIER PAYMENTS
  // ============================================================================

  Future<int> addSupplierPayment({
    required int supplierId,
    required String supplierName,
    required double amount,
    required DateTime date,
    String paymentMethod = 'Cash',
    String? reference,
    String? notes,
  }) async {
    final db = await instance.database;

    final paymentId = await db.insert('supplier_payments', {
      'supplierId': supplierId,
      'supplierName': supplierName,
      'date': date.toIso8601String(),
      'amount': amount,
      'paymentMethod': paymentMethod,
      'reference': reference,
      'notes': notes,
      'createdAt': DateTime.now().toIso8601String(),
    });

    debugPrint('✅ Supplier payment added: $amount to $supplierName');
    return paymentId;
  }

  Future<List<Map<String, dynamic>>> getSupplierPaymentsInRange({
    required String supplierName,
    required String fromDate,
    required String toDate,
  }) async {
    final db = await instance.database;

    try {
      return await db.query(
        'supplier_payments',
        where: 'supplierName = ? AND date BETWEEN ? AND ?',
        whereArgs: [supplierName, fromDate, '$toDate 23:59:59'],
        orderBy: 'date ASC',
      );
    } catch (e) {
      debugPrint('❌ Error getting supplier payments: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllSupplierPayments(
    int supplierId,
  ) async {
    final db = await instance.database;

    try {
      return await db.query(
        'supplier_payments',
        where: 'supplierId = ?',
        whereArgs: [supplierId],
        orderBy: 'date DESC',
      );
    } catch (e) {
      debugPrint('❌ Error getting supplier payments: $e');
      return [];
    }
  }

  // ============================================================================
  // CUSTOMER PAYMENTS
  // ============================================================================

  Future<int> addCustomerPayment({
    required int customerId,
    required String customerName,
    required double amount,
    required DateTime date,
    String paymentMethod = 'Cash',
    String? reference,
    String? notes,
  }) async {
    final db = await instance.database;

    final paymentId = await db.insert('customer_payments', {
      'customerId': customerId,
      'customerName': customerName,
      'date': date.toIso8601String(),
      'amount': amount,
      'paymentMethod': paymentMethod,
      'reference': reference,
      'notes': notes,
      'createdAt': DateTime.now().toIso8601String(),
    });

    debugPrint('✅ Customer payment received: $amount from $customerName');
    return paymentId;
  }

  Future<List<Map<String, dynamic>>> getCustomerPaymentsInRange({
    required String customerName,
    required String fromDate,
    required String toDate,
  }) async {
    final db = await instance.database;

    try {
      return await db.query(
        'customer_payments',
        where: 'customerName = ? AND date BETWEEN ? AND ?',
        whereArgs: [customerName, fromDate, '$toDate 23:59:59'],
        orderBy: 'date ASC',
      );
    } catch (e) {
      debugPrint('❌ Error getting customer payments: $e');
      return [];
    }
  }

  // ============================================================================
  // EXPENSES OPERATIONS
  // ============================================================================

  Future<int> addExpense(Map<String, dynamic> expenseMap) async {
    final db = await instance.database;

    final safeMap = <String, dynamic>{
      'date': expenseMap['date'],
      'category': expenseMap['category'],
      'amount': expenseMap['amount'],
      'description': expenseMap['description'] ?? '',
    };

    try {
      final columns = await db.rawQuery('PRAGMA table_info(expenses)');
      final columnNames = columns.map((c) => c['name'] as String).toSet();

      if (columnNames.contains('paymentMethod') &&
          expenseMap['paymentMethod'] != null) {
        safeMap['paymentMethod'] = expenseMap['paymentMethod'];
      }
      if (columnNames.contains('reference') &&
          expenseMap['reference'] != null) {
        safeMap['reference'] = expenseMap['reference'];
      }
    } catch (e) {
      debugPrint('⚠️ Could not check expense columns: $e');
    }

    final id = await db.insert('expenses', safeMap);
    debugPrint('✅ Expense saved with ID: $id');
    return id;
  }

  Future<List<Map<String, dynamic>>> getExpensesInDateRange(
    String from,
    String to,
  ) async {
    final db = await instance.database;
    return await db.query(
      'expenses',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [from, '$to 23:59:59'],
      orderBy: 'date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllExpenses() async {
    final db = await instance.database;
    return await db.query('expenses', orderBy: 'date DESC');
  }

  // ============================================================================
  // GENERAL PAYMENTS OPERATIONS
  // ============================================================================

  Future<int> addPayment(Map<String, dynamic> paymentMap) async {
    final db = await instance.database;
    return await db.insert('payments', paymentMap);
  }

  Future<List<Map<String, dynamic>>> getPaymentsInDateRange(
    String from,
    String to,
  ) async {
    final db = await instance.database;
    return await db.query(
      'payments',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [from, '$to 23:59:59'],
      orderBy: 'date DESC',
    );
  }

  // ============================================================================
  // DAILY CLOSING OPERATIONS
  // ============================================================================

  Future<int> saveDailyClosing(Map<String, dynamic> closingMap) async {
    final db = await instance.database;

    final existing = await db.query(
      'daily_closing',
      where: 'date = ?',
      whereArgs: [closingMap['date']],
    );

    if (existing.isNotEmpty) {
      return await db.update(
        'daily_closing',
        closingMap,
        where: 'date = ?',
        whereArgs: [closingMap['date']],
      );
    }

    return await db.insert('daily_closing', closingMap);
  }

  Future<Map<String, dynamic>?> getDailyClosing(String date) async {
    final db = await instance.database;
    final result = await db.query(
      'daily_closing',
      where: 'date = ?',
      whereArgs: [date],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // ============================================================================
  // SETTINGS OPERATIONS
  // ============================================================================

  // Future<void> saveSetting(String key, String value) async {
  //   final db = await instance.database;
  //   await db.insert('settings', {
  //     'key': key,
  //     'value': value,
  //   }, conflictAlgorithm: ConflictAlgorithm.replace);
  // }

  Future<String?> getSetting(String key) async {
    final db = await instance.database;
    final result = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    return result.isNotEmpty ? result.first['value'] as String? : null;
  }

  // ============================================================================
// COMPANY SETTINGS OPERATIONS
// ============================================================================

Future<void> saveCompanySettings({
  required String shopName,
  required String shopAddress,
  required String shopPhone,
  String? shopTagline,
  String? shopEmail,
  String? shopLogo,
}) async {
  final db = await instance.database;
  
  await db.insert('settings', {'key': 'shop_name', 'value': shopName},
      conflictAlgorithm: ConflictAlgorithm.replace);
  await db.insert('settings', {'key': 'shop_address', 'value': shopAddress},
      conflictAlgorithm: ConflictAlgorithm.replace);
  await db.insert('settings', {'key': 'shop_phone', 'value': shopPhone},
      conflictAlgorithm: ConflictAlgorithm.replace);
  
  if (shopTagline != null) {
    await db.insert('settings', {'key': 'shop_tagline', 'value': shopTagline},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  if (shopEmail != null) {
    await db.insert('settings', {'key': 'shop_email', 'value': shopEmail},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  if (shopLogo != null) {
    await db.insert('settings', {'key': 'shop_logo', 'value': shopLogo},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  debugPrint('✅ Company settings saved');
}

Future<Map<String, String?>> getCompanySettings() async {
  final db = await instance.database;
  
  final shopName = await getSetting('shop_name');
  final shopAddress = await getSetting('shop_address');
  final shopPhone = await getSetting('shop_phone');
  final shopTagline = await getSetting('shop_tagline');
  final shopEmail = await getSetting('shop_email');
  final shopLogo = await getSetting('shop_logo');
  
  return {
    'shop_name': shopName ?? 'Medical Store',
    'shop_address': shopAddress ?? 'Shop Address',
    'shop_phone': shopPhone ?? '0300-0000000',
    'shop_tagline': shopTagline,
    'shop_email': shopEmail,
    'shop_logo': shopLogo,
  };
}

  // ============================================================================
  // DASHBOARD QUERIES
  // ============================================================================

  Future<double> getTodaySalesTotal() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final result = await db.rawQuery(
      'SELECT IFNULL(SUM(total), 0) as total FROM sales WHERE dateTime LIKE ?',
      ['$today%'],
    );

    final total = result.first['total'] as num;
    return total.toDouble();
  }

  Future<int> getTodayOrdersCount() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sales WHERE dateTime LIKE ?',
      ['$today%'],
    );

    return result.first['count'] as int;
  }

  Future<int> getTotalCustomers() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM customers WHERE isActive = 1 OR isActive IS NULL',
    );
    return result.first['count'] as int;
  }

  Future<int> getLowStockCount({int threshold = 10}) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE stock <= parLevel AND (isActive = 1 OR isActive IS NULL)',
    );
    return result.first['count'] as int;
  }

  Future<double> getTodayPurchasesTotal() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final result = await db.rawQuery(
      'SELECT IFNULL(SUM(totalAmount), 0) as total FROM purchases WHERE date LIKE ?',
      ['$today%'],
    );

    final total = result.first['total'] as num;
    return total.toDouble();
  }

  Future<double> getTodayExpensesTotal() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final result = await db.rawQuery(
      'SELECT IFNULL(SUM(amount), 0) as total FROM expenses WHERE date LIKE ?',
      ['$today%'],
    );

    final total = result.first['total'] as num;
    return total.toDouble();
  }

  Future<double> getTotalReceivables() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT IFNULL(SUM(openingBalance), 0) as total FROM customers WHERE (isActive = 1 OR isActive IS NULL) AND openingBalance > 0',
    );

    final total = result.first['total'] as num;
    return total.toDouble();
  }

  Future<double> getTotalPayables() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT IFNULL(SUM(openingBalance), 0) as total FROM suppliers WHERE (isActive = 1 OR isActive IS NULL) AND openingBalance > 0',
    );

    final total = result.first['total'] as num;
    return total.toDouble();
  }

  Future<Map<String, dynamic>> getDashboardSummary() async {
    return {
      'todaySales': await getTodaySalesTotal(),
      'todayOrders': await getTodayOrdersCount(),
      'totalCustomers': await getTotalCustomers(),
      'lowStockCount': await getLowStockCount(),
      'todayPurchases': await getTodayPurchasesTotal(),
      'todayExpenses': await getTodayExpensesTotal(),
      'totalReceivables': await getTotalReceivables(),
      'totalPayables': await getTotalPayables(),
    };
  }

  // ============================================================================
  // REPORTS
  // ============================================================================

  Future<Map<String, dynamic>> getProfitLossReport(
    String from,
    String to,
  ) async {
    final db = await database;

    final salesResult = await db.rawQuery(
      'SELECT IFNULL(SUM(total), 0) as total FROM sales WHERE dateTime BETWEEN ? AND ?',
      [from, '$to 23:59:59'],
    );
    double totalSales = (salesResult.first['total'] as num).toDouble();

    final cogsResult = await db.rawQuery(
      '''
      SELECT IFNULL(SUM(si.tradePrice * si.quantity), 0) as total
      FROM sale_items si
      INNER JOIN sales s ON si.saleId = s.id
      WHERE s.dateTime BETWEEN ? AND ?
    ''',
      [from, '$to 23:59:59'],
    );
    double cogs = (cogsResult.first['total'] as num).toDouble();

    final expensesResult = await db.rawQuery(
      'SELECT IFNULL(SUM(amount), 0) as total FROM expenses WHERE date BETWEEN ? AND ?',
      [from, '$to 23:59:59'],
    );
    double totalExpenses = (expensesResult.first['total'] as num).toDouble();

    double grossProfit = totalSales - cogs;
    double netProfit = grossProfit - totalExpenses;

    return {
      'totalSales': totalSales,
      'costOfGoodsSold': cogs,
      'grossProfit': grossProfit,
      'totalExpenses': totalExpenses,
      'netProfit': netProfit,
    };
  }

  Future<double> getInventoryValue() async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT IFNULL(SUM(stock * tradePrice), 0) as total FROM products WHERE isActive = 1 OR isActive IS NULL',
    );

    return (result.first['total'] as num).toDouble();
  }

  Future<int> getLastInvoiceNumber() async {
  final db = await database;

  final result = await db.rawQuery(
    "SELECT invoiceId FROM sales ORDER BY id DESC LIMIT 1"
  );

  if (result.isEmpty) return 1;

  String lastInvoice = result.first['invoiceId'].toString();

  int number = int.tryParse(lastInvoice.replaceAll('INV-', '')) ?? 0;

  return number + 1;
}

  // ============================================================================
  // CATEGORIES CRUD OPERATIONS
  // ============================================================================

  Future<int> addCategory(Category category) async {
    final db = await instance.database;
    return await db.insert('categories', category.toMap());
  }

  Future<List<Category>> getAllCategories({bool activeOnly = true}) async {
    final db = await instance.database;

    String? where;
    if (activeOnly) {
      where = 'isActive = 1 OR isActive IS NULL';
    }

    final result = await db.query(
      'categories',
      where: where,
      orderBy: 'name ASC',
    );
    return result.map((map) => Category.fromMap(map)).toList();
  }

  Future<Category?> getCategoryById(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Category.fromMap(result.first);
  }

  Future<int> updateCategory(Category category) async {
    final db = await instance.database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await instance.database;
    return await db.update(
      'categories',
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> hardDeleteCategory(int id) async {
    final db = await instance.database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================================
  // BRANDS CRUD OPERATIONS
  // ============================================================================

  Future<int> addBrand(Brand brand) async {
    final db = await instance.database;
    return await db.insert('brands', brand.toMap());
  }

  Future<List<Brand>> getAllBrands({bool activeOnly = true}) async {
    final db = await instance.database;

    String? where;
    if (activeOnly) {
      where = 'isActive = 1 OR isActive IS NULL';
    }

    final result = await db.query(
      'brands',
      where: where,
      orderBy: 'name ASC',
    );
    return result.map((map) => Brand.fromMap(map)).toList();
  }

  Future<Brand?> getBrandById(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'brands',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Brand.fromMap(result.first);
  }

  Future<int> updateBrand(Brand brand) async {
    final db = await instance.database;
    return await db.update(
      'brands',
      brand.toMap(),
      where: 'id = ?',
      whereArgs: [brand.id],
    );
  }

  Future<int> deleteBrand(int id) async {
    final db = await instance.database;
    return await db.update(
      'brands',
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> hardDeleteBrand(int id) async {
    final db = await instance.database;
    return await db.delete(
      'brands',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================================
  // ISSUE UNITS CRUD OPERATIONS
  // ============================================================================

  Future<int> addIssueUnit(IssueUnit unit) async {
    final db = await instance.database;
    return await db.insert('issue_units', unit.toMap());
  }

  Future<List<IssueUnit>> getAllIssueUnits({bool activeOnly = true}) async {
    final db = await instance.database;

    String? where;
    if (activeOnly) {
      where = 'isActive = 1 OR isActive IS NULL';
    }

    final result = await db.query(
      'issue_units',
      where: where,
      orderBy: 'name ASC',
    );
    return result.map((map) => IssueUnit.fromMap(map)).toList();
  }

  Future<IssueUnit?> getIssueUnitById(int id) async {
    final db = await instance.database;
    final result = await db.query(
      'issue_units',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return IssueUnit.fromMap(result.first);
  }

  Future<int> updateIssueUnit(IssueUnit unit) async {
    final db = await instance.database;
    return await db.update(
      'issue_units',
      unit.toMap(),
      where: 'id = ?',
      whereArgs: [unit.id],
    );
  }

  Future<int> deleteIssueUnit(int id) async {
    final db = await instance.database;
    return await db.update(
      'issue_units',
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> hardDeleteIssueUnit(int id) async {
    final db = await instance.database;
    return await db.delete(
      'issue_units',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'medical_store.db');

    await close();
    await deleteDatabase(path);
    _database = null;

    debugPrint('⚠️ DATABASE RESET COMPLETED - All data deleted!');
  }

  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;
    final path = await getDatabasePath();

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
    );

    Map<String, int> tableInfo = {};
    for (var table in tables) {
      final tableName = table['name'] as String;
      final count = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName',
      );
      tableInfo[tableName] = count.first['count'] as int;
    }

    return {'path': path, 'tables': tableInfo, 'version': 10};
  }

  Future<void> printDatabaseInfo() async {
    final info = await getDatabaseInfo();

    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('📊 DATABASE INFORMATION');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('Path: ${info['path']}');
    debugPrint('Version: ${info['version']}');
    debugPrint('───────────────────────────────────────────────────────────');
    debugPrint('Tables and Record Counts:');

    final tables = info['tables'] as Map<String, int>;
    tables.forEach((tableName, count) {
      debugPrint('  • $tableName: $count records');
    });

    debugPrint('═══════════════════════════════════════════════════════════');
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
    _database = null;
  }
}
