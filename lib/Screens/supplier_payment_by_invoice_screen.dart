// lib/screens/supplier_payment_by_invoice_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/models/supplier.dart';
import 'package:medical_app/services/database_helper.dart';

class SupplierPaymentByInvoiceScreen extends StatefulWidget {
  const SupplierPaymentByInvoiceScreen({super.key});

  @override
  State<SupplierPaymentByInvoiceScreen> createState() =>
      _SupplierPaymentByInvoiceScreenState();
}

class _SupplierPaymentByInvoiceScreenState
    extends State<SupplierPaymentByInvoiceScreen> {
  // Controllers
  final TextEditingController paymentAmountController = TextEditingController();
  final TextEditingController referenceController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  // Data
  List<Supplier> allSuppliers = [];
  Supplier? selectedSupplier;
  List<Map<String, dynamic>> unpaidInvoices = [];
  Set<int> selectedInvoiceIds = {};
  bool isLoading = false;
  double supplierTotalBalance = 0.0;
  String selectedPaymentMethod = 'Cash';
  DateTime paymentDate = DateTime.now();

  final currencyFormat = NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );
  final dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  @override
  void dispose() {
    paymentAmountController.dispose();
    referenceController.dispose();
    notesController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    final suppliers = await DatabaseHelper.instance.getAllSuppliers();
    setState(() => allSuppliers = suppliers);
  }

  Future<void> _loadUnpaidInvoices() async {
    if (selectedSupplier == null) return;

    setState(() => isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;

      // Get unpaid/partially paid invoices
      final invoices = await db.query(
        'purchases',
        where: 'supplierId = ? AND balance > 0',
        whereArgs: [selectedSupplier!.id],
        orderBy: 'date ASC',
      );

      // Calculate total balance
      final balanceResult = await db.rawQuery('''
        SELECT COALESCE(SUM(balance), 0) as totalBalance
        FROM purchases
        WHERE supplierId = ?
      ''', [selectedSupplier!.id]);

      final totalBalance = (balanceResult.first['totalBalance'] as num).toDouble();

      setState(() {
        unpaidInvoices = invoices;
        supplierTotalBalance = totalBalance;
        selectedInvoiceIds.clear();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error loading invoices: $e');
    }
  }

  double get selectedInvoicesTotal {
    return unpaidInvoices
        .where((inv) => selectedInvoiceIds.contains(inv['id']))
        .fold(0.0, (sum, inv) => sum + (inv['balance'] as num).toDouble());
  }

  double get paymentAmount {
    return double.tryParse(paymentAmountController.text) ?? 0.0;
  }

  Map<int, double> _calculatePaymentDistribution() {
    Map<int, double> distribution = {};
    double remainingAmount = paymentAmount;

    // Sort selected invoices by date (FIFO)
    final selectedInvoices = unpaidInvoices
        .where((inv) => selectedInvoiceIds.contains(inv['id']))
        .toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

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

  Future<void> _processPayment() async {
    if (selectedSupplier == null) {
      _showErrorSnackBar('Please select a supplier');
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
        'selected invoices total (${currencyFormat.format(selectedInvoicesTotal)}). '
        'Excess amount will be ignored. Continue?',
      );
      if (!confirm) return;
    }

    setState(() => isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        double remainingAmount = paymentAmount;

        // Get selected invoices ordered by date
        final selectedInvoices = unpaidInvoices
            .where((inv) => selectedInvoiceIds.contains(inv['id']))
            .toList()
          ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

        for (var invoice in selectedInvoices) {
          if (remainingAmount <= 0) break;

          final invoiceId = invoice['id'] as int;
          final invoiceNumber = invoice['invoiceNumber'] as String;
          final currentBalance = (invoice['balance'] as num).toDouble();
          final currentAmountPaid = (invoice['amountPaid'] as num).toDouble();

          // Calculate payment for this invoice
          final paymentForInvoice =
              remainingAmount > currentBalance ? currentBalance : remainingAmount;

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
            'supplierId': selectedSupplier!.id,
            'supplierName': selectedSupplier!.name,
            'purchaseId': invoiceId,
            'invoiceNumber': invoiceNumber,
            'date': paymentDate.toIso8601String(),
            'amount': paymentForInvoice,
            'paymentMethod': selectedPaymentMethod,
            'reference': referenceController.text.isEmpty ? null : referenceController.text,
            'notes': notesController.text.isEmpty ? null : notesController.text,
            'createdAt': DateTime.now().toIso8601String(),
          });

          remainingAmount -= paymentForInvoice;
        }
      });

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Payment processed successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Reload invoices
      await _loadUnpaidInvoices();
      _clearForm();
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error processing payment: $e');
    }
  }

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
        selectedInvoiceIds = unpaidInvoices.map((inv) => inv['id'] as int).toSet();
      }
    });
  }

  void _fillPaymentAmount() {
    setState(() {
      paymentAmountController.text = selectedInvoicesTotal.toStringAsFixed(0);
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
      setState(() => paymentDate = picked);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<bool> _showConfirmDialog(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    appBar: AppBar(
      title: const Text('Pay Supplier Invoices'),
      backgroundColor: const Color(0xFF009688),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Left Panel - Scrollable
          SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildPaymentForm(),
                  const SizedBox(height: 16),
                  _buildPaymentSummary(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Right Panel - Invoice List
          Expanded(child: _buildInvoiceList()),
        ],
      ),
    ),
  );
}

  Widget _buildPaymentForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                  color: const Color(0xFF009688).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.payment, color: Color(0xFF009688), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Payment Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Supplier Selection
          const Text(
            'SELECT SUPPLIER',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
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
                hint: const Text(
                  'Choose supplier...',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
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
                onChanged: (val) async {
                  setState(() {
                    selectedSupplier = val;
                    unpaidInvoices.clear();
                    selectedInvoiceIds.clear();
                    supplierTotalBalance = 0.0;
                  });
                  if (val != null) {
                    await _loadUnpaidInvoices();
                  }
                },
              ),
            ),
          ),

          if (selectedSupplier != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFEF4444).withOpacity(0.1),
                    const Color(0xFFF59E0B).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Outstanding',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(supplierTotalBalance),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${unpaidInvoices.length} Invoices',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),

            // Payment Amount
            _buildTextField(
              label: 'PAYMENT AMOUNT',
              controller: paymentAmountController,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.payments,
              suffixWidget: TextButton(
                onPressed: _fillPaymentAmount,
                child: const Text('Fill Total', style: TextStyle(fontSize: 11)),
              ),
            ),

            const SizedBox(height: 16),

            // Payment Date
            const Text(
              'PAYMENT DATE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _selectDate,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFF8FAFC),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(
                      dateFormat.format(paymentDate),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Payment Method
            const Text(
              'PAYMENT METHOD',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
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
                child: DropdownButton<String>(
                  value: selectedPaymentMethod,
                  isExpanded: true,
                  items: ['Cash', 'Bank Transfer', 'Cheque', 'Credit Card', 'Other']
                      .map((method) => DropdownMenuItem(
                            value: method,
                            child: Text(method, style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => selectedPaymentMethod = val!),
                ),
              ),
            ),

            // const SizedBox(height: 16),

            // // Reference
            // _buildTextField(
            //   label: 'REFERENCE (Optional)',
            //   controller: referenceController,
            //   prefixIcon: Icons.receipt_long,
            // ),

            const SizedBox(height: 16),

            // Notes
            _buildTextField(
              label: 'NOTES (Optional)',
              controller: notesController,
              prefixIcon: Icons.note,
              maxLines: 3,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    IconData? prefixIcon,
    Widget? suffixWidget,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          inputFormatters: keyboardType == TextInputType.number
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
              : null,
          decoration: InputDecoration(
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 18, color: const Color(0xFF64748B))
                : null,
            suffixIcon: suffixWidget,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF009688), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSummary() {
  if (selectedInvoiceIds.isEmpty) return const SizedBox.shrink();

  final distribution = _calculatePaymentDistribution();

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calculate,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12), // ✅ Fixed missing spacing
              const Text(
                'Payment Distribution',
                style: TextStyle(
                  fontSize: 14, // ✅ Fixed font size (was 3!)
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
      
          _buildSummaryRow(
            'Selected Invoices',
            '${selectedInvoiceIds.length}',
            Colors.blue,
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Invoices Total',
            currencyFormat.format(selectedInvoicesTotal),
            Colors.orange,
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Payment Amount',
            currencyFormat.format(paymentAmount),
            Colors.green,
          ),
      
          if (distribution.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'FIFO Distribution:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            ...distribution.entries.map((entry) {
              final invoice =
                  unpaidInvoices.firstWhere((inv) => inv['id'] == entry.key);
              final invoiceNumber = invoice['invoiceNumber'] as String;
              final invoiceBalance = (invoice['balance'] as num).toDouble();
              final paymentForInvoice = entry.value;
              final willBePaid = paymentForInvoice >= invoiceBalance;
      
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: willBePaid
                      ? const Color(0xFF10B981).withOpacity(0.1)
                      : const Color(0xFFF59E0B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: willBePaid
                        ? const Color(0xFF10B981).withOpacity(0.3)
                        : const Color(0xFFF59E0B).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoiceNumber,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Balance: ${currencyFormat.format(invoiceBalance)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
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
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: willBePaid
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                        if (willBePaid)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'PAID',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
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
      
          // Process Button
          SizedBox(
            width: double.infinity,
            height: 48,
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
                  : const Icon(Icons.check_circle, size: 18),
              label: Text(isLoading ? 'Processing...' : 'Process Payment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF009688),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Unpaid Invoices',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                if (unpaidInvoices.isNotEmpty)
                  TextButton.icon(
                    onPressed: _selectAllInvoices,
                    icon: Icon(
                      selectedInvoiceIds.length == unpaidInvoices.length
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Select All',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),

          // Invoice List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : unpaidInvoices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              selectedSupplier == null
                                  ? Icons.person_search
                                  : Icons.check_circle_outline,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              selectedSupplier == null
                                  ? 'Select a supplier to view unpaid invoices'
                                  : 'No unpaid invoices for this supplier',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: unpaidInvoices.length,
                        itemBuilder: (context, index) {
                          final invoice = unpaidInvoices[index];
                          final invoiceId = invoice['id'] as int;
                          final invoiceNumber = invoice['invoiceNumber'] as String;
                          final date = DateTime.parse(invoice['date'] as String);
                          final totalAmount = (invoice['totalAmount'] as num).toDouble();
                          final amountPaid = (invoice['amountPaid'] as num).toDouble();
                          final balance = (invoice['balance'] as num).toDouble();
                          final isSelected = selectedInvoiceIds.contains(invoiceId);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF009688)
                                    : Colors.grey.shade200,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            color: isSelected
                                ? const Color(0xFF009688).withOpacity(0.05)
                                : Colors.white,
                            child: CheckboxListTile(
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    selectedInvoiceIds.add(invoiceId);
                                  } else {
                                    selectedInvoiceIds.remove(invoiceId);
                                  }
                                });
                              },
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      invoiceNumber,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: amountPaid > 0
                                          ? const Color(0xFFF59E0B).withOpacity(0.1)
                                          : const Color(0xFFEF4444).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: amountPaid > 0
                                            ? const Color(0xFFF59E0B).withOpacity(0.3)
                                            : const Color(0xFFEF4444).withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      amountPaid > 0 ? 'PARTIAL' : 'UNPAID',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: amountPaid > 0
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        dateFormat.format(date),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Total Amount',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                          Text(
                                            currencyFormat.format(totalAmount),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (amountPaid > 0)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Paid',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                            Text(
                                              currencyFormat.format(amountPaid),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF10B981),
                                              ),
                                            ),
                                          ],
                                        ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text(
                                            'Outstanding',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                          Text(
                                            currencyFormat.format(balance),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFEF4444),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              activeColor: const Color(0xFF009688),
                              checkboxShape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}