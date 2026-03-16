import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/Screens/bulk_import_screen.dart';
import 'package:medical_app/Screens/items_screen.dart';
import 'package:medical_app/Screens/master_data_screen.dart';
import 'package:medical_app/Screens/purchase_entry_screen.dart';
import 'package:medical_app/Screens/settings_screen.dart';
import 'package:medical_app/Screens/supplier_screen.dart';
import 'package:medical_app/services/database_helper.dart';
import 'package:medical_app/Screens/addItemScreen.dart';
import 'package:medical_app/Screens/add_customer_screen.dart';
import 'package:medical_app/Screens/sales_screen.dart';
import 'package:medical_app/reports/inventory_screen.dart';
import 'package:medical_app/Screens/expense_entry_screen.dart';
import 'package:medical_app/Screens/reports_screen.dart';
import 'package:medical_app/Screens/sale_history_screen.dart';
import 'package:medical_app/Screens/daily_closing_screen.dart';

class PremiumDashboardScreen extends StatefulWidget {
  const PremiumDashboardScreen({super.key});

  @override
  State<PremiumDashboardScreen> createState() => _PremiumDashboardScreenState();
}

class _PremiumDashboardScreenState extends State<PremiumDashboardScreen> {
int _selectedIndex = 0;
  bool _isSidebarExpanded = true;

  final List<Map<String, dynamic>> sidebarItems = [
    {'title': 'Dashboard', 'icon': Icons.dashboard_outlined, 'activeIcon': Icons.dashboard_rounded},
    {'title': 'Inventory', 'icon': Icons.inventory_2_outlined, 'activeIcon': Icons.inventory_2_rounded},
    {'title': 'Add Item', 'icon': Icons.add_box_outlined, 'activeIcon': Icons.add_box_rounded},
    {'title': 'ITEMs', 'icon': Icons.add, 'activeIcon': Icons.add_box_rounded},
    {'title': 'Customers', 'icon': Icons.people_outline_rounded, 'activeIcon': Icons.people_rounded},
    {'title': 'Suppliers', 'icon': Icons.local_shipping_outlined, 'activeIcon': Icons.local_shipping_rounded},
    {'title': 'Sales', 'icon': Icons.point_of_sale_outlined, 'activeIcon': Icons.point_of_sale_rounded},
    {'title': 'Receipts', 'icon': Icons.receipt_long_outlined, 'activeIcon': Icons.receipt_long_rounded},
    {'title': 'Payments', 'icon': Icons.payment_outlined, 'activeIcon': Icons.payment_rounded},
    {'title': 'Purchases', 'icon': Icons.shopping_cart_outlined, 'activeIcon': Icons.shopping_cart_rounded},
    {'title': 'Expenses', 'icon': Icons.money_off_outlined, 'activeIcon': Icons.money_off_rounded},
    {'title': 'Reports', 'icon': Icons.bar_chart_outlined, 'activeIcon': Icons.bar_chart_rounded},
    {'title': 'Sale History', 'icon': Icons.history_outlined, 'activeIcon': Icons.history_rounded},
    {'title': 'Daily Closing', 'icon': Icons.account_balance_wallet_outlined, 'activeIcon': Icons.account_balance_wallet_rounded},
    {'title': 'Settings', 'icon': Icons.settings_outlined, 'activeIcon': Icons.settings_rounded},
    {'title': 'Master Data', 'icon': Icons.account_tree_sharp, 'activeIcon': Icons.account_tree_rounded},
    {'title': 'Bulk Upload', 'icon': Icons.upload_file_outlined, 'activeIcon': Icons.upload_file_rounded},
  ];

