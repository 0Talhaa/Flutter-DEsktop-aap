import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/services/database_helper.dart';

class PurchaseReport extends StatefulWidget {
  const PurchaseReport({super.key});

  @override
  State<PurchaseReport> createState() => _PurchaseReportState();
}

class _PurchaseReportState extends State<PurchaseReport> {
  // State
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();
  List<Map<String, dynamic>> allPurchases = [];
  List<Map<String, dynamic>> filteredPurchases = [];
  bool isLoading = true;
  String searchQuery = '';
  String sortBy = 'Date (Newest)';

  // Controllers
  final TextEditingController searchController = TextEditingController();

  // Metrics
  double totalPurchaseAmount = 0.0;
  int totalInvoices = 0;
  int totalItemsBought = 0;
  double avgInvoiceValue = 0.0;
  String topSupplier = '-';

  // Formats
  final currencyFormat = NumberFormat.currency(locale: 'en_PK', symbol: 'Rs. ', decimalDigits: 0);
  final dateFormat = DateFormat('dd MMM yyyy');

  final List<String> sortOptions = [
    'Date (Newest)',
    'Date (Oldest)',
    'Amount (High to Low)',
    'Amount (Low to High)',
    'Supplier (A-Z)',
  ];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => isLoading = true);

    final from = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final to = DateTime(toDate.year, toDate.month, toDate.day).add(const Duration(days: 1));

    try {
      final data = await DatabaseHelper.instance.getPurchasesInDateRange(
        from.toIso8601String(),
        to.toIso8601String(),
      );

      setState(() {
        allPurchases = data;
        _applyFiltersAndSort();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error loading purchases: $e');
    }
  }

  void _applyFiltersAndSort() {
    List<Map<String, dynamic>> temp = List.from(allPurchases);

    // 1. Search Filter
    if (searchQuery.isNotEmpty) {
      temp = temp.where((p) {
        final supplier = (p['supplierName'] ?? '').toString().toLowerCase();
        final invoice = (p['invoiceNumber'] ?? '').toString().toLowerCase();
        final q = searchQuery.toLowerCase();
        return supplier.contains(q) || invoice.contains(q);
      }).toList();
    }

    // 2. Sort
    switch (sortBy) {
      case 'Date (Newest)':
        temp.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
        break;
      case 'Date (Oldest)':
        temp.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
        break;
      case 'Amount (High to Low)':
        temp.sort((a, b) => (b['totalAmount'] as double).compareTo(a['totalAmount'] as double));
        break;
      case 'Amount (Low to High)':
        temp.sort((a, b) => (a['totalAmount'] as double).compareTo(b['totalAmount'] as double));
        break;
      case 'Supplier (A-Z)':
        temp.sort((a, b) => (a['supplierName'] ?? '').compareTo(b['supplierName'] ?? ''));
        break;
    }

    // 3. Calculate Metrics based on filtered data
    double totalAmt = 0.0;
    int itemsCount = 0;
    Map<String, int> supplierFrequency = {};

    for (var p in temp) {
      totalAmt += (p['totalAmount'] as double);
      itemsCount += (p['items'] as List).length;
      
      String sup = p['supplierName'] ?? 'Unknown';
      supplierFrequency[sup] = (supplierFrequency[sup] ?? 0) + 1;
    }

    // Find top supplier
    String topSup = '-';
    if (supplierFrequency.isNotEmpty) {
      var entry = supplierFrequency.entries.reduce((a, b) => a.value > b.value ? a : b);
      topSup = entry.key;
    }

    setState(() {
      filteredPurchases = temp;
      totalPurchaseAmount = totalAmt;
      totalInvoices = temp.length;
      totalItemsBought = itemsCount;
      avgInvoiceValue = temp.isNotEmpty ? totalAmt / temp.length : 0.0;
      topSupplier = topSup;
    });
  }

  Future<void> _selectDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate : toDate,
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
      setState(() {
        if (isFrom) fromDate = picked;
        else toDate = picked;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // Left Panel - Controls
          Container(
            width: 280,
            margin: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildControlPanel(),
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
                  _buildToolbar(),
                  const SizedBox(height: 12),
                  Expanded(child: _buildPurchaseTable()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Left Panel Widgets ---

  Widget _buildControlPanel() {
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
                  color: const Color(0xFF009688).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune, color: Color(0xFF009688), size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Report Settings',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          _buildDateSelector('From Date', fromDate, () => _selectDate(true)),
          const SizedBox(height: 16),
          _buildDateSelector('To Date', toDate, () => _selectDate(false)),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Generate Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF009688),
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

  Widget _buildDateSelector(String label, DateTime date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFFF8FAFC),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(dateFormat.format(date), style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    if (isLoading) return const SizedBox();

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
            const Text(
              'Quick Insights',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 20),
            _buildStatItem(
              'Avg Invoice Value',
              currencyFormat.format(avgInvoiceValue),
              Icons.analytics_outlined,
              const Color(0xFF3B82F6),
            ),
            const SizedBox(height: 12),
            _buildStatItem(
              'Top Supplier',
              topSupplier,
              Icons.local_shipping_outlined,
              const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 12),
            _buildStatItem(
              'Avg Items / Invoice',
              totalInvoices > 0 ? (totalItemsBought / totalInvoices).toStringAsFixed(1) : '0',
              Icons.inventory_2_outlined,
              const Color(0xFF8B5CF6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                Text(
                  value, 
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Right Content Widgets ---

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
              color: const Color(0xFF009688).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF009688), size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Purchase Report',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              Text(
                'Procurement history • ${dateFormat.format(fromDate)} to ${dateFormat.format(toDate)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          const Spacer(),
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
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Purchases',
            currencyFormat.format(totalPurchaseAmount),
            Icons.monetization_on_outlined,
            const Color(0xFF009688),
            isHighlighted: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Total Invoices',
            totalInvoices.toString(),
            Icons.receipt_long_outlined,
            const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Items Bought',
            totalItemsBought.toString(),
            Icons.dashboard_outlined,
            const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Suppliers',
            filteredPurchases.map((e) => e['supplierName']).toSet().length.toString(),
            Icons.people_outline,
            const Color(0xFF8B5CF6),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, {bool isHighlighted = false}) {
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isHighlighted ? color : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
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
            width: 280,
            child: TextField(
              controller: searchController,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search invoice or supplier...',
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
          // Sort Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButton<String>(
              value: sortBy,
              isDense: true,
              underline: const SizedBox(),
              style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
              items: sortOptions.map((option) {
                return DropdownMenuItem(value: option, child: Text(option));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    sortBy = value;
                    _applyFiltersAndSort();
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseTable() {
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
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                _buildTableHeader('Date', flex: 2),
                _buildTableHeader('Invoice #', flex: 2),
                _buildTableHeader('Supplier', flex: 4),
                _buildTableHeader('Items', flex: 2, align: TextAlign.center),
                _buildTableHeader('Total Amount', flex: 3, align: TextAlign.right),
              ],
            ),
          ),

          // Table Body
          Expanded(
            child: filteredPurchases.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.remove_shopping_cart_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No purchases found',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredPurchases.length,
                    itemBuilder: (context, index) {
                      final purchase = filteredPurchases[index];
                      final isEven = index % 2 == 0;
                      final List items = purchase['items'] as List;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                dateFormat.format(DateTime.parse(purchase['date'])),
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ),
                            // Invoice
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Icon(Icons.description_outlined, size: 14, color: Colors.grey.shade400),
                                  const SizedBox(width: 6),
                                  Text(
                                    purchase['invoiceNumber'] ?? '-',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                  ),
                                ],
                              ),
                            ),
                            // Supplier
                            Expanded(
                              flex: 4,
                              child: Text(
                                purchase['supplierName'] ?? '-',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                              ),
                            ),
                            // Items Count
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
                                    '${items.length}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6)),
                                  ),
                                ),
                              ),
                            ),
                            // Amount
                            Expanded(
                              flex: 3,
                              child: Text(
                                currencyFormat.format(purchase['totalAmount']),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF009688)),
                              ),
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

  Widget _buildTableHeader(String text, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white70, letterSpacing: 0.5),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}