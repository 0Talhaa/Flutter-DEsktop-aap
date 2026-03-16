// lib/reports/customer_ledger_report.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/models/customer.dart';
import 'package:medical_app/services/database_helper.dart';

class CustomerLedgerReport extends StatefulWidget {
  const CustomerLedgerReport({super.key});

  @override
  State<CustomerLedgerReport> createState() => _CustomerLedgerReportState();
}

class _CustomerLedgerReportState extends State<CustomerLedgerReport> {
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();
  Customer? selectedCustomer;
  List<Customer> customers = [];
  List<Map<String, dynamic>> ledgerEntries = [];
  List<Map<String, dynamic>> filteredEntries = [];

  // For All Customers Summary
  List<CustomerLedgerSummary> allCustomersSummary = [];
  bool showAllCustomers = false;

  double openingBalance = 0.0;
  double totalDebit = 0.0;
  double totalCredit = 0.0;
  double closingBalance = 0.0;

  bool isLoading = false;
  bool hasGenerated = false;
  String searchQuery = '';
  String selectedFilter = 'All';
  String customerSearchQuery = '';

  final currencyFormat = NumberFormat.currency(locale: 'en_PK', symbol: 'Rs. ', decimalDigits: 0);
  final TextEditingController searchController = TextEditingController();
  final TextEditingController customerSearchController = TextEditingController();

