// // lib/screens/customer_ledger_screen.dart

// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:medical_app/models/customer.dart';
// import 'package:medical_app/services/database_helper.dart';

// class CustomerLedgerScreen extends StatefulWidget {
//   const CustomerLedgerScreen({super.key});

//   @override
//   State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
// }

// class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
//   // Data
//   List<Customer> allCustomers = [];
//   Customer? selectedCustomer;
//   List<Map<String, dynamic>> ledgerEntries = [];
//   bool isLoading = false;

//   // Date Range
//   DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
//   DateTime toDate = DateTime.now();

//   // Summary
//   double openingBalance = 0.0;
//   double totalSales = 0.0;
//   double totalPaymentsReceived = 0.0;
//   double closingBalance = 0.0;

//   final currencyFormat = NumberFormat.currency(
//     locale: 'en_PK',
//     symbol: 'Rs. ',
//     decimalDigits: 0,
//   );
//   final dateFormat = DateFormat('dd MMM yyyy');
//   final dateTimeFormat = DateFormat('dd MMM yyyy hh:mm a');

//   @override
//   void initState() {
//     super.initState();
//     _loadCustomers();
//   }

//   Future<void> _loadCustomers() async {
//     final customers = await DatabaseHelper.instance.getAllCustomers();
//     setState(() => allCustomers = customers);
//   }

//   Future<void> _loadLedger() async {
//     if (selectedCustomer == null) return;
//     setState(() => isLoading = true);

//     try {
//       final db = await DatabaseHelper.instance.database;
//       final fromStr = DateFormat('yyyy-MM-dd').format(fromDate);
//       final toStr = DateFormat('yyyy-MM-dd').format(toDate);

//       // ── Opening Balance ──────────────────────────────────────
//       // = customer openingBalance + all sales before fromDate
//       //   - all payments before fromDate
//       final salesBefore = await db.rawQuery('''
//         SELECT 
//           COALESCE(SUM(total), 0) as totalSales,
//           COALESCE(SUM(amountPaid), 0) as totalPaid
//         FROM sales
//         WHERE customerId = ? AND DATE(dateTime) < ?
//       ''', [selectedCustomer!.id, fromStr]);

//       final paymentsBefore = await db.rawQuery('''
//         SELECT COALESCE(SUM(amount), 0) as totalPayments
//         FROM customer_payments
//         WHERE customerId = ? AND DATE(date) < ?
//       ''', [selectedCustomer!.id, fromStr]);

//       final salesBeforeTotal =
//           (salesBefore.first['totalSales'] as num).toDouble();
//       final paidBeforeTotal =
//           (salesBefore.first['totalPaid'] as num).toDouble();
//       final paymentsBeforeTotal =
//           (paymentsBefore.first['totalPayments'] as num).toDouble();

//       openingBalance = selectedCustomer!.openingBalance +
//           salesBeforeTotal -
//           paidBeforeTotal -
//           paymentsBeforeTotal;

//       // ── Sales in Range ───────────────────────────────────────
//       final salesResult = await db.query(
//         'sales',
//         where: 'customerId = ? AND DATE(dateTime) BETWEEN ? AND ?',
//         whereArgs: [selectedCustomer!.id, fromStr, toStr],
//         orderBy: 'dateTime ASC',
//       );

//       // ── Payments in Range ────────────────────────────────────
//       final paymentsResult = await db.query(
//         'customer_payments',
//         where: 'customerId = ? AND DATE(date) BETWEEN ? AND ?',
//         whereArgs: [selectedCustomer!.id, fromStr, toStr],
//         orderBy: 'date ASC',
//       );

//       // ── Build Ledger Entries ─────────────────────────────────
//       final entries = <Map<String, dynamic>>[];

//       // Add opening balance row
//       entries.add({
//         'type': 'opening',
//         'date': fromDate.toIso8601String(),
//         'description': 'Opening Balance',
//         'debit': openingBalance > 0 ? openingBalance : 0.0,
//         'credit': openingBalance < 0 ? openingBalance.abs() : 0.0,
//         'balance': openingBalance,
//         'reference': '',
//       });

