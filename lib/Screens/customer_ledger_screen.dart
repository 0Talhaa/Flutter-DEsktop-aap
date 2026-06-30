// lib/screens/customer_ledger_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/models/customer.dart';
import 'package:medical_app/services/database_helper.dart';

class CustomerLedgerScreen extends StatefulWidget {
  const CustomerLedgerScreen({super.key});

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen>
    with SingleTickerProviderStateMixin {
  // ── Data ────────────────────────────────────────────────────
  List<Customer> allCustomers = [];
  List<Customer> filteredCustomers = [];
  Customer? selectedCustomer;
  List<Map<String, dynamic>> ledgerEntries = [];
  bool isLoading = false;

  // ── Date Range ───────────────────────────────────────────────
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();
  String selectedRange = '30D';

  // ── Summary ──────────────────────────────────────────────────
  double totalSales = 0.0;
  double totalPaymentsReceived = 0.0;
  double closingBalance = 0.0;
  double customerCurrentBalance = 0.0;

  // ── Animation ────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // ── Search ───────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();

  // ── Theme Colors (matching your app theme) ───────────────────
  // Primary: Colors.teal (from ColorScheme.fromSeed(seedColor: Colors.teal))
  static const Color kTeal = Color(0xFF009688); // Teal primary
  static const Color kTealDark = Color(0xFF00796B); // Teal dark
  static const Color kTealLight = Color(0xFF4DB6AC); // Teal light
  static const Color kTealBg = Color(0xFFE0F2F1); // Teal background tint
  static const Color kScaffoldBg = Color(0xFFF5F5F5); // grey[50]
  static const Color kCardBg = Colors.white;
  static const Color kDebit = Color(0xFFE53935); // Red
  static const Color kDebitBg = Color(0xFFFFEBEE);
  static const Color kCredit = Color(0xFF00897B); // Teal green
  static const Color kCreditBg = Color(0xFFE0F2F1);
  static const Color kTextDark = Color(0xFF1A1A1A); // grey[900]
  static const Color kTextMid = Color(0xFF616161); // grey[700]
  static const Color kTextLight = Color(0xFF9E9E9E); // grey[500]
  static const Color kBorder = Color(0xFFE0E0E0); // grey[300]
  static const Color kRowEven = Color(0xFFFFFFFF);
  static const Color kRowOdd = Color(0xFFFAFDFD);
  static const Color kHeaderBg = Color(0xFFE0F2F1); // Teal tint for header

  final currencyFormat = NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'Rs ',
    decimalDigits: 0,
  );
  final dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _loadCustomers();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Data Loading ─────────────────────────────────────────────
  Future<void> _loadCustomers() async {
    final customers = await DatabaseHelper.instance.getAllCustomers();
    setState(() {
      allCustomers = customers;
      filteredCustomers = customers;
    });
  }

  Future<void> _loadCustomerCurrentBalance() async {
    if (selectedCustomer == null) return;
    final db = await DatabaseHelper.instance.database;

    final salesResult = await db.rawQuery(
      'SELECT COALESCE(SUM(total), 0) as totalSales, '
      'COALESCE(SUM(amountPaid), 0) as totalPaid '
      'FROM sales WHERE customerId = ?',
      [selectedCustomer!.id],
    );

    final double ts =
        (salesResult.first['totalSales'] as num?)?.toDouble() ?? 0.0;
    final double tp =
        (salesResult.first['totalPaid'] as num?)?.toDouble() ?? 0.0;
    // final double ob = selectedCustomer!.openingBalance;

    setState(() => customerCurrentBalance =  ts - tp);
  }

