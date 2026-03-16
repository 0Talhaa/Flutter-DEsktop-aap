// // lib/screens/reports/profit_loss_report.dart

// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:medical_app/services/database_helper.dart';

// class ProfitLossReport extends StatefulWidget {
//   const ProfitLossReport({super.key});

//   @override
//   State<ProfitLossReport> createState() => _ProfitLossReportState();
// }

// class _ProfitLossReportState extends State<ProfitLossReport> {
//   DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
//   DateTime toDate = DateTime.now();

//   double totalSales = 0.0;
//   double totalCost = 0.0;
//   double grossProfit = 0.0;
//   double netProfit = 0.0;
//   List<Map<String, dynamic>> topItems = [];
//   bool isLoading = true;

//   final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);

//   @override
//   void initState() {
//     super.initState();
//     _loadReport();
//   }

//   Future<void> _loadReport() async {
//     setState(() => isLoading = true);

//     // Sales in date range
//     final sales = await DatabaseHelper.instance.getSalesInDateRange(
//       fromDate.toIso8601String(),
//       toDate.toIso8601String(),
//     );

//     double salesAmount = 0.0;
//     double costAmount = 0.0;
//     Map<int, double> itemSales = {};
//     Map<int, double> itemCost = {};

//     for (var sale in sales) {
//       salesAmount += sale['total'] as double;
//       final items = sale['items'] as List<Map<String, dynamic>>;

//       for (var item in items) {
//         int productId = item['productId'];
//         double qty = item['quantity'].toDouble();
//         double salePrice = item['price'];

//         itemSales[productId] = (itemSales[productId] ?? 0) + (qty * salePrice);

//         // Product کی trade price لے کر cost calculate کریں
//         final product = await DatabaseHelper.instance.getProductById(productId);
//         if (product != null) {
//           double tradePrice = product['tradePrice'] as double;
//           itemCost[productId] = (itemCost[productId] ?? 0) + (qty * tradePrice);
//           costAmount += qty * tradePrice;
//         }
//       }
//     }

//     grossProfit = salesAmount - costAmount;
//     netProfit = grossProfit; // expenses بعد میں add کریں گے

//     // Top 5 profitable items
//     topItems = [];
//     itemSales.forEach((productId, sale) {
//       double cost = itemCost[productId] ?? 0;
//       double profit = sale - cost;
//       topItems.add({
//         'productId': productId,
//         'profit': profit,
//       });
//     });

//     topItems.sort((a, b) => b['profit'].compareTo(a['profit']));
//     topItems = topItems.take(5).toList();

//     // Product names add کریں (async)
//     for (var item in topItems) {
//       final product = await DatabaseHelper.instance.getProductById(item['productId']);
//       item['name'] = product?['itemName'] ?? 'Unknown';
//     }

//     setState(() {
//       totalSales = salesAmount;
//       totalCost = costAmount;
//       isLoading = false;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         // Date Range
//         Card(
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: Row(
//               children: [
//                 Expanded(child: _dateField('From', fromDate, (d) => fromDate = d!)),
//                 const SizedBox(width: 16),
//                 Expanded(child: _dateField('To', toDate, (d) => toDate = d!)),
//                 const SizedBox(width: 16),
//                 ElevatedButton(onPressed: _loadReport, child: const Text('Generate')),
//               ],
//             ),
//           ),
//         ),
//         const SizedBox(height: 20),

//         // Summary Cards
//         GridView.count(
//           shrinkWrap: true,
//           physics: const NeverScrollableScrollPhysics(),
//           crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
//           childAspectRatio: 3,
//           children: [
//             _plCard('Total Sales', totalSales, Colors.blue),
//             _plCard('Total Cost', totalCost, Colors.orange),
//             _plCard('Gross Profit', grossProfit, grossProfit >= 0 ? Colors.green : Colors.red),
//             _plCard('Net Profit', netProfit, netProfit >= 0 ? Colors.green : Colors.red),
//           ],
//         ),
//         const SizedBox(height: 20),

//         // Top Profitable Items
//         Card(
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text('Top 5 Profitable Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                 const SizedBox(height: 12),
//                 isLoading
//                     ? const Center(child: CircularProgressIndicator())
//                     : topItems.isEmpty
//                         ? const Text('No data')
//                         : ListView.builder(
//                             shrinkWrap: true,
//                             physics: const NeverScrollableScrollPhysics(),
//                             itemCount: topItems.length,
//                             itemBuilder: (context, i) {
//                               final item = topItems[i];
//                               return ListTile(
//                                 leading: CircleAvatar(child: Text('${i + 1}')),
//                                 title: Text(item['name']),
//                                 trailing: Text(currencyFormat.format(item['profit']), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
//                               );
//                             },
//                           ),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _dateField(String label, DateTime date, Function(DateTime) onChanged) {
//     return InkWell(
//       onTap: () async {
//         final picked = await showDatePicker(
//           context: context,
//           initialDate: date,
//           firstDate: DateTime(2020),
//           lastDate: DateTime.now(),
//         );
//         if (picked != null) onChanged(picked);
//       },
//       child: Container(
//         padding: const EdgeInsets.all(12),
//         decoration: BoxDecoration(border: Border.all(), borderRadius: BorderRadius.circular(8)),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text('$label: ${DateFormat('dd/MM/yyyy').format(date)}'),
//             const Icon(Icons.calendar_today),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _plCard(String title, double value, Color color) {
//     return Card(
//       color: color.withOpacity(0.1),
//       child: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           children: [
//             Text(currencyFormat.format(value), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
//             Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
//           ],
//         ),
//       ),
//     );
//   }
// }