import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/models/sale_item.dart';
import 'package:medical_app/services/database_helper.dart';

class ItemWiseSaleReport extends StatefulWidget {
  const ItemWiseSaleReport({super.key});

  @override
  State<ItemWiseSaleReport> createState() => _ItemWiseSaleReportState();
}

class _ItemWiseSaleReportState extends State<ItemWiseSaleReport> {
  // Filters & State
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();
  String searchQuery = '';
  String sortBy = 'Amount (High to Low)';
  bool isLoading = true;

  // Data Lists
  List<Map<String, dynamic>> allItemSales = [];
  List<Map<String, dynamic>> filteredItemSales = [];

  // Metrics
  double grandTotalRevenue = 0.0;
  int totalQuantitySold = 0;
  String bestSellingItemName = '-';
  String topRevenueItemName = '-';
  int uniqueItemsCount = 0;

  // Formatters
  final currencyFormat = NumberFormat.currency(locale: 'en_PK', symbol: 'Rs. ', decimalDigits: 0);
  final dateFormat = DateFormat('dd MMM yyyy');
  final TextEditingController searchController = TextEditingController();

  final List<String> sortOptions = [
    'Amount (High to Low)',
    'Amount (Low to High)',
    'Quantity (High to Low)',
    'Quantity (Low to High)',
    'Name (A-Z)',
  ];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => isLoading = true);

    final from = fromDate.toIso8601String();
    final to = toDate.toIso8601String();

    try {
      final allSales = await DatabaseHelper.instance.getSalesInDateRange(from, to);

      // Aggregation Logic
      Map<String, Map<String, dynamic>> itemMap = {};

      for (var sale in allSales) {
        final List<SaleItem> items = sale['items'] as List<SaleItem>;

        for (var item in items) {
          String productName = item.productName;
          int qty = item.quantity;
          double lineTotal = item.lineTotal;

          if (!itemMap.containsKey(productName)) {
            itemMap[productName] = {
              'productName': productName,
              'quantity': 0,
              'totalAmount': 0.0,
            };
          }

          itemMap[productName]!['quantity'] += qty;
          itemMap[productName]!['totalAmount'] += lineTotal;
        }
      }

      // Convert Map to List
      allItemSales = itemMap.values.map((e) => e).toList().cast<Map<String, dynamic>>();
      
      _applyFiltersAndSort();
      isLoading = false;

    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error generating report: $e');
    }
  }

  void _applyFiltersAndSort() {
    List<Map<String, dynamic>> temp = List.from(allItemSales);

    // 1. Search Filter
    if (searchQuery.isNotEmpty) {
      temp = temp.where((item) {
        return item['productName'].toString().toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

    // 2. Sorting
    switch (sortBy) {
      case 'Amount (High to Low)':
        temp.sort((a, b) => (b['totalAmount'] as double).compareTo(a['totalAmount'] as double));
        break;
      case 'Amount (Low to High)':
        temp.sort((a, b) => (a['totalAmount'] as double).compareTo(b['totalAmount'] as double));
        break;
      case 'Quantity (High to Low)':
        temp.sort((a, b) => (b['quantity'] as int).compareTo(a['quantity'] as int));
        break;
      case 'Quantity (Low to High)':
        temp.sort((a, b) => (a['quantity'] as int).compareTo(b['quantity'] as int));
        break;
      case 'Name (A-Z)':
        temp.sort((a, b) => (a['productName'] as String).compareTo(b['productName'] as String));
        break;
    }

    // 3. Calculate Metrics
    grandTotalRevenue = temp.fold(0.0, (sum, e) => sum + (e['totalAmount'] as double));
    totalQuantitySold = temp.fold(0, (sum, e) => sum + (e['quantity'] as int));
    uniqueItemsCount = temp.length;

    // Insights logic (using the full list or filtered list depending on preference, here using filtered)
    if (temp.isNotEmpty) {
      // Find item with max quantity
      var maxQtyItem = temp.reduce((curr, next) => (curr['quantity'] as int) > (next['quantity'] as int) ? curr : next);
      bestSellingItemName = maxQtyItem['productName'];

      // Find item with max revenue
      var maxRevItem = temp.reduce((curr, next) => (curr['totalAmount'] as double) > (next['totalAmount'] as double) ? curr : next);
      topRevenueItemName = maxRevItem['productName'];
    } else {
      bestSellingItemName = '-';
      topRevenueItemName = '-';
    }

    setState(() {
      filteredItemSales = temp;
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
            colorScheme: const ColorScheme.light(primary: Color(0xFF6366F1)), // Indigo theme
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
                _buildQuickInsights(),
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
                  Expanded(child: _buildSalesTable()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Left Panel ---

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
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
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune, color: Color(0xFF6366F1), size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Filters',
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
              label: const Text('Analyze Sales'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
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

  Widget _buildQuickInsights() {
    if (isLoading) return const SizedBox();

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Performers',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 20),
            _buildStatItem(
              'Most Sold (Qty)',
              bestSellingItemName,
              Icons.inventory_2_outlined,
              const Color(0xFFF59E0B),
            ),
            const SizedBox(height: 12),
            _buildStatItem(
              'Highest Revenue',
              topRevenueItemName,
              Icons.monetization_on_outlined,
              const Color(0xFF10B981),
            ),
            const SizedBox(height: 12),
            _buildStatItem(
              'Unique Items Sold',
              '$uniqueItemsCount products',
              Icons.category_outlined,
              const Color(0xFF3B82F6),
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

  // --- Main Content ---

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
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.analytics_outlined, color: Color(0xFF6366F1), size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Item Wise Sales',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              Text(
                'Product performance • ${dateFormat.format(fromDate)} - ${dateFormat.format(toDate)}',
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
    double avgPricePerItem = totalQuantitySold > 0 ? grandTotalRevenue / totalQuantitySold : 0;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Quantity',
            totalQuantitySold.toString(),
            Icons.shopping_cart_outlined,
            const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Total Revenue',
            currencyFormat.format(grandTotalRevenue),
            Icons.attach_money,
            const Color(0xFF10B981),
            isHighlighted: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Avg Price / Unit',
            currencyFormat.format(avgPricePerItem),
            Icons.trending_up,
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
          SizedBox(
            width: 300,
            child: TextField(
              controller: searchController,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search product name...',
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
                _buildTableHeader('#', flex: 1),
                _buildTableHeader('Product Name', flex: 4),
                _buildTableHeader('Sold Qty', flex: 2, align: TextAlign.center),
                _buildTableHeader('Avg Price', flex: 2, align: TextAlign.right),
                _buildTableHeader('Total Amount', flex: 3, align: TextAlign.right),
              ],
            ),
          ),

          // Table Body
          Expanded(
            child: filteredItemSales.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.remove_shopping_cart, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No items found',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredItemSales.length,
                    itemBuilder: (context, index) {
                      final item = filteredItemSales[index];
                      final isEven = index % 2 == 0;
                      final quantity = item['quantity'] as int;
                      final totalAmount = item['totalAmount'] as double;
                      final avgPrice = quantity > 0 ? totalAmount / quantity : 0.0;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isEven ? Colors.white : const Color(0xFFFAFAFA),
                          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                        ),
                        child: Row(
                          children: [
                            // Rank
                            Expanded(
                              flex: 1,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ),
                            // Name
                            Expanded(
                              flex: 4,
                              child: Text(
                                item['productName'],
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                              ),
                            ),
                            // Qty
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
                                    quantity.toString(),
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6)),
                                  ),
                                ),
                              ),
                            ),
                            // Avg Price
                            Expanded(
                              flex: 2,
                              child: Text(
                                currencyFormat.format(avgPrice),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ),
                            // Total
                            Expanded(
                              flex: 3,
                              child: Text(
                                currencyFormat.format(totalAmount),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
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
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white70),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}