  Future<void> _loadLedger() async {
    if (selectedCustomer == null) return;
    setState(() => isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;
      final fromStr = DateFormat('yyyy-MM-dd').format(fromDate);
      final toStr = DateFormat('yyyy-MM-dd').format(toDate);

      final salesResult = await db.query(
        'sales',
        where: 'customerId = ? AND DATE(dateTime) BETWEEN ? AND ?',
        whereArgs: [selectedCustomer!.id, fromStr, toStr],
        orderBy: 'dateTime ASC',
      );

      final paymentsResult = await db.query(
        'customer_payments',
        where: 'customerId = ? AND DATE(date) BETWEEN ? AND ?',
        whereArgs: [selectedCustomer!.id, fromStr, toStr],
        orderBy: 'date ASC',
      );

      final allEntries = <Map<String, dynamic>>[];

      for (var sale in salesResult) {
        allEntries.add({
          'type': 'sale',
          'date': sale['dateTime'] as String,
          'description': 'Sale Invoice #${sale['invoiceId']}',
          'debit': (sale['total'] as num).toDouble(),
          'credit': 0.0,
          'reference': 'INV-${sale['invoiceId']}',
        });

        final directPaid = (sale['amountPaid'] as num).toDouble();
        if (directPaid > 0) {
          allEntries.add({
            'type': 'direct_payment',
            'date': sale['dateTime'] as String,
            'description': 'Payment on Invoice #${sale['invoiceId']}',
            'debit': 0.0,
            'credit': directPaid,
            'reference': 'INV-${sale['invoiceId']}',
          });
        }
      }

      for (var payment in paymentsResult) {
        allEntries.add({
          'type': 'payment',
          'date': payment['date'] as String,
          'description':
              'Payment Received${payment['invoiceId'] != null ? ' — INV-${payment['invoiceId']}' : ''}',
          'debit': 0.0,
          'credit': (payment['amount'] as num).toDouble(),
          'reference': payment['reference'] ?? '',
          'paymentMethod': payment['paymentMethod'] ?? 'Cash',
          'notes': payment['notes'] ?? '',
        });
      }

      allEntries.sort(
        (a, b) => (a['date'] as String).compareTo(b['date'] as String),
      );

      double runningBalance = 0.0;
      final entries = <Map<String, dynamic>>[];
      for (var entry in allEntries) {
        runningBalance += (entry['debit'] as double);
        runningBalance -= (entry['credit'] as double);
        entries.add({...entry, 'balance': runningBalance});
      }

      closingBalance = runningBalance;

      totalSales = salesResult.fold(
        0.0,
        (sum, s) => sum + (s['total'] as num).toDouble(),
      );
      totalPaymentsReceived = paymentsResult.fold(
            0.0,
            (sum, p) => sum + (p['amount'] as num).toDouble(),
          ) +
          salesResult.fold(
            0.0,
            (sum, s) => sum + (s['amountPaid'] as num).toDouble(),
          );

      await _loadCustomerCurrentBalance();

      setState(() {
        ledgerEntries = entries;
        isLoading = false;
      });

      _animController
        ..reset()
        ..forward();
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading ledger: $e',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            backgroundColor: kDebit,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _filterCustomers(String query) {
    setState(() {
      filteredCustomers = query.isEmpty
          ? allCustomers
          : allCustomers
              .where((c) => c.name.toLowerCase().contains(query.toLowerCase()))
              .toList();
    });
  }

  void _setQuickRange(String label, int days) {
    setState(() {
      selectedRange = label;
      toDate = DateTime.now();
      fromDate = label == 'All'
          ? DateTime(2020, 1, 1)
          : DateTime.now().subtract(Duration(days: days));
    });
    if (selectedCustomer != null) _loadLedger();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate : toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: kTeal),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => isFrom ? fromDate = picked : toDate = picked);
      if (selectedCustomer != null) _loadLedger();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScaffoldBg,
      appBar: _buildAppBar(),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildFilterBar(),
                if (selectedCustomer != null) _buildSummaryCards(),
                Expanded(
                  child: selectedCustomer == null
                      ? _buildEmptyState()
                      : isLoading
                          ? _buildLoader()
                          : _buildLedgerContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kTeal,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
      ),
      title: Row(
        children: [
          const Icon(Icons.menu_book_rounded, size: 22, color: Colors.white),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer Ledger',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (selectedCustomer != null)
                Text(
                  selectedCustomer!.name,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        if (selectedCustomer != null) ...[
          // Entries badge
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                '${ledgerEntries.length} entries',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _loadLedger,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh',
          ),
        ],
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(3),
        child: Container(
          height: 3,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.0),
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Sidebar ──────────────────────────────────────────────────
  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: kBorder, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: kTealBg,
              border: Border(bottom: BorderSide(color: kBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SELECT CUSTOMER',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kTealDark,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                // Search Field
                TextField(
                  controller: _searchController,
                  onChanged: _filterCustomers,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: kTextDark,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search customer...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      color: kTextLight,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: kTeal,
                      size: 18,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kTeal, width: 2),
                    ),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),

          // Customer List
          Expanded(
            child: filteredCustomers.isEmpty
                ? Center(
                    child: Text(
                      'No customers found',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: kTextLight,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredCustomers.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: kBorder,
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, i) {
                      final c = filteredCustomers[i];
                      final isSelected = selectedCustomer?.id == c.id;
                      return _buildCustomerTile(c, isSelected);
                    },
                  ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: kBorder)),
              color: Colors.grey[50],
            ),
            child: Row(
              children: [
                Icon(Icons.people_alt_rounded, size: 15, color: kTextLight),
                const SizedBox(width: 6),
                Text(
                  '${filteredCustomers.length} of ${allCustomers.length} customers',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: kTextLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerTile(Customer customer, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          selectedCustomer = customer;
          ledgerEntries.clear();
          totalSales = 0;
          totalPaymentsReceived = 0;
          closingBalance = 0;
          customerCurrentBalance = 0;
        });
        _loadLedger();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        color: isSelected ? kTealBg : Colors.transparent,
        child: Row(
          children: [
            // Avatar circle
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected ? kTeal : Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  customer.name[0].toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : kTextMid,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? kTealDark : kTextDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (customer.phone.isNotEmpty)
                    Text(
                      customer.phone,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: kTextLight,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: kTeal,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Filter Bar ───────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: kBorder, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // From Date
          _buildDateBtn('FROM', fromDate, () => _pickDate(true)),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_rounded, size: 16, color: kTextLight),
          const SizedBox(width: 8),
          // To Date
          _buildDateBtn('TO', toDate, () => _pickDate(false)),

          const SizedBox(width: 20),
          Container(width: 1, height: 32, color: kBorder),
          const SizedBox(width: 20),

          // Quick Range label
          Text(
            'QUICK:',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: kTextLight,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 10),

          // Quick Buttons
          ...[('7D', 7), ('30D', 30), ('90D', 90), ('All', 0)]
              .map((e) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildQuickChip(e.$1, e.$2),
                  )),

          const Spacer(),

          // Date range display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: kTealBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${dateFormat.format(fromDate)}  →  ${dateFormat.format(toDate)}',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: kTealDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateBtn(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: kTextLight,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  dateFormat.format(date),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextDark,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.calendar_month_rounded, size: 16, color: kTeal),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, int days) {
    final isActive = selectedRange == label;
    return InkWell(
      onTap: () => _setQuickRange(label, days),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? kTeal : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? kTeal : kBorder,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: kTeal.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : kTextMid,
          ),
        ),
      ),
    );
  }

