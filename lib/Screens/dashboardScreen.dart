import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/Screens/bulk_import_screen.dart';
import 'package:medical_app/Screens/customer_ledger_screen.dart';
import 'package:medical_app/Screens/customer_list_screen.dart';
import 'package:medical_app/Screens/customer_payment_screen.dart';
import 'package:medical_app/Screens/items_screen.dart';
import 'package:medical_app/Screens/master_data_screen.dart';
import 'package:medical_app/Screens/purchase_entry_screen.dart';
import 'package:medical_app/Screens/purchase_list_screen.dart';
import 'package:medical_app/Screens/settings_screen.dart';
import 'package:medical_app/Screens/supplier_payment_by_invoice_screen.dart';
import 'package:medical_app/Screens/supplier_screen.dart';
import 'package:medical_app/reports/customer_ledger_screen.dart';
import 'package:medical_app/reports/supplier_ledger_report.dart';
import 'package:medical_app/reports/supplier_ledger_report_invoice_based.dart'
    hide SupplierPaymentByInvoiceScreen;
import 'package:medical_app/services/database_helper.dart';
import 'package:medical_app/Screens/addItemScreen.dart';
import 'package:medical_app/Screens/add_customer_screen.dart';
import 'package:medical_app/Screens/sales_screen.dart';
import 'package:medical_app/reports/inventory_screen.dart';
import 'package:medical_app/Screens/expense_entry_screen.dart';
import 'package:medical_app/Screens/reports_screen.dart';
import 'package:medical_app/Screens/sale_history_screen.dart';

class PremiumDashboardScreen extends StatefulWidget {
  const PremiumDashboardScreen({super.key});

  @override
  State<PremiumDashboardScreen> createState() =>
      _Pr9yMnTm4NSzvG9rrwjM2ec8xZgh1cafXH8();
}

