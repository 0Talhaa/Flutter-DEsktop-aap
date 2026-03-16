// lib/screens/sale_screen_desktop.dart
// ✅ FULLY RESPONSIVE: Desktop LCD | Tablet | Mobile

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/Screens/slip_preview_screen.dart';
import 'package:medical_app/models/customer.dart';
import 'package:medical_app/models/product.dart';
import 'package:medical_app/models/sale_item.dart';
import 'package:medical_app/services/database_helper.dart';
import 'package:medical_app/Screens/dashboardScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_app/services/thermal_print_service_3inch.dart';
import 'package:medical_app/services/thermal_print_service_6inch.dart';

// ══════════════════════════════════════════════════════════════
//  RESPONSIVE BREAKPOINTS
// ══════════════════════════════════════════════════════════════
class _BP {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

extension ContextBreakpoints on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  bool get isMobile => screenWidth < _BP.mobile;
  bool get isTablet => screenWidth >= _BP.mobile && screenWidth < _BP.tablet;
  bool get isDesktop => screenWidth >= _BP.tablet && screenWidth < _BP.desktop;
  bool get isWide => screenWidth >= _BP.desktop;
}

class SaleScreenDesktop extends StatefulWidget {
  const SaleScreenDesktop({super.key});

  @override
  State<SaleScreenDesktop> createState() => _SaleScreenDesktopState();
}

class _SaleScreenDesktopState extends State<SaleScreenDesktop> {
  double? _loadedPreviousBalance; // null = use live customer balance
  // ── Controllers ──────────────────────────────────────────────
  final TextEditingController invoiceController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController customerBalanceController =
      TextEditingController();
  final TextEditingController searchController = TextEditingController();
  final TextEditingController amountPaidController = TextEditingController();

  // ── Focus nodes ───────────────────────────────────────────────
  final FocusNode searchFocusNode = FocusNode();
  final FocusNode _mainFocusNode = FocusNode();
  final FocusNode amountPaidFocusNode = FocusNode();

  // ── Search / cart navigation ──────────────────────────────────
  int selectedSearchIndex = -1;
  int selectedCartIndex = -1;
  bool isNavigatingCart = false;

  // ── Per-item controllers & focus nodes ────────────────────────
  final Map<int, TextEditingController> qtyControllers = {};
  final Map<int, FocusNode> qtyFocusNodes = {};
  final Map<int, TextEditingController> disControllers = {};
  final Map<int, FocusNode> disFocusNodes = {};
  final Map<int, FocusNode> unitFocusNodes = {};
  final Map<int, String> selectedUnits = {};
  final Map<int, Product> cartProductData = {};

  bool _isSubmittingQty = false;
  bool _isSubmittingDis = false;

  // ── Data ──────────────────────────────────────────────────────
  List<Product> allProducts = [];
  List<SaleItem> cart = [];
  List<Customer> allCustomers = [];
  Customer? selectedCustomer;
  String searchQuery = '';
  bool _isSaleCompleted = false;
  bool _isEditMode = false;
  String selectedPayment = 'Cash';
  int? currentSaleId;

  // ── Customer dropdown ─────────────────────────────────────────
  bool _customerDropdownOpen = false;
  String _customerFilter = '';
  int _customerHighlightIndex = 0;
  final FocusNode _customerSearchFocus = FocusNode();
  final TextEditingController _customerSearchController =
      TextEditingController();
  final ScrollController _customerScrollController = ScrollController();

