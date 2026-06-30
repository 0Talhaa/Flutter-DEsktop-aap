// lib/screens/supplier_ledger_report.dart
// ✅ FIXED VERSION - Invoice by Invoice Display + Correct Balance Calculation

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/models/supplier.dart';
import 'package:medical_app/services/database_helper.dart';

class SupplierLedgerReport extends StatefulWidget {
  const SupplierLedgerReport({super.key});

  @override
  State<SupplierLedgerReport> createState() => _SupplierLedgerReportState();
}

class _SupplierLedgerReportState extends State<SupplierLedgerReport> {
  // Filters
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();
  Supplier? selectedSupplier;
  
  // Data
  List<Supplier> allSuppliers = [];
  List<LedgerEntry> ledgerEntries = [];
  bool isLoading = false;
  bool isSuppliersLoading = true;
  bool showFullScreen = false;

  // Metrics
  double reportOpeningBalance = 0.0;
  double totalPurchased = 0.0;
  double totalPaid = 0.0;
  double closingBalance = 0.0;

  final currencyFormat = NumberFormat.currency(locale: 'en_PK', symbol: 'Rs. ', decimalDigits: 0);
  final dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    try {
      final suppliers = await DatabaseHelper.instance.getAllSuppliers();
      setState(() {
        allSuppliers = suppliers;
        isSuppliersLoading = false;
      });
    } catch (e) {
      _showErrorSnackBar('Error loading suppliers: $e');
    }
  }

  Future<void> _generateLedger() async {
    if (selectedSupplier == null) {
      _showErrorSnackBar('Please select a supplier first');
      return;
    }

    setState(() => isLoading = true);

    final fromDateStr = DateTime(fromDate.year, fromDate.month, fromDate.day).toIso8601String();
    final toDateStr = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59).toIso8601String();

    try {
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('📊 GENERATING LEDGER FOR: ${selectedSupplier!.name}');
      debugPrint('📅 Period: ${dateFormat.format(fromDate)} to ${dateFormat.format(toDate)}');
      debugPrint('═══════════════════════════════════════════════════════════');

      // ✅ STEP 1: Calculate Opening Balance (invoices BEFORE fromDate)
      reportOpeningBalance = await _getOpeningBalance(fromDateStr);
      debugPrint('💰 Opening Balance (before ${dateFormat.format(fromDate)}): ${currencyFormat.format(reportOpeningBalance)}');

      // ✅ STEP 2: Get all purchases in date range
      final db = await DatabaseHelper.instance.database;
      final purchases = await db.query(
        'purchases',
        where: 'supplierId = ? AND date BETWEEN ? AND ?',
        whereArgs: [selectedSupplier!.id, fromDateStr, toDateStr],
        orderBy: 'date ASC',
      );

      debugPrint('📦 Found ${purchases.length} purchases in period');

      List<LedgerEntry> tempEntries = [];
      totalPurchased = 0;
      totalPaid = 0;

      // ✅ STEP 3: Process each invoice
      for (var purchase in purchases) {
        final purchaseId = purchase['id'] as int;
        final date = DateTime.parse(purchase['date'] as String);
        final invoiceNumber = purchase['invoiceNumber'] as String;
        final totalAmount = (purchase['totalAmount'] as num).toDouble();
        final amountPaid = (purchase['amountPaid'] as num).toDouble();
        final balance = (purchase['balance'] as num).toDouble();

        debugPrint('──────────────────────────────────────────────────────────');
        debugPrint('Invoice: $invoiceNumber (ID: $purchaseId)');
        debugPrint('  Date: ${dateFormat.format(date)}');
        debugPrint('  Total: ${currencyFormat.format(totalAmount)}');
        debugPrint('  Paid with Invoice: ${currencyFormat.format(amountPaid)}');
        debugPrint('  Balance: ${currencyFormat.format(balance)}');

        // ✅ Add PURCHASE entry (Debit - increases balance)
        tempEntries.add(LedgerEntry(
          date: date,
          description: 'Purchase Invoice #$invoiceNumber',
          invoiceNumber: invoiceNumber,
          debit: totalAmount,
          credit: 0.0,
          type: LedgerEntryType.purchase,
          referenceNo: invoiceNumber,
          purchaseId: purchaseId,
        ));
        totalPurchased += totalAmount;

        // ✅ Get ALL payments for this specific invoice
        final payments = await db.query(
          'supplier_payments',
          where: 'purchaseId = ?',
          whereArgs: [purchaseId],
          orderBy: 'date ASC',
        );

        debugPrint('  💳 Found ${payments.length} payment(s) for this invoice:');

        double totalPaymentsForInvoice = 0;
        for (var payment in payments) {
          final paymentDate = DateTime.parse(payment['date'] as String);
          final paymentAmount = (payment['amount'] as num).toDouble();
          final paymentMethod = payment['paymentMethod'] as String? ?? 'Cash';
          
          totalPaymentsForInvoice += paymentAmount;
          
          debugPrint('     - ${dateFormat.format(paymentDate)}: ${currencyFormat.format(paymentAmount)} ($paymentMethod)');

          // Add payment entry
          tempEntries.add(LedgerEntry(
            date: paymentDate,
            description: 'Payment for Invoice #$invoiceNumber',
            invoiceNumber: invoiceNumber,
            debit: 0.0,
            credit: paymentAmount,
            type: LedgerEntryType.payment,
            referenceNo: payment['reference'] as String?,
            purchaseId: purchaseId,
            paymentMethod: paymentMethod,
          ));
          totalPaid += paymentAmount;
        }

        debugPrint('  ✅ Total Payments for $invoiceNumber: ${currencyFormat.format(totalPaymentsForInvoice)}');
        debugPrint('  📊 Remaining Balance: ${currencyFormat.format(totalAmount - totalPaymentsForInvoice)}');
      }

      // ✅ STEP 4: Sort all entries by date
      tempEntries.sort((a, b) {
        int dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;
        // Same date: purchase before payment
        if (a.type == LedgerEntryType.purchase && b.type == LedgerEntryType.payment) return -1;
        if (a.type == LedgerEntryType.payment && b.type == LedgerEntryType.purchase) return 1;
        return 0;
      });

      // ✅ STEP 5: Calculate running balance
      double runningBalance = reportOpeningBalance;
      debugPrint('\n🔄 CALCULATING RUNNING BALANCE:');
      debugPrint('   Starting Balance: ${currencyFormat.format(runningBalance)}');

      for (var entry in tempEntries) {
        runningBalance = runningBalance + entry.debit - entry.credit;
        entry.balance = runningBalance;
        
        if (entry.type == LedgerEntryType.purchase) {
          debugPrint('   📦 ${entry.invoiceNumber}: +${currencyFormat.format(entry.debit)} → ${currencyFormat.format(runningBalance)}');
        } else {
          debugPrint('   💳 Payment for ${entry.invoiceNumber}: -${currencyFormat.format(entry.credit)} → ${currencyFormat.format(runningBalance)}');
        }
      }

      closingBalance = runningBalance;

      debugPrint('\n═══════════════════════════════════════════════════════════');
      debugPrint('📊 LEDGER SUMMARY:');
      debugPrint('   Opening Balance: ${currencyFormat.format(reportOpeningBalance)}');
      debugPrint('   Total Purchased: ${currencyFormat.format(totalPurchased)}');
      debugPrint('   Total Paid: ${currencyFormat.format(totalPaid)}');
      debugPrint('   Closing Balance: ${currencyFormat.format(closingBalance)}');
      debugPrint('   Formula Check: ${currencyFormat.format(reportOpeningBalance)} + ${currencyFormat.format(totalPurchased)} - ${currencyFormat.format(totalPaid)} = ${currencyFormat.format(reportOpeningBalance + totalPurchased - totalPaid)}');
      debugPrint('═══════════════════════════════════════════════════════════');

      setState(() {
        ledgerEntries = tempEntries;
        isLoading = false;
        showFullScreen = true;
      });

    } catch (e, stackTrace) {
      setState(() => isLoading = false);
      debugPrint('❌ Error generating ledger: $e');
      debugPrint('Stack trace: $stackTrace');
      _showErrorSnackBar('Error generating ledger: $e');
    }
  }

  /// ✅ Calculate opening balance from invoices BEFORE the report start date
  Future<double> _getOpeningBalance(String beforeDate) async {
    final db = await DatabaseHelper.instance.database;
    
    // Get all purchases before the date
    final purchases = await db.query(
      'purchases',
      where: 'supplierId = ? AND date < ?',
      whereArgs: [selectedSupplier!.id, beforeDate],
    );

    double openingBalance = 0.0;

    for (var purchase in purchases) {
      final purchaseId = purchase['id'] as int;
      final totalAmount = (purchase['totalAmount'] as num).toDouble();
      
      // Get all payments for this purchase
      final payments = await db.query(
        'supplier_payments',
        where: 'purchaseId = ?',
        whereArgs: [purchaseId],
      );

      final totalPayments = payments.fold<double>(
        0.0,
        (sum, payment) => sum + ((payment['amount'] as num?)?.toDouble() ?? 0.0),
      );

      // Balance = Total - Payments
      openingBalance += (totalAmount - totalPayments);
    }

    return openingBalance;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _selectDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate : toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF009688)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = picked;
        } else {
          toDate = picked;
        }
      });
    }
  }

  void _backToFilters() {
    setState(() {
      showFullScreen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Supplier Ledger - Invoice by Invoice'),
        backgroundColor: const Color(0xFF009688),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: showFullScreen ? [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Back to Filters',
            onPressed: _backToFilters,
          ),
        ] : null,
      ),
      body: showFullScreen ? _buildFullScreenLedger() : _buildFilterView(),
    );
  }

  // ==================== FILTER VIEW ====================

  Widget _buildFilterView() {
    return Row(
      children: [
        Container(
          width: 320,
          margin: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildControlPanel(),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildSummaryCards(),
                const SizedBox(height: 16),
                Expanded(child: _buildLedgerPreview()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLedgerPreview() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 30, color: Colors.grey.shade300),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ==================== FULL SCREEN LEDGER VIEW ====================

  Widget _buildFullScreenLedger() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildFullScreenHeader(),
          const SizedBox(height: 16),
          _buildSummaryCards(),
          const SizedBox(height: 16),
          _buildFullScreenLedgerTable(),
        ],
      ),
    );
  }

  Widget _buildFullScreenHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF009688).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book, color: Color(0xFF009688), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Supplier Ledger Report (Invoice by Invoice)',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${selectedSupplier!.name} • ${dateFormat.format(fromDate)} to ${dateFormat.format(toDate)}',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              _buildHeaderAction(Icons.print_outlined, 'Print', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Print feature coming soon!')),
                );
              }),
              const SizedBox(width: 8),
              _buildHeaderAction(Icons.picture_as_pdf_outlined, 'PDF', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF export coming soon!')),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreenLedgerTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12), 
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                _buildTableHeader('Date', flex: 2),
                _buildTableHeader('Invoice #', flex: 2),
                _buildTableHeader('Particulars', flex: 4),
                _buildTableHeader('Type', flex: 2, align: TextAlign.center),
                _buildTableHeader('Debit (+)', flex: 2, align: TextAlign.right),
                _buildTableHeader('Credit (-)', flex: 2, align: TextAlign.right),
                _buildTableHeader('Balance', flex: 2, align: TextAlign.right),
              ],
            ),
          ),

          // Opening Balance Row
          if (ledgerEntries.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      dateFormat.format(fromDate),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Expanded(flex: 2, child: SizedBox()),
                  const Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        Icon(Icons.arrow_forward, size: 16, color: Color(0xFF64748B)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Opening Balance Brought Forward',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(flex: 2, child: SizedBox()),
                  const Expanded(flex: 2, child: SizedBox()),
                  const Expanded(flex: 2, child: SizedBox()),
                  Expanded(
                    flex: 2, 
                    child: Text(
                      currencyFormat.format(reportOpeningBalance), 
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                  ),
                ],
              ),
            ),

          // Transaction Rows
          if (isLoading)
            Container(
              padding: const EdgeInsets.all(60),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF009688)),
                    SizedBox(height: 16),
                    Text('Loading ledger...', style: TextStyle(color: Color(0xFF64748B))),
                  ],
                ),
              ),
            )
          else if (ledgerEntries.isEmpty)
            Container(
              padding: const EdgeInsets.all(60),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      'No transactions found\nfor the selected period',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            ...ledgerEntries.asMap().entries.map((entry) {
              final index = entry.key;
              final ledgerEntry = entry.value;
              final isEven = index % 2 == 0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: isEven ? Colors.white : const Color(0xFFFAFAFA),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(
                  children: [
                    // Date
                    Expanded(
                      flex: 2,
                      child: Text(
                        dateFormat.format(ledgerEntry.date),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ),
                    
                    // Invoice Number
                    Expanded(
                      flex: 2,
                      child: Text(
                        ledgerEntry.invoiceNumber ?? '-',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                    
                    // Description
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          Icon(
                            ledgerEntry.type == LedgerEntryType.purchase ? Icons.shopping_bag : Icons.payment,
                            size: 18,
                            color: ledgerEntry.type == LedgerEntryType.purchase ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ledgerEntry.description,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (ledgerEntry.paymentMethod != null)
                                  Text(
                                    'via ${ledgerEntry.paymentMethod}',
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Type Badge
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: ledgerEntry.type == LedgerEntryType.purchase 
                                ? const Color(0xFFF59E0B).withOpacity(0.1) 
                                : const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ledgerEntry.type == LedgerEntryType.purchase ? 'PURCHASE' : 'PAYMENT',
                            style: TextStyle(
                              fontSize: 11, 
                              fontWeight: FontWeight.w600,
                              color: ledgerEntry.type == LedgerEntryType.purchase 
                                  ? const Color(0xFFF59E0B) 
                                  : const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Debit
                    Expanded(
                      flex: 2,
                      child: Text(
                        ledgerEntry.debit > 0 ? currencyFormat.format(ledgerEntry.debit) : '-',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13, 
                          fontWeight: ledgerEntry.debit > 0 ? FontWeight.w600 : FontWeight.normal,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                    
                    // Credit
                    Expanded(
                      flex: 2,
                      child: Text(
                        ledgerEntry.credit > 0 ? currencyFormat.format(ledgerEntry.credit) : '-',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13, 
                          fontWeight: ledgerEntry.credit > 0 ? FontWeight.w600 : FontWeight.normal,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                    
                    // Running Balance
                    Expanded(
                      flex: 2,
                      child: Text(
                        currencyFormat.format(ledgerEntry.balance),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13, 
                          fontWeight: FontWeight.w700, 
                          color: ledgerEntry.balance > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

          // Closing Balance Footer
          if (ledgerEntries.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: closingBalance > 0 
                    ? const Color(0xFFEF4444).withOpacity(0.1) 
                    : const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border(top: BorderSide(color: Colors.grey.shade200, width: 2)),
              ),
              child: Row(
                children: [
                  const Expanded(flex: 2, child: SizedBox()),
                  const Expanded(flex: 2, child: SizedBox()),
                  Expanded(
                    flex: 4,
                    child: Text(
                      'Closing Balance ${closingBalance > 0 ? "(Payable)" : "(Credit)"}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      currencyFormat.format(totalPurchased),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      currencyFormat.format(totalPaid),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                    ),
                  ),
                  const Expanded(flex: 2, child: SizedBox()),
                  Expanded(
                    flex: 2, 
                    child: Text(
                      currencyFormat.format(closingBalance.abs()), 
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.w700, 
                        color: closingBalance > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ==================== LEFT PANEL WIDGETS ====================

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF009688).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune, color: Color(0xFF009688), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Report Filters',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const Text(
            'SELECT SUPPLIER',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B), letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFF8FAFC),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Supplier>(
                value: selectedSupplier,
                isExpanded: true,
                hint: Text(
                  isSuppliersLoading ? 'Loading...' : 'Choose supplier...',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                items: allSuppliers.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        const Icon(Icons.business, size: 16, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    selectedSupplier = val;
                    ledgerEntries = [];
                    reportOpeningBalance = 0;
                    totalPurchased = 0;
                    totalPaid = 0;
                    closingBalance = 0;
                  });
                },
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(child: _buildDateSelector('FROM', fromDate, () => _selectDate(true))),
              const SizedBox(width: 12),
              Expanded(child: _buildDateSelector('TO', toDate, () => _selectDate(false))),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : _generateLedger,
              icon: isLoading 
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.receipt_long, size: 18),
              label: Text(isLoading ? 'Generating...' : 'Generate Ledger'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF009688),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(String label, DateTime date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B), letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFF8FAFC),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    DateFormat('dd/MM/yy').format(date),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==================== SHARED WIDGETS ====================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF009688).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.menu_book, color: Color(0xFF009688), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Supplier Ledger Report',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedSupplier != null 
                    ? '${selectedSupplier!.name} • ${dateFormat.format(fromDate)} to ${dateFormat.format(toDate)}'
                    : 'Select a supplier and date range to generate report',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          _buildHeaderAction(Icons.print_outlined, 'Print', () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Print feature coming soon!')),
            );
          }),
          const SizedBox(width: 8),
          _buildHeaderAction(Icons.picture_as_pdf_outlined, 'PDF', () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PDF export coming soon!')),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Opening Balance',
            currencyFormat.format(reportOpeningBalance),
            Icons.account_balance_wallet_outlined,
            const Color(0xFF64748B),
            subtitle: 'Balance brought forward',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Total Purchases',
            currencyFormat.format(totalPurchased),
            Icons.shopping_cart_outlined,
            const Color(0xFFF59E0B),
            subtitle: 'Debit (+)',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Total Payments',
            currencyFormat.format(totalPaid),
            Icons.payments_outlined,
            const Color(0xFF10B981),
            subtitle: 'Credit (-)',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Closing Balance',
            currencyFormat.format(closingBalance),
            Icons.account_balance_outlined,
            closingBalance > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
            subtitle: closingBalance > 0 ? 'Amount Payable' : 'Advance/Credit',
            isHighlighted: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title, 
    String value, 
    IconData icon, 
    Color color, 
    {String? subtitle, bool isHighlighted = false}
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isHighlighted ? color.withOpacity(0.3) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title, 
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isHighlighted ? color : const Color(0xFF1E293B),
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70, letterSpacing: 0.3),
      ),
    );
  }
}

// ==================== LEDGER ENTRY MODEL ====================
enum LedgerEntryType { purchase, payment }

class LedgerEntry {
  final DateTime date;
  final String description;
  final String? invoiceNumber;
  final double debit;
  final double credit;
  double balance;
  final LedgerEntryType type;
  final String? referenceNo;
  final int? purchaseId;
  final String? paymentMethod;

  LedgerEntry({
    required this.date,
    required this.description,
    this.invoiceNumber,
    required this.debit,
    required this.credit,
    this.balance = 0.0,
    required this.type,
    this.referenceNo,
    this.purchaseId,
    this.paymentMethod,
  });
}