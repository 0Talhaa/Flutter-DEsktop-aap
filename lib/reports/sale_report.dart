// lib/screens/reports/sale_report.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/services/database_helper.dart';

class SaleReport extends StatefulWidget {
  const SaleReport({super.key});

  @override
  State<SaleReport> createState() => _SaleReportState();
}

class _SaleReportState extends State<SaleReport> {
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();

  List<Map<String, dynamic>> sales = [];
  List<Map<String, dynamic>> filteredSales = [];
  bool isLoading = true;

  String searchQuery = '';
  String selectedFilter = 'All';
  String sortBy = 'Date (Newest)';

  // Summary metrics
  double totalSales = 0.0;
  double cashReceived = 0.0;
  double creditSales = 0.0;
  double totalBalance = 0.0;
  int totalInvoices = 0;
  int totalItemsSold = 0;
  int paidInvoices = 0;
  int creditInvoices = 0;

  final currencyFormat = NumberFormat.currency(locale: 'en_PK', symbol: 'Rs. ', decimalDigits: 0);
  final TextEditingController searchController = TextEditingController();

  final List<String> paymentFilters = [
    'All',
    'Fully Paid',
    'Partial Payment',
    'Credit Only',
  ];

  final List<String> sortOptions = [
    'Date (Newest)',
    'Date (Oldest)',
    'Amount (High to Low)',
    'Amount (Low to High)',
    'Customer Name',
  ];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => isLoading = true);

    try {
      final from = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final to = DateTime(toDate.year, toDate.month, toDate.day).add(const Duration(days: 1));

      final allSales = await DatabaseHelper.instance.getSalesInDateRange(
        from.toIso8601String(),
        to.toIso8601String(),
      );

      double total = 0.0;
      double cash = 0.0;
      double credit = 0.0;
      double balance = 0.0;
      int itemsCount = 0;
      int paid = 0;
      int creditCount = 0;

      for (var sale in allSales) {
        double saleTotal = sale['total'] as double;
        double amountPaid = sale['amountPaid'] as double;
        double saleBalance = sale['balance'] as double;

        total += saleTotal;
        cash += amountPaid;
        credit += (saleTotal - amountPaid);
        balance += saleBalance;

        if (saleBalance == 0) {
          paid++;
        } else if (amountPaid == 0) {
          creditCount++;
        }

        final List items = sale['items'] as List;
        itemsCount += items.length;
      }

      setState(() {
        sales = allSales;
        totalSales = total;
        cashReceived = cash;
        creditSales = credit;
        totalBalance = balance;
        totalInvoices = allSales.length;
        totalItemsSold = itemsCount;
        paidInvoices = paid;
        creditInvoices = creditCount;
        isLoading = false;
        _applyFiltersAndSort();
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error loading sales: $e');
    }
  }

  void _applyFiltersAndSort() {
    List<Map<String, dynamic>> filtered = List.from(sales);

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((sale) {
        final invoiceId = 'INV${sale['invoiceId']}'.toLowerCase();
        final customerName = (sale['customerName'] ?? 'Walk-in').toLowerCase();
        final query = searchQuery.toLowerCase();
        return invoiceId.contains(query) || customerName.contains(query);
      }).toList();
    }

    // Apply payment status filter
    switch (selectedFilter) {
      case 'Fully Paid':
        filtered = filtered.where((sale) => sale['balance'] == 0).toList();
        break;
      case 'Partial Payment':
        filtered = filtered.where((sale) {
          double balance = sale['balance'] as double;
          double paid = sale['amountPaid'] as double;
          return balance > 0 && paid > 0;
        }).toList();
        break;
      case 'Credit Only':
        filtered = filtered.where((sale) => sale['amountPaid'] == 0).toList();
        break;
    }

    // Apply sorting
    switch (sortBy) {
      case 'Date (Newest)':
        filtered.sort((a, b) => DateTime.parse(b['dateTime']).compareTo(DateTime.parse(a['dateTime'])));
        break;
      case 'Date (Oldest)':
        filtered.sort((a, b) => DateTime.parse(a['dateTime']).compareTo(DateTime.parse(b['dateTime'])));
        break;
      case 'Amount (High to Low)':
        filtered.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
        break;
      case 'Amount (Low to High)':
        filtered.sort((a, b) => (a['total'] as double).compareTo(b['total'] as double));
        break;
      case 'Customer Name':
        filtered.sort((a, b) => (a['customerName'] ?? 'Walk-in').compareTo(b['customerName'] ?? 'Walk-in'));
        break;
    }

    setState(() {
      filteredSales = filtered;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // Left Panel - Filters & Date Range
          Container(
            width: 300,
            margin: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDateRangePanel(),
                const SizedBox(height: 16),
                _buildFilterPanel(),
                const SizedBox(height: 16),
                _buildQuickStats(),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildSummaryCards(),
                  const SizedBox(height: 16),
                  _buildRevenueBreakdown(),
                  const SizedBox(height: 16),
                  _buildToolbar(),
                  const SizedBox(height: 12),
                  Expanded(child: _buildSalesTable()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangePanel() {
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
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.date_range, color: Color(0xFF10B981), size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Date Range',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDateField('From', fromDate, (d) => setState(() => fromDate = d)),
          const SizedBox(height: 12),
          _buildDateField('To', toDate, (d) => setState(() => toDate = d)),
          const SizedBox(height: 16),
          // Quick Date Buttons
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildQuickDateChip('Today', () {
                setState(() {
                  fromDate = DateTime.now();
                  toDate = DateTime.now();
                });
              }),
              _buildQuickDateChip('Yesterday', () {
                final yesterday = DateTime.now().subtract(const Duration(days: 1));
                setState(() {
                  fromDate = yesterday;
                  toDate = yesterday;
                });
              }),
              _buildQuickDateChip('Last 7 Days', () {
                setState(() {
                  fromDate = DateTime.now().subtract(const Duration(days: 7));
                  toDate = DateTime.now();
                });
              }),
              _buildQuickDateChip('Last 30 Days', () {
                setState(() {
                  fromDate = DateTime.now().subtract(const Duration(days: 30));
                  toDate = DateTime.now();
                });
              }),
              _buildQuickDateChip('This Month', () {
                final now = DateTime.now();
                setState(() {
                  fromDate = DateTime(now.year, now.month, 1);
                  toDate = now;
                });
              }),
              _buildQuickDateChip('Last Month', () {
                final now = DateTime.now();
                final lastMonth = DateTime(now.year, now.month - 1, 1);
                final lastDay = DateTime(now.year, now.month, 0);
                setState(() {
                  fromDate = lastMonth;
                  toDate = lastDay;
                });
              }),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : _loadReport,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow, size: 18),
              label: Text(isLoading ? 'Loading...' : 'Generate Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
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
                    colorScheme: const ColorScheme.light(primary: Color(0xFF10B981)),
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
                Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickDateChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
        ),
      ),
    );
  }

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
                child: const Icon(Icons.filter_list, color: Color(0xFF3B82F6), size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Filters',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Payment Status Filters
          const Text(
            'Payment Status',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          ...paymentFilters.map((filter) {
            final isActive = selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () {
                  setState(() {
                    selectedFilter = filter;
                    _applyFiltersAndSort();
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF3B82F6).withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive ? const Color(0xFF3B82F6) : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getFilterIcon(filter),
                        size: 16,
                        color: isActive ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          filter,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                            color: isActive ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      if (isActive)
                        const Icon(Icons.check, size: 16, color: Color(0xFF3B82F6)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),

          // const Divider(),
          // const SizedBox(height: 16),
          // const SizedBox(height: 16),

          // Sort Options
          // const Text(
          //   'Sort By',
          //   style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          // ),
          // const SizedBox(height: 8),
          // Container(
          //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          //   decoration: BoxDecoration(
          //     color: const Color(0xFFF8FAFC),
          //     borderRadius: BorderRadius.circular(8),
          //     border: Border.all(color: const Color(0xFFE2E8F0)),
          //   ),
          //   child: DropdownButton<String>(
          //     value: sortBy,
          //     isExpanded: true,
          //     underline: const SizedBox(),
          //     style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
          //     icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
          //     items: sortOptions.map((option) {
          //       return DropdownMenuItem(
          //         value: option,
          //         child: Text(option),
          //       );
          //     }).toList(),
          //     onChanged: (value) {
          //       if (value != null) {
          //         setState(() {
          //           sortBy = value;
          //           _applyFiltersAndSort();
          //         });
          //       }
          //     },
          //   ),
          // ),

          // const SizedBox(height: 16),

          // Clear Filters Button
          // SizedBox(
          //   width: double.infinity,
          //   child: OutlinedButton.icon(
          //     onPressed: () {
          //       setState(() {
          //         selectedFilter = 'All';
          //         sortBy = 'Date (Newest)';
          //         searchQuery = '';
          //         searchController.clear();
          //         _applyFiltersAndSort();
          //       });
          //     },
          //     icon: const Icon(Icons.clear_all, size: 16),
          //     label: const Text('Clear All'),
          //     style: OutlinedButton.styleFrom(
          //       foregroundColor: const Color(0xFF64748B),
          //       padding: const EdgeInsets.symmetric(vertical: 12),
          //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'All':
        return Icons.receipt_long;
      case 'Fully Paid':
        return Icons.check_circle_outline;
      case 'Partial Payment':
        return Icons.payment;
      case 'Credit Only':
        return Icons.credit_card;
      default:
        return Icons.receipt_long;
    }
  }

  Widget _buildQuickStats() {
    return Expanded(
      child: Container(
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
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.insights, color: Color(0xFF8B5CF6), size: 16),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Quick Stats',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildQuickStatItem(
                      'Total Invoices',
                      totalInvoices.toString(),
                      Icons.receipt_long,
                      const Color(0xFF3B82F6),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickStatItem(
                      'Fully Paid',
                      paidInvoices.toString(),
                      Icons.check_circle,
                      const Color(0xFF10B981),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickStatItem(
                      'Credit Sales',
                      creditInvoices.toString(),
                      Icons.credit_card,
                      const Color(0xFFF59E0B),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickStatItem(
                      'Items Sold',
                      totalItemsSold.toString(),
                      Icons.inventory,
                      const Color(0xFF8B5CF6),
                    ),
                    const Divider(height: 24),
                    _buildQuickStatItem(
                      'Avg. Invoice',
                      totalInvoices > 0 ? currencyFormat.format(totalSales / totalInvoices) : 'Rs. 0',
                      Icons.calculate,
                      const Color(0xFF06B6D4),
                      isAmount: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatItem(String label, String value, IconData icon, Color color, {bool isAmount = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isAmount ? 11 : 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.point_of_sale, color: Color(0xFF10B981), size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sales Report',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              Text(
                '${DateFormat('dd MMM').format(fromDate)} - ${DateFormat('dd MMM yyyy').format(toDate)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          const Spacer(),
          _buildHeaderAction(Icons.refresh, 'Refresh', _loadReport),
          const SizedBox(width: 8),
          _buildHeaderAction(Icons.print_outlined, 'Print', () {}),
          const SizedBox(width: 8),
          _buildHeaderAction(Icons.download_outlined, 'Export', () {}),
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

  Widget _buildSummaryCards() {
    final collectionRate = totalSales > 0 ? (cashReceived / totalSales * 100) : 0;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Sales',
            currencyFormat.format(totalSales),
            Icons.point_of_sale,
            const Color(0xFF3B82F6),
            subtitle: '$totalInvoices invoices',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Cash Received',
            currencyFormat.format(cashReceived),
            Icons.account_balance_wallet,
            const Color(0xFF10B981),
            subtitle: '$paidInvoices paid',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Credit Sales',
            currencyFormat.format(creditSales),
            Icons.credit_card,
            const Color(0xFFF59E0B),
            subtitle: '$creditInvoices credit',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Collection Rate',
            '${collectionRate.toStringAsFixed(1)}%',
            Icons.trending_up,
            const Color(0xFF8B5CF6),
            subtitle: 'Payment efficiency',
            isHighlighted: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color,
      {String? subtitle, bool isHighlighted = false}) {
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
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isHighlighted ? color : const Color(0xFF1E293B),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueBreakdown() {
    final cashPercent = totalSales > 0 ? (cashReceived / totalSales) : 0.5;
    final creditPercent = totalSales > 0 ? (creditSales / totalSales) : 0.5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              const Text(
                'Revenue Breakdown',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              const Spacer(),
              _buildBreakdownLegend('Cash', currencyFormat.format(cashReceived), const Color(0xFF10B981)),
              const SizedBox(width: 16),
              _buildBreakdownLegend('Credit', currencyFormat.format(creditSales), const Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 12),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (cashPercent > 0)
                    Expanded(
                      flex: (cashPercent * 100).toInt().clamp(1, 99),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF34D399)],
                          ),
                        ),
                      ),
                    ),
                  if (creditPercent > 0)
                    Expanded(
                      flex: (creditPercent * 100).toInt().clamp(1, 99),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(cashPercent * 100).toStringAsFixed(1)}% Cash',
                style: const TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w500),
              ),
              Text(
                '${(creditPercent * 100).toStringAsFixed(1)}% Credit',
                style: const TextStyle(fontSize: 10, color: Color(0xFFF59E0B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownLegend(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
            Text(
              value,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToolbar() {
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
            width: 300,
            child: TextField(
              controller: searchController,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search by invoice or customer...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                prefixIcon: Icon(Icons.search, size: 16, color: Colors.grey.shade400),
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
                _applyFiltersAndSort();
              },
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(Icons.filter_list, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  selectedFilter,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${filteredSales.length} sales',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTable() {
    if (isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(child: CircularProgressIndicator()),
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
                _buildTableHeader('Invoice', flex: 2),
                _buildTableHeader('Date & Time', flex: 3),
                _buildTableHeader('Customer', flex: 3),
                _buildTableHeader('Items', flex: 2, align: TextAlign.center),
                _buildTableHeader('Total', flex: 2, align: TextAlign.right),
                _buildTableHeader('Paid', flex: 2, align: TextAlign.right),
                _buildTableHeader('Balance', flex: 2, align: TextAlign.right),
                _buildTableHeader('Status', flex: 2, align: TextAlign.center),
              ],
            ),
          ),

          // Table Body
          Expanded(
            child: filteredSales.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No sales found',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try adjusting your date range or filters',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredSales.length,
                    itemBuilder: (context, index) {
                      final sale = filteredSales[index];
                      final isEven = index % 2 == 0;
                      final balance = sale['balance'] as double;
                      final paid = sale['amountPaid'] as double;
                      final total = sale['total'] as double;
                      final items = sale['items'] as List;

                      String status;
                      Color statusColor;
                      IconData statusIcon;

                      if (balance == 0) {
                        status = 'Paid';
                        statusColor = const Color(0xFF10B981);
                        statusIcon = Icons.check_circle;
                      } else if (paid == 0) {
                        status = 'Credit';
                        statusColor = const Color(0xFFF59E0B);
                        statusIcon = Icons.credit_card;
                      } else {
                        status = 'Partial';
                        statusColor = const Color(0xFF3B82F6);
                        statusIcon = Icons.payment;
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isEven ? Colors.white : const Color(0xFFFAFAFA),
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade100),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Invoice
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'INV-${sale['invoiceId']}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                              ),
                            ),
                            // Date & Time
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('dd MMM yyyy').format(DateTime.parse(sale['dateTime'])),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    DateFormat('hh:mm a').format(DateTime.parse(sale['dateTime'])),
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            // Customer
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.person_outline,
                                      size: 12,
                                      color: Color(0xFF8B5CF6),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      sale['customerName'] ?? 'Walk-in',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF475569),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Items Count
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${items.length} items',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Total
                            Expanded(
                              flex: 2,
                              child: Text(
                                currencyFormat.format(total),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            // Paid
                            Expanded(
                              flex: 2,
                              child: Text(
                                currencyFormat.format(paid),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                            // Balance
                            Expanded(
                              flex: 2,
                              child: Text(
                                currencyFormat.format(balance),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: balance > 0 ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            // Status
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: statusColor.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(statusIcon, size: 10, color: statusColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
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
                Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Text(
                  'Showing ${filteredSales.length} of ${sales.length} sales',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const Spacer(),
                _buildFooterStat('Total', currencyFormat.format(totalSales), const Color(0xFF3B82F6)),
                const SizedBox(width: 20),
                _buildFooterStat('Cash', currencyFormat.format(cashReceived), const Color(0xFF10B981)),
                const SizedBox(width: 20),
                _buildFooterStat('Credit', currencyFormat.format(creditSales), const Color(0xFFF59E0B)),
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
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFooterStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}