  final List<Widget> _screens = [
    const PremiumDashboardHomeContent(),       // 0 - Dashboard
    const InventoryScreen(),                    // 1 - Inventory
    const AddItemScreen(),                      // 2 - Add Item
    const ItemsScreen(),                      // 2 - Add Item
    const AddCustomerScreen(),                  // 3 - Customers
    const SuppliersScreen(),                    // 4 - Suppliers
    const SaleScreenDesktop(),                  // 5 - Sales
    const Center(child: Text('Receipts - Coming Soon', style: TextStyle(fontSize: 16, color: Color(0xFF64748B)))),  // 6 - Receipts
    const Center(child: Text('Payments - Coming Soon', style: TextStyle(fontSize: 16, color: Color(0xFF64748B)))),  // 7 - Payments
    const PurchaseScreenDesktop(),              // 8 - Purchases
    const ExpenseEntryScreen(),                 // 9 - Expenses
    const ReportsScreen(),                      // 10 - Reports
    const SaleHistoryScreen(),                  // 11 - Sale History
    const DailyClosingScreen(),                 // 12 - Daily Closing
    const SettingsScreen(),                     // 13 - Settings (ADD THIS)
    const MasterDataScreen(),                   // 14 - Master Data
    const BulkImportScreen(),                   // 14 - Bulk Upload (REUSE MasterDataScreen for now, can create separate screen later)
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWideScreen = width > 950;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: isWideScreen ? null : _buildMobileDrawer(),
      body: Row(
        children: [
          if (isWideScreen)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: _isSidebarExpanded ? 240 : 68,
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
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (isWideScreen)
            _buildIconButton(
              icon: _isSidebarExpanded ? Icons.menu_open_rounded : Icons.menu_rounded,
              onTap: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
              tooltip: _isSidebarExpanded ? 'Collapse' : 'Expand',
            ),
          if (!isWideScreen)
            _buildIconButton(
              icon: Icons.menu_rounded,
              onTap: () => Scaffold.of(context).openDrawer(),
            ),
          const SizedBox(width: 12),
          Text(
            sidebarItems[_selectedIndex]['title'],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          // Search bar
          Container(
            width: 200,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildIconButton(icon: Icons.notifications_none_rounded, badge: 3),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Text(
                      'MS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Admin',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey.shade600),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    VoidCallback? onTap,
    String? tooltip,
    int? badge,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              Center(child: Icon(icon, size: 20, color: const Color(0xFF64748B))),
              if (badge != null)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badge.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                    ),
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
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo Header
          Container(
            height: 56,
            padding: EdgeInsets.symmetric(horizontal: narrow ? 0 : 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: narrow ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                // Container(
                //   width: 32,
                //   height: 32,
                //   decoration: BoxDecoration(
                //     gradient: const LinearGradient(
                //       colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                //     ),
                //     borderRadius: BorderRadius.circular(8),
                //   ),
                //   // child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 18),
                // ),
                if (!narrow) ...[
                  const SizedBox(width: 12),
                  const Text(
                    'Madina Medical',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  // const Spacer(),
                  // Container(
                  //   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  //   decoration: BoxDecoration(
                  //     color: const Color(0xFF22C55E).withOpacity(0.2),
                  //     borderRadius: BorderRadius.circular(4),
                  //   ),
                  //   child: const Text(
                  //     'PRO',
                  //     style: TextStyle(
                  //       color: Color(0xFF22C55E),
                  //       fontSize: 9,
                  //       fontWeight: FontWeight.w700,
                  //       letterSpacing: 0.5,
                  //     ),
                  //   ),
                  // ),
                ],
              ],
            ),
          ),
          
          // Menu Items
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: narrow ? 8 : 12, vertical: 12),
              itemCount: sidebarItems.length,
              itemBuilder: (context, index) {
                final item = sidebarItems[index];
                final isSelected = index == _selectedIndex;

                // Add separator before Settings
                if (index == sidebarItems.length - 1) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: const Color(0xFF334155), height: 1),
                      ),
                      _buildMenuItem(item, isSelected, narrow),
                    ],
                  );
                }

                return _buildMenuItem(item, isSelected, narrow);
              },
            ),
          ),

          // Bottom user section
          if (!narrow)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('MS', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Medical Store',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'admin@store.com',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.logout_rounded, size: 16, color: Colors.grey.shade500),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(Map<String, dynamic> item, bool isSelected, bool narrow) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _selectedIndex = sidebarItems.indexOf(item)),
          hoverColor: const Color(0xFF1E293B),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: narrow ? 0 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3), width: 1)
                  : null,
            ),
            child: narrow
                ? Center(
                    child: Icon(
                      isSelected ? item['activeIcon'] : item['icon'],
                      color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                      size: 20,
                    ),
                  )
                : Row(
                    children: [
                      Icon(
                        isSelected ? item['activeIcon'] : item['icon'],
                        color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item['title'],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1),
                            letterSpacing: -0.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item['title'] == 'Inventory')
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '12',
                            style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
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
  State<PremiumDashboardHomeContent> createState() => _PremiumDashboardHomeContentState();
}

