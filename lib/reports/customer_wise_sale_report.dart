// lib/screens/reports/customer_wise_sale_report.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/models/customer.dart';
import 'package:medical_app/services/database_helper.dart';

class CustomerWiseSaleReport extends StatefulWidget {
  const CustomerWiseSaleReport({super.key});

  @override
  State<CustomerWiseSaleReport> createState() => _CustomerWiseSaleReportState();
}

class _CustomerWiseSaleReportState extends State<CustomerWiseSaleReport> {
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();

  List<Map<String, dynamic>> customerSales = [];
  List<Map<String, dynamic>> filteredCustomerSales = [];
  bool isLoading = false;
  bool hasGenerated = false;

  double grandTotal = 0.0;
  int totalInvoices = 0;
  double averageSale = 0.0;
  String topCustomer = '-';

  String searchQuery = '';
  String sortBy = 'totalSales';
  bool sortAscending = false;

  final currencyFormat = NumberFormat.currency(locale: 'en_PK', symbol: 'Rs. ', decimalDigits: 0);
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      isLoading = true;
      hasGenerated = false;
    });

    try {
      final from = fromDate.toIso8601String().substring(0, 10);
      final to = toDate.toIso8601String().substring(0, 10);

      final allSales = await DatabaseHelper.instance.getSalesInDateRange(from, to);

      Map<String, Map<String, dynamic>> customerMap = {};

      for (var sale in allSales) {
        String customerName = sale['customerName'] ?? 'Walk-in Customer';
        int? customerId = sale['customerId'] as int?;
        double total = (sale['total'] as num).toDouble();
        double balance = (sale['balance'] as num?)?.toDouble() ?? 0.0;
        double paid = (sale['amountPaid'] as num?)?.toDouble() ?? 0.0;

        if (!customerMap.containsKey(customerName)) {
          customerMap[customerName] = {
            'customerId': customerId,
            'customerName': customerName,
            'totalSales': 0.0,
            'totalPaid': 0.0,
            'totalBalance': 0.0,
            'invoices': 0,
            'lastSaleDate': sale['dateTime'],
            'sales': [],
          };
        }

        customerMap[customerName]!['totalSales'] += total;
        customerMap[customerName]!['totalPaid'] += paid;
        customerMap[customerName]!['totalBalance'] += balance;
        customerMap[customerName]!['invoices'] += 1;
        customerMap[customerName]!['lastSaleDate'] = sale['dateTime'];
        (customerMap[customerName]!['sales'] as List).add(sale);
      }

      customerSales = customerMap.values.toList();

      // Sort by total sales descending
      _sortData();

      // Calculate totals
      grandTotal = customerSales.fold(0.0, (sum, e) => sum + (e['totalSales'] as double));
      totalInvoices = customerSales.fold(0, (sum, e) => sum + (e['invoices'] as int));
      averageSale = customerSales.isNotEmpty ? grandTotal / totalInvoices : 0;
      topCustomer = customerSales.isNotEmpty ? customerSales.first['customerName'] : '-';

      filteredCustomerSales = List.from(customerSales);

      setState(() {
        isLoading = false;
        hasGenerated = true;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error loading report: $e');
    }
  }

  void _sortData() {
    customerSales.sort((a, b) {
      dynamic aValue = a[sortBy];
      dynamic bValue = b[sortBy];

      if (aValue is String && bValue is String) {
        return sortAscending ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
      } else {
        return sortAscending
            ? (aValue as num).compareTo(bValue as num)
            : (bValue as num).compareTo(aValue as num);
      }
    });
    filteredCustomerSales = List.from(customerSales);
    _filterData();
  }

  void _filterData() {
    setState(() {
      if (searchQuery.isEmpty) {
        filteredCustomerSales = List.from(customerSales);
      } else {
        filteredCustomerSales = customerSales.where((c) {
          return c['customerName'].toString().toLowerCase().contains(searchQuery.toLowerCase());
        }).toList();
      }
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
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Row(
              children: [
                // Left Panel - Filters
                Container(
                  width: 300,
                  margin: const EdgeInsets.fromLTRB(16, 0, 0, 16),
                  child: Column(
                    children: [
                      _buildFilterPanel(),
                      const SizedBox(height: 16),
                      Expanded(child: _buildTopCustomersPanel()),
                    ],
                  ),
                ),
                // Main Content
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        _buildSummaryCards(),
                        const SizedBox(height: 16),
                        _buildTableToolbar(),
                        const SizedBox(height: 12),
                        Expanded(child: _buildDataTable()),
                      ],
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.people_outline, color: Color(0xFF8B5CF6), size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Customer Wise Sales Report',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              Text(
                '${DateFormat('dd MMM yyyy').format(fromDate)} - ${DateFormat('dd MMM yyyy').format(toDate)}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),
          const Spacer(),
          if (hasGenerated) ...[
            _buildHeaderAction(Icons.refresh, 'Refresh', _loadReport),
            const SizedBox(width: 8),
            _buildHeaderAction(Icons.print_outlined, 'Print', () {}),
            const SizedBox(width: 8),
            _buildHeaderAction(Icons.download_outlined, 'Export', () {}),
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
              _buildQuickDateChip('7 Days', () {
                setState(() {
                  fromDate = DateTime.now().subtract(const Duration(days: 7));
                  toDate = DateTime.now();
                });
              }),
              _buildQuickDateChip('30 Days', () {
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
              _buildQuickDateChip('This Year', () {
                final now = DateTime.now();
                setState(() {
                  fromDate = DateTime(now.year, 1, 1);
                  toDate = now;
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
                backgroundColor: const Color(0xFF8B5CF6),
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
                    colorScheme: const ColorScheme.light(primary: Color(0xFF8B5CF6)),
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

  Widget _buildTopCustomersPanel() {
    final topCustomers = customerSales.take(5).toList();

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
                const Icon(Icons.emoji_events_outlined, size: 16, color: Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                const Text(
                  'Top Customers',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
          Expanded(
            child: !hasGenerated
                ? Center(
                    child: Text(
                      'Generate report first',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  )
                : topCustomers.isEmpty
                    ? Center(
                        child: Text(
                          'No customers found',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: topCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = topCustomers[index];
                          final percentage = grandTotal > 0
                              ? ((customer['totalSales'] as double) / grandTotal * 100)
                              : 0.0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                // Rank Badge
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: _getRankColor(index),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
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
                                        customer['customerName'],
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E293B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      // Progress Bar
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: LinearProgressIndicator(
                                          value: percentage / 100,
                                          backgroundColor: Colors.grey.shade200,
                                          valueColor: AlwaysStoppedAnimation(_getRankColor(index)),
                                          minHeight: 4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      currencyFormat.format(customer['totalSales']),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    Text(
                                      '${percentage.toStringAsFixed(1)}%',
                                      style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return const Color(0xFFF59E0B); // Gold
      case 1:
        return const Color(0xFF94A3B8); // Silver
      case 2:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Customers',
            customerSales.length.toString(),
            Icons.people_outline,
            const Color(0xFF3B82F6),
            subtitle: 'Active in period',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Total Invoices',
            totalInvoices.toString(),
            Icons.receipt_long_outlined,
            const Color(0xFF8B5CF6),
            subtitle: 'Bills generated',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Grand Total',
            currencyFormat.format(grandTotal),
            Icons.account_balance_wallet_outlined,
            const Color(0xFF10B981),
            subtitle: 'Total revenue',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Average Sale',
            currencyFormat.format(averageSale),
            Icons.analytics_outlined,
            const Color(0xFFF59E0B),
            subtitle: 'Per invoice',
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
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

  Widget _buildTableToolbar() {
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
                hintText: 'Search customers...',
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
                _filterData();
              },
            ),
          ),
          const SizedBox(width: 16),
          // Sort Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(Icons.sort, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: sortBy,
                  underline: const SizedBox(),
                  isDense: true,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  items: const [
                    DropdownMenuItem(value: 'totalSales', child: Text('Total Sales')),
                    DropdownMenuItem(value: 'invoices', child: Text('Invoices')),
                    DropdownMenuItem(value: 'customerName', child: Text('Name')),
                    DropdownMenuItem(value: 'totalBalance', child: Text('Balance')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => sortBy = value);
                      _sortData();
                    }
                  },
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    setState(() => sortAscending = !sortAscending);
                    _sortData();
                  },
                  child: Icon(
                    sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            '${filteredCustomerSales.length} customers',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
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
                child: Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 16),
              Text(
                'No Report Generated',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'Select date range and click "Generate Report"',
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                _buildTableHeader('#', flex: 1),
                _buildTableHeader('Customer', flex: 4),
                _buildTableHeader('Invoices', flex: 2, align: TextAlign.center),
                _buildTableHeader('Total Sales', flex: 3, align: TextAlign.right),
                _buildTableHeader('Amount Paid', flex: 3, align: TextAlign.right),
                _buildTableHeader('Balance', flex: 3, align: TextAlign.right),
                _buildTableHeader('Last Sale', flex: 2, align: TextAlign.center),
                _buildTableHeader('', flex: 1),
              ],
            ),
          ),
          // Table Body
          Expanded(
            child: filteredCustomerSales.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No customers found',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredCustomerSales.length,
                    itemBuilder: (context, index) {
                      final customer = filteredCustomerSales[index];
                      final isEven = index % 2 == 0;
                      final hasBalance = (customer['totalBalance'] as double) > 0;
                      final percentage = grandTotal > 0
                          ? ((customer['totalSales'] as double) / grandTotal * 100)
                          : 0.0;

                      return InkWell(
                        onTap: () => _showCustomerDetails(customer),
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
                              // Rank
                              Expanded(
                                flex: 1,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: index < 3 ? _getRankColor(index) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: index < 3 ? Colors.white : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Customer Name
                              Expanded(
                                flex: 4,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          customer['customerName'].toString().isNotEmpty
                                              ? customer['customerName'].toString()[0].toUpperCase()
                                              : 'C',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF8B5CF6),
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
                                            customer['customerName'],
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '${percentage.toStringAsFixed(1)}%',
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF10B981),
                                                  ),
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
                              // Invoices
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      customer['invoices'].toString(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF3B82F6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Total Sales
                              Expanded(
                                flex: 3,
                                child: Text(
                                  currencyFormat.format(customer['totalSales']),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              // Amount Paid
                              Expanded(
                                flex: 3,
                                child: Text(
                                  currencyFormat.format(customer['totalPaid']),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                              // Balance
                              Expanded(
                                flex: 3,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: hasBalance
                                        ? const Color(0xFFEF4444).withOpacity(0.1)
                                        : const Color(0xFF10B981).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    currencyFormat.format(customer['totalBalance']),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: hasBalance ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ),
                              // Last Sale Date
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: Text(
                                    DateFormat('dd/MM').format(DateTime.parse(customer['lastSaleDate'])),
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ),
                              ),
                              // Action
                              Expanded(
                                flex: 1,
                                child: IconButton(
                                  icon: const Icon(Icons.visibility_outlined, size: 18),
                                  color: Colors.grey.shade400,
                                  onPressed: () => _showCustomerDetails(customer),
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
                const Text(
                  'Grand Total',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                ),
                const Spacer(),
                _buildFooterStat('Customers', customerSales.length.toString(), const Color(0xFF3B82F6)),
                const SizedBox(width: 24),
                _buildFooterStat('Invoices', totalInvoices.toString(), const Color(0xFF8B5CF6)),
                const SizedBox(width: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, size: 16, color: Colors.white70),
                      const SizedBox(width: 8),
                      Text(
                        currencyFormat.format(grandTotal),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
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

  Widget _buildFooterStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  void _showCustomerDetails(Map<String, dynamic> customer) {
    final sales = customer['sales'] as List;

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
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        customer['customerName'].toString()[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer['customerName'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          '${sales.length} invoices in this period',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Summary Row
              Row(
                children: [
                  Expanded(
                    child: _buildDetailStat('Total Sales', currencyFormat.format(customer['totalSales']), const Color(0xFF10B981)),
                  ),
                  Expanded(
                    child: _buildDetailStat('Amount Paid', currencyFormat.format(customer['totalPaid']), const Color(0xFF3B82F6)),
                  ),
                  Expanded(
                    child: _buildDetailStat('Balance Due', currencyFormat.format(customer['totalBalance']), const Color(0xFFEF4444)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Invoice History',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 12),
              // Invoice List
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: sales.length,
                    itemBuilder: (context, index) {
                      final sale = sales[index];
                      final balance = (sale['balance'] as num?)?.toDouble() ?? 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.receipt_outlined, size: 16, color: Color(0xFF3B82F6)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Invoice #${sale['invoiceId']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(sale['dateTime'])),
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  currencyFormat.format(sale['total']),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                if (balance > 0)
                                  Text(
                                    'Due: ${currencyFormat.format(balance)}',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFFEF4444)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Print Statement'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Close'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  Widget _buildDetailStat(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}