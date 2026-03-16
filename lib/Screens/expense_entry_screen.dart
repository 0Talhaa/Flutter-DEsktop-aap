// lib/screens/expense_entry_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/services/database_helper.dart';

class ExpenseEntryScreen extends StatefulWidget {
  const ExpenseEntryScreen({super.key});

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  DateTime selectedDate = DateTime.now();
  String? selectedCategory;
  String? selectedPaymentMethod;
  bool _isSaving = false;

  final TextEditingController amountController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController referenceController = TextEditingController();

  // Recent expenses list
  List<Map<String, dynamic>> recentExpenses = [];
  double todayTotal = 0;
  double monthTotal = 0;

  final List<Map<String, dynamic>> categories = [
    {'name': 'Rent', 'icon': Icons.home_outlined, 'color': Color(0xFF3B82F6)},
    {'name': 'Electricity Bill', 'icon': Icons.bolt_outlined, 'color': Color(0xFFF59E0B)},
    {'name': 'Water Bill', 'icon': Icons.water_drop_outlined, 'color': Color(0xFF06B6D4)},
    {'name': 'Internet Bill', 'icon': Icons.wifi_outlined, 'color': Color(0xFF8B5CF6)},
    {'name': 'Salary', 'icon': Icons.people_outline, 'color': Color(0xFF10B981)},
    {'name': 'Transport', 'icon': Icons.directions_car_outlined, 'color': Color(0xFFEF4444)},
    {'name': 'Stationery', 'icon': Icons.edit_outlined, 'color': Color(0xFFEC4899)},
    {'name': 'Cleaning', 'icon': Icons.cleaning_services_outlined, 'color': Color(0xFF14B8A6)},
    {'name': 'Repair & Maintenance', 'icon': Icons.build_outlined, 'color': Color(0xFFF97316)},
    {'name': 'Marketing', 'icon': Icons.campaign_outlined, 'color': Color(0xFF6366F1)},
    {'name': 'Medicine Purchase', 'icon': Icons.medical_services_outlined, 'color': Color(0xFF059669)},
    {'name': 'Miscellaneous', 'icon': Icons.more_horiz, 'color': Color(0xFF64748B)},
  ];

  final List<Map<String, dynamic>> paymentMethods = [
    {'name': 'Cash', 'icon': Icons.money},
    {'name': 'Bank Transfer', 'icon': Icons.account_balance},
    {'name': 'Cheque', 'icon': Icons.receipt_long},
    {'name': 'Online', 'icon': Icons.phone_android},
  ];

  final currencyFormat = NumberFormat.currency(locale: 'en_PK', symbol: 'Rs. ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadRecentExpenses();
    amountController.addListener(_updatePreview);
  }

  void _updatePreview() {
    setState(() {});
  }

  Future<void> _loadRecentExpenses() async {
    final today = DateTime.now();
    final startOfMonth = DateTime(today.year, today.month, 1);
    
    final expenses = await DatabaseHelper.instance.getExpensesInDateRange(
      startOfMonth.toIso8601String().substring(0, 10),
      today.toIso8601String().substring(0, 10),
    );

    double todaySum = 0;
    double monthSum = 0;
    final todayStr = today.toIso8601String().substring(0, 10);

    for (var exp in expenses) {
      monthSum += (exp['amount'] as num).toDouble();
      if ((exp['date'] as String).startsWith(todayStr)) {
        todaySum += (exp['amount'] as num).toDouble();
      }
    }

    setState(() {
      recentExpenses = expenses.take(5).toList();
      todayTotal = todaySum;
      monthTotal = monthSum;
    });
  }