//       // Merge sales and payments sorted by date
//       final allEntries = <Map<String, dynamic>>[];

//       for (var sale in salesResult) {
//         allEntries.add({
//           'type': 'sale',
//           'date': sale['dateTime'] as String,
//           'description': 'Sale Invoice INV-${sale['invoiceId']}',
//           'debit': (sale['total'] as num).toDouble(),
//           'credit': 0.0,
//           'reference': 'INV-${sale['invoiceId']}',
//           'amountPaid': (sale['amountPaid'] as num).toDouble(),
//           'balance': (sale['balance'] as num).toDouble(),
//         });

//         // If sale had direct payment
//         final directPaid = (sale['amountPaid'] as num).toDouble();
//         if (directPaid > 0) {
//           allEntries.add({
//             'type': 'direct_payment',
//             'date': sale['dateTime'] as String,
//             'description':
//                 'Payment with Invoice INV-${sale['invoiceId']}',
//             'debit': 0.0,
//             'credit': directPaid,
//             'reference': 'INV-${sale['invoiceId']}',
//           });
//         }
//       }

//       for (var payment in paymentsResult) {
//         allEntries.add({
//           'type': 'payment',
//           'date': payment['date'] as String,
//           'description':
//               'Payment Received${payment['invoiceId'] != null ? ' for INV-${payment['invoiceId']}' : ''}',
//           'debit': 0.0,
//           'credit': (payment['amount'] as num).toDouble(),
//           'reference': payment['reference'] ?? '',
//           'paymentMethod': payment['paymentMethod'] ?? 'Cash',
//           'notes': payment['notes'] ?? '',
//         });
//       }

//       // Sort all entries by date
//       allEntries.sort(
//         (a, b) => (a['date'] as String).compareTo(b['date'] as String),
//       );

//       // Calculate running balance
//       double runningBalance = openingBalance;
//       for (var entry in allEntries) {
//         runningBalance += (entry['debit'] as double);
//         runningBalance -= (entry['credit'] as double);
//         entries.add({...entry, 'balance': runningBalance});
//       }

//       closingBalance = runningBalance;

//       // Calculate summary
//       totalSales = salesResult.fold(
//         0.0,
//         (sum, s) => sum + (s['total'] as num).toDouble(),
//       );
//       totalPaymentsReceived = paymentsResult.fold(
//             0.0,
//             (sum, p) => sum + (p['amount'] as num).toDouble(),
//           ) +
//           salesResult.fold(
//             0.0,
//             (sum, s) => sum + (s['amountPaid'] as num).toDouble(),
//           );

//       setState(() {
//         ledgerEntries = entries;
//         isLoading = false;
//       });
//     } catch (e) {
//       setState(() => isLoading = false);
//       debugPrint('❌ Ledger error: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error loading ledger: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     }
//   }

//   Future<void> _selectFromDate() async {
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: fromDate,
//       firstDate: DateTime(2020),
//       lastDate: DateTime.now(),
//     );
//     if (picked != null) {
//       setState(() => fromDate = picked);
//       if (selectedCustomer != null) _loadLedger();
//     }
//   }

//   Future<void> _selectToDate() async {
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: toDate,
//       firstDate: DateTime(2020),
//       lastDate: DateTime.now(),
//     );
//     if (picked != null) {
//       setState(() => toDate = picked);
//       if (selectedCustomer != null) _loadLedger();
//     }
//   }

