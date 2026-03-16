// lib/screens/purchase_screen_desktop.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/models/supplier.dart';
import 'package:medical_app/models/product.dart';
import 'package:medical_app/models/purchase.dart';
import 'package:medical_app/services/database_helper.dart';
import 'package:medical_app/Screens/dashboardScreen.dart';
import 'package:medical_app/models/purchasemodel.dart';

class PurchaseScreenDesktop extends StatefulWidget {
  const PurchaseScreenDesktop({super.key});

  @override
  State<PurchaseScreenDesktop> createState() => _PurchaseScreenDesktopState();
}

class _PurchaseScreenDesktopState extends State<PurchaseScreenDesktop> {
  // Controllers
  final TextEditingController invoiceController = TextEditingController();
  final TextEditingController dateController = TextEditingController();
  final TextEditingController supplierNameController = TextEditingController();
  final TextEditingController supplierBalanceController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  final TextEditingController amountPaidController = TextEditingController();

  // Focus nodes
  final FocusNode searchFocusNode = FocusNode();
  final FocusNode _mainFocusNode = FocusNode();
  int selectedSearchIndex = -1;

  // Cart navigation
  int selectedCartIndex = -1;
  bool isNavigatingCart = false;

  // Per-item controllers & focus nodes
  final Map<int, TextEditingController> qtyControllers = {};
  final Map<int, FocusNode> qtyFocusNodes = {};
  final Map<int, TextEditingController> disControllers = {};
  final Map<int, FocusNode> disFocusNodes = {};
  final Map<int, FocusNode> unitFocusNodes = {};
  final Map<int, String> selectedUnits = {};
  final Map<int, Product> cartProductData = {};

  // Per-item T.P and R.P controllers
  final Map<int, TextEditingController> tpControllers = {};
  final Map<int, FocusNode> tpFocusNodes = {};
  final Map<int, TextEditingController> rpControllers = {};
  final Map<int, FocusNode> rpFocusNodes = {};

  bool _isSubmittingQty = false;
  bool _isSubmittingDis = false;

  // Data
  List<Product> allProducts = [];
  List<PurchaseItem> cart = [];
  List<Supplier> allSuppliers = [];
  Supplier? selectedSupplier;
  String searchQuery = '';
  bool _isPurchaseCompleted = false;
  bool _isEditMode = false;
  int? currentPurchaseId;

