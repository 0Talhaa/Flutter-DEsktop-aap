// lib/screens/reports/inventory_ledger_report.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/models/product.dart';
import 'package:medical_app/models/sale_item.dart';
import 'package:medical_app/services/database_helper.dart';

class InventoryLedgerReport extends StatefulWidget {
  const InventoryLedgerReport({super.key});

  @override
  State<InventoryLedgerReport> createState() => _InventoryLedgerReportState();
}

class _InventoryLedgerReportState extends State<InventoryLedgerReport> {
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();
  Product? selectedProduct;
  bool isAllProducts = false; // NEW: Track if "All Products" is selected

  List<Product> allProducts = [];
  List<Product> filteredProducts = [];
  List<Map<String, dynamic>> ledgerEntries = [];
  List<Map<String, dynamic>> filteredEntries = [];

  bool isLoading = false;
  bool hasGenerated = false;
  String productSearchQuery = '';
  String entrySearchQuery = '';
  String selectedFilter = 'All';

  // Summary metrics
  int totalIn = 0;
  int totalOut = 0;
  int openingStock = 0;
  int closingStock = 0;

  final dateFormat = DateFormat('dd/MM/yyyy');
  final TextEditingController productSearchController = TextEditingController();
  final TextEditingController entrySearchController = TextEditingController();