//   // ============================================================
//   // BUILD
//   // ============================================================

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8FAFC),
//       appBar: AppBar(
//         title: const Text('Customer Ledger'),
//         backgroundColor: const Color(0xFF1565C0),
//         foregroundColor: Colors.white,
//         elevation: 0,
//         actions: [
//           if (selectedCustomer != null)
//             IconButton(
//               onPressed: _loadLedger,
//               icon: const Icon(Icons.refresh),
//               tooltip: 'Refresh',
//             ),
//         ],
//       ),
//       body: Column(
//         children: [
//           _buildFilterBar(),
//           if (selectedCustomer != null) _buildSummaryCards(),
//           Expanded(
//             child: selectedCustomer == null
//                 ? _buildEmptyState()
//                 : isLoading
//                     ? const Center(child: CircularProgressIndicator())
//                     : _buildLedgerTable(),
//           ),
//         ],
//       ),
//     );
//   }

//   // ============================================================
//   // FILTER BAR
//   // ============================================================

//   Widget _buildFilterBar() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         border: Border(
//           bottom: BorderSide(color: Color(0xFFE2E8F0)),
//         ),
//       ),
//       child: Row(
//         children: [
//           // Customer Dropdown
//           Expanded(
//             flex: 3,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'CUSTOMER',
//                   style: TextStyle(
//                     fontSize: 10,
//                     fontWeight: FontWeight.w600,
//                     color: Color(0xFF64748B),
//                     letterSpacing: 0.5,
//                   ),
//                 ),
//                 const SizedBox(height: 6),
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 12),
//                   decoration: BoxDecoration(
//                     border: Border.all(color: const Color(0xFFE2E8F0)),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: DropdownButtonHideUnderline(
//                     child: DropdownButton<Customer>(
//                       value: selectedCustomer,
//                       isExpanded: true,
//                       hint: const Text(
//                         'Select customer...',
//                         style: TextStyle(fontSize: 13),
//                       ),
//                       items: allCustomers
//                           .map(
//                             (c) => DropdownMenuItem(
//                               value: c,
//                               child: Text(
//                                 c.name,
//                                 style: const TextStyle(fontSize: 13),
//                               ),
//                             ),
//                           )
//                           .toList(),
//                       onChanged: (val) {
//                         setState(() {
//                           selectedCustomer = val;
//                           ledgerEntries.clear();
//                         });
//                         if (val != null) _loadLedger();
//                       },
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(width: 12),

//           // From Date
//           Expanded(
//             flex: 2,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'FROM DATE',
//                   style: TextStyle(
//                     fontSize: 10,
//                     fontWeight: FontWeight.w600,
//                     color: Color(0xFF64748B),
//                     letterSpacing: 0.5,
//                   ),
//                 ),
//                 const SizedBox(height: 6),
//                 InkWell(
//                   onTap: _selectFromDate,
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 12,
//                     ),
//                     decoration: BoxDecoration(
//                       border: Border.all(color: const Color(0xFFE2E8F0)),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Row(
//                       children: [
//                         const Icon(
//                           Icons.calendar_today,
//                           size: 14,
//                           color: Color(0xFF64748B),
//                         ),
//                         const SizedBox(width: 6),
//                         Text(
//                           dateFormat.format(fromDate),
//                           style: const TextStyle(fontSize: 13),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(width: 12),

//           // To Date
//           Expanded(
//             flex: 2,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'TO DATE',
//                   style: TextStyle(
//                     fontSize: 10,
//                     fontWeight: FontWeight.w600,
//                     color: Color(0xFF64748B),
//                     letterSpacing: 0.5,
//                   ),
//                 ),
//                 const SizedBox(height: 6),
//                 InkWell(
//                   onTap: _selectToDate,
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 12,
//                       vertical: 12,
//                     ),
//                     decoration: BoxDecoration(
//                       border: Border.all(color: const Color(0xFFE2E8F0)),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Row(
//                       children: [
//                         const Icon(
//                           Icons.calendar_today,
//                           size: 14,
//                           color: Color(0xFF64748B),
//                         ),
//                         const SizedBox(width: 6),
//                         Text(
//                           dateFormat.format(toDate),
//                           style: const TextStyle(fontSize: 13),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(width: 12),

