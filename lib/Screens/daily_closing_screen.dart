// lib/screens/daily_closing_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/services/database_helper.dart';

class DailyClosingScreen extends StatefulWidget {
  const DailyClosingScreen({super.key});

  @override
  State<DailyClosingScreen> createState() => _DailyClosingScreenState();
}

class _DailyClosingScreenState extends State<DailyClosingScreen> {
  DateTime selectedDate = DateTime.now();
  double openingCash = 0.0;
  final TextEditingController physicalCashController = TextEditingController();

  double totalSales = 0.0;
  double cashSales = 0.0;
  double creditSales = 0.0;
  double totalExpenses = 0.0;
  double expectedCash = 0.0;
  double physicalCash = 0.0;
  double difference = 0.0;

  bool isLoading = true;

  final currencyFormat = NumberFormat.currency(
    locale: 'en_IN', 
    symbol: 'Rs. ', 
    decimalDigits: 0
  );

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  @override
  void dispose() {
    physicalCashController.dispose();
    super.dispose();
  }

  Future<void> _loadReport() async {
    setState(() => isLoading = true);

    final from = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final to = from.add(const Duration(days: 1));

    try {
      final sales = await DatabaseHelper.instance.getSalesInDateRange(
        from.toIso8601String(),
        to.toIso8601String(),
      );

      final expenses = await DatabaseHelper.instance.getExpensesInDateRange(
        from.toIso8601String(),
        to.toIso8601String(),
      );

      double cashReceived = 0.0;
      double credit = 0.0;
      double salesTotal = 0.0;

      for (var sale in sales) {
        double paid = (sale['amountPaid'] as num).toDouble();
        double total = (sale['total'] as num).toDouble();
        cashReceived += paid;
        credit += (total - paid);
        salesTotal += total;
      }

      double expensesTotal = expenses.fold(0.0, (sum, e) => sum + (e['amount'] as num).toDouble());

      setState(() {
        totalSales = salesTotal;
        cashSales = cashReceived;
        creditSales = credit;
        totalExpenses = expensesTotal;

        expectedCash = openingCash + cashSales - totalExpenses;
        physicalCash = double.tryParse(physicalCashController.text) ?? 0.0;
        difference = physicalCash - expectedCash;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint("Error loading report: $e");
    }
  }

  Future<void> _saveClosing() async {
    // Logic to save closing state to DB could go here
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Closing saved! Difference: ${currencyFormat.format(difference)}'),
        backgroundColor: difference.abs() < 10 ? Colors.green : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Daily Closing Report'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Date Selector
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Color(0xFF009688)),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('dd MMMM yyyy').format(selectedDate),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() => selectedDate = picked);
                                _loadReport();
                              }
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Change'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Opening Cash
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Opening Cash (from yesterday)',
                          prefixText: 'Rs. ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (v) {
                          openingCash = double.tryParse(v) ?? 0.0;
                          _loadReport();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Summary Cards
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    childAspectRatio: 1.8,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: [
                      _summaryCard('Total Sales', totalSales, Colors.blue),
                      _summaryCard('Cash Received', cashSales, Colors.green),
                      _summaryCard('Credit Sales', creditSales, Colors.orange),
                      _summaryCard('Expenses', totalExpenses, Colors.red),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Cash Calculation Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text('Cash Calculation', 
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))),
                          const Divider(height: 30),
                          _calcRow('Opening Cash', openingCash, null),
                          _calcRow('(+) Cash Sales', cashSales, Colors.green),
                          _calcRow('(-) Expenses', totalExpenses, Colors.red),
                          const Divider(thickness: 2),
                          _calcRow('Expected Cash', expectedCash, null, isBold: true),
                          const SizedBox(height: 25),

                          // Physical Cash Entry
                          TextField(
                            controller: physicalCashController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'Physical Cash Counted',
                              prefixText: 'Rs. ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            onChanged: (v) {
                              setState(() {
                                physicalCash = double.tryParse(v) ?? 0.0;
                                difference = physicalCash - expectedCash;
                              });
                            },
                          ),
                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Difference', 
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, 
                                color: difference.abs() > 10 ? Colors.red : Colors.green)),
                              Text(
                                currencyFormat.format(difference),
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, 
                                color: difference.abs() > 10 ? Colors.red : Colors.green),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Fixed Save Button using WidgetStateProperty to avoid the error
                  ElevatedButton.icon(
                    onPressed: _saveClosing,
                    icon: const Icon(Icons.save, size: 28, color: Colors.white),
                    label: const Text('Save Closing & Lock Day', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(
                        difference.abs() < 10 ? Colors.green[700] : Colors.orange[800],
                      ),
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(vertical: 16),
                      ),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
    );
  }

  Widget _calcRow(String label, double value, Color? color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            currencyFormat.format(value), 
            style: TextStyle(
              fontSize: 16, 
              color: color, 
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal
            )
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String title, double value, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              child: Text(currencyFormat.format(value), 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            ),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}