  final List<String> transactionFilters = ['All', 'Purchases', 'Sales', 'Returns', 'Adjustments'];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await DatabaseHelper.instance.getAllProducts();
    setState(() {
      allProducts = products;
      filteredProducts = products;
    });
  }

  void _filterProducts() {
    setState(() {
      if (productSearchQuery.isEmpty) {
        filteredProducts = allProducts;
      } else {
        filteredProducts = allProducts.where((p) {
          return p.itemName.toLowerCase().contains(productSearchQuery.toLowerCase()) ||
              (p.itemCode?.toLowerCase().contains(productSearchQuery.toLowerCase()) ?? false);
        }).toList();
      }
    });
  }

  Future<void> _generateLedger() async {
    if (!isAllProducts && selectedProduct == null) {
      _showErrorSnackBar('Please select a product or "All Products"');
      return;
    }

    setState(() {
      isLoading = true;
      hasGenerated = false;
    });

    try {
      ledgerEntries = [];

      final from = fromDate.toIso8601String().substring(0, 10);
      final to = toDate.toIso8601String().substring(0, 10);

      if (isAllProducts) {
        // Generate ledger for ALL products
        await _generateAllProductsLedger(from, to);
      } else {
        // Generate ledger for single product
        await _generateSingleProductLedger(from, to);
      }

      // SORT BY DATE
      ledgerEntries.sort((a, b) => a['date'].compareTo(b['date']));

      // Calculate running balance and totals
      _calculateBalances();

      filteredEntries = List.from(ledgerEntries);

      setState(() {
        isLoading = false;
        hasGenerated = true;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error generating ledger: $e');
    }
  }

  Future<void> _generateSingleProductLedger(String from, String to) async {
    final selectedId = selectedProduct!.id;

    // Get opening stock (stock before from date - simplified, using current stock)
    openingStock = selectedProduct!.stock;

    // PURCHASES
    final purchases = await DatabaseHelper.instance.getPurchasesInDateRange(from, to);
    for (var purchase in purchases) {
      final List items = purchase['items'];

      for (var item in items) {
        if (item['productId'] == selectedId) {
          ledgerEntries.add({
            'productId': item['productId'],
            'productName': item['productName'] ?? selectedProduct!.itemName,
            'date': DateTime.parse(purchase['date']),
            'type': 'Purchase',
            'reference': 'PUR-${purchase['invoiceNumber']}',
            'supplier': purchase['supplierName'] ?? '-',
            'inQty': item['quantity'] as int,
            'outQty': 0,
            'rate': (item['tradePrice'] as num?)?.toDouble() ?? 0,
            'balance': 0,
            'icon': Icons.add_circle_outline,
            'color': const Color(0xFF10B981),
          });
        }
      }
    }

    // SALES
    final sales = await DatabaseHelper.instance.getSalesInDateRange(from, to);
    for (var sale in sales) {
      final List<SaleItem> items = sale['items'];

      for (var item in items) {
        if (item.productId == selectedId) {
          ledgerEntries.add({
            'productId': item.productId,
            'productName': item.productName,
            'date': DateTime.parse(sale['dateTime']),
            'type': 'Sale',
            'reference': 'INV-${sale['invoiceId']}',
            'customer': sale['customerName'] ?? 'Walk-in',
            'inQty': 0,
            'outQty': item.quantity,
            'rate': item.price,
            'balance': 0,
            'icon': Icons.remove_circle_outline,
            'color': const Color(0xFFEF4444),
          });
        }
      }
    }

    // Add opening balance entry
    ledgerEntries.insert(0, {
      'productId': selectedId,
      'productName': selectedProduct!.itemName,
      'date': fromDate,
      'type': 'Opening',
      'reference': 'Opening Stock',
      'inQty': openingStock,
      'outQty': 0,
      'rate': selectedProduct!.tradePrice ?? 0,
      'balance': openingStock,
      'icon': Icons.inventory_2_outlined,
      'color': const Color(0xFF6366F1),
    });
  }

  Future<void> _generateAllProductsLedger(String from, String to) async {
    // Calculate total opening stock
    openingStock = 0;
    for (var product in allProducts) {
      openingStock += product.stock;
    }

    // PURCHASES - for all products
    final purchases = await DatabaseHelper.instance.getPurchasesInDateRange(from, to);
    for (var purchase in purchases) {
      final List items = purchase['items'];

      for (var item in items) {
        ledgerEntries.add({
          'productId': item['productId'],
          'productName': item['productName'] ?? 'Unknown Product',
          'date': DateTime.parse(purchase['date']),
          'type': 'Purchase',
          'reference': 'PUR-${purchase['invoiceNumber']}',
          'supplier': purchase['supplierName'] ?? '-',
          'inQty': item['quantity'] as int,
          'outQty': 0,
          'rate': (item['tradePrice'] as num?)?.toDouble() ?? 0,
          'balance': 0,
          'icon': Icons.add_circle_outline,
          'color': const Color(0xFF10B981),
        });
      }
    }

    // SALES - for all products
    final sales = await DatabaseHelper.instance.getSalesInDateRange(from, to);
    for (var sale in sales) {
      final List<SaleItem> items = sale['items'];

      for (var item in items) {
        ledgerEntries.add({
          'productId': item.productId,
          'productName': item.productName,
          'date': DateTime.parse(sale['dateTime']),
          'type': 'Sale',
          'reference': 'INV-${sale['invoiceId']}',
          'customer': sale['customerName'] ?? 'Walk-in',
          'inQty': 0,
          'outQty': item.quantity,
          'rate': item.price,
          'balance': 0,
          'icon': Icons.remove_circle_outline,
          'color': const Color(0xFFEF4444),
        });
      }
    }

    // Add opening balance entry
    ledgerEntries.insert(0, {
      'productId': null,
      'productName': 'All Products',
      'date': fromDate,
      'type': 'Opening',
      'reference': 'Opening Stock',
      'inQty': openingStock,
      'outQty': 0,
      'rate': 0,
      'balance': openingStock,
      'icon': Icons.inventory_2_outlined,
      'color': const Color(0xFF6366F1),
    });
  }

  void _calculateBalances() {
    int runningBalance = openingStock;
    totalIn = 0;
    totalOut = 0;

    for (int i = 1; i < ledgerEntries.length; i++) {
      final entry = ledgerEntries[i];
      final inQty = entry['inQty'] as int;
      final outQty = entry['outQty'] as int;

      totalIn += inQty;
      totalOut += outQty;

      runningBalance = runningBalance + inQty - outQty;
      entry['balance'] = runningBalance;
    }

    closingStock = runningBalance;
  }

  void _filterEntries() {
    setState(() {
      filteredEntries = ledgerEntries.where((entry) {
        bool matchesFilter = selectedFilter == 'All' ||
            entry['type'] == selectedFilter.replaceAll('s', '');
        bool matchesSearch = entrySearchQuery.isEmpty ||
            entry['reference'].toString().toLowerCase().contains(entrySearchQuery.toLowerCase()) ||
            entry['productName'].toString().toLowerCase().contains(entrySearchQuery.toLowerCase());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // Left Panel - Filters & Product Selection
          Container(
            width: 320,
            margin: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildFilterPanel(),
                const SizedBox(height: 16),
                Expanded(child: _buildProductListPanel()),
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
                  if (hasGenerated) ...[
                    _buildSummaryCards(),
                    const SizedBox(height: 16),
                    _buildStockMovementBar(),
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
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.filter_list, color: Color(0xFF10B981), size: 16),
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
              onPressed: isLoading ? null : _generateLedger,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow, size: 18),
              label: Text(isLoading ? 'Loading...' : 'Generate Ledger'),
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

  Widget _buildProductListPanel() {
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
                const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                const Text(
                  'Select Product',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${allProducts.length}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: productSearchController,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search products...',
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
                productSearchQuery = value;
                _filterProducts();
              },
            ),
          ),
          // NEW: "All Products" option
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  isAllProducts = true;
                  selectedProduct = null;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isAllProducts ? const Color(0xFF6366F1).withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isAllProducts ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isAllProducts
                            ? const Color(0xFF6366F1)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.apps,
                        size: 20,
                        color: isAllProducts ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All Products',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isAllProducts ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'View consolidated ledger',
                            style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.check_circle,
                      color: isAllProducts ? const Color(0xFF6366F1) : Colors.grey.shade300,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                final product = filteredProducts[index];
                final isSelected = !isAllProducts && selectedProduct?.id == product.id;
                final isLowStock = product.stock <= (product.parLevel ?? 10);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        selectedProduct = product;
                        isAllProducts = false;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF10B981).withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF10B981) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.medication_outlined,
                              size: 18,
                              color: isSelected ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.itemName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? const Color(0xFF10B981) : const Color(0xFF1E293B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    Text(
                                      product.issueUnit ?? '-',
                                      style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                                    ),
                                    if (product.itemCode != null) ...[
                                      Text(' • ', style: TextStyle(color: Colors.grey.shade400)),
                                      Text(
                                        product.itemCode!,
                                        style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isLowStock
                                      ? const Color(0xFFEF4444).withOpacity(0.1)
                                      : const Color(0xFF10B981).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${product.stock}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isLowStock ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                  ),
                                ),
                              ),
                              if (isLowStock)
                                Row(
                                  children: [
                                    Icon(Icons.warning_amber, size: 10, color: Colors.orange.shade600),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Low',
                                      style: TextStyle(fontSize: 8, color: Colors.orange.shade600),
                                    ),
                                  ],
                                ),
                            ],
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
            child: const Icon(Icons.inventory_outlined, color: Color(0xFF10B981), size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Inventory Ledger',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
              ),
              if (isAllProducts)
                Row(
                  children: [
                    const Text(
                      'All Products',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6366F1), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${DateFormat('dd MMM').format(fromDate)} - ${DateFormat('dd MMM yyyy').format(toDate)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                )
              else if (selectedProduct != null)
                Row(
                  children: [
                    Text(
                      selectedProduct!.itemName,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF10B981), fontWeight: FontWeight.w500),
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
                  'Select a product to view stock movement',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
            ],
          ),
          const Spacer(),
          if (hasGenerated) ...[
            _buildHeaderAction(Icons.refresh, 'Refresh', _generateLedger),
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

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Opening Stock',
            openingStock.toString(),
            Icons.inventory_2_outlined,
            const Color(0xFF6366F1),
            subtitle: 'At period start',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Stock In',
            '+$totalIn',
            Icons.add_circle_outline,
            const Color(0xFF10B981),
            subtitle: 'Purchases',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Stock Out',
            '-$totalOut',
            Icons.remove_circle_outline,
            const Color(0xFFEF4444),
            subtitle: 'Sales',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Closing Stock',
            closingStock.toString(),
            Icons.inventory_outlined,
            closingStock <= (selectedProduct?.parLevel ?? 10) ? const Color(0xFFEF4444) : const Color(0xFF10B981),
            subtitle: 'Current balance',
            isHighlighted: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, {String? subtitle, bool isHighlighted = false}) {
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
                    fontSize: 20,
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

  Widget _buildStockMovementBar() {
    final total = totalIn + totalOut;
    final inPercent = total > 0 ? (totalIn / total) : 0.5;
    final outPercent = total > 0 ? (totalOut / total) : 0.5;

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
                'Stock Movement',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              const Spacer(),
              _buildMovementLegend('In', totalIn, const Color(0xFF10B981)),
              const SizedBox(width: 16),
              _buildMovementLegend('Out', totalOut, const Color(0xFFEF4444)),
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
                  Expanded(
                    flex: (inPercent * 100).toInt().clamp(1, 99),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF34D399)],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: (outPercent * 100).toInt().clamp(1, 99),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFF87171)],
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
                '${(inPercent * 100).toStringAsFixed(1)}% Inward',
                style: const TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w500),
              ),
              Text(
                '${(outPercent * 100).toStringAsFixed(1)}% Outward',
                style: const TextStyle(fontSize: 10, color: Color(0xFFEF4444), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMovementLegend(String label, int value, Color color) {
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
        Text(
          '$label: $value',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

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
            width: 220,
            child: TextField(
              controller: entrySearchController,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search transactions...',
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
                entrySearchQuery = value;
                _filterEntries();
              },
            ),
          ),
          const SizedBox(width: 16),
          // Filter chips
          ...transactionFilters.take(3).map((filter) {
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
                    color: isActive ? const Color(0xFF10B981) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
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
            '${filteredEntries.length} entries',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

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
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 16),
              Text(
                'No Ledger Generated',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a product and click "Generate Ledger"',
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
                _buildTableHeader('Type', flex: 2),
                if (isAllProducts) _buildTableHeader('Product', flex: 3),
                _buildTableHeader('Reference', flex: 3),
                _buildTableHeader('Details', flex: 3),
                _buildTableHeader('In', flex: 2, align: TextAlign.center),
                _buildTableHeader('Out', flex: 2, align: TextAlign.center),
                _buildTableHeader('Balance', flex: 2, align: TextAlign.center),
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
                        Icon(Icons.search_off, size: 40, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No transactions found',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredEntries.length,
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];
                      final isEven = index % 2 == 0;
                      final inQty = entry['inQty'] as int;
                      final outQty = entry['outQty'] as int;
                      final balance = entry['balance'] as int;

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
                            // Date
                            Expanded(
                              flex: 2,
                              child: Text(
                                dateFormat.format(entry['date']),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
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
                                  Expanded(
                                    child: Text(
                                      entry['type'],
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: entry['color'] as Color,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Product Name (only for "All Products" view)
                            if (isAllProducts)
                              Expanded(
                                flex: 3,
                                child: Text(
                                  entry['productName'],
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1E293B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            // Reference
                            Expanded(
                              flex: 3,
                              child: Text(
                                entry['reference'],
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF3B82F6),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Details
                            Expanded(
                              flex: 3,
                              child: Text(
                                entry['supplier'] ?? entry['customer'] ?? '-',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // In
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: inQty > 0
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '+$inQty',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      )
                                    : Text('-', style: TextStyle(color: Colors.grey.shade400)),
                              ),
                            ),
                            // Out
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: outQty > 0
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '-$outQty',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFEF4444),
                                          ),
                                        ),
                                      )
                                    : Text('-', style: TextStyle(color: Colors.grey.shade400)),
                              ),
                            ),
                            // Balance
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    balance.toString(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
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
                // Product Info
                if (!isAllProducts && selectedProduct != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.medication, size: 16, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedProduct!.itemName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        '${selectedProduct!.issueUnit ?? '-'} • ${selectedProduct!.companyName ?? 'N/A'}',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ] else if (isAllProducts) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.apps, size: 16, color: Color(0xFF6366F1)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'All Products',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      ),
                      Text(
                        'Consolidated ledger',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ],
                const Spacer(),
                _buildFooterStat('Total In', '+$totalIn', const Color(0xFF10B981)),
                const SizedBox(width: 20),
                _buildFooterStat('Total Out', '-$totalOut', const Color(0xFFEF4444)),
                const SizedBox(width: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory, size: 16, color: Colors.white70),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Closing Stock',
                            style: TextStyle(fontSize: 9, color: Colors.white70),
                          ),
                          Text(
                            closingStock.toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
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
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  @override
  void dispose() {
    productSearchController.dispose();
    entrySearchController.dispose();
    super.dispose();
  }
}