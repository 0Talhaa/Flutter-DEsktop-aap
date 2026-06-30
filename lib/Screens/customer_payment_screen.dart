// lib/screens/customer_payment_by_invoice_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/models/customer.dart';
import 'package:medical_app/services/database_helper.dart';

class CustomerPaymentByInvoiceScreen extends StatefulWidget {
  const CustomerPaymentByInvoiceScreen({super.key});

  @override
  State<CustomerPaymentByInvoiceScreen> createState() =>
      _CustomerPaymentByInvoiceScreenState();
}

class _CustomerPaymentByInvoiceScreenState
    extends State<CustomerPaymentByInvoiceScreen> {
  // Controllers
  final TextEditingController paymentAmountController =
      TextEditingController();
  final TextEditingController referenceController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  // Data
  List<Customer> allCustomers = [];
  Customer? selectedCustomer;
  List<Map<String, dynamic>> unpaidInvoices = [];
  Set<int> selectedInvoiceIds = {};
  bool isLoading = false;
  double customerTotalBalance = 0.0;
  String selectedPaymentMethod = 'Cash';
  DateTime paymentDate = DateTime.now();

  // ── Premium Colors ──────────────────────────────────────────
  static const Color kPrimary = Color(0xFF1A237E);
  static const Color kTeal = Color(0xFF009688); // Teal primary
  static const Color kPrimaryLight = Color(0xFF3949AB);
  static const Color kSurface = Color(0xFFF8F9FF);
  static const Color kCard = Color(0xFFFFFFFF);
  static const Color kDebit = Color(0xFFE53935);
  static const Color kCredit = Color(0xFF00897B);
  static const Color kWarning = Color(0xFFF59E0B);
  static const Color kText = Color(0xFF0D1B5E);
  static const Color kSubText = Color(0xFF607D8B);
  static const Color kBorder = Color(0xFFE8EAF6);

  final currencyFormat = NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );
  final dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    paymentAmountController.dispose();
    referenceController.dispose();
    notesController.dispose();
    super.dispose();
  }

  // ============================================================
  // DATA LOADING
  // ============================================================

  Future<void> _loadCustomers() async {
    final customers = await DatabaseHelper.instance.getAllCustomers();
    setState(() => allCustomers = customers);
  }

  Future<void> _loadUnpaidInvoices() async {
    if (selectedCustomer == null) return;
    setState(() => isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;

      // ✅ FIX: Use balance > 0.009 to avoid floating point issues
      // Also explicitly check status != 'paid' as double safety
      final invoices = await db.rawQuery('''
        SELECT * FROM sales
        WHERE customerId = ?
          AND balance > 0.009
          AND (status IS NULL OR status != 'paid')
        ORDER BY dateTime ASC
      ''', [selectedCustomer!.id]);

      // ✅ Calculate total outstanding balance
      final balanceResult = await db.rawQuery('''
        SELECT COALESCE(SUM(balance), 0) as totalBalance
        FROM sales
        WHERE customerId = ?
          AND balance > 0.009
          AND (status IS NULL OR status != 'paid')
      ''', [selectedCustomer!.id]);

      final totalBalance =
          (balanceResult.first['totalBalance'] as num?)?.toDouble() ?? 0.0;

      // ✅ Convert to List<Map<String, dynamic>> properly
      final invoiceList = invoices
          .map((inv) => Map<String, dynamic>.from(inv))
          .toList();

      setState(() {
        unpaidInvoices = invoiceList;
        customerTotalBalance = totalBalance;
        selectedInvoiceIds.clear();
        isLoading = false;
      });

      debugPrint(
        '✅ Loaded ${invoiceList.length} unpaid invoices for customer',
      );
      for (var inv in invoiceList) {
        debugPrint(
          '  Invoice ${inv['invoiceId']}: '
          'Total=${inv['total']}, '
          'Paid=${inv['amountPaid']}, '
          'Balance=${inv['balance']}',
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error loading invoices: $e');
      debugPrint('❌ Load invoices error: $e');
    }
  }

  // ============================================================
  // COMPUTED GETTERS
  // ============================================================

  double get selectedInvoicesTotal {
    return unpaidInvoices
        .where((inv) => selectedInvoiceIds.contains(inv['id'] as int))
        .fold(
          0.0,
          (sum, inv) => sum + (inv['balance'] as num).toDouble(),
        );
  }

  double get paymentAmount {
    return double.tryParse(paymentAmountController.text) ?? 0.0;
  }

  Map<int, double> _calculatePaymentDistribution() {
    final Map<int, double> distribution = {};
    double remainingAmount = paymentAmount;

    final selectedInvoices = unpaidInvoices
        .where((inv) => selectedInvoiceIds.contains(inv['id'] as int))
        .toList()
      ..sort(
        (a, b) => (a['dateTime'] as String).compareTo(
          b['dateTime'] as String,
        ),
      );

    for (var invoice in selectedInvoices) {
      if (remainingAmount <= 0) break;
      final invoiceId = invoice['id'] as int;
      final balance = (invoice['balance'] as num).toDouble();
      final payment = remainingAmount >= balance ? balance : remainingAmount;
      distribution[invoiceId] = payment;
      remainingAmount -= payment;
    }

    return distribution;
  }

  // ============================================================
  // PROCESS PAYMENT — ✅ FIXED
  // ============================================================

  Future<void> _processPayment() async {
    if (selectedCustomer == null) {
      _showErrorSnackBar('Please select a customer');
      return;
    }
    if (selectedInvoiceIds.isEmpty) {
      _showErrorSnackBar('Please select at least one invoice');
      return;
    }
    if (paymentAmount <= 0) {
      _showErrorSnackBar('Please enter a valid payment amount');
      return;
    }
    if (paymentAmount > selectedInvoicesTotal) {
      final confirm = await _showConfirmDialog(
        'Payment amount (${currencyFormat.format(paymentAmount)}) exceeds '
        'selected invoices total '
        '(${currencyFormat.format(selectedInvoicesTotal)}). '
        'Excess amount will be ignored. Continue?',
      );
      if (!confirm) return;
    }

    setState(() => isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;

      await db.transaction((txn) async {
        double remainingAmount = paymentAmount;

        final selectedInvoices = unpaidInvoices
            .where(
              (inv) => selectedInvoiceIds.contains(inv['id'] as int),
            )
            .toList()
          ..sort(
            (a, b) => (a['dateTime'] as String).compareTo(
              b['dateTime'] as String,
            ),
          );

        for (var invoice in selectedInvoices) {
          if (remainingAmount <= 0.009) break;

          final invoiceDbId = invoice['id'] as int;
          final invoiceNumber = invoice['invoiceId'] as String;

          // ✅ Re-fetch live values from DB to avoid stale data
          final freshRows = await txn.query(
            'sales',
            where: 'id = ?',
            whereArgs: [invoiceDbId],
          );

          if (freshRows.isEmpty) continue;
          final fresh = freshRows.first;

          final currentBalance =
              (fresh['balance'] as num).toDouble();
          final currentAmountPaid =
              (fresh['amountPaid'] as num).toDouble();

          if (currentBalance <= 0.009) continue;

          final paymentForInvoice = remainingAmount > currentBalance
              ? currentBalance
              : remainingAmount;

          final newAmountPaid = currentAmountPaid + paymentForInvoice;
          final newBalance = currentBalance - paymentForInvoice;

          // ✅ Update sale record
          await txn.update(
            'sales',
            {
              'amountPaid': newAmountPaid,
              'balance': newBalance < 0.009 ? 0.0 : newBalance,
              'status': newBalance < 0.009 ? 'paid' : 'pending',
            },
            where: 'id = ?',
            whereArgs: [invoiceDbId],
          );

          // ✅ Record in customer_payments
          await txn.insert('customer_payments', {
            'customerId': selectedCustomer!.id,
            'customerName': selectedCustomer!.name,
            'saleId': invoiceDbId,
            'invoiceId': invoiceNumber,
            'date': DateFormat('yyyy-MM-dd').format(paymentDate),
            'amount': paymentForInvoice,
            'paymentMethod': selectedPaymentMethod,
            'reference': referenceController.text.trim().isEmpty
                ? null
                : referenceController.text.trim(),
            'notes': notesController.text.trim().isEmpty
                ? null
                : notesController.text.trim(),
            'createdAt': DateTime.now().toIso8601String(),
          });

          remainingAmount -= paymentForInvoice;

          debugPrint(
            '✅ Invoice $invoiceNumber: '
            'Paid ${currencyFormat.format(paymentForInvoice)}, '
            'Balance: ${currencyFormat.format(newBalance < 0.009 ? 0 : newBalance)}',
          );
        }
      });

      setState(() => isLoading = false);

      if (mounted) {
        _showSuccessSnackBar('Payment processed successfully!');
      }

      // ✅ Reload to reflect changes
      await _loadUnpaidInvoices();
      _clearForm();
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error processing payment: $e');
      debugPrint('❌ Payment error: $e');
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  void _clearForm() {
    paymentAmountController.clear();
    referenceController.clear();
    notesController.clear();
    setState(() {
      selectedInvoiceIds.clear();
      selectedPaymentMethod = 'Cash';
      paymentDate = DateTime.now();
    });
  }

  void _selectAllInvoices() {
    setState(() {
      if (selectedInvoiceIds.length == unpaidInvoices.length) {
        selectedInvoiceIds.clear();
      } else {
        selectedInvoiceIds =
            unpaidInvoices.map((inv) => inv['id'] as int).toSet();
      }
    });
  }

  void _fillPaymentAmount() {
    setState(() {
      paymentAmountController.text =
          selectedInvoicesTotal.toStringAsFixed(0);
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: kPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => paymentDate = picked);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: kDebit,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: kCredit,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: kPrimary),
            const SizedBox(width: 10),
            Text(
              'Confirm',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: kText,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 13, color: kSubText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: kSubText),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Continue',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: _buildAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left Panel ─────────────────────────────────────
            SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildPaymentForm(),
                    const SizedBox(height: 16),
                    if (selectedInvoiceIds.isNotEmpty) _buildPaymentSummary(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            // ── Right Panel ────────────────────────────────────
            Expanded(child: _buildInvoiceList()),
          ],
        ),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color.fromARGB(255, 3, 128, 115), Color.fromARGB(255, 26, 227, 207)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Receive Payment',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (selectedCustomer != null)
            Text(
              '${selectedCustomer!.name}  •  '
              'Outstanding: ${currencyFormat.format(customerTotalBalance)}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white60,
              ),
            ),
        ],
      ),
      foregroundColor: Colors.white,
    );
  }

  // ============================================================
  // PAYMENT FORM
  // ============================================================

  Widget _buildPaymentForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.payment_rounded,
                  color: kPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Payment Details',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Customer Dropdown ────────────────────────────────
          _buildLabel('SELECT CUSTOMER'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: kBorder, width: 1.5),
              borderRadius: BorderRadius.circular(10),
              color: kSurface,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Customer>(
                value: selectedCustomer,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: kPrimaryLight,
                ),
                hint: Text(
                  'Choose customer...',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: kSubText,
                  ),
                ),
                items: allCustomers.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_rounded,
                          size: 16,
                          color: kPrimaryLight,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            c.name,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: kText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) async {
                  setState(() {
                    selectedCustomer = val;
                    unpaidInvoices.clear();
                    selectedInvoiceIds.clear();
                    customerTotalBalance = 0.0;
                  });
                  if (val != null) await _loadUnpaidInvoices();
                },
              ),
            ),
          ),

          if (selectedCustomer != null) ...[
            const SizedBox(height: 16),

            // ── Outstanding Balance Banner ───────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kDebit.withOpacity(0.08),
                    kWarning.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: kDebit.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kDebit.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: kDebit,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Outstanding',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: kSubText,
                          ),
                        ),
                        Text(
                          currencyFormat.format(customerTotalBalance),
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: kDebit,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: kDebit,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${unpaidInvoices.length} Invoice${unpaidInvoices.length != 1 ? 's' : ''}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Divider(color: kBorder),
            const SizedBox(height: 20),

            // ── Payment Amount ───────────────────────────────
            _buildLabel('PAYMENT AMOUNT'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: paymentAmountController,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.payments_rounded,
              hintText: '0',
              suffixWidget: TextButton(
                onPressed:
                    selectedInvoiceIds.isEmpty ? null : _fillPaymentAmount,
                style: TextButton.styleFrom(foregroundColor: kPrimaryLight),
                child: Text(
                  'Fill Total',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Payment Date ─────────────────────────────────
            _buildLabel('PAYMENT DATE'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: kBorder, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                  color: kSurface,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 16,
                      color: kPrimaryLight,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      dateFormat.format(paymentDate),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: kText,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Payment Method ───────────────────────────────
            _buildLabel('PAYMENT METHOD'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: kBorder, width: 1.5),
                borderRadius: BorderRadius.circular(10),
                color: kSurface,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedPaymentMethod,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: kPrimaryLight,
                  ),
                  items: [
                    'Cash',
                    'Bank Transfer',
                    'Cheque',
                    'Credit Card',
                    'Other',
                  ]
                      .map(
                        (method) => DropdownMenuItem(
                          value: method,
                          child: Text(
                            method,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: kText,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setState(() => selectedPaymentMethod = val!),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Reference ───────────────────────────────────
            _buildLabel('REFERENCE (Optional)'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: referenceController,
              prefixIcon: Icons.tag_rounded,
              hintText: 'Cheque no., transfer ID...',
            ),

            const SizedBox(height: 16),

            // ── Notes ────────────────────────────────────────
            _buildLabel('NOTES (Optional)'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: notesController,
              prefixIcon: Icons.note_rounded,
              hintText: 'Any additional notes...',
              maxLines: 3,
            ),
          ],
        ],
      ),
    );
  }

  // ── Label ───────────────────────────────────────────────────
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: kSubText,
        letterSpacing: 1.0,
      ),
    );
  }

  // ── Text Field ──────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    TextInputType? keyboardType,
    IconData? prefixIcon,
    Widget? suffixWidget,
    String hintText = '',
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.poppins(fontSize: 13, color: kText),
      inputFormatters: keyboardType == TextInputType.number
          ? [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ]
          : null,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: kSubText),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 18, color: kSubText)
            : null,
        suffixIcon: suffixWidget,
        filled: true,
        fillColor: kSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kPrimary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
    );
  }

  // ============================================================
  // PAYMENT SUMMARY
  // ============================================================

  Widget _buildPaymentSummary() {
    final distribution = _calculatePaymentDistribution();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kPrimaryLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calculate_rounded,
                  color: kPrimaryLight,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Payment Distribution',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Summary rows
          _buildSummaryRow(
            'Selected Invoices',
            '${selectedInvoiceIds.length}',
            kPrimaryLight,
            Icons.receipt_rounded,
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Invoices Total',
            currencyFormat.format(selectedInvoicesTotal),
            kWarning,
            Icons.summarize_rounded,
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Payment Amount',
            currencyFormat.format(paymentAmount),
            kCredit,
            Icons.payments_rounded,
          ),

          if (distribution.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: kBorder),
            const SizedBox(height: 10),
            Text(
              'FIFO DISTRIBUTION',
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: kSubText,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            ...distribution.entries.map((entry) {
              final invoice = unpaidInvoices.firstWhere(
                (inv) => inv['id'] == entry.key,
              );
              final invoiceNumber = invoice['invoiceId'] as String;
              final invoiceBalance =
                  (invoice['balance'] as num).toDouble();
              final paymentForInvoice = entry.value;
              final willBePaid = paymentForInvoice >= invoiceBalance - 0.009;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: willBePaid
                      ? kCredit.withOpacity(0.07)
                      : kWarning.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: willBePaid
                        ? kCredit.withOpacity(0.25)
                        : kWarning.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INV-$invoiceNumber',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kText,
                            ),
                          ),
                          Text(
                            'Balance: ${currencyFormat.format(invoiceBalance)}',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: kSubText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currencyFormat.format(paymentForInvoice),
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: willBePaid ? kCredit : kWarning,
                          ),
                        ),
                        if (willBePaid)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: kCredit,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'PAID',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 16),

          // ── Process Button ───────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : _processPayment,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(
                isLoading ? 'Processing...' : 'Process Payment',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                shadowColor: kPrimary.withOpacity(0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: kSubText,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // INVOICE LIST
  // ============================================================

  Widget _buildInvoiceList() {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color.fromARGB(255, 3, 128, 115), Color.fromARGB(255, 26, 227, 207)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Unpaid Invoices',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                if (unpaidInvoices.isNotEmpty)
                  TextButton.icon(
                    onPressed: _selectAllInvoices,
                    icon: Icon(
                      selectedInvoiceIds.length == unpaidInvoices.length
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: Text(
                      selectedInvoiceIds.length == unpaidInvoices.length
                          ? 'Deselect All'
                          : 'Select All',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────
          Expanded(
            child: isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: kPrimary),
                        const SizedBox(height: 16),
                        Text(
                          'Loading invoices...',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: kSubText,
                          ),
                        ),
                      ],
                    ),
                  )
                : unpaidInvoices.isEmpty
                    ? _buildEmptyInvoiceState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: unpaidInvoices.length,
                        itemBuilder: (context, index) =>
                            _buildInvoiceCard(unpaidInvoices[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyInvoiceState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: selectedCustomer == null
                  ? kPrimary.withOpacity(0.06)
                  : kCredit.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              selectedCustomer == null
                  ? Icons.person_search_rounded
                  : Icons.check_circle_rounded,
              size: 56,
              color: selectedCustomer == null
                  ? kPrimary.withOpacity(0.3)
                  : kCredit,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            selectedCustomer == null
                ? 'Select a Customer'
                : ' All Cleared!',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectedCustomer == null
                ? 'Choose a customer to view unpaid invoices'
                : 'No outstanding invoices for this customer',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: kSubText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final invoiceId = invoice['id'] as int;
    final invoiceNumber = invoice['invoiceId'] as String;
    final date = DateTime.parse(invoice['dateTime'] as String);
    final totalAmount = (invoice['total'] as num).toDouble();
    final amountPaid = (invoice['amountPaid'] as num).toDouble();
    final balance = (invoice['balance'] as num).toDouble();
    final isSelected = selectedInvoiceIds.contains(invoiceId);
    final isPartial = amountPaid > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? kPrimary.withOpacity(0.04) : kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? kPrimary : kBorder,
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: kPrimary.withOpacity(0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              selectedInvoiceIds.remove(invoiceId);
            } else {
              selectedInvoiceIds.add(invoiceId);
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // ── Checkbox ──────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isSelected ? kPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? kPrimary : kSubText,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      )
                    : null,
              ),
              const SizedBox(width: 14),

              // ── Invoice Info ───────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'INV-$invoiceNumber',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: kText,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isPartial
                                ? kWarning.withOpacity(0.12)
                                : kDebit.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isPartial
                                  ? kWarning.withOpacity(0.4)
                                  : kDebit.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            isPartial ? 'PARTIAL' : 'UNPAID',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isPartial ? kWarning : kDebit,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          size: 12,
                          color: kSubText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(date),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: kSubText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Amounts ───────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Sale total (small)
                  Text(
                    'Total: ${currencyFormat.format(totalAmount)}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: kSubText,
                    ),
                  ),

                  // Amount paid (if partial)
                  if (isPartial) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Paid: ${currencyFormat.format(amountPaid)}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kCredit,
                      ),
                    ),
                  ],

                  const SizedBox(height: 4),

                  // Outstanding (big)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kDebit.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: kDebit.withOpacity(0.25),
                      ),
                    ),
                    child: Text(
                      currencyFormat.format(balance),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: kDebit,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}