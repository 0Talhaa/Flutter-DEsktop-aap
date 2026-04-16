import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/Screens/bulk_import_screen.dart';
import 'package:medical_app/Screens/customer_list_screen.dart';
import 'package:medical_app/Screens/customer_payment_screen.dart';
import 'package:medical_app/Screens/items_screen.dart';
import 'package:medical_app/Screens/master_data_screen.dart';
import 'package:medical_app/Screens/purchase_entry_screen.dart';
import 'package:medical_app/Screens/settings_screen.dart';
import 'package:medical_app/Screens/supplier_payment_by_invoice_screen.dart';
import 'package:medical_app/Screens/supplier_screen.dart';
import 'package:medical_app/reports/supplier_ledger_report_invoice_based.dart';
import 'package:medical_app/services/database_helper.dart';
import 'package:medical_app/Screens/addItemScreen.dart';
import 'package:medical_app/Screens/add_customer_screen.dart';
import 'package:medical_app/Screens/sales_screen.dart';
import 'package:medical_app/reports/inventory_screen.dart';
import 'package:medical_app/Screens/expense_entry_screen.dart';
import 'package:medical_app/Screens/reports_screen.dart';
import 'package:medical_app/Screens/sale_history_screen.dart';
// import 'package:medical_app/Screens/daily_closing_screen.dart';

class PremiumDashboardScreen extends StatefulWidget {
  const PremiumDashboardScreen({super.key});

  @override
  State<PremiumDashboardScreen> createState() => _PremiumDashboardScreenState();
}

class _PremiumDashboardScreenState extends State<PremiumDashboardScreen> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;
  Key _refreshKey = UniqueKey(); // Add this key for refreshing

  final List<Map<String, dynamic>> sidebarItems = [
    // DASHBOARD
    {
      'title': 'Dashboard',
      'icon': Icons.grid_view_outlined,
      'activeIcon': Icons.grid_view
    },

    // INVENTORY MANAGEMENT
    {
      'title': 'Inventory',
      'icon': Icons.inventory_2_outlined,
      'activeIcon': Icons.inventory_2
    },
    {
      'title': 'Add Item',
      'icon': Icons.add_circle_outline,
      'activeIcon': Icons.add_circle
    },
    {
      'title': 'Items',
      'icon': Icons.list_alt_outlined,
      'activeIcon': Icons.list_alt
    },

    // CUSTOMER MANAGEMENT
    {
      'title': 'Customers',
      'icon': Icons.people_outline,
      'activeIcon': Icons.people
    },

    // SALES MANAGEMENT
    {
      'title': 'Sales',
      'icon': Icons.point_of_sale_outlined,
      'activeIcon': Icons.point_of_sale
    },
    {
      'title': 'Sale History',
      'icon': Icons.history_outlined,
      'activeIcon': Icons.history
    },

    // SUPPLIER MANAGEMENT
    {
      'title': 'Suppliers',
      'icon': Icons.local_shipping_outlined,
      'activeIcon': Icons.local_shipping
    },

    // PURCHASE MANAGEMENT
    {
      'title': 'Purchases',
      'icon': Icons.shopping_cart_outlined,
      'activeIcon': Icons.shopping_cart
    },

    // ACCOUNTS & PAYMENTS
    {
      'title': 'Payments',
      'icon': Icons.payments_outlined,
      'activeIcon': Icons.payments
    },
    {
      'title': 'Supplier Payment',
      'icon': Icons.payments_outlined,
      'activeIcon': Icons.payments
    },
    {
      'title': 'Expenses',
      'icon': Icons.account_balance_wallet_outlined,
      'activeIcon': Icons.account_balance_wallet
    },
    {
      'title': 'Supplier Ledger',
      'icon': Icons.book_outlined,
      'activeIcon': Icons.book
    },

    // REPORTS & ANALYTICS
    {
      'title': 'Reports',
      'icon': Icons.assessment_outlined,
      'activeIcon': Icons.assessment
    },

    // SYSTEM / SETTINGS
    {
      'title': 'Master Data',
      'icon': Icons.storage_outlined,
      'activeIcon': Icons.storage
    },
    {
      'title': 'Bulk Upload',
      'icon': Icons.upload_file_outlined,
      'activeIcon': Icons.upload_file
    },
    {
      'title': 'Company Settings',
      'icon': Icons.settings_outlined,
      'activeIcon': Icons.settings
    },
  ];

  // Method to refresh the entire app
  void _refreshApp() {
    setState(() {
      _refreshKey = UniqueKey();
    });
  }

  List<Widget> get _screens => [
        // Dashboard
        PremiumDashboardHomeContent(key: _refreshKey),

        // Inventory
        InventoryScreen(key: _refreshKey),
        AddItemScreen(key: _refreshKey),
        ItemsScreen(key: _refreshKey),

        // Customers
        CustomerListScreen(key: _refreshKey),

        // Sales
        SaleScreenDesktop(key: _refreshKey),
        SaleHistoryScreen(key: _refreshKey),

        // Suppliers
        SuppliersScreen(key: _refreshKey),

        // Purchases
        PurchaseScreenDesktop(key: _refreshKey),

        // Accounts
        CustomerListScreen(key: _refreshKey, forPayment: true),
        SupplierPaymentByInvoiceScreen(key: _refreshKey),
        ExpenseEntryScreen(key: _refreshKey),
        SupplierLedgerReportInvoiceBased(key: _refreshKey),

        // Reports
        ReportsScreen(key: _refreshKey),

        // System
        MasterDataScreen(key: _refreshKey),
        BulkImportScreen(key: _refreshKey),
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
            sidebarItems[_selectedIndex]['title'],
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const Spacer(),

          // REFRESH BUTTON - Added here
          _buildRefreshButton(),

          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: Color(0xFF6B7280)),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF2563EB),
                  child: const Text(
                    'MS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
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

  // Refresh Button Widget
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.refresh,
                color: Color(0xFF2563EB),
                size: 20,
              ),
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
          // Logo Header
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
                : Row(
                    children: const [
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

          // Menu Items
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: narrow ? 12 : 16,
                vertical: 16,
              ),
              itemCount: sidebarItems.length,
              itemBuilder: (context, index) {
                final item = sidebarItems[index];
                final isSelected = index == _selectedIndex;

                // Divider before Settings
                if (index == 14) {
                  return Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: Color(0xFFE5E7EB), height: 1),
                      ),
                      _buildMenuItem(item, isSelected, narrow),
                    ],
                  );
                }

                return _buildMenuItem(item, isSelected, narrow);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
      Map<String, dynamic> item, bool isSelected, bool narrow) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () =>
            setState(() => _selectedIndex = sidebarItems.indexOf(item)),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: narrow ? 0 : 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: narrow
              ? Center(
                  child: Icon(
                    isSelected ? item['activeIcon'] : item['icon'],
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF6B7280),
                    size: 22,
                  ),
                )
              : Row(
                  children: [
                    Icon(
                      isSelected ? item['activeIcon'] : item['icon'],
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF6B7280),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item['title'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF374151),
                        ),
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
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
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
            ? 3
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
            childAspectRatio: 2.8,
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
            child: Icon(
              stat['icon'],
              color: stat['color'],
              size: 20,
            ),
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
        'screen': const CustomerListScreen(),
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
                        builder: (_) => action['screen'] as Widget),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (action['color'] as Color).withOpacity(0.1),
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
