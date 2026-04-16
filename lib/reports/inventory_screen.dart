// lib/screens/inventory_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/models/product.dart';
import 'package:medical_app/services/database_helper.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Product> products = [];
  List<Product> filteredProducts = [];
  String searchQuery = '';
  bool isLoading = true;
  String _selectedFilter = 'All';

  final currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() => isLoading = true);

    final data = await DatabaseHelper.instance.getAllProducts();

    setState(() {
      products = data;
      _applyFilters();
      isLoading = false;
    });
  }

  void _applyFilters() {
    List<Product> result = products;

    // Apply search
    if (searchQuery.isNotEmpty) {
      result = result.where((p) {
        return p.itemName.toLowerCase().contains(searchQuery.toLowerCase()) ||
            (p.itemCode?.toLowerCase().contains(searchQuery.toLowerCase()) ??
                false) ||
            (p.companyName
                    ?.toLowerCase()
                    .contains(searchQuery.toLowerCase()) ??
                false);
      }).toList();
    }

    // Apply category filter
    switch (_selectedFilter) {
      case 'Low Stock':
        result = result
            .where((p) =>
                (p.stock ?? 0) < (p.parLevel ?? 0) && (p.stock ?? 0) > 0)
            .toList();
        break;
      case 'Out of Stock':
        result = result.where((p) => (p.stock ?? 0) == 0).toList();
        break;
      case 'In Stock':
        result = result
            .where((p) => (p.stock ?? 0) >= (p.parLevel ?? 0))
            .toList();
        break;
    }

    filteredProducts = result;
  }

  void _filterProducts(String query) {
    setState(() {
      searchQuery = query;
      _applyFilters();
    });
  }

  void _setFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    int totalItems = products.length;
    int lowStockCount = products
        .where((p) =>
            (p.stock ?? 0) < (p.parLevel ?? 0) && (p.stock ?? 0) > 0)
        .length;
    int outOfStockCount = products.where((p) => (p.stock ?? 0) == 0).length;
    int inStockCount = products
        .where((p) => (p.stock ?? 0) >= (p.parLevel ?? 0))
        .length;
    double totalStockValue = products.fold(
        0.0, (sum, p) => sum + (p.retailPrice * (p.stock ?? 0)));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // ── Header Section ──
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inventory Management',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage and adjust your product stock levels',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _headerActionButton(
                          icon: Icons.file_download_outlined,
                          label: 'Export',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Export feature coming soon')),
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        _headerActionButton(
                          icon: Icons.refresh,
                          label: 'Refresh',
                          onTap: _loadInventory,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Summary Cards ──
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Total Items',
                        value: totalItems.toString(),
                        icon: Icons.inventory_2_outlined,
                        color: Colors.white,
                        isSelected: _selectedFilter == 'All',
                        onTap: () => _setFilter('All'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'In Stock',
                        value: inStockCount.toString(),
                        icon: Icons.check_circle_outline,
                        color: Colors.greenAccent,
                        isSelected: _selectedFilter == 'In Stock',
                        onTap: () => _setFilter('In Stock'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Low Stock',
                        value: lowStockCount.toString(),
                        icon: Icons.warning_amber_rounded,
                        color: Colors.orangeAccent,
                        isSelected: _selectedFilter == 'Low Stock',
                        onTap: () => _setFilter('Low Stock'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Out of Stock',
                        value: outOfStockCount.toString(),
                        icon: Icons.cancel_outlined,
                        color: Colors.redAccent,
                        isSelected: _selectedFilter == 'Out of Stock',
                        onTap: () => _setFilter('Out of Stock'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Stock Value',
                        value: currencyFormat.format(totalStockValue),
                        icon: Icons.account_balance_wallet_outlined,
                        color: Colors.lightGreenAccent,
                        isSelected: false,
                        onTap: () {},
                        isValueCard: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: _filterProducts,
                      decoration: InputDecoration(
                        hintText: 'Search by name, code or company...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon:
                            Icon(Icons.search, color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: _selectedFilter,
                        underline: const SizedBox(),
                        items: ['All', 'In Stock', 'Low Stock', 'Out of Stock']
                            .map((f) => DropdownMenuItem(
                                value: f, child: Text(f)))
                            .toList(),
                        onChanged: (v) => _setFilter(v!),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Results info ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${filteredProducts.length} of ${products.length} items',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_selectedFilter != 'All')
                  TextButton.icon(
                    onPressed: () => _setFilter('All'),
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Clear Filter'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),

          // ── Stock Table ──
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border(
                          bottom:
                              BorderSide(color: Colors.grey[300]!, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          _tableHeader('Code', 1),
                          _tableHeader('Item Name', 3),
                          _tableHeader('Company', 2),
                          _tableHeader('Packing', 1),
                          _tableHeaderCenter('Stock', 1),
                          _tableHeaderCenter('PAR Level', 1),
                          _tableHeader('Status', 1),
                          _tableHeaderRight('Retail Price', 2),
                          _tableHeaderRight('Stock Value', 2),
                          _tableHeaderCenter('Adjust Stock', 2),
                        ],
                      ),
                    ),

                    // Table Body
                    Expanded(
                      child: isLoading
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Loading inventory...'),
                                ],
                              ),
                            )
                          : filteredProducts.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inventory_2_outlined,
                                          size: 64,
                                          color: Colors.grey[300]),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No items found',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey[500],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Try adjusting your search or filter',
                                        style: TextStyle(
                                            color: Colors.grey[400]),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: filteredProducts.length,
                                  itemBuilder: (context, i) {
                                    final p = filteredProducts[i];
                                    return _buildProductRow(p, i);
                                  },
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
  }

  // ── Product Row ──
  Widget _buildProductRow(Product p, int index) {
    bool isLowStock =
        (p.stock ?? 0) < (p.parLevel ?? 0) && (p.stock ?? 0) > 0;
    bool isOutOfStock = (p.stock ?? 0) == 0;
    double value = p.retailPrice * (p.stock ?? 0);

    Color rowColor = index % 2 == 0 ? Colors.white : const Color(0xFFFAFBFC);
    if (isOutOfStock) rowColor = Colors.red.shade50;
    if (isLowStock) rowColor = Colors.orange.shade50;

    return Container(
      decoration: BoxDecoration(
        color: rowColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Row(
        children: [
          // Code
          Expanded(
            flex: 1,
            child: Text(
              p.itemCode ?? '-',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontFamily: 'monospace',
              ),
            ),
          ),

          // Item Name
          Expanded(
            flex: 3,
            child: Text(
              p.itemName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),

          // Company
          Expanded(
            flex: 2,
            child: Text(
              p.companyName ?? '-',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),

          // Packing
          Expanded(
            flex: 1,
            child: Text(
              p.issueUnit ?? '-',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),

          // Stock
          Expanded(
            flex: 1,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isOutOfStock
                      ? Colors.red[100]
                      : isLowStock
                          ? Colors.orange[100]
                          : Colors.green[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  (p.stock ?? 0).toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isOutOfStock
                        ? Colors.red[800]
                        : isLowStock
                            ? Colors.orange[800]
                            : Colors.green[800],
                  ),
                ),
              ),
            ),
          ),

          // PAR Level
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                (p.parLevel ?? 0).toString(),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),

          // Status Badge
          Expanded(
            flex: 1,
            child: _stockStatusBadge(p),
          ),

          // Retail Price
          Expanded(
            flex: 2,
            child: Text(
              currencyFormat.format(p.retailPrice),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),

          // Stock Value
          Expanded(
            flex: 2,
            child: Text(
              currencyFormat.format(value),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Action Buttons - Add / Subtract / Edit
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Subtract Button
                _actionIconButton(
                  icon: Icons.remove,
                  color: Colors.red,
                  tooltip: 'Subtract Stock',
                  onPressed: () =>
                      _showAdjustStockDialog(p, AdjustmentType.subtract),
                ),
                const SizedBox(width: 4),
                // Add Button
                _actionIconButton(
                  icon: Icons.add,
                  color: Colors.green,
                  tooltip: 'Add Stock',
                  onPressed: () =>
                      _showAdjustStockDialog(p, AdjustmentType.add),
                ),
                const SizedBox(width: 4),
                // Set Stock Button
                _actionIconButton(
                  icon: Icons.edit,
                  color: Colors.blue,
                  tooltip: 'Set Stock',
                  onPressed: () =>
                      _showAdjustStockDialog(p, AdjustmentType.set),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stock Status Badge ──
  Widget _stockStatusBadge(Product p) {
    bool isLowStock =
        (p.stock ?? 0) < (p.parLevel ?? 0) && (p.stock ?? 0) > 0;
    bool isOutOfStock = (p.stock ?? 0) == 0;

    String label;
    Color bgColor;
    Color textColor;
    IconData icon;

    if (isOutOfStock) {
      label = 'Out';
      bgColor = Colors.red[50]!;
      textColor = Colors.red[700]!;
      icon = Icons.cancel;
    } else if (isLowStock) {
      label = 'Low';
      bgColor = Colors.orange[50]!;
      textColor = Colors.orange[700]!;
      icon = Icons.warning;
    } else {
      label = 'OK';
      bgColor = Colors.green[50]!;
      textColor = Colors.green[700]!;
      icon = Icons.check_circle;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: textColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Action Icon Button ──
  Widget _actionIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // ══  ADJUST STOCK DIALOG (Add / Subtract / Set)
  // ══════════════════════════════════════════════
  void _showAdjustStockDialog(Product product, AdjustmentType type) {
  final quantityController = TextEditingController();
  final reasonController = TextEditingController();
  String? selectedReason;
  AdjustmentType currentType = type;
  int currentStock = product.stock ?? 0;
  int previewStock = currentStock;
  bool hasError = false;
  String errorMessage = '';

  List<String> addReasons = [
    'Purchase / Restock',
    'Return from Customer',
    'Transfer In',
    'Found in Audit',
    'Opening Stock',
    'Other',
  ];

  List<String> subtractReasons = [
    'Damaged / Expired',
    'Lost / Missing',
    'Return to Supplier',
    'Transfer Out',
    'Adjustment / Correction',
    'Sample / Demo',
    'Other',
  ];

  List<String> setReasons = [
    'Physical Count',
    'Stock Audit',
    'System Correction',
    'Opening Balance',
    'Other',
  ];

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          List<String> reasons = currentType == AdjustmentType.add
              ? addReasons
              : currentType == AdjustmentType.subtract
                  ? subtractReasons
                  : setReasons;

          void updatePreview() {
            int qty = int.tryParse(quantityController.text) ?? 0;
            hasError = false;
            errorMessage = '';

            switch (currentType) {
              case AdjustmentType.add:
                previewStock = currentStock + qty;
                break;
              case AdjustmentType.subtract:
                previewStock = currentStock - qty;
                if (previewStock < 0) {
                  hasError = true;
                  errorMessage =
                      'Cannot subtract more than current stock ($currentStock)';
                  previewStock = currentStock;
                }
                break;
              case AdjustmentType.set:
                previewStock = qty;
                if (qty < 0) {
                  hasError = true;
                  errorMessage = 'Stock cannot be negative';
                  previewStock = currentStock;
                }
                break;
            }
            setDialogState(() {});
          }

          Color typeColor = currentType == AdjustmentType.add
              ? Colors.green
              : currentType == AdjustmentType.subtract
                  ? Colors.red
                  : Colors.blue;

          IconData typeIcon = currentType == AdjustmentType.add
              ? Icons.add_circle_outline
              : currentType == AdjustmentType.subtract
                  ? Icons.remove_circle_outline
                  : Icons.edit_outlined;

          String typeTitle = currentType == AdjustmentType.add
              ? 'Add Stock'
              : currentType == AdjustmentType.subtract
                  ? 'Subtract Stock'
                  : 'Set Stock';

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            // ✅ ADD: Constrain dialog height
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Dialog Header (stays fixed at top) ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          typeColor.withOpacity(0.9),
                          typeColor.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(typeIcon,
                              color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                typeTitle,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                product.itemName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      Colors.white.withOpacity(0.9),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  // ✅ SCROLLABLE BODY
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          // ── Product Info Card ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                _productInfoItem('Code',
                                    product.itemCode ?? '-'),
                                _divider(),
                                _productInfoItem('Company',
                                    product.companyName ?? '-'),
                                _divider(),
                                _productInfoItem('Packing',
                                    product.issueUnit ?? '-'),
                                _divider(),
                                _productInfoItem(
                                    'PAR Level',
                                    (product.parLevel ?? 0)
                                        .toString()),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Adjustment Type Selector ──
                          const Text(
                            'Adjustment Type',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _adjustmentTypeButton(
                                label: 'Add',
                                icon: Icons.add_circle_outline,
                                color: Colors.green,
                                isSelected: currentType ==
                                    AdjustmentType.add,
                                onTap: () {
                                  currentType = AdjustmentType.add;
                                  selectedReason = null;
                                  updatePreview();
                                },
                              ),
                              const SizedBox(width: 12),
                              _adjustmentTypeButton(
                                label: 'Subtract',
                                icon:
                                    Icons.remove_circle_outline,
                                color: Colors.red,
                                isSelected: currentType ==
                                    AdjustmentType.subtract,
                                onTap: () {
                                  currentType =
                                      AdjustmentType.subtract;
                                  selectedReason = null;
                                  updatePreview();
                                },
                              ),
                              const SizedBox(width: 12),
                              _adjustmentTypeButton(
                                label: 'Set',
                                icon: Icons.edit_outlined,
                                color: Colors.blue,
                                isSelected: currentType ==
                                    AdjustmentType.set,
                                onTap: () {
                                  currentType = AdjustmentType.set;
                                  selectedReason = null;
                                  updatePreview();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── Quantity Input ──
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentType ==
                                              AdjustmentType.set
                                          ? 'New Stock Quantity'
                                          : 'Quantity',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(
                                                12),
                                        border: Border.all(
                                          color: hasError
                                              ? Colors.red
                                              : Colors.grey[300]!,
                                          width:
                                              hasError ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          if (currentType !=
                                              AdjustmentType.set)
                                            InkWell(
                                              onTap: () {
                                                int current =
                                                    int.tryParse(
                                                            quantityController
                                                                .text) ??
                                                        0;
                                                if (current > 0) {
                                                  quantityController
                                                          .text =
                                                      (current - 1)
                                                          .toString();
                                                  updatePreview();
                                                }
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets
                                                        .all(12),
                                                decoration:
                                                    BoxDecoration(
                                                  color: Colors
                                                      .grey[100],
                                                  borderRadius:
                                                      const BorderRadius
                                                          .only(
                                                    topLeft: Radius
                                                        .circular(
                                                            11),
                                                    bottomLeft: Radius
                                                        .circular(
                                                            11),
                                                  ),
                                                ),
                                                child: const Icon(
                                                    Icons.remove,
                                                    size: 20),
                                              ),
                                            ),
                                          Expanded(
                                            child: TextField(
                                              controller:
                                                  quantityController,
                                              keyboardType:
                                                  TextInputType
                                                      .number,
                                              textAlign:
                                                  TextAlign.center,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                              style:
                                                  const TextStyle(
                                                fontSize: 20,
                                                fontWeight:
                                                    FontWeight.bold,
                                              ),
                                              decoration:
                                                  const InputDecoration(
                                                hintText: '0',
                                                border:
                                                    InputBorder
                                                        .none,
                                                contentPadding:
                                                    EdgeInsets
                                                        .symmetric(
                                                            vertical:
                                                                12),
                                              ),
                                              onChanged: (_) =>
                                                  updatePreview(),
                                            ),
                                          ),
                                          if (currentType !=
                                              AdjustmentType.set)
                                            InkWell(
                                              onTap: () {
                                                int current =
                                                    int.tryParse(
                                                            quantityController
                                                                .text) ??
                                                        0;
                                                quantityController
                                                        .text =
                                                    (current + 1)
                                                        .toString();
                                                updatePreview();
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets
                                                        .all(12),
                                                decoration:
                                                    BoxDecoration(
                                                  color: Colors
                                                      .grey[100],
                                                  borderRadius:
                                                      const BorderRadius
                                                          .only(
                                                    topRight: Radius
                                                        .circular(
                                                            11),
                                                    bottomRight:
                                                        Radius
                                                            .circular(
                                                                11),
                                                  ),
                                                ),
                                                child: const Icon(
                                                    Icons.add,
                                                    size: 20),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (hasError)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(
                                                top: 6),
                                        child: Text(
                                          errorMessage,
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),

                              // ── Stock Preview ──
                              Expanded(
                                child: Container(
                                  padding:
                                      const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: typeColor
                                        .withOpacity(0.05),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: Border.all(
                                        color: typeColor
                                            .withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .spaceEvenly,
                                        children: [
                                          Column(
                                            children: [
                                              Text(
                                                'Current',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors
                                                      .grey[600],
                                                ),
                                              ),
                                              const SizedBox(
                                                  height: 4),
                                              Text(
                                                currentStock
                                                    .toString(),
                                                style:
                                                    const TextStyle(
                                                  fontSize: 24,
                                                  fontWeight:
                                                      FontWeight
                                                          .bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Icon(
                                            Icons.arrow_forward,
                                            color: typeColor,
                                            size: 28,
                                          ),
                                          Column(
                                            children: [
                                              Text(
                                                'New',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors
                                                      .grey[600],
                                                ),
                                              ),
                                              const SizedBox(
                                                  height: 4),
                                              Text(
                                                previewStock
                                                    .toString(),
                                                style: TextStyle(
                                                  fontSize: 24,
                                                  fontWeight:
                                                      FontWeight
                                                          .bold,
                                                  color: typeColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (previewStock !=
                                          currentStock) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 12,
                                              vertical: 4),
                                          decoration:
                                              BoxDecoration(
                                            color: typeColor
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius
                                                    .circular(20),
                                          ),
                                          child: Text(
                                            '${previewStock > currentStock ? '+' : ''}${previewStock - currentStock} units',
                                            style: TextStyle(
                                              color: typeColor,
                                              fontWeight:
                                                  FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── Reason Dropdown ──
                          const Text(
                            'Reason for Adjustment',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey[300]!),
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: DropdownButton<String>(
                              value: selectedReason,
                              isExpanded: true,
                              underline: const SizedBox(),
                              hint: const Text(
                                  'Select reason for adjustment...'),
                              items: reasons
                                  .map((r) => DropdownMenuItem(
                                      value: r,
                                      child: Text(r)))
                                  .toList(),
                              onChanged: (v) {
                                setDialogState(
                                    () => selectedReason = v);
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Notes ──
                          const Text(
                            'Notes (Optional)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: reasonController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText:
                                  'Add any additional notes...',
                              hintStyle: TextStyle(
                                  color: Colors.grey[400]),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.grey[300]!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ✅ ACTION BUTTONS (fixed at bottom)
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                              side: BorderSide(
                                  color: Colors.grey[300]!),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: hasError ||
                                    (quantityController
                                        .text.isEmpty) ||
                                    selectedReason == null
                                ? null
                                : () async {
                                    await DatabaseHelper.instance
                                        .updateProductStock(
                                            product.id!,
                                            previewStock);
                                    _loadInventory();
                                    Navigator.pop(context);

                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(
                                                Icons.check_circle,
                                                color:
                                                    Colors.white),
                                            const SizedBox(
                                                width: 12),
                                            Expanded(
                                              child: Text(
                                                '${product.itemName} stock updated: $currentStock → $previewStock',
                                                style:
                                                    const TextStyle(
                                                  fontWeight:
                                                      FontWeight
                                                          .w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        backgroundColor:
                                            typeColor,
                                        behavior:
                                            SnackBarBehavior
                                                .floating,
                                        shape:
                                            RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius
                                                  .circular(12),
                                        ),
                                        margin:
                                            const EdgeInsets.all(
                                                16),
                                        duration:
                                            const Duration(
                                                seconds: 3),
                                      ),
                                    );
                                  },
                            icon: Icon(typeIcon, size: 20),
                            label: Text(
                              'Confirm $typeTitle',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: typeColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  Colors.grey[300],
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  // ── Helper Widgets ──

  Widget _headerActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    bool isValueCard = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.25)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.5)
                : Colors.white.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
                if (isSelected)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: isValueCard ? 16 : 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _tableHeaderCenter(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _tableHeaderRight(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _productInfoItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 30,
      color: Colors.grey[300],
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _adjustmentTypeButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? color : Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? color : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Adjustment Type Enum ──
enum AdjustmentType {
  add,
  subtract,
  set,
}