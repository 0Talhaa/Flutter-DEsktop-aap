// lib/screens/reports/stock_report.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/models/product.dart';
import 'package:medical_app/services/database_helper.dart';

class StockReport extends StatefulWidget {
  const StockReport({super.key});

  @override
  State<StockReport> createState() => _StockReportState();
}

class _StockReportState extends State<StockReport> {
  List<Product> products = [];
  List<Product> filteredProducts = [];
  String searchQuery = '';
  String selectedFilter = 'All';
  String sortBy = 'Name';
  bool sortAscending = true;
  bool isLoading = true;

  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);
  final TextEditingController searchController = TextEditingController();

  final List<String> stockFilters = [
    'All',
    'In Stock',
    'Low Stock',
    'Out of Stock',
    'Critical',
  ];

  final List<String> sortOptions = [
    'Name',
    'Stock (High to Low)',
    'Stock (Low to High)',
    'Value (High to Low)',
    'Company',
  ];

  // Summary metrics
  int totalItems = 0;
  int inStockItems = 0;
  int lowStockItems = 0;
  int outOfStockItems = 0;
  double totalStockValue = 0;
  double totalPotentialRevenue = 0;

  @override
  void initState() {
    super.initState();
    _loadStock();
  }

  Future<void> _loadStock() async {
    setState(() => isLoading = true);

    try {
      final data = await DatabaseHelper.instance.getAllProducts();

      setState(() {
        products = data;
        _applyFiltersAndSort();
        _calculateMetrics();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error loading stock: $e');
    }
  }

  void _calculateMetrics() {
    totalItems = products.length;
    inStockItems = products.where((p) => p.stock > (p.parLevel ?? 0)).length;
    lowStockItems = products.where((p) => p.stock > 0 && p.stock <= (p.parLevel ?? 0)).length;
    outOfStockItems = products.where((p) => p.stock == 0).length;
    totalStockValue = products.fold(0.0, (sum, p) => sum + (p.tradePrice ?? 0) * p.stock);
    totalPotentialRevenue = products.fold(0.0, (sum, p) => sum + p.retailPrice * p.stock);
  }

  void _applyFiltersAndSort() {
    List<Product> filtered = List.from(products);

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((p) {
        return p.itemName.toLowerCase().contains(searchQuery.toLowerCase()) ||
            (p.itemCode?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
            (p.companyName?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);
      }).toList();
    }

    // Apply stock status filter
    switch (selectedFilter) {
      case 'In Stock':
        filtered = filtered.where((p) => p.stock > (p.parLevel ?? 0)).toList();
        break;
      case 'Low Stock':
        filtered = filtered.where((p) => p.stock > 0 && p.stock <= (p.parLevel ?? 0)).toList();
        break;
      case 'Out of Stock':
        filtered = filtered.where((p) => p.stock == 0).toList();
        break;
      case 'Critical':
        filtered = filtered.where((p) => p.stock <= (p.parLevel ?? 0) * 0.5).toList();
        break;
    }

    // Apply sorting
    switch (sortBy) {
      case 'Name':
        filtered.sort((a, b) => sortAscending
            ? a.itemName.compareTo(b.itemName)
            : b.itemName.compareTo(a.itemName));
        break;
      case 'Stock (High to Low)':
        filtered.sort((a, b) => b.stock.compareTo(a.stock));
        break;
      case 'Stock (Low to High)':
        filtered.sort((a, b) => a.stock.compareTo(b.stock));
        break;
      case 'Value (High to Low)':
        filtered.sort((a, b) {
          final aValue = (a.tradePrice ?? 0) * a.stock;
          final bValue = (b.tradePrice ?? 0) * b.stock;
          return bValue.compareTo(aValue);
        });
        break;
      case 'Company':
        filtered.sort((a, b) => sortAscending
            ? (a.companyName ?? '').compareTo(b.companyName ?? '')
            : (b.companyName ?? '').compareTo(a.companyName ?? ''));
        break;
    }

    setState(() {
      filteredProducts = filtered;
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

  Color _getStockStatusColor(Product product) {
    if (product.stock == 0) return const Color(0xFFEF4444); // Red - Out of stock
    if (product.stock <= (product.parLevel ?? 0) * 0.5) return const Color(0xFFF97316); // Orange - Critical
    if (product.stock <= (product.parLevel ?? 0)) return const Color(0xFFFBBF24); // Yellow - Low
    return const Color(0xFF10B981); // Green - Good stock
  }

  String _getStockStatus(Product product) {
    if (product.stock == 0) return 'Out of Stock';
    if (product.stock <= (product.parLevel ?? 0) * 0.5) return 'Critical';
    if (product.stock <= (product.parLevel ?? 0)) return 'Low Stock';
    return 'In Stock';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // Left Panel - Filters
          Container(
            width: 280,
            margin: const EdgeInsets.all(16),
            child: Column(
              children: [
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
                  _buildToolbar(),
                  const SizedBox(height: 12),
                  Expanded(child: _buildStockTable()),
                ],
              ),
            ),
          ),
        ],
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

          // Stock Status Filters
          const Text(
            'Stock Status',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          ...stockFilters.map((filter) {
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

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Sort Options
          const Text(
            'Sort By',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButton<String>(
              value: sortBy,
              isExpanded: true,
              underline: const SizedBox(),
              style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
              items: sortOptions.map((option) {
                return DropdownMenuItem(
                  value: option,
                  child: Text(option),
                );
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

          const SizedBox(height: 16),

          // Clear Filters Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  selectedFilter = 'All';
                  sortBy = 'Name';
                  searchQuery = '';
                  searchController.clear();
                  _applyFiltersAndSort();
                });
              },
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Clear All'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case 'All':
        return Icons.inventory_2_outlined;
      case 'In Stock':
        return Icons.check_circle_outline;
      case 'Low Stock':
        return Icons.warning_amber_outlined;
      case 'Out of Stock':
        return Icons.remove_circle_outline;
      case 'Critical':
        return Icons.priority_high;
      default:
        return Icons.inventory_2_outlined;
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
                  'Quick Insights',
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
                      'Total Products',
                      totalItems.toString(),
                      Icons.inventory_2_outlined,
                      const Color(0xFF3B82F6),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickStatItem(
                      'In Stock',
                      inStockItems.toString(),
                      Icons.check_circle,
                      const Color(0xFF10B981),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickStatItem(
                      'Low Stock',
                      lowStockItems.toString(),
                      Icons.warning_amber,
                      const Color(0xFFFBBF24),
                    ),
                    const SizedBox(height: 12),
                    _buildQuickStatItem(
                      'Out of Stock',
                      outOfStockItems.toString(),
                      Icons.remove_circle,
                      const Color(0xFFEF4444),
                    ),
                    const Divider(height: 24),
                    _buildQuickStatItem(
                      'Stock Value',
                      currencyFormat.format(totalStockValue),
                      Icons.account_balance_wallet,
                      const Color(0xFF8B5CF6),
                      isAmount: true,
                    ),
                    const SizedBox(height: 12),
                    _buildQuickStatItem(
                      'Potential Revenue',
                      currencyFormat.format(totalPotentialRevenue),
                      Icons.trending_up,
                      const Color(0xFF10B981),
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
                    fontSize: isAmount ? 12 : 16,
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
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_outlined, color: Color(0xFF3B82F6), size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Stock Report',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              Text(
                'Real-time inventory status • ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
          const Spacer(),
          _buildHeaderAction(Icons.refresh, 'Refresh', _loadStock),
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
    final margin = totalPotentialRevenue - totalStockValue;
    final marginPercent = totalStockValue > 0 ? (margin / totalStockValue * 100) : 0;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Items',
            totalItems.toString(),
            Icons.inventory_2_outlined,
            const Color(0xFF3B82F6),
            subtitle: '${filteredProducts.length} shown',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Stock Value',
            currencyFormat.format(totalStockValue),
            Icons.account_balance_wallet_outlined,
            const Color(0xFF8B5CF6),
            subtitle: 'At trade price',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Potential Revenue',
            currencyFormat.format(totalPotentialRevenue),
            Icons.trending_up,
            const Color(0xFF10B981),
            subtitle: 'At retail price',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Profit Margin',
            '${marginPercent.toStringAsFixed(1)}%',
            Icons.show_chart,
            const Color(0xFFF59E0B),
            subtitle: currencyFormat.format(margin),
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
                hintText: 'Search by name, code, or company...',
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
            '${filteredProducts.length} items',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildStockTable() {
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
                _buildTableHeader('Code', flex: 2),
                _buildTableHeader('Product Name', flex: 4),
                _buildTableHeader('Company', flex: 3),
                _buildTableHeader('Pack', flex: 2),
                _buildTableHeader('Stock', flex: 2, align: TextAlign.center),
                _buildTableHeader('PAR', flex: 2, align: TextAlign.center),
                _buildTableHeader('Status', flex: 2, align: TextAlign.center),
                _buildTableHeader('Trade Price', flex: 2, align: TextAlign.right),
                _buildTableHeader('Retail Price', flex: 2, align: TextAlign.right),
                _buildTableHeader('Value', flex: 2, align: TextAlign.right),
              ],
            ),
          ),

          // Table Body
          Expanded(
            child: filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No products found',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try adjusting your filters or search',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      final isEven = index % 2 == 0;
                      final stockValue = (product.tradePrice ?? 0) * product.stock;
                      final statusColor = _getStockStatusColor(product);
                      final status = _getStockStatus(product);

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
                            // Code
                            Expanded(
                              flex: 2,
                              child: Text(
                                product.itemCode ?? '-',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            // Product Name
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.medication_outlined,
                                      size: 14,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      product.itemName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1E293B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Company
                            Expanded(
                              flex: 3,
                              child: Text(
                                product.companyName ?? '-',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Pack
                            Expanded(
                              flex: 2,
                              child: Text(
                                product.issueUnit ?? '-',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ),
                            // Stock
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    product.stock.toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // PAR
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    product.parLevel.toString(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
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
                                      Icon(
                                        _getStatusIcon(status),
                                        size: 10,
                                        color: statusColor,
                                      ),
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
                            // Trade Price
                            Expanded(
                              flex: 2,
                              child: Text(
                                currencyFormat.format(product.tradePrice ?? 0),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                              ),
                            ),
                            // Retail Price
                            Expanded(
                              flex: 2,
                              child: Text(
                                currencyFormat.format(product.retailPrice),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            // Value
                            Expanded(
                              flex: 2,
                              child: Text(
                                currencyFormat.format(stockValue),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3B82F6),
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
                  'Showing ${filteredProducts.length} of $totalItems products',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const Spacer(),
                _buildFooterStat('In Stock', '$inStockItems', const Color(0xFF10B981)),
                const SizedBox(width: 20),
                _buildFooterStat('Low Stock', '$lowStockItems', const Color(0xFFFBBF24)),
                const SizedBox(width: 20),
                _buildFooterStat('Out of Stock', '$outOfStockItems', const Color(0xFFEF4444)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'In Stock':
        return Icons.check_circle;
      case 'Low Stock':
        return Icons.warning_amber;
      case 'Critical':
        return Icons.priority_high;
      case 'Out of Stock':
        return Icons.remove_circle;
      default:
        return Icons.circle;
    }
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
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
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