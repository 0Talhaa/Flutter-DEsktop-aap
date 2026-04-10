// lib/screens/reports/sale_report.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/models/sale_item.dart';
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
  bool isLoading = false;
  bool reportGenerated = false;

  String searchQuery = '';
  String selectedFilter = 'All';

  double totalSales = 0.0;
  double cashReceived = 0.0;
  double creditSales = 0.0;
  int totalInvoices = 0;
  int paidInvoices = 0;
  int creditInvoices = 0;

  final currencyFormat =
      NumberFormat.currency(locale: 'en_PK', symbol: 'Rs. ', decimalDigits: 0);
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadReport() async {
    setState(() {
      isLoading = true;
    });

    try {
      final from = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final to = DateTime(toDate.year, toDate.month, toDate.day)
          .add(const Duration(days: 1));

      final allSales = await DatabaseHelper.instance.getSalesInDateRange(
        from.toIso8601String(),
        to.toIso8601String(),
      );

      double total = 0, cash = 0, credit = 0;
      int paid = 0, creditCount = 0;

      for (var sale in allSales) {
        double saleTotal = sale['total'] as double;
        double amountPaid = sale['amountPaid'] as double;
        double saleBalance = sale['balance'] as double;

        total += saleTotal;
        cash += amountPaid;
        credit += (saleTotal - amountPaid);

        if (saleBalance == 0) paid++;
        if (amountPaid == 0 && saleBalance > 0) creditCount++;
      }

      setState(() {
        sales = allSales;
        totalSales = total;
        cashReceived = cash;
        creditSales = credit;
        totalInvoices = allSales.length;
        paidInvoices = paid;
        creditInvoices = creditCount;
        isLoading = false;
        _applyFilters();
      });

      // 🔥 Show full-screen report modal
      if (!mounted) return;
      _showFullScreenReport();
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar('Error loading sales: $e', isError: true);
    }
  }