  // ── Summary Cards ────────────────────────────────────────────
  Widget _buildSummaryCards() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(
          children: [
            _buildSummaryCard(
              label: 'Period Sales',
              value: totalSales,
              icon: Icons.receipt_long_rounded,
              iconColor: kDebit,
              bgColor: kDebitBg,
              subtitle: 'Debit transactions',
            ),
            const SizedBox(width: 14),
            _buildSummaryCard(
              label: 'Period Payments',
              value: totalPaymentsReceived,
              icon: Icons.payments_rounded,
              iconColor: kCredit,
              bgColor: kCreditBg,
              subtitle: 'Credit received',
            ),
            const SizedBox(width: 14),
            _buildSummaryCard(
              label: 'Period Balance',
              value: closingBalance.abs(),
              icon: Icons.bar_chart_rounded,
              iconColor: const Color(0xFF1565C0),
              bgColor: const Color(0xFFE3F2FD),
              subtitle: closingBalance > 0
                  ? 'Closing debit'
                  : closingBalance < 0
                      ? 'Closing credit'
                      : 'Settled',
            ),
            const SizedBox(width: 14),
            _buildCurrentBalanceCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required double value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    String subtitle = '',
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: kTextLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currencyFormat.format(value),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kTextDark,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: kTextLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentBalanceCard() {
    final isDebit = customerCurrentBalance > 0;
    final isPaid = customerCurrentBalance == 0;
    final color = isPaid
        ? kCredit
        : isDebit
            ? kDebit
            : kCredit;
    final bgColor = isPaid
        ? kCreditBg
        : isDebit
            ? kDebitBg
            : kCreditBg;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4), width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isPaid
                    ? Icons.check_circle_rounded
                    : isDebit
                        ? Icons.account_balance_wallet_rounded
                        : Icons.trending_down_rounded,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Current Balance',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: kTextLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: kTealBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ALL TIME',
                          style: GoogleFonts.poppins(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: kTealDark,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPaid
                        ? '✓ Fully Paid'
                        : currencyFormat.format(customerCurrentBalance.abs()),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    isPaid
                        ? 'No outstanding dues'
                        : isDebit
                            ? 'Outstanding (Dr)'
                            : 'Overpaid (Cr)',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: color.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Ledger Content ───────────────────────────────────────────
  Widget _buildLedgerContent() {
    if (ledgerEntries.isEmpty) {
      return _buildNoTransactions();
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        children: [
          _buildTableHeader(),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: ledgerEntries.length,
              itemBuilder: (ctx, i) => _buildLedgerRow(i, ledgerEntries[i]),
            ),
          ),
          _buildTableFooter(),
        ],
      ),
    );
  }