//           // Quick Range Buttons
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'QUICK RANGE',
//                 style: TextStyle(
//                   fontSize: 10,
//                   fontWeight: FontWeight.w600,
//                   color: Color(0xFF64748B),
//                   letterSpacing: 0.5,
//                 ),
//               ),
//               const SizedBox(height: 6),
//               Row(
//                 children: [
//                   _buildQuickRangeBtn('7D', 7),
//                   const SizedBox(width: 6),
//                   _buildQuickRangeBtn('30D', 30),
//                   const SizedBox(width: 6),
//                   _buildQuickRangeBtn('90D', 90),
//                 ],
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildQuickRangeBtn(String label, int days) {
//     return InkWell(
//       onTap: () {
//         setState(() {
//           toDate = DateTime.now();
//           fromDate = DateTime.now().subtract(Duration(days: days));
//         });
//         if (selectedCustomer != null) _loadLedger();
//       },
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//         decoration: BoxDecoration(
//           color: const Color(0xFF1565C0).withOpacity(0.1),
//           borderRadius: BorderRadius.circular(6),
//           border: Border.all(
//             color: const Color(0xFF1565C0).withOpacity(0.3),
//           ),
//         ),
//         child: Text(
//           label,
//           style: const TextStyle(
//             fontSize: 11,
//             fontWeight: FontWeight.w600,
//             color: Color(0xFF1565C0),
//           ),
//         ),
//       ),
//     );
//   }

//   // ============================================================
//   // SUMMARY CARDS
//   // ============================================================

//   Widget _buildSummaryCards() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       color: const Color(0xFFF1F5F9),
//       child: Row(
//         children: [
//           _buildSummaryCard(
//             'Opening Balance',
//             openingBalance,
//             Icons.account_balance_wallet,
//             const Color(0xFF64748B),
//           ),
//           const SizedBox(width: 12),
//           _buildSummaryCard(
//             'Total Sales',
//             totalSales,
//             Icons.shopping_cart,
//             const Color(0xFF3B82F6),
//           ),
//           const SizedBox(width: 12),
//           _buildSummaryCard(
//             'Payments Received',
//             totalPaymentsReceived,
//             Icons.payments,
//             const Color(0xFF10B981),
//           ),
//           const SizedBox(width: 12),
//           _buildSummaryCard(
//             'Closing Balance',
//             closingBalance,
//             Icons.account_balance,
//             closingBalance > 0
//                 ? const Color(0xFFEF4444)
//                 : const Color(0xFF10B981),
//             isHighlighted: true,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSummaryCard(
//     String label,
//     double amount,
//     IconData icon,
//     Color color, {
//     bool isHighlighted = false,
//   }) {
//     return Expanded(
//       child: Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: isHighlighted ? color.withOpacity(0.1) : Colors.white,
//           borderRadius: BorderRadius.circular(10),
//           border: Border.all(
//             color: isHighlighted ? color.withOpacity(0.3) : Colors.transparent,
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.04),
//               blurRadius: 6,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(10),
//               decoration: BoxDecoration(
//                 color: color.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Icon(icon, color: color, size: 20),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     label,
//                     style: const TextStyle(
//                       fontSize: 11,
//                       color: Color(0xFF64748B),
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     currencyFormat.format(amount),
//                     style: TextStyle(
//                       fontSize: 15,
//                       fontWeight: FontWeight.w700,
//                       color: color,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ============================================================
//   // LEDGER TABLE
//   // ============================================================

//   Widget _buildLedgerTable() {
//     if (ledgerEntries.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
//             const SizedBox(height: 16),
//             Text(
//               'No transactions found in this date range',
//               style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
//             ),
//           ],
//         ),
//       );
//     }

