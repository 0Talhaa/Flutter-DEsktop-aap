// lib/screens/add_item_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medical_app/Screens/dashboardScreen.dart';
import 'package:medical_app/services/database_helper.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/brand.dart';
import '../models/issue_unit.dart';

// ============================================================
// MODEL: Represents one dynamic conversion tier
// ============================================================
class UnitConversionRow {
  final String id;
  TextEditingController nameController;      // e.g. "Strip", "Box", "Carton"
  TextEditingController quantityController;  // e.g. 10 (tablets per strip)
  TextEditingController priceController;     // price for this unit
  String containsUnit;                       // what the quantity refers to (previous tier)

  UnitConversionRow({
    required this.id,
    String name = '',
    String quantity = '',
    String price = '',
    this.containsUnit = '',
  })  : nameController = TextEditingController(text: name),
        quantityController = TextEditingController(text: quantity),
        priceController = TextEditingController(text: price);

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    priceController.dispose();
  }
}

// ============================================================
// SCREEN
// ============================================================
class AddItemScreen extends StatefulWidget {
  const AddItemScreen({Key? key}) : super(key: key);

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isLoading = true;

  // Basic Controllers
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _itemCodeController = TextEditingController();
  final TextEditingController _tradePriceController = TextEditingController();
  final TextEditingController _retailPriceController = TextEditingController();
  final TextEditingController _taxController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _parLevelController = TextEditingController();
  final TextEditingController _issueUnitController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Base unit price controller
  final TextEditingController _pricePerBaseUnitController = TextEditingController();

  String? _selectedCompany;
  String? _selectedCategory;
  String? _selectedIssueUnit;
  String _selectedBaseUnit = 'Tablet';
  bool _enableUnitConversion = false;

  // ── Dynamic conversion tiers (user can add/remove) ──────────
  final List<UnitConversionRow> _conversionRows = [];
  int _rowIdCounter = 0;

  // Preset unit names for quick-pick
  final List<String> _presetUnitNames = [
    'Strip',
    'Box',
    'Carton',
    'Pack',
    'Bottle',
    'Dozen',
    'Vial',
    'Ampule',
    'Case',
    'Pallet',
  ];

  // ── Dropdown lists (loaded from database) ───────────────────
  List<String> companies = [];
  List<String> categories = [];
  List<String> issueUnits = [];

  final List<String> baseUnits = [
    'Tablet',
    'Capsule',
    'Piece',
    'ML',
    'MG',
    'Unit',
  ];

  // ── Colors ───────────────────────────────────────────────────
  static const Color _blue = Color(0xFF3B82F6);
  static const Color _green = Color(0xFF10B981);
  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _slate = Color(0xFF1E293B);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  // Tier accent colours (cycles if user adds many rows)
  final List<Color> _tierColors = [
    const Color(0xFF10B981), // green
    const Color(0xFFF59E0B), // amber
    const Color(0xFF8B5CF6), // purple
    const Color(0xFFEF4444), // red
    const Color(0xFF06B6D4), // cyan
    const Color(0xFFF97316), // orange
  ];

  Color _colorForIndex(int index) => _tierColors[index % _tierColors.length];

  @override
  void initState() {
    super.initState();
    _generateItemCode();
    _loadDropdownData();
    _tradePriceController.addListener(() => setState(() {}));
    _retailPriceController.addListener(() => setState(() {}));
    _pricePerBaseUnitController.addListener(_recalcAllPrices);
  }