void _showFullScreenReport() {
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.7),
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Container(); // Required but not used
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      // Slide down animation
      final slideAnimation = Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ));

      final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeIn),
      );

      return FadeTransition(
        opacity: fadeAnimation,
        child: SlideTransition(
          position: slideAnimation,
          child: Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            body: Column(
              children: [
                // 🔥 Top bar with close button
                _buildReportHeader(),
                
                // 🔥 Full report content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildSummaryRow(),
                        const SizedBox(height: 16),
                        _buildSearchFilterBar(),
                        const SizedBox(height: 12),
                        Expanded(child: _buildFullTable()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// 🔥 Report header with close button
Widget _buildReportHeader() {
  return Container(
    padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1E293B), Color(0xFF334155)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        // Icon
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.assessment_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        
        // Title & Date Range
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sales Report',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${DateFormat('dd MMM yyyy').format(fromDate)} - ${DateFormat('dd MMM yyyy').format(toDate)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        // Print Button
        IconButton(
          onPressed: () {
            // Add print functionality
            _showSnackBar('Print feature coming soon');
          },
          icon: const Icon(Icons.print_outlined, color: Colors.white),
          tooltip: 'Print Report',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.1),
            padding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(width: 8),
        
        // Export Button
        IconButton(
          onPressed: () {
            // Add export functionality
            _showSnackBar('Export feature coming soon');
          },
          icon: const Icon(Icons.file_download_outlined, color: Colors.white),
          tooltip: 'Export Report',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.1),
            padding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(width: 8),
        
        // Close Button
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          tooltip: 'Close Report',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.2),
            padding: const EdgeInsets.all(12),
          ),
        ),
      ],
    ),
  );
}
  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(sales);

    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((sale) {
        final invoiceId = 'INV${sale['invoiceId']}'.toLowerCase();
        final customerName = (sale['customerName'] ?? 'Walk-in').toLowerCase();
        final query = searchQuery.toLowerCase();
        return invoiceId.contains(query) || customerName.contains(query);
      }).toList();
    }

    switch (selectedFilter) {
      case 'Paid':
        filtered = filtered.where((s) => s['balance'] == 0).toList();
        break;
      case 'Partial':
        filtered = filtered.where((s) {
          return (s['balance'] as double) > 0 &&
              (s['amountPaid'] as double) > 0;
        }).toList();
        break;
      case 'Credit':
        filtered = filtered.where((s) => s['amountPaid'] == 0).toList();
        break;
    }

    filtered.sort((a, b) =>
        DateTime.parse(b['dateTime']).compareTo(DateTime.parse(a['dateTime'])));

    setState(() => filteredSales = filtered);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // Top Bar - Date Selection & Generate
          _buildTopBar(),

          // Content
          Expanded(
            child: !reportGenerated
                ? _buildInitialState()
                : isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: Color(0xFF10B981)))
                    : _buildReportContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Title Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assessment_outlined,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales Report',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Generate and view sales data',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Date Range & Generate Button
          Row(
            children: [
              // From Date
              Expanded(
                  child: _buildDatePicker('From', fromDate, (d) {
                setState(() => fromDate = d);
              })),
              const SizedBox(width: 12),
              // To Date
              Expanded(
                  child: _buildDatePicker('To', toDate, (d) {
                setState(() => toDate = d);
              })),
              const SizedBox(width: 12),
              // Quick Dates
              _buildQuickDateButton('Today', () {
                setState(() {
                  fromDate = DateTime.now();
                  toDate = DateTime.now();
                });
              }),
              const SizedBox(width: 8),
              _buildQuickDateButton('7 Days', () {
                setState(() {
                  fromDate = DateTime.now().subtract(const Duration(days: 7));
                  toDate = DateTime.now();
                });
              }),
              const SizedBox(width: 8),
              _buildQuickDateButton('30 Days', () {
                setState(() {
                  fromDate = DateTime.now().subtract(const Duration(days: 30));
                  toDate = DateTime.now();
                });
              }),
              const SizedBox(width: 8),
              _buildQuickDateButton('This Month', () {
                final now = DateTime.now();
                setState(() {
                  fromDate = DateTime(now.year, now.month, 1);
                  toDate = now;
                });
              }),
              const SizedBox(width: 16),
              // Generate Button
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : _loadReport,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(
                    isLoading ? 'Loading...' : 'Generate',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(
      String label, DateTime date, Function(DateTime) onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme:
                    const ColorScheme.light(primary: Color(0xFF10B981)),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDateButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assessment_outlined,
              size: 64,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Select Date Range & Generate Report',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your date range above and click Generate',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Summary Cards Row
          _buildSummaryRow(),
          const SizedBox(height: 16),

          // Revenue Bar + Search/Filter
          _buildSearchFilterBar(),
          const SizedBox(height: 12),

          // Full Width Table
          Expanded(child: _buildFullTable()),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final collectionRate =
        totalSales > 0 ? (cashReceived / totalSales * 100) : 0.0;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Total Sales',
            currencyFormat.format(totalSales),
            Icons.point_of_sale_rounded,
            const Color(0xFF3B82F6),
            '$totalInvoices invoices',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Cash Received',
            currencyFormat.format(cashReceived),
            Icons.account_balance_wallet_rounded,
            const Color(0xFF10B981),
            '$paidInvoices fully paid',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Credit / Pending',
            currencyFormat.format(creditSales),
            Icons.schedule_rounded,
            const Color(0xFFF59E0B),
            '$creditInvoices on credit',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Collection Rate',
            '${collectionRate.toStringAsFixed(1)}%',
            Icons.trending_up_rounded,
            collectionRate >= 70
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
            'Payment efficiency',
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Revenue breakdown mini bar
          _buildMiniRevenueBar(),
          const SizedBox(width: 24),

          // Search
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: searchController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search invoice or customer...',
                  hintStyle:
                      TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  prefixIcon:
                      Icon(Icons.search, size: 18, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            searchController.clear();
                            searchQuery = '';
                            _applyFilters();
                          },
                        )
                      : null,
                ),
                onChanged: (v) {
                  searchQuery = v;
                  _applyFilters();
                },
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Filter Chips
          ...['All', 'Paid', 'Partial', 'Credit'].map((filter) {
            final isActive = selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  setState(() {
                    selectedFilter = filter;
                    _applyFilters();
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _getFilterColor(filter).withOpacity(0.1)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive
                          ? _getFilterColor(filter)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? _getFilterColor(filter)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(width: 8),
          // Count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${filteredSales.length}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'Paid':
        return const Color(0xFF10B981);
      case 'Partial':
        return const Color(0xFF3B82F6);
      case 'Credit':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildMiniRevenueBar() {
    final cashPct = totalSales > 0 ? (cashReceived / totalSales) : 0.5;
    final creditPct = totalSales > 0 ? (creditSales / totalSales) : 0.5;

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Revenue Split',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            const SizedBox(height: 4),
            SizedBox(
              width: 150,
              height: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    Expanded(
                      flex: (cashPct * 100).toInt().clamp(1, 99),
                      child: Container(color: const Color(0xFF10B981)),
                    ),
                    Expanded(
                      flex: (creditPct * 100).toInt().clamp(1, 99),
                      child: Container(color: const Color(0xFFF59E0B)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _miniLegend('Cash ${(cashPct * 100).toStringAsFixed(0)}%',
                    const Color(0xFF10B981)),
                const SizedBox(width: 12),
                _miniLegend('Credit ${(creditPct * 100).toStringAsFixed(0)}%',
                    const Color(0xFFF59E0B)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _miniLegend(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w500, color: color)),
      ],
    );
  }

  Widget _buildFullTable() {
    if (filteredSales.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No sales found',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600),
              ),
              const SizedBox(height: 6),
              Text(
                'Try adjusting your date range or filters',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                _tableHeader('#', flex: 1),
                _tableHeader('Invoice', flex: 2),
                _tableHeader('Date', flex: 2),
                _tableHeader('Customer', flex: 3),
                _tableHeader('Items', flex: 1, align: TextAlign.center),
                _tableHeader('Total', flex: 2, align: TextAlign.right),
                _tableHeader('Paid', flex: 2, align: TextAlign.right),
                _tableHeader('Balance', flex: 2, align: TextAlign.right),
                _tableHeader('Status', flex: 2, align: TextAlign.center),
              ],
            ),
          ),

          // Table Body
          Expanded(
            child: ListView.builder(
              itemCount: filteredSales.length,
              itemBuilder: (context, index) {
                return _buildTableRow(filteredSales[index], index);
              },
            ),
          ),

          // Table Footer
          _buildTableFooter(),
        ],
      ),
    );
  }

  Widget _tableHeader(String text,
      {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> sale, int index) {
    final balance = sale['balance'] as double;
    final paid = sale['amountPaid'] as double;
    final total = sale['total'] as double;
    final items = sale['items'] as List;
    final isEven = index % 2 == 0;
    final dateTime = DateTime.parse(sale['dateTime']);

    String status;
    Color statusColor;
    IconData statusIcon;

    if (balance == 0) {
      status = 'Paid';
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.check_circle_rounded;
    } else if (paid == 0) {
      status = 'Credit';
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.schedule_rounded;
    } else {
      status = 'Partial';
      statusColor = const Color(0xFF3B82F6);
      statusIcon = Icons.timelapse_rounded;
    }

    return InkWell(
      onTap: () => _showSaleDetail(sale),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isEven ? Colors.white : const Color(0xFFFAFBFC),
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            // Row Number
            Expanded(
              flex: 1,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Invoice ID
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'INV-${sale['invoiceId']}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
            ),
            // Date
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('dd MMM yyyy').format(dateTime),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    DateFormat('hh:mm a').format(dateTime),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            // Customer
            Expanded(
              flex: 3,
              child: Text(
                sale['customerName'] ?? 'Walk-in Customer',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF475569),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Items
            Expanded(
              flex: 1,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      fontSize: 11,
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
                  fontSize: 13,
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
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF10B981),
                ),
              ),
            ),
            // Balance
            Expanded(
              flex: 2,
              child: Text(
                balance > 0 ? currencyFormat.format(balance) : '—',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: balance > 0
                      ? const Color(0xFFEF4444)
                      : Colors.grey.shade400,
                ),
              ),
            ),
            // Status
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
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
      ),
    );
  }

  Widget _buildTableFooter() {
    // Calculate filtered totals
    double fTotal = 0, fPaid = 0, fBalance = 0;
    for (var sale in filteredSales) {
      fTotal += sale['total'] as double;
      fPaid += sale['amountPaid'] as double;
      fBalance += sale['balance'] as double;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Row(
        children: [
          // Left side info
          Expanded(
            flex: 1,
            child: SizedBox(),
          ),
          Expanded(
            flex: 2,
            child: SizedBox(),
          ),
          Expanded(
            flex: 2,
            child: SizedBox(),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Total (${filteredSales.length} sales)',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(flex: 1, child: SizedBox()),
          // Total
          Expanded(
            flex: 2,
            child: Text(
              currencyFormat.format(fTotal),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          // Paid
          Expanded(
            flex: 2,
            child: Text(
              currencyFormat.format(fPaid),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6EE7B7),
              ),
            ),
          ),
          // Balance
          Expanded(
            flex: 2,
            child: Text(
              currencyFormat.format(fBalance),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFCA5A5),
              ),
            ),
          ),
          // Empty for status
          const Expanded(flex: 2, child: SizedBox()),
        ],
      ),
    );
  }

  void _showSaleDetail(Map<String, dynamic> sale) {
    final items = sale['items'] as List<SaleItem>; // ✅ Proper type
    final balance = sale['balance'] as double;
    final paid = sale['amountPaid'] as double;
    final total = sale['total'] as double;
    final dateTime = DateTime.parse(sale['dateTime']);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long,
                        color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INV-${sale['invoiceId']}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            DateFormat('dd MMM yyyy • hh:mm a')
                                .format(dateTime),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Content - Scrollable
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.person_outline,
                                color: Color(0xFF8B5CF6), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Customer',
                                  style: TextStyle(
                                      fontSize: 11, color: Color(0xFF94A3B8))),
                              Text(
                                sale['customerName'] ?? 'Walk-in Customer',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Items Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Items',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              )),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${items.length} item${items.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Items List
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final isLast = index == items.length - 1;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                border: isLast
                                    ? null
                                    : Border(
                                        bottom: BorderSide(
                                            color: Colors.grey.shade200)),
                              ),
                              child: Row(
                                children: [
                                  // Item Number
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Item Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.productName, // ✅ Using dot notation
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              '${item.quantity} × ${currencyFormat.format(item.price)}', // ✅
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                            if (item.packing != null) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFE0E7FF),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  item.packing!, // ✅
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF4F46E5),
                                                  ),
                                                ),
                                              ),
                                            ],
                                            if (item.discount != null &&
                                                item.discount! > 0) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFDCFCE7),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '-${item.discount!.toStringAsFixed(0)}%', // ✅
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF16A34A),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Line Total
                                  Text(
                                    currencyFormat.format(
                                        item.lineTotal), // ✅ Using getter
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Summary
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _summaryRowLight(
                                'Subtotal',
                                currencyFormat
                                    .format(sale['subtotal'] ?? total)),
                            if ((sale['discount'] ?? 0) > 0) ...[
                              const SizedBox(height: 8),
                              _summaryRowLight(
                                'Discount',
                                '- ${currencyFormat.format(sale['discount'])}',
                                color: const Color(0xFF4ADE80),
                              ),
                            ],
                            if ((sale['tax'] ?? 0) > 0) ...[
                              const SizedBox(height: 8),
                              _summaryRowLight(
                                'Tax',
                                currencyFormat.format(sale['tax']),
                              ),
                            ],
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Divider(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.2)),
                            ),
                            _summaryRowLight(
                              'Total',
                              currencyFormat.format(total),
                              isBold: true,
                              fontSize: 18,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _paymentBox(
                                    'Paid',
                                    currencyFormat.format(paid),
                                    const Color(0xFF10B981),
                                    Icons.check_circle_outline,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _paymentBox(
                                    'Balance',
                                    currencyFormat.format(balance),
                                    balance > 0
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF64748B),
                                    balance > 0
                                        ? Icons.schedule
                                        : Icons.check_circle,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRowLight(String label, String value,
      {bool isBold = false, Color? color, double fontSize = 13}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize - 1,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: Colors.white70,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: color ?? Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _paymentBox(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
              color: const Color(0xFF475569),
            )),
        Text(value,
            style: TextStyle(
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: color ?? const Color(0xFF1E293B),
            )),
      ],
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