  final List<String> transactionFilters = ['All', 'Sales', 'Payments', 'Returns', 'Adjustments'];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final cust = await DatabaseHelper.instance.getAllCustomers();
    setState(() {
      customers = cust;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERATE LEDGER - HANDLES BOTH SINGLE AND ALL CUSTOMERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _generateLedger() async {
    setState(() {
      isLoading = true;
      hasGenerated = false;
      showAllCustomers = selectedCustomer == null;
    });

    try {
      final from = fromDate.toIso8601String().substring(0, 10);
      final to = toDate.toIso8601String().substring(0, 10);

      if (selectedCustomer == null) {
        // Generate ledger for ALL customers
        await _generateAllCustomersLedger(from, to);
      } else {
        // Generate ledger for single customer
        await _generateSingleCustomerLedger(from, to);
      }

      setState(() {
        isLoading = false;
        hasGenerated = true;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error generating ledger: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERATE LEDGER FOR ALL CUSTOMERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _generateAllCustomersLedger(String from, String to) async {
    ledgerEntries = [];
    allCustomersSummary = [];
    totalDebit = 0.0;
    totalCredit = 0.0;
    openingBalance = 0.0;
    closingBalance = 0.0;

    for (var customer in customers) {
      double customerOpeningBalance = customer.openingBalance;
      double customerTotalDebit = 0.0;
      double customerTotalCredit = 0.0;
      double runningBalance = customerOpeningBalance;

      // Get sales for this customer
      final sales = await DatabaseHelper.instance.getCustomerCreditSales(
        customer.id!,
        from,
        to,
      );

      // Add opening balance if > 0
      if (customerOpeningBalance != 0) {
        if (customerOpeningBalance > 0) {
          customerTotalDebit += customerOpeningBalance;
        } else {
          customerTotalCredit += customerOpeningBalance.abs();
        }

        ledgerEntries.add({
          'date': fromDate,
          'customerId': customer.id,
          'customerName': customer.name,
          'customerPhone': customer.phone,
          'type': 'Opening',
          'reference': '-',
          'description': 'Opening Balance',
          'debit': customerOpeningBalance > 0 ? customerOpeningBalance : 0.0,
          'credit': customerOpeningBalance < 0 ? customerOpeningBalance.abs() : 0.0,
          'balance': runningBalance,
          'icon': Icons.account_balance_wallet_outlined,
          'color': const Color(0xFF6366F1),
        });
      }

      // Process sales
      for (var sale in sales) {
        double saleBalance = (sale['balance'] as num).toDouble();
        double saleTotal = (sale['total'] as num).toDouble();
        double amountPaid = (sale['amountPaid'] as num?)?.toDouble() ?? 0.0;

        runningBalance += saleBalance;
        customerTotalDebit += saleTotal;

        ledgerEntries.add({
          'date': DateTime.parse(sale['dateTime']),
          'customerId': customer.id,
          'customerName': customer.name,
          'customerPhone': customer.phone,
          'type': 'Sale',
          'reference': 'INV-${sale['invoiceId']}',
          'description': 'Sale Invoice',
          'debit': saleTotal,
          'credit': 0.0,
          'balance': runningBalance,
          'details': sale,
          'icon': Icons.shopping_cart_outlined,
          'color': const Color(0xFFEF4444),
        });

        // If payment was made
        if (amountPaid > 0) {
          runningBalance -= amountPaid;
          customerTotalCredit += amountPaid;

          ledgerEntries.add({
            'date': DateTime.parse(sale['dateTime']),
            'customerId': customer.id,
            'customerName': customer.name,
            'customerPhone': customer.phone,
            'type': 'Payment',
            'reference': 'PAY-${sale['invoiceId']}',
            'description': 'Payment Received',
            'debit': 0.0,
            'credit': amountPaid,
            'balance': runningBalance,
            'icon': Icons.payments_outlined,
            'color': const Color(0xFF10B981),
          });
        }
      }

      double customerClosingBalance = runningBalance;

      // Add to summary
      allCustomersSummary.add(CustomerLedgerSummary(
        customer: customer,
        openingBalance: customerOpeningBalance,
        totalDebit: customerTotalDebit,
        totalCredit: customerTotalCredit,
        closingBalance: customerClosingBalance,
        transactionCount: sales.length,
      ));

      // Update totals
      openingBalance += customerOpeningBalance;
      totalDebit += customerTotalDebit;
      totalCredit += customerTotalCredit;
      closingBalance += customerClosingBalance;
    }

    // Sort entries by date
    ledgerEntries.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    // Sort summary by closing balance (highest first)
    allCustomersSummary.sort((a, b) => b.closingBalance.compareTo(a.closingBalance));

    filteredEntries = List.from(ledgerEntries);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERATE LEDGER FOR SINGLE CUSTOMER
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _generateSingleCustomerLedger(String from, String to) async {
    openingBalance = selectedCustomer!.openingBalance;
    allCustomersSummary = [];

    final sales = await DatabaseHelper.instance.getCustomerCreditSales(
      selectedCustomer!.id!,
      from,
      to,
    );

    ledgerEntries = [];
    totalDebit = 0.0;
    totalCredit = 0.0;

    double runningBalance = openingBalance;

    // Opening Balance entry
    ledgerEntries.add({
      'date': fromDate,
      'customerId': selectedCustomer!.id,
      'customerName': selectedCustomer!.name,
      'customerPhone': selectedCustomer!.phone,
      'type': 'Opening',
      'reference': '-',
      'description': 'Opening Balance',
      'debit': openingBalance > 0 ? openingBalance : 0.0,
      'credit': openingBalance < 0 ? openingBalance.abs() : 0.0,
      'balance': runningBalance,
      'icon': Icons.account_balance_wallet_outlined,
      'color': const Color(0xFF6366F1),
    });

    if (openingBalance > 0) {
      totalDebit += openingBalance;
    } else {
      totalCredit += openingBalance.abs();
    }

    // Sales entries
    for (var sale in sales) {
      double saleBalance = (sale['balance'] as num).toDouble();
      double saleTotal = (sale['total'] as num).toDouble();
      double amountPaid = (sale['amountPaid'] as num?)?.toDouble() ?? 0.0;

      runningBalance += saleBalance;
      totalDebit += saleTotal;

      ledgerEntries.add({
        'date': DateTime.parse(sale['dateTime']),
        'customerId': selectedCustomer!.id,
        'customerName': selectedCustomer!.name,
        'customerPhone': selectedCustomer!.phone,
        'type': 'Sale',
        'reference': 'INV-${sale['invoiceId']}',
        'description': 'Sale Invoice',
        'debit': saleTotal,
        'credit': 0.0,
        'balance': runningBalance,
        'details': sale,
        'icon': Icons.shopping_cart_outlined,
        'color': const Color(0xFFEF4444),
      });

      // If payment was made
      if (amountPaid > 0) {
        runningBalance -= amountPaid;
        totalCredit += amountPaid;

        ledgerEntries.add({
          'date': DateTime.parse(sale['dateTime']),
          'customerId': selectedCustomer!.id,
          'customerName': selectedCustomer!.name,
          'customerPhone': selectedCustomer!.phone,
          'type': 'Payment',
          'reference': 'PAY-${sale['invoiceId']}',
          'description': 'Payment Received',
          'debit': 0.0,
          'credit': amountPaid,
          'balance': runningBalance,
          'icon': Icons.payments_outlined,
          'color': const Color(0xFF10B981),
        });
      }
    }

    closingBalance = runningBalance;
    filteredEntries = List.from(ledgerEntries);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FILTER ENTRIES
  // ═══════════════════════════════════════════════════════════════════════════

  void _filterEntries() {
    setState(() {
      filteredEntries = ledgerEntries.where((entry) {
        bool matchesFilter = selectedFilter == 'All' || entry['type'] == selectedFilter;
        bool matchesSearch = searchQuery.isEmpty ||
            entry['description'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
            entry['reference'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
            (entry['customerName']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false);
        return matchesFilter && matchesSearch;
      }).toList();
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Get filtered customers for the list
  List<Customer> get filteredCustomers {
    if (customerSearchQuery.isEmpty) return customers;
    return customers.where((c) =>
        c.name.toLowerCase().contains(customerSearchQuery.toLowerCase()) ||
        c.phone.toLowerCase().contains(customerSearchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // Left Panel - Filters & Customer Selection
          Container(
            width: 320,
            margin: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildFilterPanel(),
                const SizedBox(height: 16),
                Expanded(child: _buildCustomerListPanel()),
              ],
            ),
          ),

          // Main Content - Ledger
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  if (hasGenerated) ...[
                    _buildSummaryCards(),
                    const SizedBox(height: 16),
                    if (showAllCustomers && allCustomersSummary.isNotEmpty)
                      // _buildCustomerSummaryPanel(),
                    if (showAllCustomers && allCustomersSummary.isNotEmpty)
                      const SizedBox(height: 16),
                    _buildLedgerToolbar(),
                    const SizedBox(height: 12),
                  ],
                  Expanded(child: _buildLedgerTable()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FILTER PANEL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.filter_list, color: Color(0xFF3B82F6), size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Date Range',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDateField('From Date', fromDate, (d) => setState(() => fromDate = d)),
          const SizedBox(height: 12),
          _buildDateField('To Date', toDate, (d) => setState(() => toDate = d)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickDateButton('7 Days', () {
                  setState(() {
                    fromDate = DateTime.now().subtract(const Duration(days: 7));
                    toDate = DateTime.now();
                  });
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickDateButton('30 Days', () {
                  setState(() {
                    fromDate = DateTime.now().subtract(const Duration(days: 30));
                    toDate = DateTime.now();
                  });
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildQuickDateButton('This Month', () {
                  final now = DateTime.now();
                  setState(() {
                    fromDate = DateTime(now.year, now.month, 1);
                    toDate = now;
                  });
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickDateButton('This Year', () {
                  final now = DateTime.now();
                  setState(() {
                    fromDate = DateTime(now.year, 1, 1);
                    toDate = now;
                  });
                }),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Generate Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : _generateLedger,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow, size: 18),
              label: Text(
                isLoading 
                  ? 'Generating...' 
                  : selectedCustomer == null 
                    ? 'Generate All Customers' 
                    : 'Generate Ledger'
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedCustomer == null 
                  ? const Color(0xFF8B5CF6) // Purple for all customers
                  : const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(String label, DateTime date, Function(DateTime) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 1)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(primary: Color(0xFF3B82F6)),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) onChanged(picked);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickDateButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CUSTOMER LIST PANEL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCustomerListPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_outline, size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                const Text(
                  'Select Customer',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
                const Spacer(),
                Text(
                  '${customers.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          
          // Search
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: customerSearchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search customer...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade400),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  customerSearchQuery = value;
                });
              },
            ),
          ),
          
          // "All Customers" Option
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  selectedCustomer = null;
                  hasGenerated = false;
                  ledgerEntries = [];
                  filteredEntries = [];
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selectedCustomer == null 
                    ? const Color(0xFF8B5CF6).withOpacity(0.1) 
                    : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selectedCustomer == null 
                      ? const Color(0xFF8B5CF6) 
                      : const Color(0xFFE2E8F0),
                    width: selectedCustomer == null ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.groups, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All Customers',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selectedCustomer == null 
                                ? const Color(0xFF8B5CF6) 
                                : const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'Generate combined ledger',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    if (selectedCustomer == null)
                      const Icon(Icons.check_circle, color: Color(0xFF8B5CF6), size: 20),
                  ],
                ),
              ),
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Divider(height: 1),
          ),
          
          // Customer List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: filteredCustomers.length,
              itemBuilder: (context, index) {
                final customer = filteredCustomers[index];
                final isSelected = selectedCustomer?.id == customer.id;
                final hasBalance = customer.openingBalance > 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        selectedCustomer = customer;
                        hasGenerated = false;
                        ledgerEntries = [];
                        filteredEntries = [];
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : const Color(0xFF64748B),
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
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  customer.phone,
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          if (hasBalance)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                currencyFormat.format(customer.openingBalance),
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                        ],
                      ),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: showAllCustomers 
                ? const Color(0xFF8B5CF6).withOpacity(0.1)
                : const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              showAllCustomers ? Icons.groups : Icons.receipt_long_outlined, 
              color: showAllCustomers ? const Color(0xFF8B5CF6) : const Color(0xFF6366F1), 
              size: 24
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                showAllCustomers ? 'All Customers Ledger' : 'Customer Ledger',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              if (hasGenerated)
                Row(
                  children: [
                    if (showAllCustomers)
                      Text(
                        '${allCustomersSummary.length} customers',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF8B5CF6), fontWeight: FontWeight.w500),
                      )
                    else if (selectedCustomer != null)
                      Text(
                        selectedCustomer!.name,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF3B82F6), fontWeight: FontWeight.w500),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${DateFormat('dd MMM').format(fromDate)} - ${DateFormat('dd MMM yyyy').format(toDate)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                )
              else
                Text(
                  selectedCustomer == null 
                    ? 'Click "Generate All Customers" to view combined ledger'
                    : 'Select a customer to view ledger',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
            ],
          ),
          const Spacer(),
          if (hasGenerated) ...[
            _buildHeaderAction(Icons.print_outlined, 'Print', () {}),
            const SizedBox(width: 8),
            _buildHeaderAction(Icons.download_outlined, 'Export', () {}),
            const SizedBox(width: 8),
            _buildHeaderAction(Icons.email_outlined, 'Email', () {}),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUMMARY CARDS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Balance', 
            openingBalance, 
            Icons.account_balance_wallet_outlined, 
            const Color(0xFF6366F1),
            subtitle: showAllCustomers ? '${allCustomersSummary.length} customers' : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Total Debit', 
            totalDebit, 
            Icons.arrow_upward, 
            const Color(0xFFEF4444),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Total Credit', 
            totalCredit, 
            Icons.arrow_downward, 
            const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Closing Balance', 
            closingBalance, 
            Icons.account_balance, 
            closingBalance > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981), 
            isHighlighted: true,
            subtitle: closingBalance > 0 ? 'Receivable' : 'Payable',
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title, 
    double amount, 
    IconData icon, 
    Color color, 
    {bool isHighlighted = false, String? subtitle}
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isHighlighted ? color.withOpacity(0.3) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    currencyFormat.format(amount),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isHighlighted ? color : const Color(0xFF1E293B),
                    ),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CUSTOMER SUMMARY PANEL (for All Customers view)
  // ═══════════════════════════════════════════════════════════════════════════

  // Widget _buildCustomerSummaryPanel() {
  //   // Show top 5 customers with highest balance
  //   final topCustomers = allCustomersSummary.take(5).toList();
    
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(12),
  //       border: Border.all(color: const Color(0xFFE2E8F0)),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           children: [
  //             const Icon(Icons.leaderboard, size: 18, color: Color(0xFF8B5CF6)),
  //             const SizedBox(width: 8),
  //             const Text(
  //               'Top Outstanding Balances',
  //               style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
  //             ),
  //             const Spacer(),
  //             TextButton.icon(
  //               onPressed: () => _showAllCustomersSummaryDialog(),
  //               icon: const Icon(Icons.visibility, size: 14),
  //               label: const Text('View All'),
  //               style: TextButton.styleFrom(
  //                 foregroundColor: const Color(0xFF8B5CF6),
  //                 textStyle: const TextStyle(fontSize: 12),
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 12),
  //         SingleChildScrollView(
  //           scrollDirection: Axis.horizontal,
  //           child: Row(
  //             children: topCustomers.map((summary) {
  //               return Container(
  //                 width: 180,
  //                 margin: const EdgeInsets.only(right: 12),
  //                 padding: const EdgeInsets.all(12),
  //                 decoration: BoxDecoration(
  //                   color: const Color(0xFFF8FAFC),
  //                   borderRadius: BorderRadius.circular(10),
  //                   border: Border.all(color: const Color(0xFFE2E8F0)),
  //                 ),
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Row(
  //                       children: [
  //                         Container(
  //                           width: 32,
  //                           height: 32,
  //                           decoration: BoxDecoration(
  //                             color: const Color(0xFF3B82F6).withOpacity(0.1),
  //                             borderRadius: BorderRadius.circular(6),
  //                           ),
  //                           child: Center(
  //                             child: Text(
  //                               summary.customer.name[0].toUpperCase(),
  //                               style: const TextStyle(
  //                                 fontSize: 12,
  //                                 fontWeight: FontWeight.w600,
  //                                 color: Color(0xFF3B82F6),
  //                               ),
  //                             ),
  //                           ),
  //                         ),
  //                         const SizedBox(width: 8),
  //                         Expanded(
  //                           child: Text(
  //                             summary.customer.name,
  //                             style: const TextStyle(
  //                               fontSize: 12,
  //                               fontWeight: FontWeight.w600,
  //                               color: Color(0xFF1E293B),
  //                             ),
  //                             maxLines: 1,
  //                             overflow: TextOverflow.ellipsis,
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                     const SizedBox(height: 8),
  //                     Text(
  //                       currencyFormat.format(summary.closingBalance),
  //                       style: TextStyle(
  //                         fontSize: 14,
  //                         fontWeight: FontWeight.w700,
  //                         color: summary.closingBalance > 0 
  //                           ? const Color(0xFFEF4444) 
  //                           : const Color(0xFF10B981),
  //                       ),
  //                     ),
  //                     Text(
  //                       '${summary.transactionCount} transactions',
  //                       style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
  //                     ),
  //                   ],
  //                 ),
  //               );
  //             }).toList(),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  void _showAllCustomersSummaryDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 700,
          height: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.groups, color: Color(0xFF8B5CF6), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'All Customers Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Expanded(flex: 3, child: Text('Customer', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600))),
                    Expanded(flex: 2, child: Text('Opening', textAlign: TextAlign.right, style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600))),
                    Expanded(flex: 2, child: Text('Debit', textAlign: TextAlign.right, style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600))),
                    Expanded(flex: 2, child: Text('Credit', textAlign: TextAlign.right, style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600))),
                    Expanded(flex: 2, child: Text('Closing', textAlign: TextAlign.right, style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: allCustomersSummary.length,
                  itemBuilder: (context, index) {
                    final summary = allCustomersSummary[index];
                    final isEven = index % 2 == 0;
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isEven ? Colors.white : const Color(0xFFFAFAFA),
                        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      summary.customer.name[0].toUpperCase(),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    summary.customer.name,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              currencyFormat.format(summary.openingBalance),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              currencyFormat.format(summary.totalDebit),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              currencyFormat.format(summary.totalCredit),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF10B981)),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: summary.closingBalance > 0 
                                  ? const Color(0xFFEF4444).withOpacity(0.1)
                                  : const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                currencyFormat.format(summary.closingBalance),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: summary.closingBalance > 0 
                                    ? const Color(0xFFEF4444) 
                                    : const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.w700)),
                    Row(
                      children: [
                        Text(
                          'Receivable: ${currencyFormat.format(closingBalance)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: closingBalance > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LEDGER TOOLBAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLedgerToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Search
          SizedBox(
            width: 250,
            child: TextField(
              controller: searchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: showAllCustomers ? 'Search by customer, reference...' : 'Search transactions...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade400),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                searchQuery = value;
                _filterEntries();
              },
            ),
          ),
          const SizedBox(width: 16),
          // Filter chips
          ...transactionFilters.map((filter) {
            final isActive = selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  setState(() => selectedFilter = filter);
                  _filterEntries();
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF3B82F6) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isActive ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
          const Spacer(),
          Text(
            '${filteredEntries.length} transactions',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LEDGER TABLE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLedgerTable() {
    if (!hasGenerated) {
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
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  selectedCustomer == null ? Icons.groups : Icons.receipt_long_outlined, 
                  size: 48, 
                  color: Colors.grey.shade400
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Ledger Generated',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                selectedCustomer == null 
                  ? 'Click "Generate All Customers" to view combined ledger'
                  : 'Select a customer and click "Generate Ledger"',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                if (showAllCustomers) _buildTableHeader('Customer', flex: 3),
                _buildTableHeader('Type', flex: 2),
                _buildTableHeader('Reference', flex: 2),
                _buildTableHeader('Description', flex: 3),
                _buildTableHeader('Debit', flex: 2, align: TextAlign.right),
                _buildTableHeader('Credit', flex: 2, align: TextAlign.right),
                _buildTableHeader('Balance', flex: 2, align: TextAlign.right),
              ],
            ),
          ),
          // Table Body
          Expanded(
            child: filteredEntries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No transactions found',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredEntries.length,
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];
                      final isEven = index % 2 == 0;

                      return InkWell(
                        onTap: entry['details'] != null
                            ? () => _showTransactionDetails(entry)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isEven ? Colors.white : const Color(0xFFFAFAFA),
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade100),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Date
                              Expanded(
                                flex: 2,
                                child: Text(
                                  DateFormat('dd MMM yyyy').format(entry['date']),
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                ),
                              ),
                              // Customer Name (only for all customers view)
                              if (showAllCustomers)
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Center(
                                          child: Text(
                                            (entry['customerName'] as String)[0].toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF3B82F6),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          entry['customerName'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF1E293B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // Type
                              Expanded(
                                flex: 2,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: (entry['color'] as Color).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(
                                        entry['icon'] as IconData,
                                        size: 12,
                                        color: entry['color'] as Color,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      entry['type'],
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: entry['color'] as Color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Reference
                              Expanded(
                                flex: 2,
                                child: Text(
                                  entry['reference'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                              ),
                              // Description
                              Expanded(
                                flex: 3,
                                child: Text(
                                  entry['description'],
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                                ),
                              ),
                              // Debit
                              Expanded(
                                flex: 2,
                                child: Text(
                                  entry['debit'] > 0 ? currencyFormat.format(entry['debit']) : '-',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: entry['debit'] > 0 ? const Color(0xFFEF4444) : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              // Credit
                              Expanded(
                                flex: 2,
                                child: Text(
                                  entry['credit'] > 0 ? currencyFormat.format(entry['credit']) : '-',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: entry['credit'] > 0 ? const Color(0xFF10B981) : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              // Balance
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: entry['balance'] > 0
                                        ? const Color(0xFFEF4444).withOpacity(0.1)
                                        : const Color(0xFF10B981).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    currencyFormat.format(entry['balance']),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: entry['balance'] > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Text(
                  showAllCustomers ? 'All Customers Total' : 'Total',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Debit', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    Text(
                      currencyFormat.format(totalDebit),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                    ),
                  ],
                ),
                const SizedBox(width: 32),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Credit', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    Text(
                      currencyFormat.format(totalCredit),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                    ),
                  ],
                ),
                const SizedBox(width: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: closingBalance > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        showAllCustomers ? 'Total Receivable' : 'Closing Balance',
                        style: const TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                      Text(
                        currencyFormat.format(closingBalance),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> entry) {
    final details = entry['details'] as Map<String, dynamic>?;
    if (details == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (entry['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(entry['icon'] as IconData, color: entry['color'] as Color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invoice #${details['invoiceId']}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.parse(details['dateTime'])),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Customer info for all customers view
              if (showAllCustomers && entry['customerName'] != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text(
                        entry['customerName'],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        entry['customerPhone'] ?? '',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              const Divider(),
              const SizedBox(height: 16),
              _buildDetailRow('Subtotal', currencyFormat.format(details['subtotal'] ?? 0)),
              _buildDetailRow('Discount', currencyFormat.format(details['discount'] ?? 0)),
              _buildDetailRow('Tax', currencyFormat.format(details['tax'] ?? 0)),
              const Divider(height: 24),
              _buildDetailRow('Total', currencyFormat.format(details['total'] ?? 0), isBold: true),
              _buildDetailRow('Amount Paid', currencyFormat.format(details['amountPaid'] ?? 0), color: const Color(0xFF10B981)),
              _buildDetailRow('Balance', currencyFormat.format(details['balance'] ?? 0), color: const Color(0xFFEF4444), isBold: true),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Print'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Close'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: color ?? const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    customerSearchController.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER CLASS FOR CUSTOMER SUMMARY
// ═══════════════════════════════════════════════════════════════════════════════

class CustomerLedgerSummary {
  final Customer customer;
  final double openingBalance;
  final double totalDebit;
  final double totalCredit;
  final double closingBalance;
  final int transactionCount;

  CustomerLedgerSummary({
    required this.customer,
    required this.openingBalance,
    required this.totalDebit,
    required this.totalCredit,
    required this.closingBalance,
    required this.transactionCount,
  });
}