  Future<void> _saveExpense() async {
    double amount = double.tryParse(amountController.text) ?? 0.0;
    
    if (amount <= 0) {
      _showErrorSnackBar('Please enter a valid amount');
      return;
    }

    if (selectedCategory == null) {
      _showErrorSnackBar('Please select a category');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final expenseMap = {
        'date': selectedDate.toIso8601String(),
        'category': selectedCategory,
        'amount': amount,
        'description': descriptionController.text.trim(),
        'paymentMethod': selectedPaymentMethod ?? 'Cash',
        'reference': referenceController.text.trim(),
      };

      await DatabaseHelper.instance.addExpense(expenseMap);
      await _loadRecentExpenses();

      if (mounted) {
        _showSuccessDialog(amount);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showErrorSnackBar('Error saving expense: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessDialog(double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Expense Saved!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Text(
                currencyFormat.format(amount),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
              ),
              Text(
                selectedCategory ?? '',
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: const Text('Done', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _clearForm();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Text('Add Another'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearForm() {
    amountController.clear();
    descriptionController.clear();
    referenceController.clear();
    setState(() {
      selectedCategory = null;
      selectedPaymentMethod = null;
      selectedDate = DateTime.now();
      _isSaving = false;
    });
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // Main Form Area
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(),
                  const SizedBox(height: 24),

                  // Quick Amount Buttons
                  _buildQuickAmountSection(),
                  const SizedBox(height: 20),

                  // Amount & Date Card
                  _buildAmountDateCard(),
                  const SizedBox(height: 20),

                  // Category Selection
                  _buildCategoryCard(),
                  const SizedBox(height: 20),

                  // Payment & Description Card
                  _buildPaymentDescriptionCard(),
                  const SizedBox(height: 24),

                  // Action Buttons
                  _buildActionButtons(),
                ],
              ),
            ),
          ),

          // Right Side Panel
          Container(
            width: 340,
            margin: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Summary Card
                _buildSummaryCard(),
                const SizedBox(height: 20),
                // Preview Card
                _buildPreviewCard(),
                const SizedBox(height: 20),
                // Recent Expenses
                Expanded(child: _buildRecentExpensesCard()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.receipt_long_outlined, color: Color(0xFFEF4444), size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add New Expense',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Record business expenses and track spending',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: _clearForm,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Reset'),
          style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildQuickAmountSection() {
    final quickAmounts = [100, 500, 1000, 2000, 5000, 10000];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on, size: 18, color: const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              const Text(
                'Quick Amount',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickAmounts.map((amount) {
              final isSelected = amountController.text == amount.toString();
              return InkWell(
                onTap: () {
                  amountController.text = amount.toString();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEF4444) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    'Rs. $amount',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountDateCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.attach_money, color: Color(0xFFEF4444), size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Amount & Date',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Amount Field
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'Amount',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                          ),
                          Text(' *', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 24),
                          prefixText: 'Rs. ',
                          prefixStyle: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFFEF2F2),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFFECACA)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFFECACA)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Date Picker
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Date',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFFEF4444),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() => selectedDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey.shade500),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  DateFormat('dd MMM').format(selectedDate),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.category_outlined, color: Color(0xFF8B5CF6), size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Select Category',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
                const Text(' *', style: TextStyle(color: Color(0xFFEF4444), fontSize: 14)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.3,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = selectedCategory == cat['name'];

                return InkWell(
                  onTap: () => setState(() => selectedCategory = cat['name']),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? (cat['color'] as Color).withOpacity(0.1) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? (cat['color'] as Color) : const Color(0xFFE2E8F0),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          cat['icon'] as IconData,
                          size: 22,
                          color: isSelected ? cat['color'] as Color : Colors.grey.shade500,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cat['name'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? cat['color'] as Color : Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDescriptionCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description_outlined, color: Color(0xFF10B981), size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Payment Details',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Payment Method
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Method',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: paymentMethods.map((method) {
                              final isSelected = selectedPaymentMethod == method['name'];
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: InkWell(
                                    onTap: () => setState(() => selectedPaymentMethod = method['name']),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF10B981).withOpacity(0.1) : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            method['icon'] as IconData,
                                            size: 18,
                                            color: isSelected ? const Color(0xFF10B981) : Colors.grey.shade500,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            method['name'] as String,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                              color: isSelected ? const Color(0xFF10B981) : Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Reference Number
                    Expanded(
                      child: _buildTextField(
                        controller: referenceController,
                        label: 'Reference / Receipt No.',
                        hint: 'e.g., Bill-001',
                        icon: Icons.tag_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Description
                _buildTextField(
                  controller: descriptionController,
                  label: 'Description / Notes',
                  hint: 'Add details about this expense...',
                  icon: Icons.notes_outlined,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveExpense,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(_isSaving ? 'Saving...' : 'Save Expense'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFF97316)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Expense Summary',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem('Today', currencyFormat.format(todayTotal)),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _buildSummaryItem('This Month', currencyFormat.format(monthTotal)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildPreviewCard() {
    double amount = double.tryParse(amountController.text) ?? 0;
    Map<String, dynamic>? selectedCat = selectedCategory != null
        ? categories.firstWhere((c) => c['name'] == selectedCategory, orElse: () => categories.last)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: const [
                Icon(Icons.preview_outlined, size: 16, color: Color(0xFF64748B)),
                SizedBox(width: 8),
                Text(
                  'Preview',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Category Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: selectedCat != null
                        ? (selectedCat['color'] as Color).withOpacity(0.1)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(
                    selectedCat != null ? selectedCat['icon'] as IconData : Icons.receipt_long_outlined,
                    color: selectedCat != null ? selectedCat['color'] as Color : Colors.grey.shade400,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  selectedCategory ?? 'Select Category',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selectedCategory != null ? const Color(0xFF1E293B) : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  amount > 0 ? currencyFormat.format(amount) : 'Rs. 0',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: amount > 0 ? const Color(0xFFEF4444) : Colors.grey.shade300,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('dd MMMM yyyy').format(selectedDate),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                if (descriptionController.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      descriptionController.text,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentExpensesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_outlined, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                const Text(
                  'Recent Expenses',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                ),
                const Spacer(),
                Text(
                  '${recentExpenses.length} items',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Expanded(
            child: recentExpenses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text(
                          'No recent expenses',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: recentExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = recentExpenses[index];
                      final cat = categories.firstWhere(
                        (c) => c['name'] == expense['category'],
                        orElse: () => categories.last,
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: (cat['color'] as Color).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(cat['icon'] as IconData, size: 16, color: cat['color'] as Color),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    expense['category'] ?? 'Expense',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    DateFormat('dd MMM').format(DateTime.parse(expense['date'])),
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              currencyFormat.format(expense['amount']),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFEF4444),
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
}