  final currencyFormat = NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );

  // ── Mobile search panel visibility toggle ─────────────────────
  bool _searchPanelExpanded = false;

  // ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _generateInvoiceNumber();
    _setCurrentDate();
    _loadProducts();
    _loadCustomers();
    customerBalanceController.text = '0.00';
    amountPaidController.addListener(_onAmountPaidChanged);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => searchFocusNode.requestFocus());
  }

  // ══════════════════════════════════════════════════════════════
  //  KEY HANDLERS
  // ══════════════════════════════════════════════════════════════
  KeyEventResult _handleGlobalKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    if (isCtrl && key == LogicalKeyboardKey.keyS) {
      _saveSale(updateExisting: _isSaleCompleted && _isEditMode);
      return KeyEventResult.handled;
    }
    if (isCtrl && key == LogicalKeyboardKey.keyA) {
      _performSaveAndNew();
      return KeyEventResult.handled;
    }
    if (isCtrl && key == LogicalKeyboardKey.keyP) {
      _showSlipPreview();
      return KeyEventResult.handled;
    }
    if (isCtrl && key == LogicalKeyboardKey.keyF) {
      _showFindInvoiceDialog();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    final filtered = allProducts
        .where(
            (p) => p.itemName.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    if (searchQuery.isNotEmpty && filtered.isNotEmpty) {
      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() {
          selectedSearchIndex = (selectedSearchIndex + 1) % filtered.length;
          isNavigatingCart = false;
        });
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() {
          selectedSearchIndex =
              (selectedSearchIndex - 1 + filtered.length) % filtered.length;
          isNavigatingCart = false;
        });
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter) {
        if (selectedSearchIndex >= 0 && selectedSearchIndex < filtered.length) {
          _addToCartAndFocusQty(filtered[selectedSearchIndex]);
        }
        return KeyEventResult.handled;
      }
    } else if (searchQuery.isEmpty && cart.isNotEmpty) {
      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() {
          isNavigatingCart = true;
          selectedCartIndex = (selectedCartIndex + 1) % cart.length;
        });
        _focusCartItemQty(selectedCartIndex);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() {
          isNavigatingCart = true;
          selectedCartIndex =
              (selectedCartIndex - 1 + cart.length) % cart.length;
        });
        _focusCartItemQty(selectedCartIndex);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter && isNavigatingCart) {
        if (selectedCartIndex >= 0) _focusCartItemQty(selectedCartIndex);
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.tab) {
      _returnFocusToSearch();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ══════════════════════════════════════════════════════════════
  //  CUSTOMER DROPDOWN
  // ══════════════════════════════════════════════════════════════
  void _openCustomerDropdown() {
    setState(() {
      _customerDropdownOpen = true;
      _customerFilter = '';
      _customerHighlightIndex = 0;
    });
    _customerSearchController.clear();

    final filteredCustomers = _filteredCustomers();
    if (selectedCustomer != null) {
      final idx =
          filteredCustomers.indexWhere((c) => c.id == selectedCustomer!.id);
      if (idx != -1) _customerHighlightIndex = idx + 1;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _CustomerDropdownDialog(
        allCustomers: allCustomers,
        selectedCustomer: selectedCustomer,
        currencyFormat: currencyFormat,
        onSelected: (Customer? c) {
          setState(() {
            selectedCustomer = c;
            if (c != null) {
              customerNameController.text = c.name;
              customerBalanceController.text =
                  c.openingBalance.toStringAsFixed(0);
            } else {
              customerNameController.text = 'Walk-in Customer';
              customerBalanceController.text = '0.00';
            }
            _customerDropdownOpen = false;
          });
          Navigator.pop(ctx);
          Future.delayed(const Duration(milliseconds: 80), () {
            if (mounted) searchFocusNode.requestFocus();
          });
        },
        onClose: () {
          setState(() => _customerDropdownOpen = false);
          Navigator.pop(ctx);
          Future.delayed(const Duration(milliseconds: 80), () {
            if (mounted) searchFocusNode.requestFocus();
          });
        },
      ),
    );
  }

  List<Customer> _filteredCustomers() {
    if (_customerFilter.isEmpty) return allCustomers;
    return allCustomers
        .where(
            (c) => c.name.toLowerCase().contains(_customerFilter.toLowerCase()))
        .toList();
  }

  // ══════════════════════════════════════════════════════════════
  //  MISC HELPERS
  // ══════════════════════════════════════════════════════════════
  void _onAmountPaidChanged() => setState(() {});
  void _generateInvoiceNumber() {
    final now = DateTime.now();
    invoiceController.text = '${now.millisecondsSinceEpoch % 100000}';
  }

  void _setCurrentDate() {
    dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
  }

  Future<void> _loadCustomers() async {
    final customers = await DatabaseHelper.instance.getAllCustomers();
    setState(() => allCustomers = customers);
  }

  Future<void> _loadProducts() async {
    final products = await DatabaseHelper.instance.getAllProducts();
    setState(() => allProducts = products);
  }

  // ══════════════════════════════════════════════════════════════
  //  BALANCE CALCULATIONS
  // ══════════════════════════════════════════════════════════════
  double get totalQuantity => cart.fold(0, (s, i) => s + i.quantity).toDouble();
  double get subtotalAmount =>
      cart.fold(0.0, (s, i) => s + (i.price * i.quantity));
  double _getItemDiscountAmount(SaleItem item) =>
      item.price * item.quantity * ((item.discount ?? 0) / 100);
  double _getItemLineTotal(SaleItem item) =>
      item.price * item.quantity - _getItemDiscountAmount(item);
  double get totalDiscount =>
      cart.fold(0.0, (s, i) => s + _getItemDiscountAmount(i));
  double get amountAfterDiscount => subtotalAmount - totalDiscount;
  double get taxAmount => amountAfterDiscount * 0.0;
  double get saleAmount => amountAfterDiscount + taxAmount;
  double get previousBalance => 
    _loadedPreviousBalance ?? selectedCustomer?.openingBalance ?? 0.0;
  double get totalDue => previousBalance + saleAmount;
  double get amountPaid => double.tryParse(amountPaidController.text) ?? 0.0;
  double get remainingBalance => totalDue - amountPaid;

  Map<String, double> _calculateBalances() => {
        'subtotal': subtotalAmount,
        'discount': totalDiscount,
        'amountAfterDiscount': amountAfterDiscount,
        'tax': taxAmount,
        'saleAmount': saleAmount,
        'previousBalance': previousBalance,
        'totalDue': totalDue,
        'amountPaid': amountPaid,
        'remainingBalance': remainingBalance,
      };

  // ══════════════════════════════════════════════════════════════
  //  FOCUS NODE FACTORIES
  // ══════════════════════════════════════════════════════════════
  FocusNode _createQtyFocusNode(int productId) {
    final node = FocusNode();
    node.addListener(() {
      if (!node.hasFocus && mounted && !_isSubmittingQty)
        _commitQtyValue(productId);
    });
    return node;
  }

  FocusNode _createDisFocusNode(int productId) {
    final node = FocusNode();
    node.addListener(() {
      if (!node.hasFocus && mounted && !_isSubmittingDis)
        _commitDisValue(productId);
    });
    return node;
  }

  FocusNode _createUnitFocusNode(int productId) => FocusNode();

  // ══════════════════════════════════════════════════════════════
  //  COMMIT VALUES
  // ══════════════════════════════════════════════════════════════
  void _commitQtyValue(int productId) {
    final controller = qtyControllers[productId];
    if (controller == null) return;
    final numValue = int.tryParse(controller.text) ?? 0;
    final index = cart.indexWhere((e) => e.productId == productId);
    if (index == -1) return;
    final item = cart[index];
    if (item.quantity == numValue) return;
    setState(() {
      if (numValue <= 0) {
        _removeCartItem(productId);
      } else {
        final product = cartProductData[productId];
        final unitType = selectedUnits[productId] ?? 'Unit';
        int baseQty = numValue;
        if (product != null && product.hasUnitConversion) {
          baseQty = product.convertToBaseUnits(numValue, unitType);
        }
        cart[index] = item.copyWith(quantity: numValue, baseQuantity: baseQty);
      }
    });
  }

  void _commitDisValue(int productId) {
    final controller = disControllers[productId];
    if (controller == null) return;
    final numValue = double.tryParse(controller.text) ?? 0;
    final index = cart.indexWhere((e) => e.productId == productId);
    if (index == -1) return;
    final item = cart[index];
    if (item.discount == numValue) return;
    setState(() {
      cart[index] = item.copyWith(discount: numValue);
    });
  }

  // ══════════════════════════════════════════════════════════════
  //  REMOVE CART ITEM
  // ══════════════════════════════════════════════════════════════
  void _removeCartItem(int productId) {
    qtyControllers[productId]?.dispose();
    qtyControllers.remove(productId);
    qtyFocusNodes[productId]?.dispose();
    qtyFocusNodes.remove(productId);
    disControllers[productId]?.dispose();
    disControllers.remove(productId);
    disFocusNodes[productId]?.dispose();
    disFocusNodes.remove(productId);
    unitFocusNodes[productId]?.dispose();
    unitFocusNodes.remove(productId);
    selectedUnits.remove(productId);
    cartProductData.remove(productId);
    cart.removeWhere((item) => item.productId == productId);
  }

  // ══════════════════════════════════════════════════════════════
  //  CART FOCUS HELPERS
  // ══════════════════════════════════════════════════════════════
  void _focusCartItemQty(int index) {
    if (index < 0 || index >= cart.length) return;
    final item = cart[index];
    final focusNode = qtyFocusNodes[item.productId];
    final controller = qtyControllers[item.productId];
    if (focusNode != null && controller != null) {
      focusNode.requestFocus();
      controller.selection =
          TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    }
  }

  void _focusCartItemDis(int index) {
    if (index < 0 || index >= cart.length) return;
    final item = cart[index];
    final focusNode = disFocusNodes[item.productId];
    final controller = disControllers[item.productId];
    if (focusNode != null && controller != null) {
      focusNode.requestFocus();
      controller.selection =
          TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  F1 — UNIT SELECTOR
  // ══════════════════════════════════════════════════════════════
  void _focusOnUnitSelector() {
    if (cart.isEmpty) {
      _snack('No items in cart. Add an item first!', Colors.orange);
      return;
    }
    if (selectedCartIndex < 0 || selectedCartIndex >= cart.length) {
      setState(() {
        selectedCartIndex = cart.length - 1;
        isNavigatingCart = true;
      });
    }
    final item = cart[selectedCartIndex];
    final product = cartProductData[item.productId];
    if (product == null || !product.hasUnitConversion) {
      _snack('${item.productName} has no unit conversion', Colors.orange);
      return;
    }
    _showUnitSelectionDialog(item.productId, product);
  }

  // ══════════════════════════════════════════════════════════════
  //  UNIT OPTIONS BUILDER
  // ══════════════════════════════════════════════════════════════
  List<_UnitOption> _getUnitOptions(Product product) {
    final options = <_UnitOption>[];
    options.add(_UnitOption(
      unitKey: product.baseUnit ?? 'Tablet',
      displayName: product.baseUnit ?? 'Tablet',
      price: product.pricePerUnit ?? product.retailPrice,
      containsLabel: '1 (base unit)',
      tierIndex: 0,
    ));
    if (product.conversionTiers != null &&
        product.conversionTiers!.isNotEmpty) {
      for (int i = 0; i < product.conversionTiers!.length; i++) {
        final tier = product.conversionTiers![i];
        options.add(_UnitOption(
          unitKey: tier['name'] as String? ?? 'Tier ${i + 1}',
          displayName: tier['name'] as String? ?? 'Tier ${i + 1}',
          price: (tier['price'] as num?)?.toDouble() ?? 0.0,
          containsLabel:
              '${tier['quantity']} ${tier['containsUnit'] ?? options.last.displayName}s',
          tierIndex: i + 1,
        ));
      }
    } else {
      if ((product.pricePerStrip ?? 0) > 0 ||
          (product.unitsPerStrip ?? 0) > 0) {
        options.add(_UnitOption(
          unitKey: 'Strip',
          displayName: 'Strip',
          price: product.pricePerStrip ??
              (product.retailPrice * (product.unitsPerStrip ?? 10)),
          containsLabel:
              '${product.unitsPerStrip ?? 10} ${product.baseUnit ?? 'Tablet'}s',
          tierIndex: 1,
        ));
      }
      if ((product.pricePerBox ?? 0) > 0 || (product.stripsPerBox ?? 0) > 0) {
        options.add(_UnitOption(
          unitKey: 'Box',
          displayName: 'Box',
          price: product.pricePerBox ??
              ((product.pricePerStrip ?? product.retailPrice) *
                  (product.stripsPerBox ?? 10)),
          containsLabel: '${product.stripsPerBox ?? 10} Strips',
          tierIndex: 2,
        ));
      }
    }
    return options;
  }

  void _showUnitSelectionDialog(int productId, Product product) {
    final currentUnit = selectedUnits[productId] ?? product.baseUnit ?? 'Unit';
    final unitOptions = _getUnitOptions(product);
    const tierColors = [
      Color(0xFF3B82F6),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
      Color(0xFFEF4444),
      Color(0xFF06B6D4),
    ];
    Color colorFor(int i) => tierColors[i % tierColors.length];
    int highlightIndex =
        unitOptions.indexWhere((o) => o.unitKey == currentUnit);
    if (highlightIndex < 0) highlightIndex = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return KeyboardListener(
          focusNode: FocusNode()..requestFocus(),
          onKeyEvent: (event) {
            if (event is! KeyDownEvent) return;
            final key = event.logicalKey;
            final numStr = key.keyLabel;
            final num = int.tryParse(numStr);
            if (num != null && num >= 1 && num <= unitOptions.length) {
              final opt = unitOptions[num - 1];
              _updateUnitSelection(productId, opt.unitKey, product, opt.price);
              Navigator.pop(context);
              return;
            }
            if (key == LogicalKeyboardKey.arrowDown) {
              setDialogState(() =>
                  highlightIndex = (highlightIndex + 1) % unitOptions.length);
            } else if (key == LogicalKeyboardKey.arrowUp) {
              setDialogState(() => highlightIndex =
                  (highlightIndex - 1 + unitOptions.length) %
                      unitOptions.length);
            } else if (key == LogicalKeyboardKey.enter) {
              final opt = unitOptions[highlightIndex];
              _updateUnitSelection(productId, opt.unitKey, product, opt.price);
              Navigator.pop(context);
            } else if (key == LogicalKeyboardKey.tab) {
              Navigator.pop(context);
            }
          },
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(children: [
                const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Select Unit',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      Text(product.itemName,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ])),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('${unitOptions.length} Tiers',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            content: SizedBox(
              width: 380,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.keyboard, size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'Press 1–${unitOptions.length} to select  |  ↑↓ + Enter  |  Esc to cancel',
                      style:
                          TextStyle(fontSize: 11, color: Colors.blue.shade700),
                    ),
                  ]),
                ),
                if (unitOptions.length > 1)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFFBBF24).withOpacity(0.4)),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [
                            Icon(Icons.calculate_outlined,
                                size: 14, color: Color(0xFFF59E0B)),
                            SizedBox(width: 6),
                            Text('Conversion Info',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF92400E))),
                          ]),
                          const SizedBox(height: 6),
                          ...List.generate(unitOptions.length - 1, (i) {
                            final upper = unitOptions[i + 1];
                            return Text(
                                '• 1 ${upper.displayName} = ${upper.containsLabel}',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF92400E)));
                          }),
                        ]),
                  ),
                ...unitOptions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final opt = entry.value;
                  final isSelected = currentUnit == opt.unitKey;
                  final isHighlighted = i == highlightIndex;
                  final color = colorFor(i);
                  return GestureDetector(
                    onTap: () {
                      _updateUnitSelection(
                          productId, opt.unitKey, product, opt.price);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isHighlighted
                            ? color.withOpacity(0.15)
                            : (isSelected
                                ? color.withOpacity(0.08)
                                : Colors.grey.shade50),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isHighlighted
                              ? color
                              : (isSelected ? color : Colors.grey.shade300),
                          width: (isHighlighted || isSelected) ? 2 : 1,
                        ),
                        boxShadow: (isHighlighted || isSelected)
                            ? [
                                BoxShadow(
                                    color: color.withOpacity(0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2))
                              ]
                            : [],
                      ),
                      child: Row(children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isHighlighted
                                ? color
                                : (isSelected
                                    ? color
                                    : color.withOpacity(0.12)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                              child: Text('${i + 1}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: (isHighlighted || isSelected)
                                          ? Colors.white
                                          : color))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Row(children: [
                                Text(opt.displayName,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: (isHighlighted || isSelected)
                                            ? color
                                            : const Color(0xFF1E293B))),
                                if (i == 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(4)),
                                    child: const Text('BASE',
                                        style: TextStyle(
                                            fontSize: 8,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ]),
                              Text(opt.containsLabel,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600)),
                            ])),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(currencyFormat.format(opt.price),
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: (isHighlighted || isSelected)
                                          ? color
                                          : const Color(0xFF10B981))),
                              if (isSelected)
                                Icon(Icons.check_circle,
                                    color: color, size: 16),
                            ]),
                      ]),
                    ),
                  );
                }),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel (Esc)')),
            ],
          ),
        );
      }),
    ).then((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) searchFocusNode.requestFocus();
      });
    });
  }

  void _updateUnitSelection(
      int productId, String newUnit, Product product, double newPrice) {
    final index = cart.indexWhere((e) => e.productId == productId);
    if (index == -1) return;
    final item = cart[index];
    final qty = item.quantity;
    int baseQty = product.convertToBaseUnits(qty, newUnit);
    double tradePrice = product.getTradePriceByUnit(newUnit);
    setState(() {
      selectedUnits[productId] = newUnit;
      cart[index] = item.copyWith(
          price: newPrice,
          tradePrice: tradePrice,
          unitType: newUnit,
          baseQuantity: baseQty);
    });
    _snack('${product.itemName}: $newUnit @ ${currencyFormat.format(newPrice)}',
        Colors.green);
  }

  // ══════════════════════════════════════════════════════════════
  //  PRINT SIZE DIALOG
  // ══════════════════════════════════════════════════════════════
  Future<String?> _showPrintSizeDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return KeyboardListener(
          focusNode: FocusNode()..requestFocus(),
          onKeyEvent: (event) {
            if (event is! KeyDownEvent) return;
            if (event.logicalKey.keyLabel == '1')
              Navigator.pop(context, '3inch');
            if (event.logicalKey.keyLabel == '2')
              Navigator.pop(context, '6inch');
            if (event.logicalKey == LogicalKeyboardKey.tab)
              Navigator.pop(context, null);
          },
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            titlePadding: EdgeInsets.zero,
            title: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Row(children: [
                Icon(Icons.print, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text('Select Paper Size',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.keyboard, size: 14, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Text(
                      'Press 1 for 3-inch  |  Press 2 for 6-inch  |  Esc to cancel',
                      style:
                          TextStyle(fontSize: 11, color: Colors.blue.shade700)),
                ]),
              ),
              const SizedBox(height: 4),
              _buildSizeOption(context,
                  label: '3-inch Slip  [1]',
                  subtitle: '58mm · 32 chars/line · Compact receipt',
                  icon: Icons.receipt,
                  iconColor: const Color(0xFF10B981),
                  value: '3inch'),
              const SizedBox(height: 12),
              _buildSizeOption(context,
                  label: '6-inch Slip  [2]',
                  subtitle: '152mm · 64 chars/line · Wide receipt',
                  icon: Icons.receipt_long,
                  iconColor: const Color(0xFF8B5CF6),
                  value: '6inch'),
              const SizedBox(height: 8),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel (Esc)')),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSizeOption(
    BuildContext context, {
    required String label,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String value,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: iconColor.withOpacity(0.3)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: iconColor)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ])),
          Icon(Icons.arrow_forward_ios,
              size: 14, color: iconColor.withOpacity(0.6)),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  SLIP PREVIEW
  // ══════════════════════════════════════════════════════════════
  Future<void> _showSlipPreview() async {
    if (cart.isEmpty) {
      _snack('No items to preview!', Colors.orange);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final balances = _calculateBalances();
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (_) => SlipPreviewScreen(
        shopName: prefs.getString('shop_name') ?? 'MEDICAL STORE',
        shopAddress: prefs.getString('shop_address') ?? '123 Main Street, City',
        shopPhone: prefs.getString('shop_phone') ?? '0300-1234567',
        shopTagline:
            prefs.getString('shop_tagline') ?? 'Thank you for your purchase!',
        invoiceNumber: 'INV${invoiceController.text}',
        date: dateController.text,
        customerName: selectedCustomer?.name ?? 'Walk-in Customer',
        cartItems: cart,
        balances: balances,
        paymentMethod: selectedPayment,
        getLineTotal: _getItemLineTotal,
        onPrint: _printInvoice,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PRINT INVOICE (builds receipt bytes only — no BT sending)
  // ══════════════════════════════════════════════════════════════
  Future<void> _printInvoice() async {
    if (cart.isEmpty) {
      _snack('No items to print!', Colors.orange);
      return;
    }
    final selectedSize = await _showPrintSizeDialog();
    if (selectedSize == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: Card(
              child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Preparing receipt…'),
        ]),
      ))),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final shopName = prefs.getString('shop_name') ?? 'MEDICAL STORE';
      final shopAddress =
          prefs.getString('shop_address') ?? '123 Main Street, City';
      final shopPhone = prefs.getString('shop_phone') ?? '0300-1234567';
      final shopTagline =
          prefs.getString('shop_tagline') ?? 'Thank you for your purchase!';
      final balances = _calculateBalances();
      final customerName = selectedCustomer?.name ?? 'Walk-in Customer';
      final invoiceNumber = 'INV${invoiceController.text}';
      final date = dateController.text;

      final Uint8List bytes;
      if (selectedSize == '3inch') {
        final items3 = cart
            .map((item) => ReceiptItem(
                  qty: item.quantity,
                  productName: item.productName,
                  tradePrice: item.tradePrice ?? 0,
                  retailPrice: item.price,
                  discountPercent: item.discount ?? 0,
                  lineTotal: _getItemLineTotal(item),
                ))
            .toList();
        bytes = await ThermalPrintService3Inch.buildReceipt(
          shopName: shopName,
          shopAddress: shopAddress,
          shopPhone: shopPhone,
          shopTagline: shopTagline,
          invoiceNumber: invoiceNumber,
          date: date,
          customerName: customerName,
          items: items3,
          subtotal: balances['subtotal']!,
          totalDiscount: balances['discount']!,
          tax: balances['tax']!,
          saleAmount: balances['saleAmount']!,
          previousBalance: balances['previousBalance']!,
          totalDue: balances['totalDue']!,
          amountPaid: balances['amountPaid']!,
          remainingBalance: balances['remainingBalance']!,
          paymentMethod: selectedPayment,
        );
      } else {
        final items6 = cart
            .map((item) => ReceiptItem6(
                  qty: item.quantity,
                  productName: item.productName,
                  tradePrice: item.tradePrice ?? 0,
                  retailPrice: item.price,
                  discountPercent: item.discount ?? 0,
                  lineTotal: _getItemLineTotal(item),
                ))
            .toList();
        bytes = await ThermalPrintService6Inch.buildReceipt(
          shopName: shopName,
          shopAddress: shopAddress,
          shopPhone: shopPhone,
          shopTagline: shopTagline,
          invoiceNumber: invoiceNumber,
          date: date,
          customerName: customerName,
          items: items6,
          subtotal: balances['subtotal']!,
          totalDiscount: balances['discount']!,
          tax: balances['tax']!,
          saleAmount: balances['saleAmount']!,
          previousBalance: balances['previousBalance']!,
          totalDue: balances['totalDue']!,
          amountPaid: balances['amountPaid']!,
          remainingBalance: balances['remainingBalance']!,
          paymentMethod: selectedPayment,
        );
      }

      if (mounted) Navigator.pop(context);

      // bytes are ready — inform user (no BT send)
      _snack(
          '✅ Receipt built (${bytes.length} bytes). Connect a printer to send.',
          Colors.green);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _snack('Print Error: $e', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 2)));
  }

  // ══════════════════════════════════════════════════════════════
  //  BUILD — RESPONSIVE ROOT
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _mainFocusNode,
      onKeyEvent: _handleGlobalKey,
      child: Scaffold(
        backgroundColor: const Color(0xFFE8E8E8),
        floatingActionButton: context.isMobile
            ? FloatingActionButton.extended(
                onPressed: () => setState(
                    () => _searchPanelExpanded = !_searchPanelExpanded),
                backgroundColor: const Color(0xFF0D47A1),
                icon: Icon(_searchPanelExpanded ? Icons.close : Icons.search),
                label: Text(_searchPanelExpanded ? 'Close' : 'Search'),
              )
            : null,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            if (w >= _BP.desktop) return _buildWideDesktopLayout();
            if (w >= _BP.tablet) return _buildTabletLayout();
            if (w >= _BP.mobile) return _buildSmallTabletLayout();
            return _buildMobileLayout();
          },
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  LAYOUT 1 — WIDE DESKTOP (≥1200px)
  // ══════════════════════════════════════════════════════════════
  Widget _buildWideDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInvoiceAndCustomerSection(),
                const SizedBox(height: 10),
                Expanded(child: _buildItemsTable()),
                const SizedBox(height: 16),
                _buildBottomSection(),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(width: 360, child: _buildSearchPanel()),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  LAYOUT 2 — DESKTOP LCD (900-1199px)
  // ══════════════════════════════════════════════════════════════
  Widget _buildTabletLayout() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInvoiceAndCustomerSection(compact: true),
                const SizedBox(height: 8),
                Expanded(child: _buildItemsTable(compact: true)),
                const SizedBox(height: 12),
                _buildBottomSection(compact: true),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(width: 300, child: _buildSearchPanel()),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  LAYOUT 3 — SMALL TABLET (600-899px)
  // ══════════════════════════════════════════════════════════════
  Widget _buildSmallTabletLayout() {
    return Column(
      children: [
        _buildTabletSearchStrip(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInvoiceAndCustomerSection(compact: true),
                const SizedBox(height: 12),
                SizedBox(height: 380, child: _buildItemsTable(compact: true)),
                const SizedBox(height: 12),
                _buildBottomSection(compact: true),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  LAYOUT 4 — MOBILE (<600px)
  // ══════════════════════════════════════════════════════════════
  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildMobileTopBar(),
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          height: _searchPanelExpanded ? 340 : 0,
          child: _searchPanelExpanded
              ? ClipRect(child: _buildSearchPanel(mobile: true))
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInvoiceAndCustomerSection(compact: true, mobile: true),
                const SizedBox(height: 10),
                SizedBox(
                    height: 320,
                    child: _buildItemsTable(compact: true, mobile: true)),
                const SizedBox(height: 10),
                _buildBottomSection(compact: true, mobile: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  MOBILE TOP BAR
  // ══════════════════════════════════════════════════════════════
  Widget _buildMobileTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        gradient:
            LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1976D2)]),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(children: [
          const Icon(Icons.medical_services, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Sale Screen',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              Text('INV${invoiceController.text}  •  ${dateController.text}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ),
          const Icon(Icons.print_outlined, color: Colors.white54, size: 18),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _showSlipPreview(),
            icon: const Icon(Icons.print, color: Colors.white, size: 20),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            onPressed: () =>
                _saveSale(updateExisting: _isSaleCompleted && _isEditMode),
            icon: const Icon(Icons.save, color: Colors.white, size: 20),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (_) => const PremiumDashboardScreen()),
                (_) => false),
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  TABLET SEARCH STRIP
  // ══════════════════════════════════════════════════════════════
  Widget _buildTabletSearchStrip() {
    final filtered = allProducts
        .where(
            (p) => p.itemName.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFD3D3D3),
        border: Border(bottom: BorderSide(color: Color(0xFFBBBBBB))),
      ),
      child: Column(children: [
        InkWell(
          onTap: () =>
              setState(() => _searchPanelExpanded = !_searchPanelExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              const Icon(Icons.search, size: 18, color: Color(0xFF0D47A1)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  searchQuery.isEmpty
                      ? 'Tap to search items…'
                      : 'Searching: "$searchQuery"',
                  style: TextStyle(
                      fontSize: 13,
                      color: searchQuery.isEmpty
                          ? Colors.grey.shade600
                          : const Color(0xFF0D47A1)),
                ),
              ),
              if (cart.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${cart.length} items',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 11)),
                ),
              const SizedBox(width: 8),
              Icon(
                  _searchPanelExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.grey.shade600),
            ]),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          height: _searchPanelExpanded ? 300 : 0,
          child: _searchPanelExpanded
              ? ClipRect(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(children: [
                      Focus(
                        onKeyEvent: _handleSearchKey,
                        child: TextField(
                          controller: searchController,
                          focusNode: searchFocusNode,
                          autofocus: true,
                          onChanged: (value) => setState(() {
                            searchQuery = value;
                            selectedSearchIndex = value.isNotEmpty ? 0 : -1;
                            isNavigatingCart = false;
                          }),
                          decoration: InputDecoration(
                            hintText: 'Type to search…',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                    searchQuery.isEmpty
                                        ? 'Start typing to search…'
                                        : 'No products found',
                                    style: const TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (_, index) {
                                  final product = filtered[index];
                                  final isSelected =
                                      index == selectedSearchIndex;
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    color: isSelected
                                        ? Colors.blue.shade100
                                        : Colors.white,
                                    elevation: isSelected ? 3 : 1,
                                    child: ListTile(
                                      dense: true,
                                      title: Text(product.itemName,
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal)),
                                      subtitle: Text(
                                          '${product.issueUnit ?? '-'} • ${currencyFormat.format(product.retailPrice)} • Stock: ${product.stock}',
                                          style: const TextStyle(fontSize: 11)),
                                      trailing: Icon(Icons.add_circle,
                                          color: isSelected
                                              ? Colors.blue
                                              : Colors.green,
                                          size: 22),
                                      onTap: () {
                                        _addToCartAndFocusQty(product);
                                        setState(
                                            () => _searchPanelExpanded = false);
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ]),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  INVOICE & CUSTOMER SECTION
  // ══════════════════════════════════════════════════════════════
  Widget _buildInvoiceAndCustomerSection({
    bool compact = false,
    bool mobile = false,
  }) {
    if (mobile) {
      return Column(children: [
        _buildMobileInvoiceRow(),
        const SizedBox(height: 8),
        _buildCustomerCard(compact: true),
      ]);
    }
    return Column(children: [
      Row(children: [
        Expanded(
            child: _buildLabeledTextField(
                label: 'Invoice ID',
                controller:
                    TextEditingController(text: 'INV${invoiceController.text}'),
                readOnly: true,
                compact: compact)),
        SizedBox(width: compact ? 10 : 16),
        Expanded(
            child: _buildLabeledTextField(
                label: 'Invoice Date',
                controller: dateController,
                readOnly: true,
                compact: compact)),
        SizedBox(width: compact ? 10 : 16),
        _buildPrintIndicator(compact: compact),
      ]),
      SizedBox(height: compact ? 10 : 16),
      _buildCustomerCard(compact: compact),
    ]);
  }

  Widget _buildMobileInvoiceRow() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Invoice',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('INV${invoiceController.text}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ])),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Date',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text(dateController.text,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ])),
          _buildPrintIndicator(compact: true),
        ]),
      ),
    );
  }

  /// Simple print-ready indicator (replaces Bluetooth indicator).
  Widget _buildPrintIndicator({bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 6 : 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.print_outlined, color: Colors.blue.shade600, size: 18),
        const SizedBox(width: 5),
        if (!compact)
          Text('Slip Preview',
              style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
      ]),
    );
  }

  Widget _buildCustomerCard({bool compact = false}) {
    Customer? matchedCustomer;
    if (selectedCustomer != null) {
      try {
        matchedCustomer =
            allCustomers.firstWhere((c) => c.id == selectedCustomer!.id);
      } catch (_) {
        matchedCustomer = null;
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 16),
        child: Row(children: [
          Expanded(
            flex: 2,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Customer *',
                    style: TextStyle(
                        fontSize: compact ? 12 : 13, color: Colors.black87)),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue.shade300),
                  ),
                  child: Text('F10',
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 5),
              InkWell(
                onTap: _openCustomerDropdown,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                      horizontal: 10, vertical: compact ? 8 : 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Row(children: [
                    Icon(Icons.person_outline,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(
                      matchedCustomer?.name ?? 'Walk-in Customer',
                      style: TextStyle(
                          fontSize: compact ? 12 : 14,
                          color: matchedCustomer != null
                              ? Colors.black87
                              : Colors.grey.shade500),
                      overflow: TextOverflow.ellipsis,
                    )),
                    if (matchedCustomer != null &&
                        matchedCustomer.openingBalance > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                            currencyFormat
                                .format(matchedCustomer.openingBalance),
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600)),
                      ),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_drop_down,
                        color: Colors.grey.shade600, size: 18),
                  ]),
                ),
              ),
            ]),
          ),
          SizedBox(width: compact ? 12 : 24),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Previous Balance',
                  style: TextStyle(
                      fontSize: compact ? 12 : 13, color: Colors.black87)),
              const SizedBox(height: 5),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                    horizontal: 10, vertical: compact ? 8 : 10),
                decoration: BoxDecoration(
                  color: previousBalance > 0
                      ? Colors.red.shade50
                      : const Color(0xFFD3D3D3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: previousBalance > 0
                          ? Colors.red.shade300
                          : Colors.grey.shade400),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(currencyFormat.format(previousBalance),
                          style: TextStyle(
                              fontSize: compact ? 12 : 14,
                              fontWeight: FontWeight.w600,
                              color: previousBalance > 0
                                  ? Colors.red.shade700
                                  : Colors.black87)),
                      if (previousBalance > 0)
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: Colors.red.shade400),
                    ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildLabeledTextField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    FocusNode? focusNode,
    Function(String)? onChanged,
    bool compact = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: compact ? 11 : 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87)),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? const Color(0xFFD3D3D3) : Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            focusNode: focusNode,
            style: TextStyle(fontSize: compact ? 12 : 14),
            onChanged: onChanged,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 10, vertical: compact ? 7 : 10),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  ITEMS TABLE
  // ══════════════════════════════════════════════════════════════
  Widget _buildItemsTable({bool compact = false, bool mobile = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFD3D3D3),
            border: Border(bottom: BorderSide(color: Colors.grey.shade400)),
          ),
          padding: EdgeInsets.symmetric(
              horizontal: mobile ? 6 : 8, vertical: compact ? 7 : 10),
          child: mobile
              ? _buildMobileTableHeader()
              : _buildFullTableHeader(compact: compact),
        ),
        Expanded(
          child: cart.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 40, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      const Text('No items added',
                          style: TextStyle(color: Colors.grey, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                          mobile
                              ? 'Tap the search button to add items'
                              : 'Search → Enter → QTY → Enter → DIS → Enter',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 11),
                          textAlign: TextAlign.center),
                    ]))
              : ListView.builder(
                  itemCount: cart.length,
                  itemBuilder: (context, index) {
                    final item = cart[index];
                    final product = cartProductData[item.productId];
                    final isSelected =
                        isNavigatingCart && index == selectedCartIndex;
                    return Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blue.shade50
                            : (index.isEven
                                ? Colors.white
                                : Colors.grey.shade50),
                        border: Border(
                          bottom: BorderSide(
                              color: Colors.grey.shade300, width: 0.5),
                          left: isSelected
                              ? const BorderSide(color: Colors.blue, width: 3)
                              : BorderSide.none,
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                          horizontal: mobile ? 6 : 8, vertical: 6),
                      child: mobile
                          ? _buildMobileCartRow(item, product, index)
                          : _buildFullCartRow(item, product, index,
                              compact: compact),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _buildFullTableHeader({bool compact = false}) {
    final fs = compact ? 10.0 : 11.0;
    final style = TextStyle(
        fontSize: fs, fontWeight: FontWeight.w600, color: Colors.black87);
    return Row(children: [
      Expanded(
          flex: 1,
          child: Text('S#', textAlign: TextAlign.center, style: style)),
      Expanded(
          flex: 3,
          child:
              Text('Product Name', textAlign: TextAlign.center, style: style)),
      Expanded(
          flex: 2,
          child: Text('Unit (F1)', textAlign: TextAlign.center, style: style)),
      Expanded(
          flex: 1,
          child: Text('QTY', textAlign: TextAlign.center, style: style)),
      Expanded(
          flex: 2,
          child: Text('R.P', textAlign: TextAlign.center, style: style)),
      Expanded(
          flex: 2,
          child: Text('T.P', textAlign: TextAlign.center, style: style)),
      Expanded(
          flex: 1,
          child: Text('DIS%', textAlign: TextAlign.center, style: style)),
      Expanded(
          flex: 2,
          child: Text('Amount', textAlign: TextAlign.center, style: style)),
      Expanded(
          flex: 1,
          child: Text('Del', textAlign: TextAlign.center, style: style)),
    ]);
  }

  Widget _buildMobileTableHeader() {
    const style = TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black87);
    return const Row(children: [
      Expanded(flex: 4, child: Text('Product', style: style)),
      Expanded(
          flex: 2,
          child: Text('QTY', textAlign: TextAlign.center, style: style)),
      Expanded(
          flex: 2,
          child: Text('Price', textAlign: TextAlign.center, style: style)),
      Expanded(
          flex: 2,
          child: Text('Total', textAlign: TextAlign.center, style: style)),
      Expanded(flex: 1, child: Text('', style: style)),
    ]);
  }

  Widget _buildFullCartRow(SaleItem item, Product? product, int index,
      {bool compact = false}) {
    return Row(children: [
      _buildDataCell('${index + 1}', flex: 1, compact: compact),
      _buildProductNameCell(item, product, flex: 3, compact: compact),
      _buildUnitCell(item, product, index: index, flex: 2, compact: compact),
      _buildEditableQtyCell(item, index: index, compact: compact),
      _buildPriceCell(item, flex: 2, compact: compact),
      _buildTraderPriceCell(item, flex: 2, compact: compact),
      _buildEditableDisCell(item, index: index, compact: compact),
      _buildDataCell(currencyFormat.format(_getItemLineTotal(item)),
          flex: 2, bold: true, compact: compact),
      _buildDeleteCell(item, flex: 1),
    ]);
  }

  Widget _buildMobileCartRow(SaleItem item, Product? product, int index) {
    bool isReadOnly = _isSaleCompleted && !_isEditMode;
    return Row(children: [
      Expanded(
          flex: 4,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.productName,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            Text(selectedUnits[item.productId] ?? item.unitType ?? 'Pc',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ])),
      Expanded(
          flex: 2,
          child: _buildEditableQtyCell(item,
              index: index, compact: true, mobile: true)),
      Expanded(
          flex: 2,
          child: Text(currencyFormat.format(item.price),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500))),
      Expanded(
          flex: 2,
          child: Text(currencyFormat.format(_getItemLineTotal(item)),
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
      Expanded(
          flex: 1,
          child: IconButton(
            onPressed: isReadOnly
                ? null
                : () => setState(() => _removeCartItem(item.productId)),
            icon: Icon(Icons.delete_outline,
                size: 16,
                color: isReadOnly ? Colors.grey : Colors.red.shade400),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          )),
    ]);
  }

  // ══════════════════════════════════════════════════════════════
  //  SEARCH PANEL
  // ══════════════════════════════════════════════════════════════
  Widget _buildSearchPanel({bool mobile = false}) {
    final filtered = allProducts
        .where(
            (p) => p.itemName.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(children: [
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFFD3D3D3),
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4), topRight: Radius.circular(4)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: const Center(
            child: Text('Search Item (↑↓ Arrow Keys)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFFD3D3D3),
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              Focus(
                onKeyEvent: _handleSearchKey,
                child: TextField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  autofocus: !mobile,
                  onChanged: (value) => setState(() {
                    searchQuery = value;
                    selectedSearchIndex = value.isNotEmpty ? 0 : -1;
                    isNavigatingCart = false;
                  }),
                  decoration: InputDecoration(
                    hintText: 'Type to search…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 7),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: Colors.grey.shade400)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                            searchQuery.isEmpty
                                ? 'Start typing to search…'
                                : 'No products found',
                            style: const TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final product = filtered[index];
                          final isSelected = index == selectedSearchIndex;
                          final tierCount = product.conversionTiers?.length ??
                              (product.hasUnitConversion ? 2 : 0);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            color: isSelected
                                ? Colors.blue.shade100
                                : Colors.white,
                            elevation: isSelected ? 3 : 1,
                            child: ListTile(
                              dense: true,
                              leading: isSelected
                                  ? const Icon(Icons.arrow_right,
                                      color: Colors.blue)
                                  : null,
                              title: Row(children: [
                                Expanded(
                                    child: Text(product.itemName,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal))),
                                if (product.hasUnitConversion)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [
                                        Color(0xFF3B82F6),
                                        Color(0xFF8B5CF6)
                                      ]),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('${tierCount + 1}T',
                                        style: const TextStyle(
                                            fontSize: 8,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                  ),
                              ]),
                              subtitle: Text(
                                  '${product.issueUnit ?? '-'} • ${currencyFormat.format(product.retailPrice)} • Stk: ${product.stock}',
                                  style: const TextStyle(fontSize: 10)),
                              trailing: isSelected
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius:
                                              BorderRadius.circular(4)),
                                      child: const Text('Enter ⏎',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9)))
                                  : null,
                              onTap: () {
                                _addToCartAndFocusQty(product);
                                if (mobile)
                                  setState(() => _searchPanelExpanded = false);
                              },
                            ),
                          );
                        },
                      ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  TABLE CELL WIDGETS
  // ══════════════════════════════════════════════════════════════
  Widget _buildDataCell(String text,
      {int flex = 1,
      bool alignLeft = false,
      bool bold = false,
      bool compact = false}) {
    return Expanded(
        flex: flex,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(text,
              textAlign: alignLeft ? TextAlign.left : TextAlign.center,
              style: TextStyle(
                  fontSize: compact ? 10 : 12,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ));
  }

  Widget _buildProductNameCell(SaleItem item, Product? product,
      {int flex = 3, bool compact = false}) {
    final hasConversion = product?.hasUnitConversion ?? false;
    final tierCount =
        product?.conversionTiers?.length ?? (hasConversion ? 2 : 0);
    return Expanded(
        flex: flex,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(children: [
            Expanded(
                child: Text(item.productName,
                    style: TextStyle(fontSize: compact ? 11 : 12),
                    overflow: TextOverflow.ellipsis)),
            if (hasConversion)
              Container(
                margin: const EdgeInsets.only(left: 3),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)]),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text('${tierCount + 1}T',
                    style: const TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
          ]),
        ));
  }

  Widget _buildUnitCell(SaleItem item, Product? product,
      {required int index, int flex = 2, bool compact = false}) {
    final hasConversion = product?.hasUnitConversion ?? false;
    final currentUnit = selectedUnits[item.productId] ??
        item.unitType ??
        product?.baseUnit ??
        'Pc';
    bool isReadOnly = _isSaleCompleted && !_isEditMode;

    if (!hasConversion) {
      return Expanded(
          flex: flex,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(item.packing ?? 'Pc',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: compact ? 10 : 12, color: Colors.grey.shade600)),
          ));
    }

    return Expanded(
        flex: flex,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: InkWell(
            onTap: isReadOnly
                ? null
                : () {
                    setState(() {
                      selectedCartIndex = index;
                      isNavigatingCart = true;
                    });
                    _showUnitSelectionDialog(item.productId, product!);
                  },
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? 4 : 8, vertical: compact ? 4 : 6),
              decoration: BoxDecoration(
                gradient: isReadOnly
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight),
                color: isReadOnly ? Colors.grey.shade200 : null,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color:
                        isReadOnly ? Colors.grey.shade400 : Colors.transparent),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(currentUnit,
                        style: TextStyle(
                            fontSize: compact ? 10 : 11,
                            fontWeight: FontWeight.w600,
                            color: isReadOnly
                                ? Colors.grey.shade600
                                : Colors.white)),
                    if (!isReadOnly) ...[
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down,
                          size: 14, color: Colors.white),
                    ],
                  ]),
            ),
          ),
        ));
  }

  Widget _buildPriceCell(SaleItem item, {int flex = 2, bool compact = false}) {
    return Expanded(
        flex: flex,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(currencyFormat.format(item.price),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: compact ? 10 : 12,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500)),
        ));
  }

  Widget _buildTraderPriceCell(SaleItem item,
      {int flex = 2, bool compact = false}) {
    return Expanded(
        flex: flex,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(currencyFormat.format(item.tradePrice),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: compact ? 10 : 12,
                  color: const Color.fromARGB(255, 249, 191, 2),
                  fontWeight: FontWeight.w500)),
        ));
  }

  Widget _buildDeleteCell(SaleItem item, {int flex = 1}) {
    bool isReadOnly = _isSaleCompleted && !_isEditMode;
    return Expanded(
        flex: flex,
        child: Center(
          child: IconButton(
            onPressed: isReadOnly
                ? null
                : () => setState(() => _removeCartItem(item.productId)),
            icon: Icon(Icons.delete_outline,
                size: 18,
                color: isReadOnly ? Colors.grey : Colors.red.shade400),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ));
  }

  Widget _buildEditableQtyCell(SaleItem item,
      {required int index, bool compact = false, bool mobile = false}) {
    final itemId = item.productId;
    final controller = qtyControllers[itemId];
    final focusNode = qtyFocusNodes[itemId];
    if (controller == null || focusNode == null) {
      return _buildDataCell(item.quantity.toString(),
          flex: 1, compact: compact);
    }
    bool isReadOnly = _isSaleCompleted && !_isEditMode;
    return Expanded(
        flex: 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            readOnly: isReadOnly,
            style: TextStyle(
                fontSize: compact ? 11 : 12, fontWeight: FontWeight.bold),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                  vertical: compact ? 6 : 8, horizontal: 3),
              filled: true,
              fillColor:
                  isReadOnly ? const Color(0xFFE0E0E0) : Colors.blue.shade50,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Colors.blue, width: 2)),
            ),
            onSubmitted: (value) {
              _isSubmittingQty = true;
              _commitQtyValue(itemId);
              _isSubmittingQty = false;
              if (!mobile) _focusCartItemDis(index);
            },
          ),
        ));
  }

  Widget _buildEditableDisCell(SaleItem item,
      {required int index, bool compact = false}) {
    final itemId = item.productId;
    final controller = disControllers[itemId];
    final focusNode = disFocusNodes[itemId];
    if (controller == null || focusNode == null) {
      return _buildDataCell('${(item.discount ?? 0).toStringAsFixed(0)}%',
          flex: 1, compact: compact);
    }
    bool isReadOnly = _isSaleCompleted && !_isEditMode;
    final discountAmount = _getItemDiscountAmount(item);
    return Expanded(
        flex: 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: controller,
              focusNode: focusNode,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              readOnly: isReadOnly,
              style: TextStyle(fontSize: compact ? 11 : 12),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              ],
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                    vertical: compact ? 6 : 8, horizontal: 3),
                filled: true,
                fillColor: isReadOnly
                    ? const Color(0xFFE0E0E0)
                    : Colors.orange.shade50,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:
                        const BorderSide(color: Colors.orange, width: 2)),
                hintText: '0%',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 9),
                suffixText: '%',
                suffixStyle: TextStyle(
                    fontSize: 9,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold),
              ),
              onSubmitted: (value) {
                _isSubmittingDis = true;
                _commitDisValue(itemId);
                _isSubmittingDis = false;
                _returnFocusToSearch();
              },
            ),
            if (discountAmount > 0)
              Text('-${currencyFormat.format(discountAmount)}',
                  style: TextStyle(
                      fontSize: 8,
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w500)),
          ]),
        ));
  }

  // ══════════════════════════════════════════════════════════════
  //  BOTTOM SECTION
  // ══════════════════════════════════════════════════════════════
  Widget _buildBottomSection({bool compact = false, bool mobile = false}) {
    return Column(children: [
      if (selectedCustomer != null && previousBalance > 0)
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [Colors.orange.shade50, Colors.red.shade50]),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade300),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.account_balance_wallet,
                  color: Colors.orange.shade700, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('${selectedCustomer!.name} has previous balance',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.orange.shade800)),
                  const SizedBox(height: 2),
                  Text(
                      'Prev: ${currencyFormat.format(previousBalance)} + Sale: ${currencyFormat.format(saleAmount)} = Due: ${currencyFormat.format(totalDue)}',
                      style: TextStyle(
                          fontSize: 10, color: Colors.orange.shade700)),
                ])),
            Text(currencyFormat.format(totalDue),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.red.shade700)),
          ]),
        ),
      if (mobile)
        _buildMobileTotalsGrid()
      else
        Row(children: [
          Expanded(
              child: _buildTotalField('Total Items',
                  '${cart.length} items (${totalQuantity.toStringAsFixed(0)} qty)',
                  compact: compact)),
          SizedBox(width: compact ? 8 : 12),
          Expanded(
              child: _buildTotalField(
                  'Sale Amount', currencyFormat.format(saleAmount),
                  highlight: true, compact: compact)),
          SizedBox(width: compact ? 8 : 12),
          Expanded(
              child: _buildTotalField(
                  'Total Due', currencyFormat.format(totalDue),
                  color: Colors.purple.shade100,
                  borderColor: Colors.purple.shade400,
                  textColor: Colors.purple.shade800,
                  compact: compact)),
        ]),
      SizedBox(height: compact ? 8 : 12),
      if (mobile)
        _buildMobileAmountPaid()
      else
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Text('Amount Paid (F4)',
                      style: TextStyle(
                          fontSize: compact ? 12 : 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87)),
                  const SizedBox(width: 8),
                  _buildQuickAmountButton('Full', totalDue),
                  const SizedBox(width: 4),
                  _buildQuickAmountButton('Sale', saleAmount),
                  const SizedBox(width: 4),
                  _buildQuickAmountButton('Clear', 0),
                ]),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.shade400, width: 2),
                  ),
                  child: TextField(
                    controller: amountPaidController,
                    focusNode: amountPaidFocusNode,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                        fontSize: compact ? 14 : 16,
                        fontWeight: FontWeight.bold),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                    ],
                    decoration: InputDecoration(
                      prefixIcon:
                          Icon(Icons.payments, color: Colors.green.shade600),
                      hintText: 'Enter amount…',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: compact ? 10 : 12),
                    ),
                    onSubmitted: (_) => _returnFocusToSearch(),
                  ),
                ),
              ])),
          SizedBox(width: compact ? 8 : 12),
          Expanded(
              child: _buildTotalField(
            'Remaining Balance',
            currencyFormat.format(remainingBalance),
            isNegative: remainingBalance > 0,
            color: remainingBalance > 0
                ? Colors.red.shade50
                : Colors.green.shade50,
            borderColor: remainingBalance > 0
                ? Colors.red.shade300
                : Colors.green.shade300,
            textColor: remainingBalance > 0
                ? Colors.red.shade700
                : Colors.green.shade700,
            compact: compact,
          )),
        ]),
      SizedBox(height: compact ? 12 : 16),
      _buildActionButtonsRow(mobile: mobile, compact: compact),
    ]);
  }

  Widget _buildMobileTotalsGrid() {
    return Column(children: [
      Row(children: [
        Expanded(
            child: _buildTotalField('Items',
                '${cart.length} (qty: ${totalQuantity.toStringAsFixed(0)})',
                compact: true)),
        const SizedBox(width: 8),
        Expanded(
            child: _buildTotalField(
                'Sale Amount', currencyFormat.format(saleAmount),
                highlight: true, compact: true)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
            child: _buildTotalField(
                'Total Due', currencyFormat.format(totalDue),
                color: Colors.purple.shade100,
                borderColor: Colors.purple.shade400,
                textColor: Colors.purple.shade800,
                compact: true)),
        const SizedBox(width: 8),
        Expanded(
            child: _buildTotalField(
                'Remaining', currencyFormat.format(remainingBalance),
                isNegative: remainingBalance > 0,
                color: remainingBalance > 0
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderColor: remainingBalance > 0
                    ? Colors.red.shade300
                    : Colors.green.shade300,
                textColor: remainingBalance > 0
                    ? Colors.red.shade700
                    : Colors.green.shade700,
                compact: true)),
      ]),
    ]);
  }

  Widget _buildMobileAmountPaid() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Row(children: [
        const Text('Amount Paid',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        _buildQuickAmountButton('Full', totalDue),
        const SizedBox(width: 4),
        _buildQuickAmountButton('Sale', saleAmount),
        const SizedBox(width: 4),
        _buildQuickAmountButton('0', 0),
      ]),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.green.shade400, width: 2),
        ),
        child: TextField(
          controller: amountPaidController,
          focusNode: amountPaidFocusNode,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
          ],
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.payments, color: Colors.green.shade600),
            hintText: 'Enter amount paid…',
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          ),
          onSubmitted: (_) => _returnFocusToSearch(),
        ),
      ),
    ]);
  }

  Widget _buildActionButtonsRow({bool mobile = false, bool compact = false}) {
    if (mobile) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _buildActionButton(
            _isSaleCompleted && !_isEditMode
                ? 'SAVED'
                : (_isEditMode ? 'UPDATE' : 'SAVE'),
            () => _saveSale(updateExisting: _isSaleCompleted && _isEditMode),
            disabled: _isSaleCompleted && !_isEditMode,
            color: _isEditMode ? Colors.orange : Colors.blue,
            icon: Icons.save,
          ),
          _buildActionButton('NEW', _performSaveAndNew,
              disabled: cart.isEmpty,
              color: Colors.green[700],
              icon: Icons.add_circle),
          if (_isSaleCompleted)
            _buildActionButton(
              _isEditMode ? 'LOCK' : 'EDIT',
              _enableEditMode,
              color: _isEditMode ? Colors.green : Colors.orange,
              icon: _isEditMode ? Icons.lock : Icons.edit,
            ),
          _buildActionButton('FIND', _showFindInvoiceDialog,
              icon: Icons.search),
          _buildActionButton('PRINT', _showSlipPreview,
              disabled: cart.isEmpty,
              color: Colors.blue[700],
              icon: Icons.print),
          _buildActionButton(
              'CLOSE',
              () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PremiumDashboardScreen()),
                  (_) => false),
              icon: Icons.close,
              color: Colors.red[400]),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _buildActionButton(
          _isSaleCompleted && !_isEditMode
              ? 'SAVED'
              : (_isEditMode ? 'UPDATE' : 'SAVE'),
          () => _saveSale(updateExisting: _isSaleCompleted && _isEditMode),
          disabled: _isSaleCompleted && !_isEditMode,
          color: _isEditMode ? Colors.orange : Colors.blue,
          icon: Icons.save,
          compact: compact,
        ),
        SizedBox(width: compact ? 8 : 12),
        _buildActionButton('ADD', _performSaveAndNew,
            disabled: cart.isEmpty,
            color: Colors.green[700],
            icon: Icons.add_circle,
            compact: compact),
        SizedBox(width: compact ? 8 : 12),
        if (_isSaleCompleted) ...[
          _buildActionButton(
            _isEditMode ? 'LOCK' : 'EDIT',
            _enableEditMode,
            color: _isEditMode ? Colors.green : Colors.orange,
            icon: _isEditMode ? Icons.lock : Icons.edit,
            compact: compact,
          ),
          SizedBox(width: compact ? 8 : 12),
        ],
        _buildActionButton('FIND', _showFindInvoiceDialog,
            icon: Icons.search, compact: compact),
        SizedBox(width: compact ? 8 : 12),
        _buildActionButton('PRINT', _showSlipPreview,
            disabled: cart.isEmpty,
            color: Colors.blue[700],
            icon: Icons.print,
            compact: compact),
        SizedBox(width: compact ? 8 : 12),
        _buildActionButton(
            'CLOSE',
            () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (_) => const PremiumDashboardScreen()),
                (_) => false),
            icon: Icons.close,
            color: Colors.red[400],
            compact: compact),
      ]),
    );
  }

  Widget _buildQuickAmountButton(String label, double amount) {
    return InkWell(
      onTap: () =>
          setState(() => amountPaidController.text = amount.toStringAsFixed(0)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade700)),
      ),
    );
  }

  Widget _buildTotalField(
    String label,
    String value, {
    bool highlight = false,
    bool isNegative = false,
    bool compact = false,
    Color? color,
    Color? borderColor,
    Color? textColor,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87)),
      const SizedBox(height: 5),
      Container(
        width: double.infinity,
        padding:
            EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 8 : 10),
        decoration: BoxDecoration(
          color: color ??
              (highlight
                  ? Colors.green.shade100
                  : (isNegative
                      ? Colors.red.shade50
                      : const Color(0xFFD3D3D3))),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: borderColor ??
                  (highlight
                      ? Colors.green.shade400
                      : (isNegative
                          ? Colors.red.shade300
                          : Colors.grey.shade400))),
        ),
        child: Text(value,
            style: TextStyle(
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.w600,
                color: textColor ??
                    (highlight
                        ? Colors.green.shade800
                        : (isNegative
                            ? Colors.red.shade700
                            : Colors.black87)))),
      ),
    ]);
  }

  Widget _buildActionButton(
    String label,
    VoidCallback onPressed, {
    bool disabled = false,
    Color? color,
    IconData? icon,
    bool compact = false,
  }) {
    return ElevatedButton.icon(
      onPressed: disabled ? null : onPressed,
      icon: icon != null
          ? Icon(icon, size: compact ? 16 : 18)
          : const SizedBox.shrink(),
      label: Text(label,
          style: TextStyle(
              fontSize: compact ? 11 : 13, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            disabled ? Colors.grey : (color ?? const Color(0xFFD3D3D3)),
        foregroundColor: const Color.fromARGB(255, 5, 2, 2),
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 20, vertical: compact ? 9 : 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 2,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  ADD TO CART & FOCUS QTY
  // ══════════════════════════════════════════════════════════════
  void _addToCartAndFocusQty(Product p) {
    if (_isSaleCompleted && !_isEditMode) return;
    int targetProductId = p.id!;
    setState(() {
      final existIndex = cart.indexWhere((e) => e.productId == targetProductId);
      if (existIndex != -1) {
        final item = cart[existIndex];
        final newQty = item.quantity + 1;
        final unitType = selectedUnits[targetProductId] ?? p.baseUnit ?? 'Unit';
        int baseQty = newQty;
        if (p.hasUnitConversion)
          baseQty = p.convertToBaseUnits(newQty, unitType);
        cart[existIndex] =
            item.copyWith(quantity: newQty, baseQuantity: baseQty);
        qtyControllers[targetProductId]?.text = newQty.toString();
      } else {
        final defaultUnit = p.hasUnitConversion
            ? (p.baseUnit ?? 'Tablet')
            : (p.issueUnit ?? 'Pc');
        final defaultPrice = p.hasUnitConversion
            ? (p.pricePerUnit ?? p.retailPrice)
            : p.retailPrice;
        cart.add(SaleItem(
          productId: targetProductId,
          productName: p.itemName,
          price: defaultPrice,
          quantity: 1,
          packing: p.issueUnit,
          tradePrice: p.tradePrice,
          discount: 0,
          salesTax: 0,
          unitType: defaultUnit,
          baseQuantity: 1,
        ));
        cartProductData[targetProductId] = p;
        selectedUnits[targetProductId] = defaultUnit;
        qtyControllers[targetProductId] = TextEditingController(text: '1');
        qtyFocusNodes[targetProductId] = _createQtyFocusNode(targetProductId);
        disControllers[targetProductId] = TextEditingController(text: '0');
        disFocusNodes[targetProductId] = _createDisFocusNode(targetProductId);
        unitFocusNodes[targetProductId] = _createUnitFocusNode(targetProductId);
      }
      selectedCartIndex =
          cart.indexWhere((e) => e.productId == targetProductId);
      isNavigatingCart = true;
      searchController.clear();
      searchQuery = '';
      selectedSearchIndex = -1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focusNode = qtyFocusNodes[targetProductId];
      final controller = qtyControllers[targetProductId];
      if (focusNode != null && controller != null) {
        focusNode.requestFocus();
        controller.selection =
            TextSelection(baseOffset: 0, extentOffset: controller.text.length);
      }
    });
  }

  // ══════════════════════════════════════════════════════════════
  //  RETURN FOCUS TO SEARCH
  // ══════════════════════════════════════════════════════════════
  void _returnFocusToSearch() {
    searchController.clear();
    setState(() {
      searchQuery = '';
      selectedSearchIndex = -1;
      selectedCartIndex = -1;
      isNavigatingCart = false;
    });
    Future.microtask(() {
      if (mounted) searchFocusNode.requestFocus();
    });
  }

  // ══════════════════════════════════════════════════════════════
  //  SAVE / RESET
  // ══════════════════════════════════════════════════════════════
  Future<void> _performSaveAndNew() async {
    if (cart.isEmpty) return;
    if (!_isSaleCompleted) {
      await _saveSale(updateExisting: false);
    } else if (_isEditMode) {
      await _saveSale(updateExisting: true);
    }
    _resetForNewSale();
    _snack('Sale saved! → Ready for new sale', Colors.green);
  }

  void _resetForNewSale() {
    setState(() {
      cart.clear();
      for (var c in qtyControllers.values) c.dispose();
      qtyControllers.clear();
      for (var n in qtyFocusNodes.values) n.dispose();
      qtyFocusNodes.clear();
      for (var c in disControllers.values) c.dispose();
      disControllers.clear();
      for (var n in disFocusNodes.values) n.dispose();
      disFocusNodes.clear();
      for (var n in unitFocusNodes.values) n.dispose();
      unitFocusNodes.clear();
      selectedUnits.clear();
      cartProductData.clear();
      currentSaleId = null;
      _generateInvoiceNumber();
      _setCurrentDate();
      selectedCustomer = null;
      customerNameController.text = 'Walk-in Customer';
      customerBalanceController.text = '0.00';
      amountPaidController.clear();
      _isSaleCompleted = false;
      _isEditMode = false;
      searchController.clear();
      searchQuery = '';
      selectedSearchIndex = -1;
      selectedCartIndex = -1;
      isNavigatingCart = false;
      _searchPanelExpanded = false;
      _loadedPreviousBalance = null;
    });
    Future.microtask(() {
      if (mounted) searchFocusNode.requestFocus();
    });
  }

  void _syncSelectedCustomer() {
    if (selectedCustomer == null) return;
    try {
      final updatedCustomer =
          allCustomers.firstWhere((c) => c.id == selectedCustomer!.id);
      setState(() {
        selectedCustomer = updatedCustomer;
        customerBalanceController.text =
            updatedCustomer.openingBalance.toStringAsFixed(0);
      });
    } catch (e) {
      debugPrint('Could not sync customer: $e');
    }
  }

  Future<void> _saveSale({required bool updateExisting}) async {
    if (cart.isEmpty) {
      _snack('Cart is empty!', Colors.orange);
      return;
    }
    final balances = _calculateBalances();
    final saleMap = {
      'invoiceId': invoiceController.text,
      'dateTime': DateTime.now().toIso8601String(),
      'customerId': selectedCustomer?.id,
      'customerName': selectedCustomer?.name ?? 'Walk-in Customer',
      'subtotal': balances['subtotal'],
      'discount': balances['discount'],
      'tax': balances['tax'],
      'total': balances['saleAmount'],
      'previousBalance': balances['previousBalance'],
      'totalDue': balances['totalDue'],
      'amountPaid': balances['amountPaid'],
      'balance': balances['remainingBalance'],
      'paymentMethod': selectedPayment,
    };

    try {
      if (updateExisting && currentSaleId != null) {
        await DatabaseHelper.instance.updateSale(currentSaleId!, saleMap);
        await DatabaseHelper.instance.updateSaleItems(currentSaleId!, cart);
        if (selectedCustomer?.id != null) {
          await DatabaseHelper.instance.updateCustomerBalance(
              selectedCustomer!.id!, balances['remainingBalance']!);
          await _loadCustomers();
          _syncSelectedCustomer();
        }
        _snack(
            'Sale updated! Remaining: ${currencyFormat.format(balances['remainingBalance']!)}',
            Colors.green);
      } else {
        final saleId = await DatabaseHelper.instance.addSale(saleMap);
        currentSaleId = saleId;
        await DatabaseHelper.instance.addSaleItems(saleId, cart);
        if (selectedCustomer?.id != null) {
          await DatabaseHelper.instance.updateCustomerBalance(
              selectedCustomer!.id!, balances['remainingBalance']!);
          await _loadCustomers();
          _syncSelectedCustomer();
        }
        _snack(
          balances['remainingBalance']! > 0
              ? 'Sale saved! Customer owes: ${currencyFormat.format(balances['remainingBalance']!)}'
              : 'Sale saved! Fully paid.',
          Colors.green,
        );
      }
      setState(() {
        _isSaleCompleted = true;
        _isEditMode = false;
      });
    } catch (e) {
      _snack('Error: $e', Colors.red);
    }
  }

  void _enableEditMode() {
    setState(() => _isEditMode = !_isEditMode);
    _snack(_isEditMode ? 'Edit mode enabled' : 'Edit mode disabled',
        _isEditMode ? Colors.orange : Colors.blue);
  }

  // ══════════════════════════════════════════════════════════════
  //  FIND INVOICE DIALOG
  // ══════════════════════════════════════════════════════════════
  void _showFindInvoiceDialog() {
    final TextEditingController findController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Find Invoice'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Enter Invoice Number:'),
          const SizedBox(height: 12),
          TextField(
            controller: findController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Invoice Number',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onSubmitted: (value) {
              Navigator.pop(context);
              _loadInvoiceByNumber(value);
            },
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadInvoiceByNumber(findController.text);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1)),
            child: const Text(
              'Find',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadInvoiceByNumber(String invoiceNumber) async {
    if (invoiceNumber.trim().isEmpty) return;
    try {
      final sale =
          await DatabaseHelper.instance.getSaleByInvoiceId(invoiceNumber);
      if (sale == null) {
        _snack('Invoice #$invoiceNumber not found', Colors.red);
        return;
      }

      final saleItems = await DatabaseHelper.instance.getSaleItems(sale['id']);
      await _loadCustomers();

      setState(() {
        cart.clear();
        for (var c in qtyControllers.values) c.dispose();
        qtyControllers.clear();
        for (var n in qtyFocusNodes.values) n.dispose();
        qtyFocusNodes.clear();
        for (var c in disControllers.values) c.dispose();
        disControllers.clear();
        for (var n in disFocusNodes.values) n.dispose();
        disFocusNodes.clear();
        for (var n in unitFocusNodes.values) n.dispose();
        unitFocusNodes.clear();
        selectedUnits.clear();
        cartProductData.clear();

        currentSaleId = sale['id'];
        invoiceController.text = sale['invoiceId'];
        dateController.text =
            DateFormat('dd/MM/yyyy').format(DateTime.parse(sale['dateTime']));

        if (sale['customerId'] != null) {
          try {
            selectedCustomer =
                allCustomers.firstWhere((c) => c.id == sale['customerId']);
            customerNameController.text = selectedCustomer?.name ?? '';
            customerBalanceController.text =
                (selectedCustomer?.openingBalance ?? 0).toStringAsFixed(0);
          } catch (_) {
            selectedCustomer = null;
            customerNameController.text = sale['customerName'] ?? 'Unknown';
            customerBalanceController.text = '0.00';
          }
        } else {
          selectedCustomer = null;
          customerNameController.text = 'Walk-in Customer';
          customerBalanceController.text = '0.00';
        }

        for (var item in saleItems) {
          final productId = item['productId'] as int;
          _loadProductForCart(productId);
          cart.add(SaleItem(
            productId: productId,
            productName: item['productName'],
            price: item['price'],
            quantity: item['quantity'],
            packing: item['packing'],
            tradePrice: item['tradePrice'] ?? 0,
            discount: item['discount'] ?? 0,
            salesTax: item['salesTax'] ?? 0,
            unitType: item['unitType'],
            baseQuantity: item['baseQuantity'],
          ));
          selectedUnits[productId] = item['unitType'] ?? 'Unit';
          qtyControllers[productId] =
              TextEditingController(text: item['quantity'].toString());
          qtyFocusNodes[productId] = _createQtyFocusNode(productId);
          disControllers[productId] =
              TextEditingController(text: (item['discount'] ?? 0).toString());
          disFocusNodes[productId] = _createDisFocusNode(productId);
          unitFocusNodes[productId] = _createUnitFocusNode(productId);
        }

        amountPaidController.text = (sale['amountPaid'] ?? 0).toString();
        _loadedPreviousBalance = (sale['previousBalance'] as num?)?.toDouble() ?? 0.0;
        _isSaleCompleted = true;
        _isEditMode = false;
        selectedCartIndex = -1;
        isNavigatingCart = false;
      });

      _snack('Invoice #$invoiceNumber loaded (${cart.length} items)',
          Colors.green);
    } catch (e) {
      _snack('Error loading invoice: $e', Colors.red);
    }
  }

  Future<void> _loadProductForCart(int productId) async {
    final product = await DatabaseHelper.instance.getProductById(productId);
    if (product != null) cartProductData[productId] = product;
  }

  @override
  void dispose() {
    invoiceController.dispose();
    dateController.dispose();
    customerNameController.dispose();
    customerBalanceController.dispose();
    searchController.dispose();
    amountPaidController.removeListener(_onAmountPaidChanged);
    amountPaidController.dispose();
    amountPaidFocusNode.dispose();
    searchFocusNode.dispose();
    _mainFocusNode.dispose();
    _customerSearchFocus.dispose();
    _customerSearchController.dispose();
    _customerScrollController.dispose();
    for (var c in qtyControllers.values) c.dispose();
    for (var n in qtyFocusNodes.values) n.dispose();
    for (var c in disControllers.values) c.dispose();
    for (var n in disFocusNodes.values) n.dispose();
    for (var n in unitFocusNodes.values) n.dispose();
    super.dispose();
  }
}

// ══════════════════════════════════════════════════════════════
//  CUSTOMER DROPDOWN DIALOG
// ══════════════════════════════════════════════════════════════
class _CustomerDropdownDialog extends StatefulWidget {
  final List<Customer> allCustomers;
  final Customer? selectedCustomer;
  final NumberFormat currencyFormat;
  final void Function(Customer?) onSelected;
  final VoidCallback onClose;

  const _CustomerDropdownDialog({
    required this.allCustomers,
    required this.selectedCustomer,
    required this.currencyFormat,
    required this.onSelected,
    required this.onClose,
  });

  @override
  State<_CustomerDropdownDialog> createState() =>
      _CustomerDropdownDialogState();
}

class _CustomerDropdownDialogState extends State<_CustomerDropdownDialog> {
  final TextEditingController _filterController = TextEditingController();
  final FocusNode _filterFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  String _filter = '';
  int _highlightIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.selectedCustomer != null) {
      final idx = widget.allCustomers
          .indexWhere((c) => c.id == widget.selectedCustomer!.id);
      if (idx != -1) _highlightIndex = idx + 1;
    }
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _filterFocus.requestFocus());
  }

  List<Customer> get _filtered {
    if (_filter.isEmpty) return widget.allCustomers;
    return widget.allCustomers
        .where((c) => c.name.toLowerCase().contains(_filter.toLowerCase()))
        .toList();
  }

  int get _totalRows => _filtered.length + 1;

  void _scrollToHighlight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      const itemHeight = 60.0;
      final offset = _highlightIndex * itemHeight;
      if (_scroll.hasClients) {
        _scroll.animateTo(offset.clamp(0, _scroll.position.maxScrollExtent),
            duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
      }
    });
  }

  void _confirm() {
    if (_highlightIndex == 0) {
      widget.onSelected(null);
    } else {
      final customers = _filtered;
      if (_highlightIndex - 1 < customers.length) {
        widget.onSelected(customers[_highlightIndex - 1]);
      }
    }
  }

  @override
  void dispose() {
    _filterController.dispose();
    _filterFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customers = _filtered;
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowDown) {
          setState(() {
            _highlightIndex = (_highlightIndex + 1) % _totalRows;
          });
          _scrollToHighlight();
        } else if (key == LogicalKeyboardKey.arrowUp) {
          setState(() {
            _highlightIndex = (_highlightIndex - 1 + _totalRows) % _totalRows;
          });
          _scrollToHighlight();
        } else if (key == LogicalKeyboardKey.enter) {
          _confirm();
        } else if (key == LogicalKeyboardKey.tab) {
          widget.onClose();
        }
      },
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient:
                LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]),
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.person_search, color: Colors.white, size: 22),
              SizedBox(width: 10),
              Text('Select Customer',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _filterController,
              focusNode: _filterFocus,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Type to filter customers…',
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white70, size: 20),
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.3))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.3))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Colors.white, width: 1.5)),
              ),
              onChanged: (v) => setState(() {
                _filter = v;
                _highlightIndex = 0;
              }),
            ),
            const SizedBox(height: 6),
            Text('↑↓ navigate  |  Enter to select  |  Esc to cancel',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7), fontSize: 11)),
          ]),
        ),
        contentPadding: const EdgeInsets.all(8),
        content: SizedBox(
          width: 400,
          height: 380,
          child: ListView.builder(
            controller: _scroll,
            itemCount: _totalRows,
            itemBuilder: (context, index) {
              final isHighlighted = index == _highlightIndex;
              if (index == 0) {
                return _CustomerRow(
                  name: 'Walk-in Customer',
                  subtitle: 'No account needed',
                  balance: null,
                  isHighlighted: isHighlighted,
                  isSelected: widget.selectedCustomer == null,
                  icon: Icons.directions_walk,
                  iconColor: Colors.green,
                  onTap: () => widget.onSelected(null),
                  currencyFormat: widget.currencyFormat,
                );
              }
              final c = customers[index - 1];
              return _CustomerRow(
                name: c.name,
                subtitle: c.phone ?? '',
                balance: c.openingBalance,
                isHighlighted: isHighlighted,
                isSelected: widget.selectedCustomer?.id == c.id,
                icon: Icons.person,
                iconColor: Colors.blue,
                onTap: () => widget.onSelected(c),
                currencyFormat: widget.currencyFormat,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  final String name, subtitle;
  final double? balance;
  final bool isHighlighted, isSelected;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final NumberFormat currencyFormat;

  const _CustomerRow({
    required this.name,
    required this.subtitle,
    required this.balance,
    required this.isHighlighted,
    required this.isSelected,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isHighlighted
              ? iconColor.withOpacity(0.12)
              : (isSelected ? iconColor.withOpacity(0.06) : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isHighlighted
                ? iconColor
                : (isSelected
                    ? iconColor.withOpacity(0.4)
                    : Colors.transparent),
            width: isHighlighted ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isHighlighted ? iconColor : iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
                color: isHighlighted ? Colors.white : iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isHighlighted ? iconColor : Colors.black87)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ])),
          if (balance != null && balance! > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(currencyFormat.format(balance),
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600)),
            ),
          if (isSelected) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_circle, color: iconColor, size: 18),
          ],
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  UNIT OPTION MODEL
// ══════════════════════════════════════════════════════════════
class _UnitOption {
  final String unitKey, displayName, containsLabel;
  final double price;
  final int tierIndex;

  const _UnitOption({
    required this.unitKey,
    required this.displayName,
    required this.price,
    required this.containsLabel,
    required this.tierIndex,
  });
}
