
import 'package:flutter/material.dart';
import 'package:medical_app/Screens/addItemScreen.dart';
import 'package:medical_app/models/product.dart';
import 'package:medical_app/services/database_helper.dart';

// ──────────────────────────────────────────────────────────────
//  ITEMS LIST SCREEN
// ──────────────────────────────────────────────────────────────
class ItemsScreen extends StatefulWidget {
  const ItemsScreen({Key? key}) : super(key: key);

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  // ── State ─────────────────────────────────────────────────
  List<Product> _allProducts = [];
  List<Product> _filtered = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];

  final _searchController = TextEditingController();

  // ── Palette ───────────────────────────────────────────────
  static const _primary = Color(0xFF1565C0);
  static const _surface = Color(0xFFF5F7FA);
  static const _cardBg = Colors.white;
  static const _textDark = Color(0xFF1A1F36);
  static const _textMuted = Color(0xFF6B7280);

  // ─────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Load from DB ─────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final products = await DatabaseHelper.instance.getAllProducts(activeOnly: true);
      final cats = <String>{'All'};
      for (final p in products) {
        if (p.category != null && p.category!.isNotEmpty) cats.add(p.category!);
      }
      setState(() {
        _allProducts = products;
        _categories = cats.toList();
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack('Error loading products: $e');
    }
  }

  // ── Filtering ────────────────────────────────────────────
  void _applyFilters() {
    final q = _searchQuery.toLowerCase();
    setState(() {
      _filtered = _allProducts.where((p) {
        final matchSearch = q.isEmpty ||
            p.itemName.toLowerCase().contains(q) ||
            (p.itemCode?.toLowerCase().contains(q) ?? false) ||
            (p.companyName?.toLowerCase().contains(q) ?? false);
        final matchCat = _selectedCategory == 'All' ||
            p.category == _selectedCategory;
        return matchSearch && matchCat;
      }).toList();
    });
  }

  // ── Delete ───────────────────────────────────────────────
  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to delete "${product.itemName}"?\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && product.id != null) {
      await DatabaseHelper.instance.deleteProduct(product.id!);
      _showSnack('"${product.itemName}" deleted.');
      _load();
    }
  }

  // ── Navigate to Add ──────────────────────────────────────
  void _goToAdd() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddItemScreen()),
    );
    _load(); // refresh after returning
  }

  // ── Navigate to Edit ─────────────────────────────────────
  void _goToEdit(Product product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditItemScreen(product: product)),
    );
    _load();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: _buildAppBar(),
      floatingActionButton: _buildFAB(),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryChips(),
          _buildStats(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? _buildEmpty()
                    : _buildList(),
          ),
        ],
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Products',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _load,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── FAB ──────────────────────────────────────────────────
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _goToAdd,
      backgroundColor: _primary,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'Add Item',
        style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Search Bar ───────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: _primary,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: 'Search by name, code or company…',
          hintStyle: const TextStyle(color: Colors.white60, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _applyFilters();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.15),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) {
          setState(() => _searchQuery = v);
          _applyFilters();
        },
      ),
    );
  }

  // ── Category Chips ───────────────────────────────────────
  Widget _buildCategoryChips() {
    return Container(
      height: 44,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final selected = cat == _selectedCategory;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategory = cat);
              _applyFilters();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? _primary : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? _primary : Colors.grey.shade300,
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : _textMuted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Stats Row ────────────────────────────────────────────
  Widget _buildStats() {
    final lowStock =
        _filtered.where((p) => p.stock <= p.parLevel && p.parLevel > 0).length;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Text(
            '${_filtered.length} item${_filtered.length == 1 ? '' : 's'}',
            style: const TextStyle(
                fontSize: 13, color: _textMuted, fontWeight: FontWeight.w500),
          ),
          if (lowStock > 0) ...[
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber,
                      size: 13, color: Colors.red.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '$lowStock low stock',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No products yet',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + Add Item to get started',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _goToAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add First Item',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── List ─────────────────────────────────────────────────
  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: _filtered.length,
        itemBuilder: (_, i) => _ProductCard(
          product: _filtered[i],
          onEdit: () => _goToEdit(_filtered[i]),
          onDelete: () => _deleteProduct(_filtered[i]),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  PRODUCT CARD
// ──────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  static const _primary = Color(0xFF1565C0);
  static const _textDark = Color(0xFF1A1F36);
  static const _textMuted = Color(0xFF6B7280);

  bool get _isLowStock =>
      product.parLevel > 0 && product.stock <= product.parLevel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isLowStock
              ? Colors.red.shade200
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: name + action buttons ────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.medication_outlined,
                      color: _primary, size: 22),
                ),
                const SizedBox(width: 12),

                // Name + code + category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.itemName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (product.itemCode != null)
                            _tag(product.itemCode!, Colors.blue.shade50,
                                Colors.blue.shade700),
                          if (product.category != null) ...[
                            const SizedBox(width: 6),
                            _tag(product.category!, Colors.purple.shade50,
                                Colors.purple.shade700),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Edit + Delete buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _iconBtn(
                      icon: Icons.edit_outlined,
                      color: _primary,
                      bg: _primary.withOpacity(0.08),
                      onTap: onEdit,
                      tooltip: 'Edit',
                    ),
                    const SizedBox(width: 8),
                    _iconBtn(
                      icon: Icons.delete_outline,
                      color: Colors.red.shade600,
                      bg: Colors.red.shade50,
                      onTap: onDelete,
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 10),

            // ── Bottom row: prices + stock ─────────────────
            Row(
              children: [
                // Trade Price
                Expanded(
                  child: _infoBox(
                    label: 'Trade Price',
                    value: 'Rs. ${product.tradePrice.toStringAsFixed(0)}',
                    valueColor: _textMuted,
                  ),
                ),
                // Retail Price
                Expanded(
                  child: _infoBox(
                    label: 'Retail Price',
                    value: 'Rs. ${product.retailPrice.toStringAsFixed(0)}',
                    valueColor: Colors.green.shade700,
                    isBold: true,
                  ),
                ),
                // Stock
                Expanded(
                  child: _infoBox(
                    label: 'Stock',
                    value: '${product.stock}',
                    valueColor: _isLowStock
                        ? Colors.red.shade600
                        : _textDark,
                    isBold: _isLowStock,
                    icon: _isLowStock
                        ? Icons.warning_amber_rounded
                        : null,
                    iconColor: Colors.red.shade500,
                  ),
                ),
                // Company
                Expanded(
                  child: _infoBox(
                    label: 'Company',
                    value: product.companyName ?? '—',
                    valueColor: _textMuted,
                  ),
                ),
              ],
            ),

            // ── Conversion badge ──────────────────────────
            if (product.hasUnitConversion) ...[
              const SizedBox(height: 8),
              _tag(
                '${(product.conversionTiers?.length ?? 0) + 1}-Tier Conversion',
                Colors.indigo.shade50,
                Colors.indigo.shade600,
                icon: Icons.transform,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color bg, Color fg, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(text,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required Color bg,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _infoBox({
    required String label,
    required String value,
    required Color valueColor,
    bool isBold = false,
    IconData? icon,
    Color? iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: _textMuted)),
        const SizedBox(height: 2),
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isBold ? FontWeight.w700 : FontWeight.w600,
                    color: valueColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  EDIT ITEM SCREEN  (wraps AddItemScreen logic with pre-filled data)
// ──────────────────────────────────────────────────────────────
class EditItemScreen extends StatefulWidget {
  final Product product;
  const EditItemScreen({Key? key, required this.product}) : super(key: key);

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late TextEditingController _itemNameCtrl;
  late TextEditingController _itemCodeCtrl;
  late TextEditingController _barcodeCtrl;
  late TextEditingController _tradePriceCtrl;
  late TextEditingController _retailPriceCtrl;
  late TextEditingController _taxCtrl;
  late TextEditingController _discountCtrl;
  late TextEditingController _parLevelCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _descriptionCtrl;

  String? _selectedCategory;
  String? _selectedCompany;
  String? _selectedIssueUnit;

  List<String> _categories = [];
  List<String> _companies = [];
  List<String> _issueUnits = [];

  static const _primary = Color(0xFF1565C0);
  static const _border = Color(0xFFE2E8F0);
  static const _slate = Color(0xFF1E293B);
  static const _muted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _itemNameCtrl = TextEditingController(text: p.itemName);
    _itemCodeCtrl = TextEditingController(text: p.itemCode ?? '');
    _barcodeCtrl = TextEditingController(text: p.barcode ?? '');
    _tradePriceCtrl =
        TextEditingController(text: p.tradePrice.toStringAsFixed(2));
    _retailPriceCtrl =
        TextEditingController(text: p.retailPrice.toStringAsFixed(2));
    _taxCtrl =
        TextEditingController(text: p.taxPercent.toStringAsFixed(0));
    _discountCtrl =
        TextEditingController(text: p.discountPercent.toStringAsFixed(0));
    _parLevelCtrl =
        TextEditingController(text: p.parLevel.toString());
    _stockCtrl = TextEditingController(text: p.stock.toString());
    _descriptionCtrl =
        TextEditingController(text: p.description ?? '');
    _selectedCategory = p.category;
    _selectedCompany = p.companyName;
    _selectedIssueUnit = p.issueUnit;
    _loadDropdowns();
  }

  @override
  void dispose() {
    for (final c in [
      _itemNameCtrl, _itemCodeCtrl, _barcodeCtrl, _tradePriceCtrl,
      _retailPriceCtrl, _taxCtrl, _discountCtrl, _parLevelCtrl,
      _stockCtrl, _descriptionCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    try {
      final cats = await DatabaseHelper.instance.getAllCategories();
      final brands = await DatabaseHelper.instance.getAllBrands();
      final units = await DatabaseHelper.instance.getAllIssueUnits();
      setState(() {
        _categories = cats.map((c) => c.name).toList();
        _companies = brands.map((b) => b.name).toList();
        _issueUnits = units.map((u) => u.name).toList();
      });
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final updated = widget.product.copyWith(
        itemName: _itemNameCtrl.text.trim(),
        itemCode: _itemCodeCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim().isEmpty
            ? null
            : _barcodeCtrl.text.trim(),
        category: _selectedCategory,
        companyName: _selectedCompany,
        issueUnit: _selectedIssueUnit,
        tradePrice: double.tryParse(_tradePriceCtrl.text) ?? 0,
        retailPrice: double.tryParse(_retailPriceCtrl.text) ?? 0,
        taxPercent: double.tryParse(_taxCtrl.text) ?? 0,
        discountPercent: double.tryParse(_discountCtrl.text) ?? 0,
        parLevel: int.tryParse(_parLevelCtrl.text) ?? 0,
        stock: int.tryParse(_stockCtrl.text) ?? widget.product.stock,
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      await DatabaseHelper.instance.updateProduct(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Product updated successfully!'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Edit: ${widget.product.itemName}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined, color: Colors.white),
            label: Text(
              _isSaving ? 'Saving…' : 'Save',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _section('Basic Information', [
                _field(_itemNameCtrl, 'Item Name *',
                    icon: Icons.medication_outlined,
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                _row([
                  _field(_itemCodeCtrl, 'Item Code',
                      icon: Icons.qr_code, readOnly: true),
                  _field(_barcodeCtrl, 'Barcode',
                      icon: Icons.barcode_reader),
                ]),
                _row([
                  _dropdown('Category', _selectedCategory, _categories,
                      (v) => setState(() => _selectedCategory = v),
                      icon: Icons.category_outlined),
                  _dropdown('Company', _selectedCompany, _companies,
                      (v) => setState(() => _selectedCompany = v),
                      icon: Icons.business_outlined),
                ]),
              ]),
              const SizedBox(height: 16),
              _section('Pricing', [
                _row([
                  _field(_tradePriceCtrl, 'Trade Price *',
                      icon: Icons.price_change_outlined,
                      prefix: 'Rs.',
                      keyboard: TextInputType.number,
                      validator: (v) =>
                          double.tryParse(v ?? '') == null ? 'Invalid' : null),
                  _field(_retailPriceCtrl, 'Retail Price *',
                      icon: Icons.sell_outlined,
                      prefix: 'Rs.',
                      keyboard: TextInputType.number,
                      validator: (v) =>
                          double.tryParse(v ?? '') == null ? 'Invalid' : null),
                ]),
                _row([
                  _field(_taxCtrl, 'Tax %',
                      icon: Icons.receipt_long_outlined,
                      suffix: '%',
                      keyboard: TextInputType.number),
                  _field(_discountCtrl, 'Discount %',
                      icon: Icons.discount_outlined,
                      suffix: '%',
                      keyboard: TextInputType.number),
                ]),
              ]),
              const SizedBox(height: 16),
              _section('Inventory', [
                _row([
                  _field(_stockCtrl, 'Current Stock',
                      icon: Icons.inventory_2_outlined,
                      keyboard: TextInputType.number),
                  _field(_parLevelCtrl, 'PAR Level',
                      icon: Icons.warning_amber_outlined,
                      keyboard: TextInputType.number),
                ]),
                _dropdown('Issue Unit', _selectedIssueUnit, _issueUnits,
                    (v) => setState(() => _selectedIssueUnit = v),
                    icon: Icons.straighten),
                _field(_descriptionCtrl, 'Description',
                    icon: Icons.description_outlined, maxLines: 3),
              ]),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12)),
              border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _slate)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children
                    .expand((w) => [w, const SizedBox(height: 12)])
                    .toList()
                  ..removeLast()),
          ),
        ],
      ),
    );
  }

  Widget _row(List<Widget> children) {
    return Row(
      children: children
          .expand((w) => [Expanded(child: w), const SizedBox(width: 12)])
          .toList()
        ..removeLast(),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    IconData? icon,
    bool readOnly = false,
    String? prefix,
    String? suffix,
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      readOnly: readOnly,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: Colors.grey.shade600, fontSize: 12),
        prefixIcon: icon != null
            ? Icon(icon, size: 18, color: Colors.grey.shade500)
            : null,
        prefixText: prefix != null ? '$prefix ' : null,
        suffixText: suffix,
        filled: true,
        fillColor: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: _primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.red.shade400)),
        errorStyle: const TextStyle(fontSize: 10),
      ),
      validator: validator,
    );
  }

  Widget _dropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged, {
    IconData? icon,
  }) {
    // Ensure value exists in items (avoids assertion error)
    final safeValue =
        items.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      value: safeValue,
      hint: Text(label,
          style:
              TextStyle(color: Colors.grey.shade400, fontSize: 13)),
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down,
          color: Colors.grey.shade500, size: 20),
      style: const TextStyle(fontSize: 13, color: _slate),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: Colors.grey.shade600, fontSize: 12),
        prefixIcon: icon != null
            ? Icon(icon, size: 18, color: Colors.grey.shade500)
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: _primary, width: 1.5)),
      ),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(8),
      items: items
          .map((i) => DropdownMenuItem(value: i, child: Text(i)))
          .toList(),
      onChanged: onChanged,
    );
  }
}