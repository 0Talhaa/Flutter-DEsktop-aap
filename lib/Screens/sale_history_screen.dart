// lib/screens/sale_history_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/models/customer.dart';
import 'package:medical_app/services/database_helper.dart';
import '../models/sale_item.dart';

class SaleHistoryScreen extends StatefulWidget {
  const SaleHistoryScreen({super.key});

  @override
  State<SaleHistoryScreen> createState() => _SaleHistoryScreenState();
}

class _SaleHistoryScreenState extends State<SaleHistoryScreen> {
  List<Map<String, dynamic>> sales = [];
  List<Map<String, dynamic>> filteredSales = [];
  String searchQuery = '';
  String? selectedCustomerFilter;
  List<Customer> customers = [];

  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    final dbSales = await DatabaseHelper.instance.getAllSalesWithItems();
    final cust = await DatabaseHelper.instance.getAllCustomers();

    setState(() {
      sales = dbSales;
      customers = cust;
      filteredSales = dbSales;
      isLoading = false;
    });
  }

  void _filterSales() {
    setState(() {
      filteredSales = sales.where((sale) {
        final matchesSearch = searchQuery.isEmpty ||
            sale['invoiceId'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
            (sale['customerName'] ?? '').toLowerCase().contains(searchQuery.toLowerCase());

        final matchesCustomer = selectedCustomerFilter == null ||
            sale['customerName'] == selectedCustomerFilter;

        return matchesSearch && matchesCustomer;
      }).toList();
    });
  }

  Future<double> _getCustomerCurrentBalance(String? customerName) async {
    if (customerName == null || customerName == 'Walk-in Customer') return 0.0;
    final custList = await DatabaseHelper.instance.getAllCustomers();
    final customer = custList.firstWhere(
      (c) => c.name == customerName,
      orElse: () => Customer(name: '', phone: '', openingBalance: 0.0),
    );
    return customer.openingBalance;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Premium Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Sale History',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Search & Filter Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10),
                          ],
                        ),
                        child: TextField(
                          onChanged: (v) {
                            searchQuery = v;
                            _filterSales();
                          },
                          decoration: InputDecoration(
                            hintText: 'Search by invoice ID or customer name...',
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10)],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedCustomerFilter,
                          hint: const Text('All Customers', style: TextStyle(color: Color(0xFF64748B))),
                          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Customers')),
                            ...customers.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))),
                          ],
                          onChanged: (v) {
                            setState(() {
                              selectedCustomerFilter = v;
                              _filterSales();
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Sales List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                : filteredSales.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No sales found',
                              style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: filteredSales.length,
                        itemBuilder: (context, index) {
                          final sale = filteredSales[index];
                          final items = sale['items'] as List<SaleItem>;
                          final isCredit = sale['balance'] > 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: isCredit ? Colors.red.shade50 : Colors.green.shade50,
                                child: Icon(
                                  isCredit ? Icons.credit_score : Icons.check_circle,
                                  color: isCredit ? Colors.red : Colors.green,
                                ),
                              ),
                              title: Text(
                                'Invoice #${sale['invoiceId']}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                              subtitle: Text(
                                '${DateFormat('dd MMM yyyy • hh:mm a').format(DateTime.parse(sale['dateTime']))}\n${sale['customerName'] ?? 'Walk-in Customer'}',
                                style: const TextStyle(color: Color(0xFF64748B)),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currencyFormat.format(sale['total']),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
                                  ),
                                  Text(
                                    isCredit ? 'Credit' : 'Paid',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isCredit ? Colors.red : Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Items:', style: TextStyle(fontWeight: FontWeight.w600)),
                                          Text('${items.length} items'),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      ...items.take(3).map((item) => Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              children: [
                                                Expanded(flex: 3, child: Text(item.productName)),
                                                Text('× ${item.quantity}', style: const TextStyle(color: Color(0xFF64748B))),
                                                const Spacer(),
                                                Text(currencyFormat.format(item.lineTotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                          )),
                                      if (items.length > 3)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text('+ ${items.length - 3} more items', style: const TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
                                        ),

                                      const Divider(height: 30),

                                      _buildAmountRow('Total Amount', currencyFormat.format(sale['total']), isBold: true),
                                      _buildAmountRow('Amount Paid', currencyFormat.format(sale['amountPaid'])),
                                      _buildAmountRow(
                                        'Remaining Balance',
                                        currencyFormat.format(sale['balance']),
                                        color: sale['balance'] > 0 ? Colors.red : Colors.green,
                                        isBold: true,
                                      ),

                                      if (sale['customerName'] != null && sale['customerName'] != 'Walk-in Customer')
                                        FutureBuilder<double>(
                                          future: _getCustomerCurrentBalance(sale['customerName']),
                                          builder: (context, snapshot) {
                                            if (snapshot.hasData && snapshot.data! > 0) {
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 12),
                                                child: _buildAmountRow(
                                                  'Customer Total Credit',
                                                  currencyFormat.format(snapshot.data!),
                                                  color: Colors.red,
                                                  isBold: true,
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),

                                      const SizedBox(height: 16),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: ElevatedButton.icon(
                                          onPressed: () => _showSaleDetailDialog(sale, items),
                                          icon: const Icon(Icons.remove_red_eye),
                                          label: const Text('View Full Details'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF3B82F6),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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

  Widget _buildAmountRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? const Color(0xFF0D47A1),
            ),
          ),
        ],
      ),
    );
  }

  void _showSaleDetailDialog(Map<String, dynamic> sale, List<SaleItem> items) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Invoice #${sale['invoiceId']}',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Date: ${DateFormat('EEEE, dd MMMM yyyy • hh:mm a').format(DateTime.parse(sale['dateTime']))}'),
                Text('Customer: ${sale['customerName'] ?? 'Walk-in Customer'}'),
                Text('Payment: ${sale['paymentMethod'] ?? 'Cash'}'),
                const SizedBox(height: 24),

                const Text('Purchased Items', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // Table-style items
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Header
                      const Row(
                        children: [
                          Expanded(flex: 4, child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          Expanded(child: Text('R.P', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          Expanded(child: Text('T.P', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                          Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        ],
                      ),
                      const Divider(height: 20),
                      // Items
                      ...items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(flex: 4, child: Text(item.productName)),
                                Expanded(child: Text('${item.quantity}', textAlign: TextAlign.center)),
                                Expanded(child: Text(currencyFormat.format(item.tradePrice), textAlign: TextAlign.center)),
                                Expanded(child: Text(currencyFormat.format(item.price), textAlign: TextAlign.center)),
                                Expanded(
                                  child: Text(
                                    currencyFormat.format(item.lineTotal),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                _buildAmountRow('Total Amount', currencyFormat.format(sale['total']), isBold: true),
                _buildAmountRow('Amount Paid', currencyFormat.format(sale['amountPaid'])),
                _buildAmountRow(
                  'Remaining Balance',
                  currencyFormat.format(sale['balance']),
                  color: sale['balance'] > 0 ? Colors.red : Colors.green,
                  isBold: true,
                ),

                if (sale['customerName'] != null && sale['customerName'] != 'Walk-in Customer')
                  FutureBuilder<double>(
                    future: _getCustomerCurrentBalance(sale['customerName']),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data! > 0) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _buildAmountRow('Customer Total Credit', currencyFormat.format(snapshot.data!), color: Colors.red, isBold: true),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Printing receipt...'), backgroundColor: Colors.green),
                        );
                      },
                      icon: const Icon(Icons.print),
                      label: const Text('Print Receipt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}