  // ============================================================
  // LOAD DATA FROM DATABASE
  // ============================================================
  Future<void> _loadDropdownData() async {
    setState(() => _isLoading = true);

    try {
      // Load Categories
      final categoriesList = await DatabaseHelper.instance.getAllCategories();
      categories = categoriesList.map((c) => c.name).toList();

      // Load Brands/Companies
      final brandsList = await DatabaseHelper.instance.getAllBrands();
      companies = brandsList.map((b) => b.name).toList();

      // Load Issue Units
      final unitsList = await DatabaseHelper.instance.getAllIssueUnits();
      issueUnits = unitsList.map((u) => u.name).toList();

      // Add "Other" option if not exists
      if (!categories.contains('Other')) categories.add('Other');
      if (!companies.contains('Other')) companies.add('Other');

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ Error loading dropdown data: $e');
      
      // Fallback to default values if database fails
      _loadDefaultDropdownValues();
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Using default values. Database error: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _loadDefaultDropdownValues() {
    categories = [
      'Tablets',
      'Capsules',
      'Syrups',
      'Injections',
      'Creams & Ointments',
      'Drops',
      'Surgical Items',
      'Baby Care',
      'Personal Care',
      'Other',
    ];

    companies = [
      'GlaxoSmithKline (GSK)',
      'Pfizer',
      'Getz Pharma',
      'Searle Pakistan',
      'Abbott Laboratories',
      'Sanofi',
      'Martin Dow',
      'Hilton Pharma',
      'Sami Pharmaceuticals',
      'Bosch Pharmaceuticals',
      'High-Q Pharmaceuticals',
      'Other',
    ];

    issueUnits = [
      'Piece',
      'Strip',
      'Box',
      'Bottle',
      'Tube',
      'Vial',
      'Ampule',
      'Pack',
      'Tablet',
      'Capsule',
    ];
  }

  void _generateItemCode() {
    final now = DateTime.now();
    _itemCodeController.text = 'ITM${now.millisecondsSinceEpoch % 100000}';
  }

  // ── Dynamic row management ───────────────────────────────────

  void _addConversionRow() {
    final previousUnit = _conversionRows.isEmpty
        ? _selectedBaseUnit
        : (_conversionRows.last.nameController.text.isNotEmpty
            ? _conversionRows.last.nameController.text
            : 'Unit');

    final row = UnitConversionRow(
      id: 'row_${_rowIdCounter++}',
      quantity: '10',
      containsUnit: previousUnit,
    );

    // listen for changes to recalc downstream prices
    row.quantityController.addListener(_recalcAllPrices);
    row.priceController.addListener(() => setState(() {}));
    row.nameController.addListener(() => setState(() {}));

    setState(() => _conversionRows.add(row));
  }

  void _removeConversionRow(int index) {
    _conversionRows[index].dispose();
    setState(() {
      _conversionRows.removeAt(index);
      _fixContainsUnits();
    });
    _recalcAllPrices();
  }

  /// After any add/remove/rename, refresh the `containsUnit` label for each row
  void _fixContainsUnits() {
    for (int i = 0; i < _conversionRows.length; i++) {
      if (i == 0) {
        _conversionRows[i].containsUnit = _selectedBaseUnit;
      } else {
        final prevName = _conversionRows[i - 1].nameController.text;
        _conversionRows[i].containsUnit =
            prevName.isNotEmpty ? prevName : 'Unit';
      }
    }
  }

  /// Recalculate every tier's price bottom-up from base unit price
  void _recalcAllPrices() {
    if (!_enableUnitConversion || _conversionRows.isEmpty) {
      setState(() {});
      return;
    }

    double basePrice = double.tryParse(_pricePerBaseUnitController.text) ?? 0;
    double runningPrice = basePrice;

    for (int i = 0; i < _conversionRows.length; i++) {
      final row = _conversionRows[i];
      final qty = int.tryParse(row.quantityController.text) ?? 1;
      final calculated = runningPrice * qty;

      // Only auto-fill if field is empty or zero so the user can override
      final existing = double.tryParse(row.priceController.text) ?? 0;
      if (existing == 0) {
        row.priceController.removeListener(_recalcAllPrices);
        row.priceController.text = calculated.toStringAsFixed(2);
        row.priceController.addListener(_recalcAllPrices);
      }
      runningPrice = double.tryParse(row.priceController.text) ?? calculated;
    }

    setState(() {});
  }

  // ── Save ─────────────────────────────────────────────────────

    Future<void> _saveItem() async {
      if (!_formKey.currentState!.validate()) return;
      setState(() => _isSaving = true);

      try {
        // ✅ Build conversionTiers from the dynamic rows
        List<Map<String, dynamic>>? tiers;
        if (_enableUnitConversion && _conversionRows.isNotEmpty) {
          tiers = [];
          for (int i = 0; i < _conversionRows.length; i++) {
            final row = _conversionRows[i];
            final previousUnitName = i == 0
                ? _selectedBaseUnit
                : (_conversionRows[i - 1].nameController.text.isNotEmpty
                    ? _conversionRows[i - 1].nameController.text
                    : 'Unit');
            tiers.add({
              'name': row.nameController.text.isNotEmpty
                  ? row.nameController.text
                  : 'Tier ${i + 1}',
              'quantity': int.tryParse(row.quantityController.text) ?? 1,
              'price': double.tryParse(row.priceController.text) ?? 0.0,
              'containsUnit': previousUnitName,
            });
          }
        }

        final newProduct = Product(
          itemName: _itemNameController.text.trim(),
          itemCode: _itemCodeController.text.trim(),
          barcode: _barcodeController.text.trim().isNotEmpty
              ? _barcodeController.text.trim()
              : null,
          category: _selectedCategory,
          tradePrice: double.parse(_tradePriceController.text),
          retailPrice: double.parse(_retailPriceController.text),
          taxPercent: double.tryParse(_taxController.text) ?? 0.0,
          discountPercent: double.tryParse(_discountController.text) ?? 0.0,
          parLevel: int.tryParse(_parLevelController.text) ?? 0,
          stock: 0,
          issueUnit: _enableUnitConversion
              ? _selectedBaseUnit
              : (_selectedIssueUnit ?? _issueUnitController.text.trim()),
          companyName: _selectedCompany ?? 'Other',
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          createdAt: DateTime.now().toIso8601String(),
          // Unit conversion fields
          hasUnitConversion: _enableUnitConversion,
          baseUnit: _enableUnitConversion ? _selectedBaseUnit : null,
          // ✅ Save ALL dynamic tiers as JSON
          conversionTiers: tiers,
          // Legacy fields (first 2 tiers for backward compat)
          unitsPerStrip: (_enableUnitConversion && _conversionRows.isNotEmpty)
              ? int.tryParse(_conversionRows[0].quantityController.text)
              : null,
          stripsPerBox: (_enableUnitConversion && _conversionRows.length >= 2)
              ? int.tryParse(_conversionRows[1].quantityController.text)
              : null,
          pricePerUnit: _enableUnitConversion
              ? double.tryParse(_pricePerBaseUnitController.text)
              : null,
          pricePerStrip: (_enableUnitConversion && _conversionRows.isNotEmpty)
              ? double.tryParse(_conversionRows[0].priceController.text)
              : null,
          pricePerBox: (_enableUnitConversion && _conversionRows.length >= 2)
              ? double.tryParse(_conversionRows[1].priceController.text)
              : null,
        );

        await DatabaseHelper.instance.addProduct(newProduct);
        if (mounted) _showSuccessDialog();
      } catch (e) {
        setState(() => _isSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save item: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: _green, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Item Added Successfully!',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _slate),
              ),
              const SizedBox(height: 8),
              Text(_itemNameController.text,
                  style: const TextStyle(fontSize: 14, color: _muted)),
              if (_enableUnitConversion) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_conversionRows.length + 1}-Tier Unit Conversion',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PremiumDashboardScreen()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        side: const BorderSide(color: _border),
                      ),
                      child: const Text('Done',
                          style: TextStyle(color: _muted)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _clearForm();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Text('Add Another', style: TextStyle(color: Colors.white),),
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

  void _clearForm() {
    _itemNameController.clear();
    _tradePriceController.clear();
    _retailPriceController.clear();
    _taxController.clear();
    _discountController.clear();
    _parLevelController.clear();
    _issueUnitController.clear();
    _barcodeController.clear();
    _descriptionController.clear();
    _pricePerBaseUnitController.clear();
    for (final r in _conversionRows) {
      r.dispose();
    }
    _conversionRows.clear();
    _selectedCompany = null;
    _selectedCategory = null;
    _selectedIssueUnit = null;
    _selectedBaseUnit = 'Tablet';
    _enableUnitConversion = false;
    _generateItemCode();
    setState(() => _isSaving = false);
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _itemCodeController.dispose();
    _tradePriceController.dispose();
    _retailPriceController.dispose();
    _taxController.dispose();
    _discountController.dispose();
    _parLevelController.dispose();
    _issueUnitController.dispose();
    _barcodeController.dispose();
    _descriptionController.dispose();
    _pricePerBaseUnitController.dispose();
    for (final r in _conversionRows) {
      r.dispose();
    }
    super.dispose();
  }

  // ============================================================
  //  BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // ── Main form ──────────────────────────────────────
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildSectionCard(
                      title: 'Basic Information',
                      icon: Icons.info_outline,
                      iconColor: _blue,
                      children: [
                        _buildTextField(
                          controller: _itemNameController,
                          label: 'Item Name',
                          hint: 'Enter product name',
                          icon: Icons.medication_outlined,
                          isRequired: true,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Item name is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _itemCodeController,
                              label: 'Item Code',
                              hint: 'Auto-generated',
                              icon: Icons.qr_code_outlined,
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _barcodeController,
                              label: 'Barcode',
                              hint: 'Scan or enter barcode',
                              icon: Icons.barcode_reader,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                            child: _buildDropdown(
                              value: _selectedCategory,
                              label: 'Category',
                              hint: 'Select category',
                              icon: Icons.category_outlined,
                              items: categories,
                              onChanged: (v) =>
                                  setState(() => _selectedCategory = v),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDropdown(
                              value: _selectedCompany,
                              label: 'Company / Brand',
                              hint: 'Select company',
                              icon: Icons.business_outlined,
                              items: companies,
                              onChanged: (v) =>
                                  setState(() => _selectedCompany = v),
                            ),
                          ),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: 'Pricing',
                      icon: Icons.attach_money,
                      iconColor: _green,
                      children: [
                        Row(children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _tradePriceController,
                              label: 'Trade Price (T.P)',
                              hint: '0.00',
                              icon: Icons.price_change_outlined,
                              isRequired: true,
                              keyboardType: TextInputType.number,
                              prefix: 'Rs.',
                              validator: (v) =>
                                  double.tryParse(v ?? '') == null
                                      ? 'Enter valid price'
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _retailPriceController,
                              label: 'Retail Price (M.R.P)',
                              hint: '0.00',
                              icon: Icons.sell_outlined,
                              isRequired: true,
                              keyboardType: TextInputType.number,
                              prefix: 'Rs.',
                              validator: (v) =>
                                  double.tryParse(v ?? '') == null
                                      ? 'Enter valid price'
                                      : null,
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _taxController,
                              label: 'Tax',
                              hint: '0',
                              icon: Icons.receipt_long_outlined,
                              keyboardType: TextInputType.number,
                              suffix: '%',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _discountController,
                              label: 'Discount',
                              hint: '0',
                              icon: Icons.discount_outlined,
                              keyboardType: TextInputType.number,
                              suffix: '%',
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _buildProfitIndicator(),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Dynamic Unit Conversion Card ──────────
                    _buildUnitConversionCard(),
                    const SizedBox(height: 20),

                    _buildSectionCard(
                      title: 'Inventory Settings',
                      icon: Icons.inventory_2_outlined,
                      iconColor: _purple,
                      children: [
                        Row(children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _parLevelController,
                              label: 'PAR Level (Minimum Stock)',
                              hint: '0',
                              icon: Icons.warning_amber_outlined,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: _buildIssueUnitDropdown()),
                        ]),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _descriptionController,
                          label: 'Description (Optional)',
                          hint: 'Add notes or description...',
                          icon: Icons.description_outlined,
                          maxLines: 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          // ── Right side panel ───────────────────────────────
          Container(
            width: 320,
            margin: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildPreviewCard(),
                  const SizedBox(height: 20),
                  if (_enableUnitConversion) _buildUnitPricingPreview(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  UNIT CONVERSION CARD (Dynamic)
  // ============================================================
  Widget _buildUnitConversionCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _enableUnitConversion
              ? _blue.withOpacity(0.35)
              : _border,
          width: _enableUnitConversion ? 2 : 1,
        ),
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
          // ── Header + Toggle ──────────────────────────────
          _buildConversionCardHeader(),

          // ── Body ────────────────────────────────────────
          if (_enableUnitConversion)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Base unit selector + price
                  _buildBaseUnitRow(),
                  const SizedBox(height: 12),

                  // ── Dynamic tier rows ─────────────────
                  ...List.generate(_conversionRows.length, (i) {
                    _fixContainsUnits();
                    return Column(
                      children: [
                        _buildArrowConnector(_colorForIndex(i)),
                        const SizedBox(height: 6),
                        _buildDynamicTierRow(i),
                        const SizedBox(height: 6),
                      ],
                    );
                  }),

                  const SizedBox(height: 8),

                  // ── Add Tier button ───────────────────
                  _buildAddTierButton(),

                  // ── Conversion summary ────────────────
                  if (_conversionRows.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildConversionSummary(),
                  ],
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.toggle_off_outlined,
                        size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'Enable to set multiple packaging tiers\n(e.g. Tablet → Strip → Box → Carton)',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConversionCardHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _enableUnitConversion
            ? LinearGradient(colors: [
                _blue.withOpacity(0.06),
                _purple.withOpacity(0.06),
              ])
            : null,
        color: _enableUnitConversion ? null : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: _enableUnitConversion
                  ? const LinearGradient(colors: [_blue, _purple])
                  : null,
              color: _enableUnitConversion ? null : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.transform,
              color: _enableUnitConversion ? Colors.white : Colors.grey.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unit Conversion & Pricing',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _slate),
                ),
                Text(
                  _enableUnitConversion
                      ? '${_conversionRows.length + 1} tiers configured  •  tap + to add more'
                      : 'Define multiple packaging tiers with individual prices',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Switch(
            value: _enableUnitConversion,
            onChanged: (value) {
              setState(() => _enableUnitConversion = value);
              if (value && _conversionRows.isEmpty) {
                // Auto-add Strip as first tier
                _addConversionRow();
              }
            },
            activeColor: _blue,
          ),
        ],
      ),
    );
  }

  // ── Base unit row (Tier 0 – always shown) ─────────────────
  Widget _buildBaseUnitRow() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_blue.withOpacity(0.06), _blue.withOpacity(0.02)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _blue.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    const BoxDecoration(color: _blue, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              const Text(
                'Base Unit',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _blue),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('TIER 0',
                    style: TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Text('Smallest sellable unit',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Unit type selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _blue.withOpacity(0.4)),
                ),
                child: DropdownButton<String>(
                  value: _selectedBaseUnit,
                  underline: const SizedBox(),
                  isDense: true,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _blue),
                  items: baseUnits.map((u) {
                    return DropdownMenuItem(value: u, child: Text(u));
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedBaseUnit = value!);
                    _fixContainsUnits();
                    _recalcAllPrices();
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Base price input
              Expanded(
                child: TextFormField(
                  controller: _pricePerBaseUnitController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  ],
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _blue),
                  decoration: InputDecoration(
                    labelText: 'Price per $_selectedBaseUnit',
                    labelStyle: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                    prefixText: 'Rs. ',
                    prefixStyle: const TextStyle(
                        fontSize: 13, color: _muted),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: _blue, width: 1.5)),
                  ),
                  validator: _enableUnitConversion
                      ? (v) => (v?.isEmpty ?? true) ? 'Required' : null
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Arrow connector between tiers ─────────────────────────
  Widget _buildArrowConnector(Color color) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 2,
            height: 10,
            color: color.withOpacity(0.4),
          ),
          Icon(Icons.keyboard_arrow_down, color: color, size: 20),
        ],
      ),
    );
  }

