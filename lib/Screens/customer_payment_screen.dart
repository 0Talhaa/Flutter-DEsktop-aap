// lib/screens/customer_payment_screen.dart
//
// Customer Payment Screen — Record payments against invoices only
// Supports: Invoice-wise allocation, receipt preview
//

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/models/customer.dart';
import 'package:medical_app/services/database_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

/// Represents one unpaid / partially-paid invoice row shown in the screen
class _InvoiceRow {
  final int saleId;
  final String invoiceId;
  final DateTime dateTime;
  final double saleTotal;
  final double previouslyPaid;

  double allocatedNow; // amount the user is paying NOW against this row
  bool isSelected;

  _InvoiceRow({
    required this.saleId,
    required this.invoiceId,
    required this.dateTime,
    required this.saleTotal,
    required this.previouslyPaid,
    this.allocatedNow = 0,
    this.isSelected = false,
  });

  double get outstanding => max(0, saleTotal - previouslyPaid);
  double get afterPayment => max(0, outstanding - allocatedNow);
}

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class CustomerPaymentScreen extends StatefulWidget {
  final Customer? customer;

  const CustomerPaymentScreen({super.key, this.customer});

  @override
  State<CustomerPaymentScreen> createState() => _CustomerPaymentScreenState();
}

class _CustomerPaymentScreenState extends State<CustomerPaymentScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _amountFocus = FocusNode();

  // ── State ─────────────────────────────────────────────────────
  bool _loading = true;
  bool _saving = false;

  List<_InvoiceRow> _invoices = [];
  String _paymentMethod = 'Cash';
  String _applyMode = 'auto'; // 'auto' | 'manual'

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  final _currency = NumberFormat.currency(locale: 'en_PK', symbol: 'Rs. ', decimalDigits: 0);
  final _dateFormat = DateFormat('dd/MM/yyyy');

  // ── Derived ───────────────────────────────────────────────────
  double get _enteredAmount => double.tryParse(_amountController.text) ?? 0;
  double get _totalOutstanding =>
      _invoices.fold(0.0, (s, r) => s + r.outstanding);
  double get _totalAllocated =>
      _invoices.fold(0.0, (s, r) => s + r.allocatedNow);
  double get _unallocated => max(0, _enteredAmount - _totalAllocated);

  // ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fadeCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _amountController.addListener(_onAmountChanged);
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _amountFocus.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  //  LOAD INVOICES
  // ─────────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    if (widget.customer == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final db = DatabaseHelper.instance;
      final dbInstance = await db.database;
      
      // Get all credit sales for this customer (where balance > 0)
      final salesData = await dbInstance.query(
        'sales',
        where: 'customerId = ? AND balance > 0',
        whereArgs: [widget.customer!.id!],
        orderBy: 'dateTime ASC',
      );

      debugPrint('📊 Found ${salesData.length} unpaid/partially-paid invoices for customer ${widget.customer!.name}');

      final rows = <_InvoiceRow>[];
      for (final s in salesData) {
        final saleTotal = (s['total'] as num?)?.toDouble() ?? 0;
        final amountPaid = (s['amountPaid'] as num?)?.toDouble() ?? 0;
        final balance = (s['balance'] as num?)?.toDouble() ?? 0;
        
        // Only include if there's actually an outstanding balance
        if (balance <= 0) continue;

        debugPrint('  Invoice ${s['invoiceId']}: Total=$saleTotal, Paid=$amountPaid, Balance=$balance');

        rows.add(_InvoiceRow(
          saleId: s['id'] as int,
          invoiceId: s['invoiceId'] as String? ?? '---',
          dateTime: DateTime.tryParse(s['dateTime'] as String? ?? '') ?? DateTime.now(),
          saleTotal: saleTotal,
          previouslyPaid: amountPaid,
          allocatedNow: 0,
          isSelected: false,
        ));
      }

      setState(() {
        _invoices = rows;
        _loading = false;
      });
      _fadeCtrl.forward();
      
      debugPrint('✅ Loaded ${_invoices.length} invoice rows');
    } catch (e) {
      setState(() => _loading = false);
      _snack('Error loading invoices: $e', Colors.red);
      debugPrint('❌ Error loading invoices: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  AUTO-ALLOCATE
  // ─────────────────────────────────────────────────────────────
  void _onAmountChanged() {
    if (_applyMode == 'auto') _autoAllocate();
    setState(() {});
  }

  void _autoAllocate() {
    double remaining = _enteredAmount;

    // Pay invoices oldest-first
    for (final inv in _invoices) {
      if (remaining <= 0) {
        inv.allocatedNow = 0;
        inv.isSelected = false;
      } else {
        final pay = min(remaining, inv.outstanding);
        inv.allocatedNow = pay;
        inv.isSelected = pay > 0;
        remaining -= pay;
      }
    }
  }

  void _setManualAllocation(int idx, double value) {
    setState(() {
      _applyMode = 'manual';
      _invoices[idx].allocatedNow = value.clamp(0, _invoices[idx].outstanding);
      _invoices[idx].isSelected = value > 0;
    });
  }

  // ─────────────────────────────────────────────────────────────
  //  SAVE PAYMENT
  // ─────────────────────────────────────────────────────────────
  Future<void> _savePayment() async {
    if (_enteredAmount <= 0) {
      _snack('Enter a payment amount', Colors.orange);
      return;
    }
    if (_totalAllocated <= 0) {
      _snack('No amount allocated to any invoice', Colors.orange);
      return;
    }

    setState(() => _saving = true);
    try {
      final db = DatabaseHelper.instance;
      final now = DateTime.now();

      // 1. Record the overall customer payment
      await db.addCustomerPayment(
        customerId: widget.customer!.id!,
        customerName: widget.customer!.name,
        amount: _totalAllocated,
        date: now,
        paymentMethod: _paymentMethod,
        notes: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );

      // 2. Update each invoice's amountPaid and balance
      for (final inv in _invoices) {
        if (inv.allocatedNow <= 0) continue;
        final newPaid = inv.previouslyPaid + inv.allocatedNow;
        final newBalance = max(0.0, inv.outstanding - inv.allocatedNow);
        await db.updateSale(inv.saleId, {
          'amountPaid': newPaid,
          'balance': newBalance,
        });
        debugPrint('✅ Updated invoice ${inv.invoiceId}: newPaid=$newPaid, newBalance=$newBalance');
      }

      setState(() => _saving = false);
      if (mounted) {
        await _showReceiptDialog();
        Navigator.pop(context, true); // pop with refresh signal
      }
    } catch (e) {
      setState(() => _saving = false);
      _snack('Error: $e', Colors.red);
      debugPrint('❌ Error saving payment: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  RECEIPT DIALOG
  // ─────────────────────────────────────────────────────────────
  Future<void> _showReceiptDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PaymentReceiptDialog(
        customer: widget.customer!,
        amountPaid: _totalAllocated,
        invoices: _invoices.where((i) => i.allocatedNow > 0).toList(),
        paymentMethod: _paymentMethod,
        date: DateTime.now(),
        remainingBalance: max(0, _totalOutstanding - _totalAllocated),
        currency: _currency,
        dateFormat: _dateFormat,
      ),
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
    ));
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (widget.customer == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Select a customer from the Customers screen to record a payment.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnim,
              child: LayoutBuilder(builder: (ctx, constraints) {
                final wide = constraints.maxWidth >= 900;
                return wide ? _buildWideLayout() : _buildNarrowLayout();
              }),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  WIDE LAYOUT (two-column)
  // ─────────────────────────────────────────────────────────────
  Widget _buildWideLayout() {
    return Column(children: [
      _buildTopBar(),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // LEFT: payment entry
            SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(children: [
                  _buildCustomerCard(),
                  const SizedBox(height: 16),
                  _buildPaymentEntryCard(),
                  const SizedBox(height: 16),
                  _buildAllocationSummaryCard(),
                  const SizedBox(height: 16),
                  _buildSaveButton(),
                ]),
              ),
            ),
            const SizedBox(width: 20),
            // RIGHT: invoice table
            Expanded(
              child: Column(children: [
                _buildInvoiceTableHeader(),
                const SizedBox(height: 8),
                Expanded(child: _buildInvoiceTable()),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  //  NARROW LAYOUT (single column)
  // ─────────────────────────────────────────────────────────────
  Widget _buildNarrowLayout() {
    return Column(children: [
      _buildTopBar(),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            _buildCustomerCard(),
            const SizedBox(height: 14),
            _buildPaymentEntryCard(),
            const SizedBox(height: 14),
            _buildInvoiceTableHeader(),
            const SizedBox(height: 8),
            SizedBox(height: 360, child: _buildInvoiceTable()),
            const SizedBox(height: 14),
            _buildAllocationSummaryCard(),
            const SizedBox(height: 14),
            _buildSaveButton(),
            const SizedBox(height: 30),
          ]),
        ),
      ),
    ]);
  }

  // ─────────────────────────────────────────────────────────────
  //  TOP BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.payments_outlined, color: Colors.white70, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Receive Payment',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                Text('Record customer payment against invoices',
                    style: TextStyle(color: Colors.white60, fontSize: 11)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_dateFormat.format(DateTime.now()),
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  CUSTOMER CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildCustomerCard() {
    final initials = widget.customer!.name
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF3949AB), Color(0xFF5C6BC0)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.customer!.name,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A237E))),
            if ((widget.customer!.phone ?? '').isNotEmpty)
              Text(widget.customer!.phone!,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('Total Outstanding',
              style: TextStyle(fontSize: 10, color: Colors.grey)),
          Text(_currency.format(_totalOutstanding),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _totalOutstanding > 0
                      ? Colors.red.shade700
                      : Colors.green.shade700)),
        ]),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  PAYMENT ENTRY CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildPaymentEntryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Section title
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: const Color(0xFFE8EAF6),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.payments, color: Color(0xFF3949AB), size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Payment Details',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A237E))),
        ]),
        const SizedBox(height: 16),

        // Amount field
        const Text('Amount Received',
            style: TextStyle(fontSize: 12, color: Color(0xFF455A64))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF3949AB), width: 2),
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFFF8F9FF),
          ),
          child: TextField(
            controller: _amountController,
            focusNode: _amountFocus,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
            ],
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A237E)),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixText: 'Rs. ',
              prefixStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF3949AB)),
              hintText: '0',
              hintStyle: TextStyle(color: Color(0xFFB0BEC5), fontSize: 20),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Quick amount buttons
        Row(children: [
          _quickBtn('Pay Full', _totalOutstanding),
          const SizedBox(width: 6),
          _quickBtn('Clear', 0),
        ]),
        const SizedBox(height: 14),

        // Payment method
        const Text('Payment Method',
            style: TextStyle(fontSize: 12, color: Color(0xFF455A64))),
        const SizedBox(height: 6),
        _buildPaymentMethodSelector(),
        const SizedBox(height: 14),

        // Note
        const Text('Note (optional)',
            style: TextStyle(fontSize: 12, color: Color(0xFF455A64))),
        const SizedBox(height: 6),
        TextField(
          controller: _noteController,
          maxLines: 2,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Add reference or note…',
            hintStyle:
                TextStyle(color: Colors.grey.shade400, fontSize: 13),
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF3949AB))),
          ),
        ),

        // Allocation mode toggle
        const SizedBox(height: 14),
        Row(children: [
          const Text('Allocation Mode:',
              style: TextStyle(fontSize: 12, color: Color(0xFF455A64))),
          const SizedBox(width: 8),
          _modeChip('Auto', 'auto'),
          const SizedBox(width: 6),
          _modeChip('Manual', 'manual'),
        ]),
      ]),
    );
  }

  Widget _quickBtn(String label, double amount) {
    return InkWell(
      onTap: () => setState(() {
        _amountController.text = amount.toStringAsFixed(0);
        if (_applyMode == 'auto') _autoAllocate();
      }),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE8EAF6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFC5CAE9)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3949AB))),
      ),
    );
  }

  Widget _modeChip(String label, String value) {
    final active = _applyMode == value;
    return GestureDetector(
      onTap: () {
        setState(() => _applyMode = value);
        if (value == 'auto') _autoAllocate();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF3949AB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? const Color(0xFF3949AB) : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : Colors.grey.shade600)),
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    const methods = ['Cash', 'Bank Transfer', 'Cheque', 'Online'];
    return Row(children: methods.map((m) {
      final active = _paymentMethod == m;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _paymentMethod = m),
          child: Container(
            margin: EdgeInsets.only(right: m == methods.last ? 0 : 6),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF3949AB) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: active
                      ? const Color(0xFF3949AB)
                      : Colors.grey.shade300),
            ),
            child: Text(m,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : Colors.grey.shade600)),
          ),
        ),
      );
    }).toList());
  }

  // ─────────────────────────────────────────────────────────────
  //  ALLOCATION SUMMARY CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildAllocationSummaryCard() {
    final newBalance = max(0.0, _totalOutstanding - _totalAllocated);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF1A237E).withOpacity(0.3), blurRadius: 12)
        ],
      ),
      child: Column(children: [
        _summaryRow('Amount Entered', _enteredAmount, Colors.white70),
        const SizedBox(height: 8),
        _summaryRow('Allocated to Invoices', _totalAllocated, Colors.lightBlue.shade200),
        const Divider(color: Colors.white24, height: 16),
        _summaryRow('Total Allocated', _totalAllocated, Colors.white,
            bold: true, fontSize: 15),
        if (_unallocated > 0) ...[
          const SizedBox(height: 4),
          _summaryRow('Unallocated (Advance)', _unallocated,
              Colors.orange.shade200),
        ],
        const Divider(color: Colors.white24, height: 16),
        _summaryRow('Remaining Balance After', newBalance,
            newBalance > 0 ? Colors.red.shade300 : Colors.green.shade300,
            bold: true, fontSize: 15),
      ]),
    );
  }

  Widget _summaryRow(String label, double value, Color color,
      {bool bold = false, double fontSize = 12}) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: fontSize,
                  color: Colors.white70,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
          Text(_currency.format(value),
              style: TextStyle(
                  fontSize: fontSize,
                  color: color,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ]);
  }

  // ─────────────────────────────────────────────────────────────
  //  SAVE BUTTON
  // ─────────────────────────────────────────────────────────────
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _saving ? null : _savePayment,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.check_circle_outline, size: 20),
        label: Text(_saving ? 'Saving…' : 'Save Payment & Print Receipt',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 4,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  INVOICE TABLE HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildInvoiceTableHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(children: [
        _th('Invoice', flex: 2),
        _th('Date', flex: 2),
        _th('Total', flex: 2),
        _th('Paid', flex: 2),
        _th('Outstanding', flex: 2),
        _th('Pay Now', flex: 2),
        _th('After', flex: 2),
      ]),
    );
  }

  Widget _th(String text, {int flex = 1}) => Expanded(
      flex: flex,
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF455A64))));

  // ─────────────────────────────────────────────────────────────
  //  INVOICE TABLE
  // ─────────────────────────────────────────────────────────────
  Widget _buildInvoiceTable() {
    if (_invoices.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle_outline, size: 48, color: Colors.green.shade300),
            const SizedBox(height: 12),
            Text('No outstanding invoices',
                style: TextStyle(color: Colors.green.shade600, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('All invoices have been paid',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ]),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)
        ],
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _invoices.length,
        itemBuilder: (context, idx) {
          final inv = _invoices[idx];
          final isHighlighted = inv.isSelected;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? const Color(0xFFE8EAF6)
                  : (idx.isEven ? Colors.white : const Color(0xFFFAFAFA)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isHighlighted
                      ? const Color(0xFF3949AB)
                      : Colors.transparent),
            ),
            child: Row(children: [
              // Invoice ID
              Expanded(
                flex: 2,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                  Text('INV${inv.invoiceId}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A237E))),
                ]),
              ),
              // Date
              Expanded(
                flex: 2,
                child: Text(_dateFormat.format(inv.dateTime),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF546E7A))),
              ),
              // Sale total
              Expanded(
                flex: 2,
                child: Text(_currency.format(inv.saleTotal),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10)),
              ),
              // Previously paid
              Expanded(
                flex: 2,
                child: Text(_currency.format(inv.previouslyPaid),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10, color: Colors.green.shade700)),
              ),
              // Outstanding
              Expanded(
                flex: 2,
                child: Text(_currency.format(inv.outstanding),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade600)),
              ),
              // Pay now (editable)
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: TextField(
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'))
                    ],
                    controller: TextEditingController(
                        text: inv.allocatedNow.toStringAsFixed(0))
                      ..selection = TextSelection.collapsed(
                          offset: inv.allocatedNow
                              .toStringAsFixed(0)
                              .length),
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: isHighlighted
                          ? Colors.white
                          : Colors.blue.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 7),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                              color: Color(0xFF3949AB), width: 2)),
                    ),
                    onChanged: (v) {
                      _setManualAllocation(
                          idx, double.tryParse(v) ?? 0);
                    },
                  ),
                ),
              ),
              // Balance after
              Expanded(
                flex: 2,
                child: Text(
                    _currency.format(inv.afterPayment),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: inv.afterPayment > 0
                            ? Colors.orange.shade700
                            : Colors.green.shade700)),
              ),
            ]),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RECEIPT DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentReceiptDialog extends StatelessWidget {
  final Customer customer;
  final double amountPaid;
  final List<_InvoiceRow> invoices;
  final String paymentMethod;
  final DateTime date;
  final double remainingBalance;
  final NumberFormat currency;
  final DateFormat dateFormat;

  const _PaymentReceiptDialog({
    required this.customer,
    required this.amountPaid,
    required this.invoices,
    required this.paymentMethod,
    required this.date,
    required this.remainingBalance,
    required this.currency,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    final receiptNo =
        'RCP-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 420,
        constraints: const BoxConstraints(maxHeight: 640),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF283593)]),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 40),
              const SizedBox(height: 8),
              const Text('Payment Received',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(currency.format(amountPaid),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Receipt No: $receiptNo',
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 11)),
            ]),
          ),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // Customer + meta
                _receiptRow('Customer', customer.name),
                _receiptRow('Date', dateFormat.format(date)),
                _receiptRow('Payment Method', paymentMethod),
                const Divider(height: 20),

                // Invoice breakdown
                if (invoices.isNotEmpty) ...[
                  const Text('Invoice-wise Breakdown:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A237E))),
                  const SizedBox(height: 8),
                  ...invoices.map((inv) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(children: [
                          Expanded(
                              child: Text(
                            'INV${inv.invoiceId}  •  ${dateFormat.format(inv.dateTime)}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF37474F)),
                          )),
                          Text(currency.format(inv.allocatedNow),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green.shade700)),
                          const SizedBox(width: 8),
                          Text(
                              inv.afterPayment > 0
                                  ? '(Rem: ${currency.format(inv.afterPayment)})'
                                  : '(Cleared ✓)',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: inv.afterPayment > 0
                                      ? Colors.red.shade400
                                      : Colors.green.shade600)),
                        ]),
                      )),
                ],

                const Divider(height: 20),

                // Final remaining
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: remainingBalance > 0
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: remainingBalance > 0
                            ? Colors.red.shade200
                            : Colors.green.shade200),
                  ),
                  child: Row(children: [
                    Icon(
                        remainingBalance > 0
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle,
                        color: remainingBalance > 0
                            ? Colors.red.shade500
                            : Colors.green.shade600,
                        size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          remainingBalance > 0
                              ? 'Remaining Balance'
                              : 'All Invoices Cleared',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: remainingBalance > 0
                                  ? Colors.red.shade700
                                  : Colors.green.shade700)),
                    ),
                    if (remainingBalance > 0)
                      Text(currency.format(remainingBalance),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.red.shade700)),
                  ]),
                ),
              ]),
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Close'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('Print'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _receiptRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF546E7A))),
            Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color ?? const Color(0xFF1E293B))),
          ]),
    );
  }
}