// lib/screens/reports/reports_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/reports/customer_ledger_screen.dart';
import 'package:medical_app/reports/customer_wise_sale_report.dart';
import 'package:medical_app/reports/inventory_ledger_report.dart';
import 'package:medical_app/reports/item_wise_sale_report.dart';
import 'package:medical_app/reports/profit_loss_report.dart';
import 'package:medical_app/reports/purchase_report.dart';
import 'package:medical_app/reports/sale_report.dart';
import 'package:medical_app/reports/stock_report.dart';
import 'package:medical_app/reports/supplier_ledger_report.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  String selectedReport = 'customer_ledger';
  String selectedCategory = 'all';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final currencyFormat = NumberFormat.currency(locale: 'en_PK', symbol: 'Rs. ', decimalDigits: 0);

  // Report Categories
  final List<ReportCategory> categories = [
    ReportCategory(id: 'all', name: 'All', icon: Icons.apps, color: const Color(0xFF6366F1)),
    ReportCategory(id: 'financial', name: 'Financial', icon: Icons.account_balance, color: const Color(0xFF10B981)),
    ReportCategory(id: 'sales', name: 'Sales', icon: Icons.trending_up, color: const Color(0xFF3B82F6)),
    ReportCategory(id: 'inventory', name: 'Inventory', icon: Icons.inventory_2, color: const Color(0xFFF59E0B)),
    ReportCategory(id: 'purchases', name: 'Purchases', icon: Icons.shopping_cart, color: const Color(0xFF8B5CF6)),
    ReportCategory(id: 'parties', name: 'Parties', icon: Icons.people, color: const Color(0xFFEC4899)),
  ];

  // All Reports
  final List<ReportItem> allReports = [
    ReportItem(
      id: 'customer_ledger',
      name: 'Customer Ledger',
      description: 'Customer transaction history & balances',
      icon: Icons.account_balance_wallet_outlined,
      color: const Color(0xFF3B82F6),
      category: 'parties',
    ),
    ReportItem(
      id: 'supplier_ledger',
      name: 'Supplier Ledger',
      description: 'Supplier transactions & payables',
      icon: Icons.local_shipping_outlined,
      color: const Color(0xFF8B5CF6),
      category: 'parties',
    ),
    ReportItem(
      id: 'sale_report',
      name: 'Sales Report',
      description: 'Sales analysis with trends',
      icon: Icons.trending_up,
      color: const Color(0xFF10B981),
      category: 'sales',
    ),
    ReportItem(
      id: 'purchase_report',
      name: 'Purchase Report',
      description: 'Purchase patterns & expenses',
      icon: Icons.shopping_bag_outlined,
      color: const Color(0xFFF59E0B),
      category: 'purchases',
    ),
    ReportItem(
      id: 'profit_loss',
      name: 'Profit & Loss',
      description: 'Financial performance analysis',
      icon: Icons.analytics_outlined,
      color: const Color(0xFFEF4444),
      category: 'financial',
    ),
    ReportItem(
      id: 'stock_report',
      name: 'Stock Report',
      description: 'Inventory levels & valuation',
      icon: Icons.inventory_outlined,
      color: const Color(0xFF06B6D4),
      category: 'inventory',
    ),
    ReportItem(
      id: 'inventory_ledger',
      name: 'Inventory Ledger',
      description: 'Item-wise stock movements',
      icon: Icons.receipt_long_outlined,
      color: const Color(0xFF84CC16),
      category: 'inventory',
    ),
    ReportItem(
      id: 'item_wise_sale',
      name: 'Item Wise Sales',
      description: 'Product-level sales performance',
      icon: Icons.pie_chart_outline,
      color: const Color(0xFFEC4899),
      category: 'sales',
    ),
    ReportItem(
      id: 'customer_wise_sale',
      name: 'Customer Wise Sales',
      description: 'Customer sales contribution',
      icon: Icons.person_outline,
      color: const Color(0xFF14B8A6),
      category: 'sales',
    ),
    ReportItem(
      id: 'expiry_report',
      name: 'Expiry Report',
      description: 'Medicine expiry tracking',
      icon: Icons.event_busy_outlined,
      color: const Color(0xFFDC2626),
      category: 'inventory',
    ),
    ReportItem(
      id: 'low_stock',
      name: 'Low Stock Alert',
      description: 'Items below reorder level',
      icon: Icons.warning_amber_outlined,
      color: const Color(0xFFD97706),
      category: 'inventory',
    ),
    ReportItem(
      id: 'daily_summary',
      name: 'Daily Summary',
      description: 'Daily business snapshot',
      icon: Icons.today_outlined,
      color: const Color(0xFF6366F1),
      category: 'financial',
    ),
  ];

  List<ReportItem> get filteredReports {
    if (selectedCategory == 'all') return allReports;
    return allReports.where((r) => r.category == selectedCategory).toList();
  }

  ReportItem get currentReport {
    return allReports.firstWhere(
      (r) => r.id == selectedReport,
      orElse: () => allReports.first,
    );
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectReport(String reportId) {
    setState(() => selectedReport = reportId);
    _animationController.reset();
    _animationController.forward();
  }

  Widget _getSelectedReportWidget() {
    switch (selectedReport) {
      case 'customer_ledger':
        return const CustomerLedgerReport();
      case 'supplier_ledger':
        return const SupplierLedgerReport();
      case 'sale_report':
        return const SaleReport();
      case 'purchase_report':
        return const PurchaseReport();
      case 'profit_loss':
        return const ProfitLossReport();
      case 'stock_report':
        return const StockReport();
      case 'inventory_ledger':
        return const InventoryLedgerReport();
      case 'item_wise_sale':
        return const ItemWiseSaleReport();
      case 'customer_wise_sale':
        return const CustomerWiseSaleReport();
      default:
        return _buildComingSoonWidget();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          
          // ════════════════════════════════════════════════════════════════
          // MOBILE LAYOUT (< 600px)
          // ════════════════════════════════════════════════════════════════
          if (width < 600) {
            return _buildMobileLayout();
          }
          
          // ════════════════════════════════════════════════════════════════
          // TABLET & DESKTOP LAYOUT (> 600px) - All use top navigation now
          // ════════════════════════════════════════════════════════════════
          return _buildDesktopLayout();
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📱 MOBILE LAYOUT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Mobile Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Dropdown + Actions Row
              Row(
                children: [
                  // Report Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [currentReport.color, currentReport.color.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(currentReport.icon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  
                  // Dropdown
                  Expanded(child: _buildMobileDropdown()),
                  
                  const SizedBox(width: 8),
                  
                  // Actions
                  _buildMobileActionButton(Icons.refresh),
                  const SizedBox(width: 4),
                  _buildMobileActionButton(Icons.more_vert),
                ],
              ),
              
              const SizedBox(height: 10),
              
              // Category Chips
              _buildMobileCategoryChips(),
            ],
          ),
        ),
        
        // Report Content
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _getSelectedReportWidget(),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedReport,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: currentReport.color, size: 18),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          items: filteredReports.map((report) {
            return DropdownMenuItem<String>(
              value: report.id,
              child: Row(
                children: [
                  Icon(report.icon, size: 14, color: report.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.name,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) _selectReport(value);
          },
          selectedItemBuilder: (context) {
            return filteredReports.map((report) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  report.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: currentReport.color,
                  ),
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildMobileActionButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Icon(icon, size: 16, color: const Color(0xFF64748B)),
    );
  }

  Widget _buildMobileCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final isSelected = selectedCategory == category.id;
          final count = category.id == 'all'
              ? allReports.length
              : allReports.where((r) => r.category == category.id).length;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => setState(() => selectedCategory = category.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? category.color : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? category.color : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withOpacity(0.2) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }



// Replace the entire _buildDesktopLayout method with this fixed version:

Widget _buildDesktopLayout() {
  return Column(
    children: [
      // ═══════════════════════════════════════════════════════════════
      // TOP HEADER BAR
      // ═══════════════════════════════════════════════════════════════
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Logo/Title Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [currentReport.color, currentReport.color.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(currentReport.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            
            // Report Title & Description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentReport.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currentReport.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            
            // Action Buttons
            _buildActionButton(Icons.refresh, 'Refresh', () {}),
            const SizedBox(width: 8),
            _buildActionButton(Icons.print_outlined, 'Print', () {}),
            const SizedBox(width: 8),
            _buildActionButton(Icons.download_outlined, 'Export', () {}),
            const SizedBox(width: 12),
            
            // Generate Button
            Material(
              color: currentReport.color,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: const Row(
                    children: [
                      Icon(Icons.play_arrow, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Generate',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      
      // ═══════════════════════════════════════════════════════════════
      // CATEGORY TABS & REPORT SELECTION
      // ═══════════════════════════════════════════════════════════════
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        child: Column(
          children: [
            // Category Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: categories.map((category) {
                  final isSelected = selectedCategory == category.id;
                  final count = category.id == 'all'
                      ? allReports.length
                      : allReports.where((r) => r.category == category.id).length;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => selectedCategory = category.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? category.color : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? category.color : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              category.icon,
                              size: 16,
                              color: isSelected ? Colors.white : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              category.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? Colors.white.withOpacity(0.25) 
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            
            // Report Cards - Horizontal Scroll - FIXED HEIGHT
            SizedBox(
              height: 100, // Increased from 90 to 100
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16, top: 8),
                itemCount: filteredReports.length,
                itemBuilder: (context, index) {
                  final report = filteredReports[index];
                  final isSelected = selectedReport == report.id;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Material(
                      color: isSelected 
                          ? report.color.withOpacity(0.1) 
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => _selectReport(report.id),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 240, // Increased from 220 to 240 for more space
                          padding: const EdgeInsets.all(12), // Reduced from 14 to 12
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              width: isSelected ? 2 : 1,
                              color: isSelected 
                                  ? report.color 
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Icon
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: report.color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(report.icon, size: 20, color: report.color),
                              ),
                              const SizedBox(width: 12),
                              
                              // Text Content - FIXED with Flexible
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min, // Important!
                                  children: [
                                    Text(
                                      report.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected 
                                            ? report.color 
                                            : const Color(0xFF1E293B),
                                        height: 1.2, // Control line height
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3), // Reduced spacing
                                    Text(
                                      report.description,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isSelected
                                            ? report.color.withOpacity(0.7)
                                            : const Color(0xFF94A3B8),
                                        height: 1.2, // Control line height
                                      ),
                                      maxLines: 2, // Allow 2 lines for description
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Check Icon
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: report.color,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check, 
                                    size: 12, 
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      
      // ═══════════════════════════════════════════════════════════════
      // REPORT CONTENT - FULL HEIGHT
      // ═══════════════════════════════════════════════════════════════
      Expanded(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _getSelectedReportWidget(),
        ),
      ),
    ],
  );
}

  Widget _buildActionButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF64748B)),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMING SOON WIDGET
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildComingSoonWidget() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: currentReport.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(currentReport.icon, size: 48, color: currentReport.color),
            ),
            const SizedBox(height: 24),
            Text(
              currentReport.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.construction, size: 16, color: Color(0xFFD97706)),
                  SizedBox(width: 6),
                  Text('Coming Soon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                currentReport.description,
                style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER CLASSES
// ═══════════════════════════════════════════════════════════════════════════════

class ReportCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  ReportCategory({required this.id, required this.name, required this.icon, required this.color});
}

class ReportItem {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final String category;

  ReportItem({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.category,
  });
}