  // ── One dynamic tier row ──────────────────────────────────
  Widget _buildDynamicTierRow(int index) {
    final row = _conversionRows[index];
    final color = _colorForIndex(index);
    final tierLabel = 'TIER ${index + 1}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row header ──────────────────────────────────
          Row(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              // Editable unit name
              SizedBox(
                width: 120,
                child: TextFormField(
                  controller: row.nameController,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color),
                  decoration: InputDecoration(
                    hintText: 'Unit name',
                    hintStyle: TextStyle(
                        color: color.withOpacity(0.4), fontSize: 13),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    suffixIcon: _buildUnitNameQuickPick(row, color),
                  ),
                  onChanged: (_) {
                    _fixContainsUnits();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4)),
                child: Text(tierLabel,
                    style: const TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              // Delete button
              GestureDetector(
                onTap: () => _removeConversionRow(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Icon(Icons.close,
                      size: 16, color: Colors.red.shade400),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Quantity + Price inputs ──────────────────────
          Row(
            children: [
              // Contains
              Text('Contains',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(width: 8),
              // Quantity input
              SizedBox(
                width: 64,
                child: TextFormField(
                  controller: row.quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: color.withOpacity(0.4))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: color, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${row.containsUnit}s',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade600),
              ),
              const Spacer(),
              // Price input
              SizedBox(
                width: 150,
                child: TextFormField(
                  controller: row.priceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d*'))
                  ],
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color),
                  decoration: InputDecoration(
                    labelText:
                        '${row.nameController.text.isEmpty ? 'Unit' : row.nameController.text} Price',
                    labelStyle: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                    prefixText: 'Rs. ',
                    prefixStyle: const TextStyle(
                        fontSize: 13, color: _muted),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: color.withOpacity(0.3))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: color, width: 1.5)),
                  ),
                  onChanged: (_) {
                    _recalcAllPrices();
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Small dropdown arrow that lets user pick a preset unit name
  Widget _buildUnitNameQuickPick(UnitConversionRow row, Color color) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.arrow_drop_down, color: color, size: 18),
      tooltip: 'Quick pick',
      onSelected: (v) {
        row.nameController.text = v;
        _fixContainsUnits();
        setState(() {});
      },
      itemBuilder: (_) => _presetUnitNames.map((name) {
        return PopupMenuItem(
          value: name,
          child: Text(name, style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
    );
  }

  // ── Add Tier button ───────────────────────────────────────
  Widget _buildAddTierButton() {
    return GestureDetector(
      onTap: _addConversionRow,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _blue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _blue.withOpacity(0.3), style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                  color: _blue, borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            const Text(
              'Add Conversion Tier',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _blue),
            ),
            const SizedBox(width: 6),
            Text(
              '(e.g. Strip, Box, Carton…)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  // ── Conversion summary (replaces old static box) ──────────
  Widget _buildConversionSummary() {
    final lines = <String>[];
    String previousUnit = _selectedBaseUnit;

    for (int i = 0; i < _conversionRows.length; i++) {
      final row = _conversionRows[i];
      final name =
          row.nameController.text.isNotEmpty ? row.nameController.text : 'Tier ${i + 1}';
      final qty = int.tryParse(row.quantityController.text) ?? 1;
      lines.add('1 $name = $qty ${previousUnit}s');
      previousUnit = name;
    }

    // Total from base to top
    if (_conversionRows.length >= 2) {
      int total = 1;
      for (final r in _conversionRows) {
        total *= int.tryParse(r.quantityController.text) ?? 1;
      }
      final topName = _conversionRows.last.nameController.text.isNotEmpty
          ? _conversionRows.last.nameController.text
          : 'Top tier';
      lines.add('1 $topName = $total ${_selectedBaseUnit}s (total)');
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_outlined,
                  size: 16, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              const Text(
                'Conversion Summary',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...lines.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• $l',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF92400E))),
              )),
        ],
      ),
    );
  }

  // ── Right-panel pricing preview (dynamic) ─────────────────
  Widget _buildUnitPricingPreview() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_blue, _purple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.price_check, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Unit Pricing Table',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    '${_conversionRows.length + 1} Tiers',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8)),
                  ),
                  child: Row(children: const [
                    Expanded(
                        flex: 2,
                        child: Text('Unit',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _muted))),
                    Expanded(
                        child: Text('Contains',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _muted),
                            textAlign: TextAlign.center)),
                    Expanded(
                        flex: 2,
                        child: Text('Price',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _muted),
                            textAlign: TextAlign.right)),
                  ]),
                ),

                // Base unit row
                _buildPriceTableRow(
                  unit: _selectedBaseUnit,
                  contains: '1',
                  price: double.tryParse(
                          _pricePerBaseUnitController.text) ??
                      0,
                  isBase: true,
                  color: _blue,
                  isLast: _conversionRows.isEmpty,
                ),

                // Dynamic tier rows
                ...List.generate(_conversionRows.length, (i) {
                  final row = _conversionRows[i];
                  final name = row.nameController.text.isNotEmpty
                      ? row.nameController.text
                      : 'Tier ${i + 1}';
                  final qty =
                      int.tryParse(row.quantityController.text) ?? 1;
                  final prevName = i == 0
                      ? _selectedBaseUnit
                      : (_conversionRows[i - 1].nameController.text
                              .isNotEmpty
                          ? _conversionRows[i - 1].nameController.text
                          : 'Unit');
                  final price =
                      double.tryParse(row.priceController.text) ?? 0;

                  // Calculated = previous price × qty
                  double prevPrice = i == 0
                      ? (double.tryParse(
                              _pricePerBaseUnitController.text) ??
                          0)
                      : (double.tryParse(
                              _conversionRows[i - 1].priceController.text) ??
                          0);
                  double calcPrice = prevPrice * qty;

                  return _buildPriceTableRow(
                    unit: name,
                    contains: '$qty ${prevName}s',
                    price: price,
                    calculatedPrice: calcPrice,
                    color: _colorForIndex(i),
                    isLast: i == _conversionRows.length - 1,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceTableRow({
    required String unit,
    required String contains,
    required double price,
    double? calculatedPrice,
    bool isBase = false,
    bool isLast = false,
    Color color = _green,
  }) {
    double savings = calculatedPrice != null && price > 0
        ? calculatedPrice - price
        : 0;
    double savingsPercent = calculatedPrice != null && calculatedPrice > 0
        ? (savings / calculatedPrice) * 100
        : 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade200)),
        borderRadius: isLast
            ? const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 6),
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle)),
                Flexible(
                  child: Text(
                    unit,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: isBase
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: _slate),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(contains,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade600),
                textAlign: TextAlign.center),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs. ${price.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: price > 0 ? color : Colors.grey.shade400),
                ),
                if (savings > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: _green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      'Save ${savingsPercent.toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _green),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  EXISTING SHARED WIDGETS
  // ============================================================

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: _blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child:
              const Icon(Icons.add_box_rounded, color: _blue, size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add New Product',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _slate,
                  letterSpacing: -0.3),
            ),
            Text(
              'Fill in the details to add a new item to inventory',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: _clearForm,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Reset'),
          style:
              TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12)),
              border:
                  Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _slate)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    String? prefix,
    String? suffix,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569))),
            if (isRequired)
              const Text(' *',
                  style: TextStyle(
                      color: Color(0xFFEF4444), fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13),
          inputFormatters: keyboardType == TextInputType.number
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
              : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
            prefixText: prefix != null ? '$prefix ' : null,
            prefixStyle: const TextStyle(
                color: Color(0xFF475569), fontSize: 13),
            suffixText: suffix,
            suffixStyle: const TextStyle(
                color: Color(0xFF475569), fontSize: 13),
            filled: true,
            fillColor:
                readOnly ? const Color(0xFFF1F5F9) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: _blue, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFFEF4444))),
            errorStyle: const TextStyle(fontSize: 11),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String label,
    required String hint,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border)),
          child: DropdownButtonFormField<String>(
            value: value,
            hint: Text(hint,
                style: TextStyle(
                    color: Colors.grey.shade400, fontSize: 13)),
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down,
                color: Colors.grey.shade500, size: 20),
            style:
                const TextStyle(fontSize: 13, color: _slate),
            decoration: InputDecoration(
              prefixIcon:
                  Icon(icon, size: 18, color: Colors.grey.shade500),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              border: InputBorder.none,
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(8),
            items: items
                .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item,
                        style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildIssueUnitDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Issue Unit',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569))),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border)),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedIssueUnit,
                  hint: Text(
                    _enableUnitConversion
                        ? _selectedBaseUnit
                        : 'Select issue unit',
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 13),
                  ),
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down,
                      color: Colors.grey.shade500, size: 20),
                  style: const TextStyle(fontSize: 13, color: _slate),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.straighten,
                        size: 18, color: Colors.grey.shade500),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: InputBorder.none,
                  ),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  items: issueUnits
                      .map((unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit,
                              style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: _enableUnitConversion
                      ? null
                      : (value) {
                          setState(() {
                            _selectedIssueUnit = value;
                            if (value != null) {
                              _issueUnitController.text = value;
                            }
                          });
                        },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfitIndicator() {
    double tradePrice =
        double.tryParse(_tradePriceController.text) ?? 0;
    double retailPrice =
        double.tryParse(_retailPriceController.text) ?? 0;
    double profit = retailPrice - tradePrice;
    double profitPercent =
        tradePrice > 0 ? (profit / tradePrice) * 100 : 0;

    Color indicatorColor = profitPercent >= 20
        ? _green
        : profitPercent >= 10
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: indicatorColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: indicatorColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            profitPercent >= 10
                ? Icons.trending_up
                : Icons.trending_down,
            color: indicatorColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profit Margin',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600)),
              Text(
                'Rs. ${profit.toStringAsFixed(0)} (${profitPercent.toStringAsFixed(1)}%)',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: indicatorColor),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: indicatorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4)),
            child: Text(
              profitPercent >= 20
                  ? 'Good'
                  : profitPercent >= 10
                      ? 'Fair'
                      : 'Low',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: indicatorColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _muted,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              side: const BorderSide(color: _border),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveItem,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined, size: 18),
            label:
                Text(_isSaving ? 'Saving...' : 'Save Product'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12)),
              border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Icon(Icons.preview_outlined,
                    size: 18, color: _muted),
                const SizedBox(width: 8),
                const Text('Preview',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _slate)),
                const Spacer(),
                if (_enableUnitConversion)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: _blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      '${_conversionRows.length + 1}-Tier',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _blue),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.medication,
                          size: 36, color: Colors.grey.shade400),
                      const SizedBox(height: 6),
                      Text('No Image',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildPreviewRow(
                    'Name',
                    _itemNameController.text.isEmpty
                        ? '—'
                        : _itemNameController.text),
                _buildPreviewRow('Code', _itemCodeController.text),
                _buildPreviewRow('Category', _selectedCategory ?? '—'),
                _buildPreviewRow('Company', _selectedCompany ?? '—'),
                const Divider(height: 16),
                _buildPreviewRow(
                  'Trade Price',
                  'Rs. ${_tradePriceController.text.isEmpty ? '0' : _tradePriceController.text}',
                  valueColor: _muted,
                ),
                _buildPreviewRow(
                  'Retail Price',
                  'Rs. ${_retailPriceController.text.isEmpty ? '0' : _retailPriceController.text}',
                  valueColor: _green,
                  isBold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade600)),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      isBold ? FontWeight.w600 : FontWeight.w500,
                  color: valueColor ?? _slate),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}