//     return Column(
//       children: [
//         // Table Header
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//           decoration: const BoxDecoration(
//             color: Color(0xFF1E293B),
//           ),
//           child: Row(
//             children: [
//               _buildHeaderCell('Date', flex: 2),
//               _buildHeaderCell('Description', flex: 4),
//               _buildHeaderCell('Reference', flex: 2),
//               _buildHeaderCell('Debit (Dr)', flex: 2),
//               _buildHeaderCell('Credit (Cr)', flex: 2),
//               _buildHeaderCell('Balance', flex: 2),
//             ],
//           ),
//         ),

//         // Table Body
//         Expanded(
//           child: ListView.builder(
//             itemCount: ledgerEntries.length,
//             itemBuilder: (context, index) {
//               final entry = ledgerEntries[index];
//               final isOpening = entry['type'] == 'opening';
//               final isSale = entry['type'] == 'sale';
//               final isPayment = entry['type'] == 'payment' ||
//                   entry['type'] == 'direct_payment';
//               final balance = entry['balance'] as double;
//               final debit = entry['debit'] as double;
//               final credit = entry['credit'] as double;

//               Color rowColor = Colors.white;
//               if (isOpening) rowColor = const Color(0xFFF1F5F9);
//               if (isSale) rowColor = const Color(0xFFFFF7ED);
//               if (isPayment) rowColor = const Color(0xFFF0FDF4);

//               return Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 20,
//                   vertical: 10,
//                 ),
//                 decoration: BoxDecoration(
//                   color: rowColor,
//                   border: Border(
//                     bottom: BorderSide(
//                       color: Colors.grey.shade200,
//                       width: 0.5,
//                     ),
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                     // Date
//                     Expanded(
//                       flex: 2,
//                       child: Text(
//                         _formatEntryDate(entry['date'] as String),
//                         style: const TextStyle(
//                           fontSize: 12,
//                           color: Color(0xFF64748B),
//                         ),
//                       ),
//                     ),

//                     // Description
//                     Expanded(
//                       flex: 4,
//                       child: Row(
//                         children: [
//                           Container(
//                             padding: const EdgeInsets.all(4),
//                             decoration: BoxDecoration(
//                               color: isOpening
//                                   ? Colors.grey.withOpacity(0.1)
//                                   : isSale
//                                       ? Colors.orange.withOpacity(0.1)
//                                       : Colors.green.withOpacity(0.1),
//                               borderRadius: BorderRadius.circular(4),
//                             ),
//                             child: Icon(
//                               isOpening
//                                   ? Icons.account_balance_wallet
//                                   : isSale
//                                       ? Icons.shopping_cart
//                                       : Icons.payments,
//                               size: 12,
//                               color: isOpening
//                                   ? Colors.grey
//                                   : isSale
//                                       ? Colors.orange
//                                       : Colors.green,
//                             ),
//                           ),
//                           const SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               entry['description'] as String,
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 fontWeight: isOpening
//                                     ? FontWeight.w600
//                                     : FontWeight.normal,
//                                 color: const Color(0xFF1E293B),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),

//                     // Reference
//                     Expanded(
//                       flex: 2,
//                       child: Text(
//                         entry['reference'] as String? ?? '',
//                         style: const TextStyle(
//                           fontSize: 11,
//                           color: Color(0xFF64748B),
//                         ),
//                       ),
//                     ),

//                     // Debit
//                     Expanded(
//                       flex: 2,
//                       child: Text(
//                         debit > 0 ? currencyFormat.format(debit) : '-',
//                         textAlign: TextAlign.right,
//                         style: TextStyle(
//                           fontSize: 12,
//                           fontWeight: FontWeight.w600,
//                           color: debit > 0
//                               ? const Color(0xFFEF4444)
//                               : Colors.grey.shade400,
//                         ),
//                       ),
//                     ),

//                     // Credit
//                     Expanded(
//                       flex: 2,
//                       child: Text(
//                         credit > 0 ? currencyFormat.format(credit) : '-',
//                         textAlign: TextAlign.right,
//                         style: TextStyle(
//                           fontSize: 12,
//                           fontWeight: FontWeight.w600,
//                           color: credit > 0
//                               ? const Color(0xFF10B981)
//                               : Colors.grey.shade400,
//                         ),
//                       ),
//                     ),

