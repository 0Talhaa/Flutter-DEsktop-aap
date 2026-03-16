// lib/screens/inventory_screen.dart

import 'package:flutter/material.dart';
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

  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);

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
      filteredProducts = data;
      isLoading = false;
    });
  }

  void _filterProducts(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredProducts = products;
      } else {
        filteredProducts = products.where((p) {
          return p.itemName.toLowerCase().contains(query.toLowerCase()) ||
              (p.itemCode?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
              (p.companyName?.toLowerCase().contains(query.toLowerCase()) ?? false);
        }).toList();
      }
    });
  }

  Future<void> _updateStock(Product product, int newStock) async {
    final updatedProduct = Product(
      id: product.id,
      itemName: product.itemName,
      itemCode: product.itemCode,
      tradePrice: product.tradePrice,
      retailPrice: product.retailPrice,
      taxPercent: product.taxPercent,
      discountPercent: product.discountPercent,
      parLevel: product.parLevel,
      issueUnit: product.issueUnit,
      companyName: product.companyName,
      stock: newStock,
    );

    await DatabaseHelper.instance.updateProduct(updatedProduct);
    _loadInventory(); // refresh list
  }

  @override
  Widget build(BuildContext context) {
    int lowStockCount = filteredProducts.where((p) => (p.stock ?? 0) < (p.parLevel ?? 0) && (p.stock ?? 0) > 0).length;
    int outOfStockCount = filteredProducts.where((p) => (p.stock ?? 0) == 0).length;
    double totalStockValue = filteredProducts.fold(0.0, (sum, p) => sum + (p.retailPrice * (p.stock ?? 0)));

    return Column(
      children: [
        // Search & Summary
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                onChanged: _filterProducts,
                decoration: InputDecoration(
                  hintText: 'Search by name, code or company...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _summaryCard('Total Items', filteredProducts.length.toString(), Icons.inventory, Colors.blue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _summaryCard('Low Stock', '$lowStockCount', Icons.warning, Colors.orange),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _summaryCard('Out of Stock', '$outOfStockCount', Icons.cancel, Colors.red),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _summaryCard('Stock Value', currencyFormat.format(totalStockValue), Icons.attach_money, Colors.green),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Stock Table
        Expanded(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF0D47A1),
                  child: const Row(
                    children: [
                      Expanded(flex: 1, child: Text('Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      Expanded(flex: 3, child: Text('Item Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Company', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('Packing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text('Stock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Expanded(flex: 1, child: Text('PAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text('Retail Price', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text('Value', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                      Expanded(flex: 1, child: Text('Actions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    ],
                  ),
                ),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredProducts.isEmpty
                          ? const Center(child: Text('No items in stock'))
                          : ListView.builder(
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, i) {
                                final p = filteredProducts[i];
                                bool isLowStock = (p.stock ?? 0) < (p.parLevel ?? 0) && (p.stock ?? 0) > 0;
                                bool isOutOfStock = (p.stock ?? 0) == 0;
                                double value = p.retailPrice * (p.stock ?? 0);

                                return Container(
                                  color: isOutOfStock ? Colors.red.shade50 : (isLowStock ? Colors.orange.shade50 : (i % 2 == 0 ? Colors.grey.shade50 : Colors.white)),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 1, child: Text(p.itemCode ?? '-', style: TextStyle(color: isLowStock || isOutOfStock ? Colors.red : null))),
                                      Expanded(flex: 3, child: Text(p.itemName, style: TextStyle(fontWeight: FontWeight.w600, color: isLowStock || isOutOfStock ? Colors.red : null))),
                                      Expanded(flex: 2, child: Text(p.companyName ?? '-')),
                                      Expanded(flex: 1, child: Text(p.issueUnit ?? '-')),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          p.stock.toString(),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isOutOfStock ? Colors.red : (isLowStock ? Colors.orange : null),
                                          ),
                                        ),
                                      ),
                                      Expanded(flex: 1, child: Text(p.parLevel.toString(), textAlign: TextAlign.center)),
                                      Expanded(flex: 2, child: Text(currencyFormat.format(p.retailPrice), textAlign: TextAlign.right)),
                                      Expanded(flex: 2, child: Text(currencyFormat.format(value), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      Expanded(
                                        flex: 1,
                                        child: IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          onPressed: () => _showEditStockDialog(p),
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
          ),
        ),
      ],
    );
  }

  void _showEditStockDialog(Product product) {
    final TextEditingController stockController = TextEditingController(text: product.stock.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Stock - ${product.itemName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Stock: ${product.stock}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New Stock Quantity',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newStock = int.tryParse(stockController.text) ?? product.stock;
              await DatabaseHelper.instance.updateProductStock(product.id!, newStock);
              _loadInventory();
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                Text(title, style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}