  // ── Table Header ─────────────────────────────────────────────
  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: kHeaderBg,
        border: Border(
          bottom: BorderSide(color: kTeal.withOpacity(0.3), width: 2),
        ),
      ),
      child: Row(
        children: [
          _hCell('#', flex: 1, align: TextAlign.center),
          _hCell('Date', flex: 3, align: TextAlign.left),
          _hCell('Description', flex: 5, align: TextAlign.left),
          _hCell('Reference', flex: 2, align: TextAlign.left),
          _hCell('Debit (Dr)', flex: 3, align: TextAlign.right),
          _hCell('Credit (Cr)', flex: 3, align: TextAlign.right),
          _hCell('Balance', flex: 3, align: TextAlign.right),
        ],
      ),
    );
  }

  Widget _hCell(String text,
      {int flex = 1, TextAlign align = TextAlign.right}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: kTealDark,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ── Ledger Row ───────────────────────────────────────────────
  Widget _buildLedgerRow(int index, Map<String, dynamic> entry) {
    final isSale = entry['type'] == 'sale';
    final balance = entry['balance'] as double;
    final debit = entry['debit'] as double;
    final credit = entry['credit'] as double;

    final Color rowBg = index.isEven ? kRowEven : kRowOdd;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      decoration: BoxDecoration(
        color: rowBg,
        border: Border(
          bottom: BorderSide(color: kBorder.withOpacity(0.6)),
          left: BorderSide(
            color: isSale ? kDebit.withOpacity(0.5) : kCredit.withOpacity(0.5),
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          // Index
          Expanded(
            flex: 1,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: kTextLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Date
          Expanded(
            flex: 3,
            child: Text(
              _formatEntryDate(entry['date'] as String),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: kTextMid,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Description
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSale ? kDebitBg : kCreditBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isSale
                        ? Icons.shopping_bag_rounded
                        : Icons.payments_rounded,
                    size: 14,
                    color: isSale ? kDebit : kCredit,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry['description'] as String,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: kTextDark,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isSale ? 'Sale Transaction' : 'Payment Received',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: kTextLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Reference
          Expanded(
            flex: 2,
            child: (entry['reference'] as String?)?.isNotEmpty == true
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: kTealBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry['reference'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: kTealDark,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : const SizedBox(),
          ),

          // Debit
          Expanded(
            flex: 3,
            child: Text(
              debit > 0 ? currencyFormat.format(debit) : '—',
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: debit > 0 ? kDebit : Colors.grey[300],
              ),
            ),
          ),

          // Credit
          Expanded(
            flex: 3,
            child: Text(
              credit > 0 ? currencyFormat.format(credit) : '—',
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: credit > 0 ? kCredit : Colors.grey[300],
              ),
            ),
          ),

          // Balance
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: balance == 0
                    ? kCreditBg
                    : balance > 0
                        ? kDebitBg
                        : kCreditBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: balance == 0
                      ? kCredit.withOpacity(0.3)
                      : balance > 0
                          ? kDebit.withOpacity(0.25)
                          : kCredit.withOpacity(0.3),
                ),
              ),
              child: Text(
                balance == 0 ? '✓ PAID' : currencyFormat.format(balance.abs()),
                textAlign: TextAlign.right,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: balance == 0
                      ? kCredit
                      : balance > 0
                          ? kDebit
                          : kCredit,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Table Footer ─────────────────────────────────────────────
  Widget _buildTableFooter() {
    final isDebit = customerCurrentBalance > 0;
    final isPaid = customerCurrentBalance == 0;
    final color = isPaid
        ? kCredit
        : isDebit
            ? kDebit
            : kCredit;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: kTeal.withOpacity(0.2), width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Customer info
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: kTealBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_rounded, color: kTeal, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selectedCustomer?.name ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kTextDark,
                ),
              ),
              Text(
                '${ledgerEntries.length} transactions in period',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: kTextLight,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Period closing
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Period Closing',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: kTextLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                currencyFormat.format(closingBalance.abs()),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kTextDark,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Container(width: 1, height: 36, color: kBorder),
          const SizedBox(width: 20),

          // Outstanding Balance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.35), width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPaid
                      ? Icons.check_circle_rounded
                      : Icons.account_balance_rounded,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'OUTSTANDING BALANCE',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: color.withOpacity(0.7),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPaid
                          ? '✓  FULLY PAID'
                          : '${currencyFormat.format(customerCurrentBalance.abs())}  '
                              '${isDebit ? 'Dr' : 'Cr'}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Loader ───────────────────────────────────────────────────
  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: kTeal,
            strokeWidth: 3,
            backgroundColor: kTeal.withOpacity(0.1),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading ledger...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: kTextMid,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: kTealBg,
              shape: BoxShape.circle,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kTeal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_rounded,
                size: 56,
                color: kTeal.withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Select a Customer',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a customer from the left panel\nto view their complete ledger',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: kTextLight,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: kTealBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kTeal.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: kTealDark),
                const SizedBox(width: 6),
                Text(
                  'Current balance is calculated from all-time records',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: kTealDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── No Transactions ──────────────────────────────────────────
  Widget _buildNoTransactions() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 52,
              color: Colors.orange.shade300,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Transactions Found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No records in the selected date range',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: kTextLight,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _setQuickRange('All', 0),
            icon: const Icon(Icons.date_range_rounded, size: 16),
            label: Text(
              'View All Time Records',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatEntryDate(String dateStr) {
    try {
      return dateFormat.format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }
}