//                     // Balance
//                     Expanded(
//                       flex: 2,
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 8,
//                           vertical: 4,
//                         ),
//                         decoration: BoxDecoration(
//                           color: balance > 0
//                               ? const Color(0xFFEF4444).withOpacity(0.1)
//                               : const Color(0xFF10B981).withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(6),
//                         ),
//                         child: Text(
//                           currencyFormat.format(balance.abs()),
//                           textAlign: TextAlign.right,
//                           style: TextStyle(
//                             fontSize: 12,
//                             fontWeight: FontWeight.w700,
//                             color: balance > 0
//                                 ? const Color(0xFFEF4444)
//                                 : const Color(0xFF10B981),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               );
//             },
//           ),
//         ),

//         // Table Footer
//         _buildTableFooter(),
//       ],
//     );
//   }

//   Widget _buildTableFooter() {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
//       decoration: const BoxDecoration(
//         color: Color(0xFF1E293B),
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(0),
//           bottomRight: Radius.circular(0),
//         ),
//       ),
//       child: Row(
//         children: [
//           const Expanded(
//             flex: 2,
//             child: Text(
//               'CLOSING BALANCE',
//               style: TextStyle(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w700,
//                 color: Colors.white,
//               ),
//             ),
//           ),
//           const Expanded(flex: 4, child: SizedBox()),
//           const Expanded(flex: 2, child: SizedBox()),
//           Expanded(
//             flex: 2,
//             child: Text(
//               currencyFormat.format(totalSales),
//               textAlign: TextAlign.right,
//               style: const TextStyle(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w700,
//                 color: Color(0xFFEF4444),
//               ),
//             ),
//           ),
//           Expanded(
//             flex: 2,
//             child: Text(
//               currencyFormat.format(totalPaymentsReceived),
//               textAlign: TextAlign.right,
//               style: const TextStyle(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w700,
//                 color: Color(0xFF10B981),
//               ),
//             ),
//           ),
//           Expanded(
//             flex: 2,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//               decoration: BoxDecoration(
//                 color: closingBalance > 0
//                     ? const Color(0xFFEF4444).withOpacity(0.2)
//                     : const Color(0xFF10B981).withOpacity(0.2),
//                 borderRadius: BorderRadius.circular(6),
//               ),
//               child: Text(
//                 '${currencyFormat.format(closingBalance.abs())} '
//                 '${closingBalance > 0 ? 'Dr' : 'Cr'}',
//                 textAlign: TextAlign.right,
//                 style: TextStyle(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w800,
//                   color: closingBalance > 0
//                       ? const Color(0xFFEF4444)
//                       : const Color(0xFF10B981),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildHeaderCell(String text, {int flex = 1}) {
//     return Expanded(
//       flex: flex,
//       child: Text(
//         text,
//         textAlign:
//             text == 'Date' || text == 'Description' || text == 'Reference'
//                 ? TextAlign.left
//                 : TextAlign.right,
//         style: const TextStyle(
//           fontSize: 11,
//           fontWeight: FontWeight.w600,
//           color: Colors.white70,
//         ),
//       ),
//     );
//   }

//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.person_search,
//             size: 80,
//             color: Colors.grey.shade300,
//           ),
//           const SizedBox(height: 16),
//           Text(
//             'Select a customer to view ledger',
//             style: TextStyle(
//               fontSize: 16,
//               color: Colors.grey.shade400,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Text(
//             'Complete transaction history with running balance',
//             style: TextStyle(
//               fontSize: 13,
//               color: Colors.grey.shade400,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String _formatEntryDate(String dateStr) {
//     try {
//       final date = DateTime.parse(dateStr);
//       return dateFormat.format(date);
//     } catch (_) {
//       return dateStr;
//     }
//   }
// }