class _Pr9yMnTm4NSzvG9rrwjM2ec8xZgh1cafXH8 extends State<PremiumDashboardScreen> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;
  Key _refreshKey = UniqueKey();

  // Track which categories are expanded
  final Map<String, bool> _expandedCategories = {
    'Dashboard': true,
    'Inventory': false,
    'Customers': false,
    'Sales': false,
    'Suppliers': false,
    'Purchases': false,
    'Accounts': false,
    'Reports': false,
    'System': false,
  };

  /*
   * SCREEN INDEX MAP (Fixed - no duplicates):
   * 0  = Dashboard
   * 1  = Inventory
   * 2  = Add Item
   * 3  = Items List
   * 4  = Customer Add (CustomerListScreen)
   * 5  = New Sale
   * 6  = Sale History
   * 7  = Supplier List
   * 8  = Purchase Entry
   * 9  = Purchase History        ← was conflicting with index 9 "Payments"
   * 10 = Supplier Payment
   * 11 = Expenses
   * 12 = Supplier Ledger
   * 13 = Customer Payment        ← CustomerPaymentByInvoiceScreen
   * 14 = Customer Ledger
   * 15 = Reports
   * 16 = Master Data
   * 17 = Bulk Upload
   * 18 = Company Settings
   * 19 = Add Customer Screen     ← separate from CustomerListScreen
   */

  final List<Map<String, dynamic>> sidebarCategories = [
    {
      'category': 'Dashboard',
      'icon': Icons.grid_view_outlined,
      'activeIcon': Icons.grid_view,
      'items': [
        {
          'title': 'Dashboard',
          'icon': Icons.grid_view_outlined,
          'activeIcon': Icons.grid_view,
          'screenIndex': 0,
        },
      ],
    },
    {
      'category': 'Inventory',
      'icon': Icons.inventory_2_outlined,
      'activeIcon': Icons.inventory_2,
      'items': [
        {
          'title': 'Inventory',
          'icon': Icons.inventory_2_outlined,
          'activeIcon': Icons.inventory_2,
          'screenIndex': 1,
        },
        {
          'title': 'Add Item',
          'icon': Icons.add_circle_outline,
          'activeIcon': Icons.add_circle,
          'screenIndex': 2,
        },
        {
          'title': 'Items List',
          'icon': Icons.list_alt_outlined,
          'activeIcon': Icons.list_alt,
          'screenIndex': 3,
        },
      ],
    },
    {
      'category': 'Customers',
      'icon': Icons.people_outline,
      'activeIcon': Icons.people,
      'items': [
        {
          'title': 'Customer List',  // Fixed typo: "Cusomer Add" → "Customer List"
          'icon': Icons.people_outline,
          'activeIcon': Icons.people,
          'screenIndex': 4,
        },
        {
          'title': 'Customer Payment',
          'icon': Icons.payments_outlined,
          'activeIcon': Icons.payments,
          'screenIndex': 13, // CustomerPaymentByInvoiceScreen
        },
        {
          'title': 'Customer Ledger',
          'icon': Icons.book_outlined,
          'activeIcon': Icons.book,
          'screenIndex': 14,
        },
      ],
    },
    {
      'category': 'Sales',
      'icon': Icons.point_of_sale_outlined,
      'activeIcon': Icons.point_of_sale,
      'items': [
        {
          'title': 'New Sale',
          'icon': Icons.point_of_sale_outlined,
          'activeIcon': Icons.point_of_sale,
          'screenIndex': 5,
        },
        {
          'title': 'Sale History',
          'icon': Icons.history_outlined,
          'activeIcon': Icons.history,
          'screenIndex': 6,
        },
      ],
    },
    {
      'category': 'Suppliers',
      'icon': Icons.local_shipping_outlined,
      'activeIcon': Icons.local_shipping,
      'items': [
        {
          'title': 'Supplier List',
          'icon': Icons.local_shipping_outlined,
          'activeIcon': Icons.local_shipping,
          'screenIndex': 7,
        },
        {
          'title': 'Supplier Payment',
          'icon': Icons.payments_outlined,
          'activeIcon': Icons.payments,
          'screenIndex': 10,
        },
        {
          'title': 'Supplier Ledger',
          'icon': Icons.book_outlined,
          'activeIcon': Icons.book,
          'screenIndex': 12,
        },
      ],
    },
    {
      'category': 'Purchases',
      'icon': Icons.shopping_cart_outlined,
      'activeIcon': Icons.shopping_cart,
      'items': [
        {
          'title': 'Purchase Entry',
          'icon': Icons.shopping_cart_outlined,
          'activeIcon': Icons.shopping_cart,
          'screenIndex': 8,
        },
        {
          'title': 'Purchase History',
          'icon': Icons.history_outlined,
          'activeIcon': Icons.history,
          'screenIndex': 9, // Fixed: unique index now
        },
      ],
    },
    {
      'category': 'Accounts',
      'icon': Icons.account_balance_wallet_outlined,
      'activeIcon': Icons.account_balance_wallet,
      'items': [
        // Removed duplicate "Payments" that had screenIndex: 9
        // Supplier Payment is already under Suppliers (screenIndex: 10)
        // Customer Payment is already under Customers (screenIndex: 13)
        {
          'title': 'Expenses',
          'icon': Icons.account_balance_wallet_outlined,
          'activeIcon': Icons.account_balance_wallet,
          'screenIndex': 11,
        },
      ],
    },
    {
      'category': 'Reports',
      'icon': Icons.assessment_outlined,
      'activeIcon': Icons.assessment,
      'items': [
        {
          'title': 'Reports',
          'icon': Icons.assessment_outlined,
          'activeIcon': Icons.assessment,
          'screenIndex': 15,
        },
      ],
    },
    {
      'category': 'System',
      'icon': Icons.settings_outlined,
      'activeIcon': Icons.settings,
      'items': [
        {
          'title': 'Master Data',
          'icon': Icons.storage_outlined,
          'activeIcon': Icons.storage,
          'screenIndex': 16,
        },
        {
          'title': 'Bulk Upload',
          'icon': Icons.upload_file_outlined,
          'activeIcon': Icons.upload_file,
          'screenIndex': 17,
        },
        {
          'title': 'Company Settings',
          'icon': Icons.settings_outlined,
          'activeIcon': Icons.settings,
          'screenIndex': 18,
        },
      ],
    },
  ];

  /// Returns the title for the currently selected screen
  String get _currentTitle {
    for (final cat in sidebarCategories) {
      for (final item in cat['items'] as List) {
        if (item['screenIndex'] == _selectedIndex) {
          return item['title'] as String;
        }
      }
    }
    return 'Dashboard';
  }

  void _refreshApp() {
    setState(() {
      _refreshKey = UniqueKey();
    });
  }

  /// FIXED: Each index maps to exactly ONE screen with no gaps or duplicates
  List<Widget> get _screens => [
        // 0 - Dashboard
        PremiumDashboardHomeContent(key: _refreshKey),
        // 1 - Inventory
        InventoryScreen(key: _refreshKey),
        // 2 - Add Item
        AddItemScreen(key: _refreshKey),
        // 3 - Items List
        ItemsScreen(key: _refreshKey),
        // 4 - Customer List
        CustomerListScreen(key: _refreshKey),
        // 5 - New Sale
        SaleScreenDesktop(key: _refreshKey),
        // 6 - Sale History
        SaleHistoryScreen(key: _refreshKey),
        // 7 - Supplier List
        SuppliersScreen(key: _refreshKey),
        // 8 - Purchase Entry
        PurchaseScreenDesktop(key: _refreshKey),
        // 9 - Purchase History (FIXED: was conflicting before)
        PurchaseListScreen(key: _refreshKey),
        // 10 - Supplier Payment
        SupplierPaymentByInvoiceScreen(key: _refreshKey),
        // 11 - Expenses
        ExpenseEntryScreen(key: _refreshKey),
        // 12 - Supplier Ledger
        SupplierLedgerReport(key: _refreshKey),
        // 13 - Customer Payment By Invoice
        CustomerPaymentByInvoiceScreen(key: _refreshKey),
        // 14 - Customer Ledger
        CustomerLedgerScreen(key: _refreshKey),
        // 15 - Reports
        ReportsScreen(key: _refreshKey),
        // 16 - Master Data
        MasterDataScreen(key: _refreshKey),
        // 17 - Bulk Import
        BulkImportScreen(key: _refreshKey),
        // 18 - Company Settings
        CompanySettingsScreen(key: _refreshKey),
      ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWideScreen = width > 950;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      drawer: isWideScreen ? null : _buildMobileDrawer(),
      body: Row(
        children: [
          if (isWideScreen)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isSidebarExpanded ? 260 : 72,
              child: _buildSidebar(),
            ),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(isWideScreen),
                Expanded(child: _screens[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── TOP BAR ──────────────────────────────────────────
  Widget _buildTopBar(bool isWideScreen) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        children: [
          if (isWideScreen)
            IconButton(
              icon: Icon(
                _isSidebarExpanded ? Icons.menu_open : Icons.menu,
                color: const Color(0xFF6B7280),
              ),
              onPressed: () =>
                  setState(() => _isSidebarExpanded = !_isSidebarExpanded),
            ),
          if (!isWideScreen)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Color(0xFF6B7280)),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          const SizedBox(width: 8),
          Text(
            _currentTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const Spacer(),
          _buildRefreshButton(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: Color(0xFF6B7280),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFF2563EB),
                  child: Text(
                    'MS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Admin',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _refreshApp,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF2563EB).withOpacity(0.2),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 6),
              Text(
                'Refresh',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SIDEBAR ───────────────────────────────────────────
  Widget _buildSidebar() {
    final bool narrow = !_isSidebarExpanded;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Logo / Header
          Container(
            height: 64,
            padding: EdgeInsets.symmetric(horizontal: narrow ? 0 : 20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
            ),
            child: narrow
                ? const Center(
                    child: Icon(
                      Icons.medical_services,
                      color: Color(0xFF2563EB),
                      size: 28,
                    ),
                  )
                : const Row(
                    children: [
                      SizedBox(width: 12),
                      Text(
                        'Easy POS',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),

          // Category Menu
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: narrow ? 8 : 12,
                vertical: 12,
              ),
              itemCount: sidebarCategories.length,
              itemBuilder: (context, index) {
                final category = sidebarCategories[index];
                return _buildCategoryTile(category, narrow);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(Map<String, dynamic> category, bool narrow) {
    final String catName = category['category'] as String;
    final List items = category['items'] as List;
    final bool isExpanded = _expandedCategories[catName] ?? false;

    // Check if any child is selected
    final bool hasActiveChild = items.any(
      (item) => item['screenIndex'] == _selectedIndex,
    );

    // Narrow mode: just show icons for each item
    if (narrow) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Tooltip(
              message: catName,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Center(
                  child: Icon(
                    category['icon'] as IconData,
                    color: hasActiveChild
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFD1D5DB),
                    size: 14,
                  ),
                ),
              ),
            ),
          ),
          ...items.map((item) {
            final bool isSelected = item['screenIndex'] == _selectedIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Tooltip(
                message: item['title'] as String,
                child: InkWell(
                  onTap: () => setState(
                    () => _selectedIndex = item['screenIndex'] as int,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFEFF6FF)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        isSelected
                            ? item['activeIcon'] as IconData
                            : item['icon'] as IconData,
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF6B7280),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      );
    }

    // Expanded mode: accordion style
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _expandedCategories[catName] = !isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: hasActiveChild
                  ? const Color(0xFFEFF6FF)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isExpanded || hasActiveChild
                      ? category['activeIcon'] as IconData
                      : category['icon'] as IconData,
                  color: hasActiveChild
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF6B7280),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    catName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: hasActiveChild
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF374151),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: hasActiveChild
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(left: 16, top: 2, bottom: 4),
            child: Column(
              children: items.map((item) {
                final bool isSelected =
                    item['screenIndex'] == _selectedIndex;
                return _buildSubMenuItem(item, isSelected);
              }).toList(),
            ),
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        const SizedBox(height: 2),
      ],
    );
  }

  Widget _buildSubMenuItem(Map<String, dynamic> item, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () =>
            setState(() => _selectedIndex = item['screenIndex'] as int),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            color:
                isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(
                    color: const Color(0xFF2563EB).withOpacity(0.2))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected
                    ? item['activeIcon'] as IconData
                    : item['icon'] as IconData,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF9CA3AF),
                size: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  item['title'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: _buildSidebar(),
    );
  }
}

// ────────────────────────────────────────────────
//               HOME CONTENT
// ────────────────────────────────────────────────

class PremiumDashboardHomeContent extends StatefulWidget {
  const PremiumDashboardHomeContent({super.key});

  @override
  State<PremiumDashboardHomeContent> createState() =>
      _PremiumDashboardHomeContentState();
}

class _PremiumDashboardHomeContentState
    extends State<PremiumDashboardHomeContent> {
  double todaySales = 0;
  int todayOrders = 0;
  int totalCustomers = 0;
  int lowStockItems = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    final db = DatabaseHelper.instance;
    todaySales = await db.getTodaySalesTotal();
    todayOrders = await db.getTodayOrdersCount();
    totalCustomers = await db.getTotalCustomers();
    lowStockItems = await db.getLowStockCount(threshold: 10);
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2563EB)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeSection(),
          const SizedBox(height: 24),
          _buildStatsGrid(),
          const SizedBox(height: 24),
          _buildQuickActions(context),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Welcome back',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      {
        'title': "Today's Sales",
        'value': 'Rs ${NumberFormat('#,###').format(todaySales)}',
        'icon': Icons.trending_up,
        'color': const Color(0xFF10B981),
        'bgColor': const Color(0xFFECFDF5),
      },
      {
        'title': 'Total Orders',
        'value': todayOrders.toString(),
        'icon': Icons.shopping_bag_outlined,
        'color': const Color(0xFF2563EB),
        'bgColor': const Color(0xFFEFF6FF),
      },
      {
        'title': 'Customers',
        'value': totalCustomers.toString(),
        'icon': Icons.people_outline,
        'color': const Color(0xFF8B5CF6),
        'bgColor': const Color(0xFFF5F3FF),
      },
      {
        'title': 'Low Stock Items',
        'value': lowStockItems.toString(),
        'icon': Icons.warning_amber_outlined,
        'color': const Color(0xFFF59E0B),
        'bgColor': const Color(0xFFFEF3C7),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 1200
            ? 4
            : constraints.maxWidth > 800
                ? 2
                : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) => _buildStatCard(stats[index]),
        );
      },
    );
  }

  Widget _buildStatCard(Map<String, dynamic> stat) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: stat['bgColor'],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(stat['icon'], color: stat['color'], size: 20),
          ),
          const Spacer(),
          Text(
            stat['value'],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            stat['title'],
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {
        'title': 'New Sale',
        'description': 'Create a new invoice',
        'icon': Icons.point_of_sale,
        'screen': const SaleScreenDesktop(),
        'color': const Color(0xFF2563EB),
      },
      {
        'title': 'Add Product',
        'description': 'Add item to inventory',
        'icon': Icons.add_box_outlined,
        'screen': const AddItemScreen(),
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'New Customer',
        'description': 'Register new customer',
        'icon': Icons.person_add_outlined,
        'screen': const AddCustomerScreen(),
        'color': const Color(0xFF8B5CF6),
      },
      {
        'title': 'View Reports',
        'description': 'Analytics and insights',
        'icon': Icons.assessment_outlined,
        'screen': const ReportsScreen(),
        'color': const Color(0xFFF59E0B),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossCount = constraints.maxWidth > 1200
                ? 4
                : constraints.maxWidth > 800
                    ? 2
                    : 1;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 3.5,
              ),
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final action = actions[index];
                return InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => action['screen'] as Widget,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (action['color'] as Color)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            action['icon'] as IconData,
                            color: action['color'] as Color,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                action['title'] as String,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                action['description'] as String,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}