class _PremiumDashboardHomeContentState extends State<PremiumDashboardHomeContent> {
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
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF3B82F6)),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 20),
          _buildStatsGrid(context),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildQuickActions(context)),
              const SizedBox(width: 20),
              Expanded(child: _buildRecentActivity()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'MADINA MEDICAL STORE',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // const Text('👋', style: TextStyle(fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                // const SizedBox(height: 16),
                // Row(
                //   children: [
                //     _buildWelcomeChip(Icons.trending_up, 'Sales +12%'),
                //     const SizedBox(width: 8),
                //     _buildWelcomeChip(Icons.people_outline, '+5 Customers'),
                //   ],
                // ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.analytics_outlined, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    final stats = [
      {
        'title': "Today's Sales",
        'value': 'Rs ${NumberFormat('#,###').format(todaySales)}',
        'change': '+12.5%',
        'isPositive': true,
        'icon': Icons.account_balance_wallet_outlined,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'Orders',
        'value': todayOrders.toString(),
        'change': '+8',
        'isPositive': true,
        'icon': Icons.shopping_bag_outlined,
        'color': const Color(0xFF3B82F6),
      },
      {
        'title': 'Customers',
        'value': totalCustomers.toString(),
        'change': '+5',
        'isPositive': true,
        'icon': Icons.people_outline_rounded,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'title': 'Low Stock',
        'value': lowStockItems.toString(),
        'change': 'Items',
        'isPositive': false,
        'icon': Icons.warning_amber_rounded,
        'color': const Color(0xFFF59E0B),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 2);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.2,
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final s = stats[index];
            return _buildStatCard(s);
          },
        );
      },
    );
  }

  Widget _buildStatCard(Map<String, dynamic> s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (s['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(s['icon'] as IconData, color: s['color'] as Color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  s['title'] as String,
                  style: const TextStyle(
                    fontSize: 8,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s['value'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (s['isPositive'] as bool)
                  ? const Color(0xFF10B981).withOpacity(0.1)
                  : const Color(0xFFF59E0B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (s['isPositive'] as bool)
                  const Icon(Icons.arrow_upward, size: 10, color: Color(0xFF10B981)),
                Text(
                  s['change'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: (s['isPositive'] as bool) ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {'title': 'New Sale', 'subtitle': 'Create invoice', 'icon': Icons.add_shopping_cart_outlined, 'screen': const SaleScreenDesktop(), 'color': const Color(0xFF3B82F6)},
      {'title': 'Add Product', 'subtitle': 'Add to inventory', 'icon': Icons.add_box_outlined, 'screen': const AddItemScreen(), 'color': const Color(0xFF10B981)},
      {'title': 'New Customer', 'subtitle': 'Register customer', 'icon': Icons.person_add_outlined, 'screen': const AddCustomerScreen(), 'color': const Color(0xFF8B5CF6)},
      {'title': 'View Reports', 'subtitle': 'Analytics & data', 'icon': Icons.bar_chart_outlined, 'screen': const ReportsScreen(), 'color': const Color(0xFFF59E0B)},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              // TextButton(
              //   onPressed: () {},
              //   style: TextButton.styleFrom(
              //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              //     minimumSize: Size.zero,
              //     tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              //   ),
              //   child: const Text('See all', style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6))),
              // ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.8,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final a = actions[index];
              return _QuickActionCard(
                title: a['title'] as String,
                subtitle: a['subtitle'] as String,
                icon: a['icon'] as IconData,
                color: a['color'] as Color,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => a['screen'] as Widget)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final activities = [
      {'title': 'Sale #1234', 'subtitle': 'Rs 2,500', 'time': '2 min ago', 'icon': Icons.receipt_outlined, 'color': const Color(0xFF10B981)},
      {'title': 'New Customer', 'subtitle': 'John Doe', 'time': '15 min ago', 'icon': Icons.person_add_outlined, 'color': const Color(0xFF3B82F6)},
      {'title': 'Low Stock', 'subtitle': 'Paracetamol', 'time': '1 hour ago', 'icon': Icons.warning_amber_rounded, 'color': const Color(0xFFF59E0B)},
      {'title': 'Purchase', 'subtitle': 'Rs 15,000', 'time': '2 hours ago', 'icon': Icons.shopping_cart_outlined, 'color': const Color(0xFF8B5CF6)},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('View all', style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...activities.map((a) => _buildActivityItem(a)).toList(),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> a) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (a['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a['title'] as String,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
                ),
                Text(
                  a['subtitle'] as String,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Text(
            a['time'] as String,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isHovered ? widget.color.withOpacity(0.05) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovered ? widget.color.withOpacity(0.3) : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.icon, color: widget.color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: _isHovered ? widget.color : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}