  final currencyFormat = NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _generateInvoiceNumber();
    _setCurrentDate();
    _loadProducts();
    _loadSuppliers();
    supplierBalanceController.text = '0.00';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      searchFocusNode.requestFocus();
    });
  }

  void _generateInvoiceNumber() {
    final now = DateTime.now();
    invoiceController.text = 'PUR${now.millisecondsSinceEpoch % 100000}';
  }

  void _setCurrentDate() {
    dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
  }

  Future<void> _loadSuppliers() async {
    final suppliers = await DatabaseHelper.instance.getAllSuppliers();
    setState(() => allSuppliers = suppliers);
  }

  Future<void> _loadProducts() async {
    final products = await DatabaseHelper.instance.getAllProducts();
    setState(() => allProducts = products);
  }

  double get totalQuantity =>
      cart.fold(0, (sum, item) => sum + item.quantity).toDouble();
  
  // ── UPDATED: Calculate total with percentage discount ──
  double get totalAmount => cart.fold(0.0, (sum, item) {
    double subtotal = item.tradePrice * item.quantity;
    double discountAmount = subtotal * ((item.discount ?? 0) / 100);
    return sum + (subtotal - discountAmount);
  });
  
  // ── NEW: Total discount amount ──
  double get totalDiscountAmount => cart.fold(0.0, (sum, item) {
    double subtotal = item.tradePrice * item.quantity;
    return sum + (subtotal * ((item.discount ?? 0) / 100));
  });
  
  // ── NEW: Subtotal before discount ──
  double get subtotalBeforeDiscount => cart.fold(0.0, (sum, item) {
    return sum + (item.tradePrice * item.quantity);
  });

  double get amountPaid =>
      double.tryParse(amountPaidController.text) ?? 0.0;
  double get balance {
    double previousBalance =
        double.tryParse(supplierBalanceController.text) ?? 0.0;
    return previousBalance + totalAmount - amountPaid;
  }

  // ==================== FOCUS NODE CREATION ====================
  FocusNode _createQtyFocusNode(int productId) {
    final node = FocusNode();
    node.addListener(() {
      if (!node.hasFocus && mounted && !_isSubmittingQty) {
        _commitQtyValue(productId);
      }
    });
    return node;
  }

  FocusNode _createDisFocusNode(int productId) {
    final node = FocusNode();
    node.addListener(() {
      if (!node.hasFocus && mounted && !_isSubmittingDis) {
        _commitDisValue(productId);
      }
    });
    return node;
  }

  FocusNode _createUnitFocusNode(int productId) => FocusNode();

  FocusNode _createTpFocusNode(int productId) {
    final node = FocusNode();
    node.addListener(() {
      if (!node.hasFocus && mounted) _commitTpValue(productId);
    });
    return node;
  }

  FocusNode _createRpFocusNode(int productId) {
    final node = FocusNode();
    node.addListener(() {
      if (!node.hasFocus && mounted) _commitRpValue(productId);
    });
    return node;
  }

  // ==================== COMMIT VALUES ====================
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

  // ── UPDATED: Validate discount percentage (0-100) ──
  void _commitDisValue(int productId) {
    final controller = disControllers[productId];
    if (controller == null) return;
    double numValue = double.tryParse(controller.text) ?? 0;
    
    // Clamp discount between 0 and 100
    if (numValue < 0) numValue = 0;
    if (numValue > 100) numValue = 100;
    
    // Update controller if value was clamped
    controller.text = numValue.toStringAsFixed(numValue.truncateToDouble() == numValue ? 0 : 2);
    
    final index = cart.indexWhere((e) => e.productId == productId);
    if (index == -1) return;
    final item = cart[index];
    if (item.discount == numValue) return;
    setState(() {
      cart[index] = item.copyWith(discount: numValue);
    });
  }

  void _commitTpValue(int productId) {
    final controller = tpControllers[productId];
    if (controller == null) return;
    final numValue = double.tryParse(controller.text) ?? 0;
    final index = cart.indexWhere((e) => e.productId == productId);
    if (index == -1) return;
    setState(() {
      cart[index] = cart[index].copyWith(tradePrice: numValue);
    });
  }

  void _commitRpValue(int productId) {
    final controller = rpControllers[productId];
    if (controller == null) return;
    final numValue = double.tryParse(controller.text) ?? 0;
    final index = cart.indexWhere((e) => e.productId == productId);
    if (index == -1) return;
    setState(() {
      cart[index] = cart[index].copyWith(retailPrice: numValue);
    });
  }

  // ==================== REMOVE ITEM ====================
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
    tpControllers[productId]?.dispose();
    tpControllers.remove(productId);
    tpFocusNodes[productId]?.dispose();
    tpFocusNodes.remove(productId);
    rpControllers[productId]?.dispose();
    rpControllers.remove(productId);
    rpFocusNodes[productId]?.dispose();
    rpFocusNodes.remove(productId);
    selectedUnits.remove(productId);
    cartProductData.remove(productId);
    cart.removeWhere((item) => item.productId == productId);
  }

  // ==================== KEYBOARD HANDLER ====================
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final filtered = allProducts
        .where((p) =>
            p.itemName.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    if (event.logicalKey == LogicalKeyboardKey.f1) {
      _focusOnUnitSelector();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.f2) {
      if (selectedCartIndex >= 0 && selectedCartIndex < cart.length) {
        _focusCartItemQty(selectedCartIndex);
      } else if (cart.isNotEmpty) {
        setState(() { selectedCartIndex = 0; isNavigatingCart = true; });
        _focusCartItemQty(0);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.f3) {
      if (selectedCartIndex >= 0 && selectedCartIndex < cart.length) {
        _focusCartItemDis(selectedCartIndex);
      } else if (cart.isNotEmpty) {
        setState(() { selectedCartIndex = 0; isNavigatingCart = true; });
        _focusCartItemDis(0);
      }
      return KeyEventResult.handled;
    }

    if (searchQuery.isNotEmpty && filtered.isNotEmpty) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          selectedSearchIndex = (selectedSearchIndex + 1) % filtered.length;
          isNavigatingCart = false;
        });
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          selectedSearchIndex =
              (selectedSearchIndex - 1 + filtered.length) % filtered.length;
          isNavigatingCart = false;
        });
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (selectedSearchIndex >= 0 &&
            selectedSearchIndex < filtered.length) {
          _addToCartAndFocusQty(filtered[selectedSearchIndex]);
        }
        return KeyEventResult.handled;
      }
    } else if (searchQuery.isEmpty && cart.isNotEmpty) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          isNavigatingCart = true;
          selectedCartIndex = (selectedCartIndex + 1) % cart.length;
        });
        _focusCartItemQty(selectedCartIndex);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          isNavigatingCart = true;
          selectedCartIndex =
              (selectedCartIndex - 1 + cart.length) % cart.length;
        });
        _focusCartItemQty(selectedCartIndex);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.enter &&
          isNavigatingCart) {
        if (selectedCartIndex >= 0) _focusCartItemQty(selectedCartIndex);
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _returnFocusToSearch();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

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

  void _focusOnUnitSelector() {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No items in cart!'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 1),
      ));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${item.productName} has no unit conversion'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    _showUnitSelectionDialog(item.productId, product);
  }

  // ==================== DYNAMIC UNIT OPTIONS ====================
  List<_UnitOption> _getUnitOptions(Product product) {
    final options = <_UnitOption>[];

    options.add(_UnitOption(
      unitKey: product.baseUnit ?? 'Tablet',
      displayName: product.baseUnit ?? 'Tablet',
      price: product.pricePerUnit ?? product.tradePrice,
      containsLabel: '1 (base unit)',
      tierIndex: 0,
    ));

    if (product.conversionTiers != null && product.conversionTiers!.isNotEmpty) {
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
          price: product.pricePerStrip ?? 0,
          containsLabel:
              '${product.unitsPerStrip ?? 10} ${product.baseUnit ?? 'Tablet'}s',
          tierIndex: 1,
        ));
      }
      if ((product.pricePerBox ?? 0) > 0 || (product.stripsPerBox ?? 0) > 0) {
        options.add(_UnitOption(
          unitKey: 'Box',
          displayName: 'Box',
          price: product.pricePerBox ?? 0,
          containsLabel: '${product.stripsPerBox ?? 10} Strips',
          tierIndex: 2,
        ));
      }
    }

    return options;
  }

  // ==================== DYNAMIC UNIT SELECTION DIALOG ====================
  void _showUnitSelectionDialog(int productId, Product product) {
    final currentUnit =
        selectedUnits[productId] ?? product.baseUnit ?? 'Unit';
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

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
              ),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Purchase Unit',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                      Text(
                        product.itemName,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${unitOptions.length} Tiers',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                        Row(children: [
                          const Icon(Icons.calculate_outlined,
                              size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 6),
                        ]),
                        const SizedBox(height: 6),
                        ...List.generate(unitOptions.length - 1, (i) {
                          final upper = unitOptions[i + 1];
                          return Text(
                            '• 1 ${upper.displayName} = ${upper.containsLabel}',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF92400E)),
                          );
                        }),
                      ],
                    ),
                  ),

                ...unitOptions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final opt = entry.value;
                  final isSelected = currentUnit == opt.unitKey;
                  final color = colorFor(i);

                  return GestureDetector(
                    onTap: () {
                      _updateUnitSelection(
                          productId, opt.unitKey, product, opt.price);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withOpacity(0.08)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? color
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color: color.withOpacity(0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2))
                              ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color
                                  : color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                i == 0 ? 'B' : '$i',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? Colors.white
                                      : color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text(
                                    opt.displayName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? color
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  if (i == 0) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: const Text('BASE',
                                          style: TextStyle(
                                              fontSize: 8,
                                              color: Colors.white,
                                              fontWeight:
                                                  FontWeight.bold)),
                                    ),
                                  ],
                                ]),
                                Text(
                                  opt.containsLabel,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                currencyFormat.format(opt.price),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? color
                                      : const Color(0xFF10B981),
                                ),
                              ),
                              Text(
                                'T.P',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey.shade500),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle,
                                    color: color, size: 16),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
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
        tradePrice: tradePrice,
        unitType: newUnit,
        baseQuantity: baseQty,
      );
      tpControllers[productId]?.text = tradePrice.toStringAsFixed(0);
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '${product.itemName}: $newUnit @ ${currencyFormat.format(tradePrice)}'),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 1),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _mainFocusNode,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.f1) {
          _focusOnUnitSelector();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE8E8E8),
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              return _buildDesktopLayout();
            } else {
              return _buildMobileLayout();
            }
          },
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
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
                _buildInvoiceAndSupplierSection(),
                const SizedBox(height: 10),
                Expanded(child: _buildItemsTable()),
                const SizedBox(height: 20),
                _buildBottomSection(),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(width: 350, child: _buildSearchPanel()),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInvoiceAndSupplierSection(),
          const SizedBox(height: 20),
          SizedBox(height: 400, child: _buildSearchPanel()),
          const SizedBox(height: 20),
          SizedBox(height: 400, child: _buildItemsTable()),
          const SizedBox(height: 20),
          _buildBottomSection(),
        ],
      ),
    );
  }

  Widget _buildShortcutChip(String key, String action, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3)),
            child: Text(key,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 3),
          Text(action,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildInvoiceAndSupplierSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildLabeledTextField(
                label: 'Invoice Number',
                controller: invoiceController,
                readOnly: false,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildLabeledTextField(
                label: 'Purchase Date',
                controller: dateController,
                readOnly: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _supplierInfoRow(),
      ],
    );
  }

  Widget _supplierInfoRow() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Supplier Name *',
                      style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Supplier>(
                    value: selectedSupplier,
                    hint: const Text('Select Supplier'),
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    items: allSuppliers.map((s) {
                      return DropdownMenuItem<Supplier>(
                          value: s, child: Text(s.name));
                    }).toList(),
                    onChanged: (Supplier? newValue) async {
                      if (newValue != null) {
                        final currentBalance = await DatabaseHelper.instance
                            .getCurrentSupplierBalance(newValue.name);
                        setState(() {
                          selectedSupplier = newValue;
                          supplierNameController.text = newValue.name;
                          supplierBalanceController.text =
                              currentBalance.toStringAsFixed(0);
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildLabeledTextField(
                label: 'Current Balance',
                controller: supplierBalanceController,
                readOnly: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabeledTextField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? const Color(0xFFD3D3D3) : Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // ── Header row ─────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFD3D3D3),
              border: Border(
                  bottom: BorderSide(color: Colors.grey.shade400)),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 10),
            child: Row(
              children: [
                _buildHeaderCell('S#', flex: 1),
                _buildHeaderCell('Product', flex: 3),
                _buildHeaderCell('Unit (F1)', flex: 2),
                _buildHeaderCell('QTY (F2)', flex: 1),
                _buildHeaderCell('T.P', flex: 2),
                _buildHeaderCell('R.P', flex: 2),
                // ── UPDATED: Changed header to show percentage ──
                _buildHeaderCell('DIS % (F3)', flex: 1),
                _buildHeaderCell('Amount', flex: 2),
                _buildHeaderCell('', flex: 1),
              ],
            ),
          ),
          // ── Body ───────────────────────────────────────────────────────────
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        const Text('No items added',
                            style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        // Text(
                        //   'Search → QTY → T.P → R.P → DIS% → Search',
                        //   style: TextStyle(
                        //       fontSize: 11,
                        //       color: Colors.grey.shade500),
                        // ),
                      ],
                    ),
                  )
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
                                color: Colors.grey.shade300,
                                width: 0.5),
                            left: isSelected
                                ? const BorderSide(
                                    color: Colors.blue, width: 3)
                                : BorderSide.none,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Row(
                          children: [
                            _buildDataCell('${index + 1}', flex: 1),
                            _buildProductNameCell(item, product, flex: 3),
                            _buildUnitCell(item, product,
                                index: index, flex: 2),
                            _buildEditableQtyCell(item, index: index),
                            _buildEditableTpCell(item, index: index),
                            _buildEditableRpCell(item, index: index),
                            // ── UPDATED: Percentage discount cell ──
                            _buildEditableDisCell(item, index: index),
                            // ── UPDATED: Show calculated amount with discount ──
                            _buildAmountCell(item, flex: 2),
                            _buildDeleteCell(item, flex: 1),
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

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildDataCell(String text, {int flex = 1, bool bold = false}) {
    return Expanded(
      flex: flex,
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    );
  }

  // ── NEW: Amount cell that shows subtotal, discount, and final amount ──
  Widget _buildAmountCell(PurchaseItem item, {int flex = 2}) {
    final subtotal = item.tradePrice * item.quantity;
    final discountPercent = item.discount ?? 0;
    final discountAmount = subtotal * (discountPercent / 100);
    final finalAmount = subtotal - discountAmount;
    
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            currencyFormat.format(finalAmount),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (discountPercent > 0)
            Text(
              '-${currencyFormat.format(discountAmount)}',
              style: TextStyle(
                fontSize: 9,
                color: Colors.red.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductNameCell(PurchaseItem item, Product? product,
      {int flex = 3}) {
    final hasConversion = product?.hasUnitConversion ?? false;
    final tierCount = product?.conversionTiers?.length ??
        (hasConversion ? 2 : 0);

    return Expanded(
      flex: flex,
      child: Row(
        children: [
          Expanded(
            child: Text(item.productName,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
          if (hasConversion)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(
                  horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${tierCount + 1}T',
                style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUnitCell(PurchaseItem item, Product? product,
      {required int index, int flex = 2}) {
    final hasConversion = product?.hasUnitConversion ?? false;
    final currentUnit = selectedUnits[item.productId] ??
        item.unitType ??
        product?.baseUnit ??
        'Pc';
    bool isReadOnly = _isPurchaseCompleted && !_isEditMode;

    if (!hasConversion) {
      return Expanded(
        flex: flex,
        child: Text(item.packing ?? 'Pc',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12)),
      );
    }

    return Expanded(
      flex: flex,
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
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            gradient: isReadOnly
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF3B82F6)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            color: isReadOnly ? Colors.grey.shade200 : null,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: isReadOnly
                    ? Colors.grey.shade400
                    : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                currentUnit,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color:
                      isReadOnly ? Colors.grey.shade600 : Colors.white,
                ),
              ),
              if (!isReadOnly) ...[
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down,
                    size: 16, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteCell(PurchaseItem item, {int flex = 1}) {
    bool isReadOnly = _isPurchaseCompleted && !_isEditMode;
    return Expanded(
      flex: flex,
      child: Center(
        child: IconButton(
          onPressed: isReadOnly
              ? null
              : () {
                  setState(() => _removeCartItem(item.productId));
                },
          icon: Icon(Icons.delete_outline,
              size: 18,
              color: isReadOnly ? Colors.grey : Colors.red.shade400),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ),
    );
  }

  Widget _buildEditableQtyCell(PurchaseItem item,
      {required int index}) {
    final itemId = item.productId;
    final controller = qtyControllers[itemId];
    final focusNode = qtyFocusNodes[itemId];
    if (controller == null || focusNode == null) {
      return _buildDataCell(item.quantity.toString(), flex: 1);
    }
    bool isReadOnly = _isPurchaseCompleted && !_isEditMode;

    return Expanded(
      flex: 1,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        readOnly: isReadOnly,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          filled: true,
          fillColor:
              isReadOnly ? const Color(0xFFE0E0E0) : Colors.blue.shade50,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
        ),
        onSubmitted: (value) {
          _isSubmittingQty = true;
          _commitQtyValue(itemId);
          _isSubmittingQty = false;
          // After QTY → focus T.P
          tpFocusNodes[itemId]?.requestFocus();
          tpControllers[itemId]?.selection = TextSelection(
              baseOffset: 0,
              extentOffset: tpControllers[itemId]!.text.length);
        },
      ),
    );
  }

  Widget _buildEditableTpCell(PurchaseItem item, {required int index}) {
    final itemId = item.productId;
    final controller = tpControllers[itemId];
    final focusNode = tpFocusNodes[itemId];
    if (controller == null || focusNode == null) {
      return _buildDataCell(item.tradePrice.toStringAsFixed(0), flex: 2);
    }
    bool isReadOnly = _isPurchaseCompleted && !_isEditMode;

    return Expanded(
      flex: 2,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        readOnly: isReadOnly,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.green.shade800),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
        ],
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          filled: true,
          fillColor:
              isReadOnly ? const Color(0xFFE0E0E0) : Colors.green.shade50,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide:
                const BorderSide(color: Colors.green, width: 2),
          ),
        ),
        onSubmitted: (value) {
          _commitTpValue(itemId);
          // After T.P → focus R.P
          rpFocusNodes[itemId]?.requestFocus();
          rpControllers[itemId]?.selection = TextSelection(
              baseOffset: 0,
              extentOffset: rpControllers[itemId]!.text.length);
        },
      ),
    );
  }

  Widget _buildEditableRpCell(PurchaseItem item, {required int index}) {
    final itemId = item.productId;
    final controller = rpControllers[itemId];
    final focusNode = rpFocusNodes[itemId];
    if (controller == null || focusNode == null) {
      return _buildDataCell(
          (item.retailPrice ?? 0).toStringAsFixed(0), flex: 2);
    }
    bool isReadOnly = _isPurchaseCompleted && !_isEditMode;

    return Expanded(
      flex: 2,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        readOnly: isReadOnly,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.purple.shade700),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
        ],
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          filled: true,
          fillColor:
              isReadOnly ? const Color(0xFFE0E0E0) : Colors.purple.shade50,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide:
                const BorderSide(color: Colors.purple, width: 2),
          ),
        ),
        onSubmitted: (value) {
          _commitRpValue(itemId);
          // After R.P → focus DIS
          disFocusNodes[itemId]?.requestFocus();
          disControllers[itemId]?.selection = TextSelection(
              baseOffset: 0,
              extentOffset: disControllers[itemId]!.text.length);
        },
      ),
    );
  }

  // ── UPDATED: Discount cell with percentage indicator ──
  Widget _buildEditableDisCell(PurchaseItem item,
      {required int index}) {
    final itemId = item.productId;
    final controller = disControllers[itemId];
    final focusNode = disFocusNodes[itemId];
    if (controller == null || focusNode == null) {
      return _buildDataCell(
          '${(item.discount ?? 0).toStringAsFixed(0)}%', flex: 1);
    }
    bool isReadOnly = _isPurchaseCompleted && !_isEditMode;

    return Expanded(
      flex: 1,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              readOnly: isReadOnly,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: (item.discount ?? 0) > 0 
                    ? Colors.orange.shade800 
                    : Colors.grey.shade600,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                // Custom formatter to limit to 100
                _PercentageInputFormatter(),
              ],
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                filled: true,
                fillColor: isReadOnly
                    ? const Color(0xFFE0E0E0)
                    : (item.discount ?? 0) > 0 
                        ? Colors.orange.shade100 
                        : Colors.orange.shade50,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide:
                      const BorderSide(color: Colors.orange, width: 2),
                ),
                // Add % suffix
                suffixText: '%',
                suffixStyle: TextStyle(
                  fontSize: 10,
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onSubmitted: (value) {
                _isSubmittingDis = true;
                _commitDisValue(itemId);
                _isSubmittingDis = false;
                _returnFocusToSearch();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    final filtered = allProducts
        .where((p) =>
            p.itemName.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFD3D3D3),
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: const Center(
              child: Text('Search Item',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFD3D3D3),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Focus(
                    onKeyEvent: _handleKeyEvent,
                    child: TextField(
                      controller: searchController,
                      focusNode: searchFocusNode,
                      autofocus: true,
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                          selectedSearchIndex =
                              value.isNotEmpty ? 0 : -1;
                          isNavigatingCart = false;
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFlowStep('Search', Icons.search),
                        const Icon(Icons.arrow_forward, size: 12),
                        _buildFlowStep('QTY', Icons.numbers),
                        const Icon(Icons.arrow_forward, size: 12),
                        _buildFlowStep('DIS%', Icons.percent),
                        const Icon(Icons.arrow_forward, size: 12),
                        _buildFlowStep('Search', Icons.refresh),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('No products found',
                                style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final product = filtered[index];
                              final isSelected =
                                  index == selectedSearchIndex;
                              final tierCount =
                                  product.conversionTiers?.length ??
                                      (product.hasUnitConversion ? 2 : 0);

                              return Card(
                                color: isSelected
                                    ? Colors.blue.shade100
                                    : Colors.white,
                                child: ListTile(
                                  dense: true,
                                  leading: isSelected
                                      ? const Icon(Icons.arrow_right,
                                          color: Colors.blue)
                                      : null,
                                  title: Row(
                                    children: [
                                      Expanded(
                                          child:
                                              Text(product.itemName)),
                                      if (product.hasUnitConversion)
                                        Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 6,
                                              vertical: 2),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF10B981),
                                                Color(0xFF3B82F6)
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    4),
                                          ),
                                          child: Text(
                                            '${tierCount + 1} Tiers',
                                            style: const TextStyle(
                                                fontSize: 9,
                                                color: Colors.white,
                                                fontWeight:
                                                    FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'T.P: ${currencyFormat.format(product.tradePrice)}'),
                                      if (product.hasUnitConversion)
                                        _buildTierPriceSubtitle(product),
                                    ],
                                  ),
                                  onTap: () =>
                                      _addToCartAndFocusQty(product),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierPriceSubtitle(Product product) {
    final options = _getUnitOptions(product);
    if (options.length <= 1) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.skip(1).map((opt) {
          return Container(
            margin: const EdgeInsets.only(right: 6, top: 2),
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Text(
              '${opt.displayName}: ${currencyFormat.format(opt.price)}',
              style: TextStyle(
                  fontSize: 10, color: Colors.green.shade700),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFlowStep(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12),
          const SizedBox(width: 2),
          Text(label, style: const TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  void _addToCartAndFocusQty(Product p) {
    if (_isPurchaseCompleted && !_isEditMode) return;
    int targetProductId = p.id!;

    setState(() {
      final existIndex =
          cart.indexWhere((e) => e.productId == targetProductId);

      if (existIndex != -1) {
        final item = cart[existIndex];
        final newQty = item.quantity + 1;
        cart[existIndex] = item.copyWith(quantity: newQty);
        qtyControllers[targetProductId]?.text = newQty.toString();
      } else {
        final defaultUnit = p.hasUnitConversion
            ? (p.baseUnit ?? 'Tablet')
            : (p.issueUnit ?? 'Pc');
        final defaultPrice = p.hasUnitConversion
            ? (p.pricePerUnit ?? p.tradePrice)
            : p.tradePrice;
        final defaultRetailPrice = p.retailPrice ?? 0.0;

        cart.add(PurchaseItem(
          productId: targetProductId,
          productName: p.itemName,
          tradePrice: defaultPrice,
          retailPrice: defaultRetailPrice,
          quantity: 1,
          packing: p.issueUnit,
          discount: 0, // Default 0%
          salesTax: 0,
          unitType: defaultUnit,
          baseQuantity: 1,
        ));

        cartProductData[targetProductId] = p;
        selectedUnits[targetProductId] = defaultUnit;

        qtyControllers[targetProductId] =
            TextEditingController(text: '1');
        qtyFocusNodes[targetProductId] =
            _createQtyFocusNode(targetProductId);
        disControllers[targetProductId] =
            TextEditingController(text: '0'); // 0%
        disFocusNodes[targetProductId] =
            _createDisFocusNode(targetProductId);
        unitFocusNodes[targetProductId] =
            _createUnitFocusNode(targetProductId);

        tpControllers[targetProductId] =
            TextEditingController(text: defaultPrice.toStringAsFixed(0));
        tpFocusNodes[targetProductId] =
            _createTpFocusNode(targetProductId);
        rpControllers[targetProductId] = TextEditingController(
            text: defaultRetailPrice.toStringAsFixed(0));
        rpFocusNodes[targetProductId] =
            _createRpFocusNode(targetProductId);
      }

      selectedCartIndex =
          cart.indexWhere((e) => e.productId == targetProductId);
      isNavigatingCart = true;
      searchController.clear();
      searchQuery = '';
      selectedSearchIndex = -1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final focusNode = qtyFocusNodes[targetProductId];
      final controller = qtyControllers[targetProductId];
      if (focusNode != null && controller != null) {
        focusNode.requestFocus();
        controller.selection =
            TextSelection(baseOffset: 0, extentOffset: controller.text.length);
      }
    });
  }

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

  Widget _buildBottomSection() {
    return Column(
      children: [
        // ── UPDATED: Added subtotal and discount summary ──
        Row(
          children: [
            Expanded(
              child: _buildTotalField('Total Items',
                  '${cart.length} (${totalQuantity.toStringAsFixed(0)} qty)'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTotalField(
                  'Subtotal', currencyFormat.format(subtotalBeforeDiscount)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTotalField(
                  'Discount', '-${currencyFormat.format(totalDiscountAmount)}',
                  isDiscount: true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTotalField(
                  'Net Total', currencyFormat.format(totalAmount),
                  highlight: true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildLabeledTextField(
                  label: 'Amount Paid',
                  controller: amountPaidController,
                  readOnly: false),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTotalField(
                  'Balance', currencyFormat.format(balance),
                  isNegative: balance > 0),
            ),
            const Expanded(flex: 2, child: SizedBox()),
          ],
        ),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(
                _isPurchaseCompleted && !_isEditMode
                    ? 'SAVED'
                    : (_isEditMode ? 'UPDATE' : 'SAVE'),
                () => _savePurchase(
                    updateExisting: _isPurchaseCompleted && _isEditMode),
                disabled: _isPurchaseCompleted && !_isEditMode,
                color: _isEditMode ? Colors.orange : Colors.blue,
                icon: Icons.save,
              ),
              const SizedBox(width: 12),
              _buildActionButton('ADD', _performSaveAndNew,
                  disabled: cart.isEmpty,
                  color: Colors.green[700],
                  icon: Icons.add_circle),
              const SizedBox(width: 12),
              if (_isPurchaseCompleted)
                _buildActionButton(
                  _isEditMode ? 'LOCK' : 'EDIT',
                  _enableEditMode,
                  color: _isEditMode ? Colors.green : Colors.orange,
                  icon: _isEditMode ? Icons.lock : Icons.edit,
                ),
              if (_isPurchaseCompleted) const SizedBox(width: 12),
              _buildActionButton('FIND', _showFindDialog,
                  icon: Icons.search),
              const SizedBox(width: 12),
              _buildActionButton('PRINT', () {},
                  disabled: cart.isEmpty,
                  color: Colors.blue[700],
                  icon: Icons.print),
              const SizedBox(width: 12),
              _buildActionButton('CLOSE', () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PremiumDashboardScreen()),
                  (route) => false,
                );
              }, icon: Icons.close, color: Colors.red[400]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalField(String label, String value,
      {bool highlight = false, bool isNegative = false, bool isDiscount = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: highlight
                ? Colors.green.shade100
                : (isNegative
                    ? Colors.red.shade50
                    : (isDiscount 
                        ? Colors.orange.shade50 
                        : const Color(0xFFD3D3D3))),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: highlight
                    ? Colors.green.shade400
                    : (isNegative
                        ? Colors.red.shade300
                        : (isDiscount
                            ? Colors.orange.shade300
                            : Colors.grey.shade400))),
          ),
          child: Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: highlight
                      ? Colors.green.shade800
                      : (isNegative
                          ? Colors.red.shade700
                          : (isDiscount
                              ? Colors.orange.shade700
                              : Colors.black87)))),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, VoidCallback onPressed,
      {bool disabled = false, Color? color, IconData? icon}) {
    return ElevatedButton.icon(
      onPressed: disabled ? null : onPressed,
      icon: icon != null
          ? Icon(icon, size: 18)
          : const SizedBox.shrink(),
      label: Text(label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            disabled ? Colors.grey : (color ?? const Color(0xFFD3D3D3)),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Future<void> _savePurchase({required bool updateExisting}) async {
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cart is empty!')));
      return;
    }
    if (selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a supplier!')));
      return;
    }

    // Commit any unsaved values
    for (final item in cart) {
      _commitTpValue(item.productId);
      _commitRpValue(item.productId);
      _commitDisValue(item.productId);
    }

    final purchase = Purchase(
      invoiceNumber: invoiceController.text,
      date: DateTime.now(),
      supplierName: selectedSupplier!.name,
      totalAmount: totalAmount,
      amountPaid: amountPaid,
      items: cart
          .map((e) => PurchaseItem(
                productId: e.productId,
                productName: e.productName,
                quantity: e.quantity,
                tradePrice: e.tradePrice,
                retailPrice: e.retailPrice,
                discount: e.discount, // This is now percentage
                salesTax: e.salesTax,
                unitType: e.unitType,
                baseQuantity: e.baseQuantity,
              ))
          .toList(),
    );

    try {
      await DatabaseHelper.instance.addPurchase(purchase);

      // Update product prices in DB
      for (final item in cart) {
        final product = cartProductData[item.productId];
        if (product != null) {
          final updatedProduct = product.copyWith(
            tradePrice: item.tradePrice,
            retailPrice: item.retailPrice ?? product.retailPrice,
          );
          await DatabaseHelper.instance.updateProduct(updatedProduct);
        }
      }

      await _loadProducts();

      final actualNewBalance = await DatabaseHelper.instance
          .getCurrentSupplierBalance(selectedSupplier!.name);
      setState(() {
        _isPurchaseCompleted = true;
        _isEditMode = false;
        supplierBalanceController.text =
            actualNewBalance.toStringAsFixed(0);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Purchase saved & product prices updated!'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _performSaveAndNew() async {
    if (cart.isEmpty) return;
    if (!_isPurchaseCompleted) {
      await _savePurchase(updateExisting: false);
    } else if (_isEditMode) {
      await _savePurchase(updateExisting: true);
    }
    _resetForNewPurchase();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Purchase saved! → Ready for new'),
      backgroundColor: Colors.green,
    ));
  }

  void _resetForNewPurchase() {
    setState(() {
      cart.clear();
      for (var c in qtyControllers.values) { c.dispose(); }
      qtyControllers.clear();
      for (var n in qtyFocusNodes.values) { n.dispose(); }
      qtyFocusNodes.clear();
      for (var c in disControllers.values) { c.dispose(); }
      disControllers.clear();
      for (var n in disFocusNodes.values) { n.dispose(); }
      disFocusNodes.clear();
      for (var n in unitFocusNodes.values) { n.dispose(); }
      unitFocusNodes.clear();
      for (var c in tpControllers.values) { c.dispose(); }
      tpControllers.clear();
      for (var n in tpFocusNodes.values) { n.dispose(); }
      tpFocusNodes.clear();
      for (var c in rpControllers.values) { c.dispose(); }
      rpControllers.clear();
      for (var n in rpFocusNodes.values) { n.dispose(); }
      rpFocusNodes.clear();
      selectedUnits.clear();
      cartProductData.clear();
      currentPurchaseId = null;
      _generateInvoiceNumber();
      _setCurrentDate();
      selectedSupplier = null;
      supplierNameController.clear();
      supplierBalanceController.text = '0.00';
      amountPaidController.clear();
      _isPurchaseCompleted = false;
      _isEditMode = false;
      searchController.clear();
      searchQuery = '';
      selectedSearchIndex = -1;
      selectedCartIndex = -1;
      isNavigatingCart = false;
    });
    Future.microtask(() {
      if (mounted) searchFocusNode.requestFocus();
    });
  }

  void _enableEditMode() {
    setState(() => _isEditMode = !_isEditMode);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          _isEditMode ? 'Edit mode enabled' : 'Edit mode disabled'),
      backgroundColor: _isEditMode ? Colors.orange : Colors.blue,
    ));
  }

  void _showFindDialog() {
    final TextEditingController findController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Find Purchase'),
        content: TextField(
          controller: findController,
          decoration:
              const InputDecoration(hintText: 'Invoice Number'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Find feature coming soon!')));
            },
            child: const Text('Find'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    invoiceController.dispose();
    dateController.dispose();
    supplierNameController.dispose();
    supplierBalanceController.dispose();
    searchController.dispose();
    amountPaidController.dispose();
    searchFocusNode.dispose();
    _mainFocusNode.dispose();
    for (var c in qtyControllers.values) { c.dispose(); }
    for (var n in qtyFocusNodes.values) { n.dispose(); }
    for (var c in disControllers.values) { c.dispose(); }
    for (var n in disFocusNodes.values) { n.dispose(); }
    for (var n in unitFocusNodes.values) { n.dispose(); }
    for (var c in tpControllers.values) { c.dispose(); }
    for (var n in tpFocusNodes.values) { n.dispose(); }
    for (var c in rpControllers.values) { c.dispose(); }
    for (var n in rpFocusNodes.values) { n.dispose(); }
    super.dispose();
  }
}

// ============================================================
// HELPER MODEL
// ============================================================
class _UnitOption {
  final String unitKey;
  final String displayName;
  final double price;
  final String containsLabel;
  final int tierIndex;

  const _UnitOption({
    required this.unitKey,
    required this.displayName,
    required this.price,
    required this.containsLabel,
    required this.tierIndex,
  });
}

// ============================================================
// PERCENTAGE INPUT FORMATTER (0-100)
// ============================================================
class _PercentageInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    
    final double? value = double.tryParse(newValue.text);
    if (value == null) {
      return oldValue;
    }
    
    // Limit to 100%
    if (value > 100) {
      return const TextEditingValue(
        text: '100',
        selection: TextSelection.collapsed(offset: 3),
      );
    }
    
    // Prevent negative values
    if (value < 0) {
      return const TextEditingValue(
        text: '0',
        selection: TextSelection.collapsed(offset: 1),
      );
    }
    
    return newValue;
  }
}