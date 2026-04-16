// lib/migrations/supplier_invoice_migration.dart

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Migration to convert from opening balance to invoice-based system
class SupplierInvoiceMigration {
  
  /// Execute migration: Remove opening balance, use invoice-based payments
  static Future<void> migrate(Database db) async {
    debugPrint('🔄 Starting Supplier Invoice Migration...');

    try {
      await db.transaction((txn) async {
        // Step 1: Create new supplier_payments table with invoice reference
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS supplier_payments_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            supplierId INTEGER NOT NULL,
            supplierName TEXT NOT NULL,
            purchaseId INTEGER,
            invoiceNumber TEXT,
            date TEXT NOT NULL,
            amount REAL NOT NULL,
            paymentMethod TEXT DEFAULT 'Cash',
            reference TEXT,
            notes TEXT,
            createdAt TEXT DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (supplierId) REFERENCES suppliers(id),
            FOREIGN KEY (purchaseId) REFERENCES purchases(id)
          )
        ''');

        // Step 2: Migrate existing payments (link to oldest unpaid invoices)
        final existingPayments = await txn.query('supplier_payments', orderBy: 'date ASC');
        
        for (var payment in existingPayments) {
          final supplierId = payment['supplierId'] as int;
          final supplierName = payment['supplierName'] as String;
          final amount = (payment['amount'] as num).toDouble();
          final date = payment['date'] as String;
          
          // Find oldest unpaid invoice for this supplier
          final unpaidInvoices = await txn.query(
            'purchases',
            where: 'supplierId = ? AND balance > 0',
            whereArgs: [supplierId],
            orderBy: 'date ASC',
          );

          if (unpaidInvoices.isNotEmpty) {
            final invoice = unpaidInvoices.first;
            await txn.insert('supplier_payments_new', {
              'supplierId': supplierId,
              'supplierName': supplierName,
              'purchaseId': invoice['id'],
              'invoiceNumber': invoice['invoiceNumber'],
              'date': date,
              'amount': amount,
              'paymentMethod': payment['paymentMethod'],
              'reference': payment['reference'],
              'notes': payment['notes'],
              'createdAt': payment['createdAt'],
            });
          }
        }

        // Step 3: Drop old supplier_payments table
        await txn.execute('DROP TABLE IF EXISTS supplier_payments');

        // Step 4: Rename new table
        await txn.execute('ALTER TABLE supplier_payments_new RENAME TO supplier_payments');

        // Step 5: Update suppliers table - remove openingBalance column
        // Since SQLite doesn't support DROP COLUMN, recreate table
        await txn.execute('''
          CREATE TABLE suppliers_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL,
            email TEXT,
            company TEXT,
            teleNumber TEXT,
            address TEXT,
            city TEXT,
            isActive INTEGER DEFAULT 1
          )
        ''');

        // Copy data (excluding openingBalance)
        await txn.execute('''
          INSERT INTO suppliers_new (id, name, phone, email, company, teleNumber, address, city, isActive)
          SELECT id, name, phone, email, company, teleNumber, address, city, isActive
          FROM suppliers
        ''');

        // Drop old suppliers table
        await txn.execute('DROP TABLE suppliers');

        // Rename new table
        await txn.execute('ALTER TABLE suppliers_new RENAME TO suppliers');

        // Step 6: Ensure purchases table has supplierId (should already exist)
        await _safeAddColumn(txn, 'purchases', 'supplierId', 'INTEGER');

        // Step 7: Update any purchases missing supplierId
        await txn.execute('''
          UPDATE purchases
          SET supplierId = (
            SELECT id FROM suppliers WHERE suppliers.name = purchases.supplierName LIMIT 1
          )
          WHERE supplierId IS NULL
        ''');

        debugPrint('✅ Supplier Invoice Migration Completed Successfully!');
      });
    } catch (e) {
      debugPrint('❌ Migration Error: $e');
      rethrow;
    }
  }

  /// Safely add column if it doesn't exist
  static Future<void> _safeAddColumn(
    Transaction txn,
    String table,
    String column,
    String type,
  ) async {
    try {
      final result = await txn.rawQuery('PRAGMA table_info($table)');
      final columnExists = result.any((row) => row['name'] == column);

      if (!columnExists) {
        await txn.execute('ALTER TABLE $table ADD COLUMN $column $type');
        debugPrint('✅ Added column $column to $table');
      }
    } catch (e) {
      debugPrint('⚠️ Error adding column $column to $table: $e');
    }
  }

  /// Calculate current supplier balance from unpaid invoices
  static Future<double> calculateSupplierBalance(Database db, int supplierId) async {
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(balance), 0) as totalBalance
      FROM purchases
      WHERE supplierId = ?
    ''', [supplierId]);

    return (result.first['totalBalance'] as num).toDouble();
  }

  /// Get unpaid/partially paid invoices for a supplier
  static Future<List<Map<String, dynamic>>> getUnpaidInvoices(
    Database db,
    int supplierId,
  ) async {
    return await db.query(
      'purchases',
      where: 'supplierId = ? AND balance > 0',
      whereArgs: [supplierId],
      orderBy: 'date ASC',
    );
  }

  /// Apply payment to invoices (FIFO - First In First Out)
  static Future<void> applyPaymentToInvoices(
    Database db,
    int supplierId,
    double paymentAmount,
    List<int> selectedInvoiceIds,
    {
      required String paymentMethod,
      required DateTime paymentDate,
      String? reference,
      String? notes,
    }
  ) async {
    await db.transaction((txn) async {
      double remainingAmount = paymentAmount;

      // Get selected invoices ordered by date
      final invoices = await txn.query(
        'purchases',
        where: 'id IN (${selectedInvoiceIds.join(',')}) AND balance > 0',
        orderBy: 'date ASC',
      );

      for (var invoice in invoices) {
        if (remainingAmount <= 0) break;

        final invoiceId = invoice['id'] as int;
        final invoiceNumber = invoice['invoiceNumber'] as String;
        final currentBalance = (invoice['balance'] as num).toDouble();
        final currentAmountPaid = (invoice['amountPaid'] as num).toDouble();

        // Calculate payment for this invoice
        final paymentForInvoice = remainingAmount > currentBalance 
            ? currentBalance 
            : remainingAmount;

        // Update invoice
        final newAmountPaid = currentAmountPaid + paymentForInvoice;
        final newBalance = currentBalance - paymentForInvoice;

        await txn.update(
          'purchases',
          {
            'amountPaid': newAmountPaid,
            'balance': newBalance,
            'status': newBalance <= 0 ? 'paid' : 'pending',
          },
          where: 'id = ?',
          whereArgs: [invoiceId],
        );

        // Record payment
        await txn.insert('supplier_payments', {
          'supplierId': supplierId,
          'supplierName': invoice['supplierName'],
          'purchaseId': invoiceId,
          'invoiceNumber': invoiceNumber,
          'date': paymentDate.toIso8601String(),
          'amount': paymentForInvoice,
          'paymentMethod': paymentMethod,
          'reference': reference,
          'notes': notes,
          'createdAt': DateTime.now().toIso8601String(),
        });

        remainingAmount -= paymentForInvoice;

        debugPrint('✅ Applied Rs. $paymentForInvoice to Invoice $invoiceNumber');
      }

      if (remainingAmount > 0) {
        debugPrint('⚠️ Warning: Rs. $remainingAmount payment remaining (no more unpaid invoices)');
      }
    });
  }
}