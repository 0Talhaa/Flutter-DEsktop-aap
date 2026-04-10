// lib/screens/supplier_payment_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/services/database_helper.dart';
import 'package:medical_app/models/supplier.dart';

class SupplierPaymentScreen extends StatefulWidget {
  final Supplier? supplier;

  const SupplierPaymentScreen({super.key, this.supplier});

  @override
  State<SupplierPaymentScreen> createState() => _SupplierPaymentScreenState();
}

class _SupplierPaymentScreenState extends State<SupplierPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  Supplier? _selectedSupplier;
  DateTime _selectedDate = DateTime.now();
  String _paymentMethod = 'Cash';
  bool _isSaving = false;

  final List<String> _paymentMethods = [
    'Cash',
    'Bank Transfer',
    'Cheque',
    'Credit Card',
    'Debit Card',
    'Online Payment',
  ];

  @override
  void initState() {
    super.initState();
    _selectedSupplier = widget.supplier;
    if (_selectedSupplier != null) {
      _loadSupplierBalance();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSupplierBalance() async {
    if (_selectedSupplier != null) {
      // Refresh supplier data to get current balance
      final supplier = await DatabaseHelper.instance.getSupplierById(_selectedSupplier!.id!);
      if (supplier != null && mounted) {
        setState(() {
          _selectedSupplier = supplier;
        });
      }
    }
  }

  Future<double> _calculateCurrentBalance() async {
    if (_selectedSupplier == null) return 0.0;

    final db = await DatabaseHelper.instance.database;

    // Get opening balance
    double openingBalance = _selectedSupplier!.openingBalance;

    // Get total purchases
    final purchasesResult = await db.rawQuery(
      'SELECT COALESCE(SUM(totalAmount), 0) as totalPurchases FROM purchases WHERE supplierId = ?',
      [_selectedSupplier!.id],
    );
    double totalPurchases = (purchasesResult.first['totalPurchases'] as num?)?.toDouble() ?? 0.0;

    // Get total payments made with purchases
    final purchasePaymentResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amountPaid), 0) as totalPaid FROM purchases WHERE supplierId = ?',
      [_selectedSupplier!.id],
    );
    double totalPurchasesPaid = (purchasePaymentResult.first['totalPaid'] as num?)?.toDouble() ?? 0.0;

    // Get separate payments
    final paymentsResult = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as totalPayments FROM supplier_payments WHERE supplierId = ?',
      [_selectedSupplier!.id],
    );
    double totalSeparatePayments = (paymentsResult.first['totalPayments'] as num?)?.toDouble() ?? 0.0;

    // Current Balance = Opening Balance + Total Purchases - Purchase Payments - Separate Payments
    return openingBalance + totalPurchases - totalPurchasesPaid - totalSeparatePayments;
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSupplier == null) {
      _showErrorSnackBar('Please select a supplier');
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      _showErrorSnackBar('Please enter a valid amount');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Add payment record
      await DatabaseHelper.instance.addSupplierPayment(
        supplierId: _selectedSupplier!.id!,
        supplierName: _selectedSupplier!.name,
        amount: amount,
        date: _selectedDate,
        paymentMethod: _paymentMethod,
        reference: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      // Calculate new balance
      final currentBalance = await _calculateCurrentBalance();

      if (mounted) {
        _showSuccessDialog(amount, currentBalance);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        _showErrorSnackBar('Error saving payment: $e');
      }
    }
  }

  void _showSuccessDialog(double amount, double newBalance) {
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
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Color(0xFF3B82F6), size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment Made!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Rs. ${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'to ${_selectedSupplier!.name}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Remaining Balance:',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    Text(
                      'Rs. ${newBalance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: newBalance > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context, true);
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
                        backgroundColor: const Color(0xFF3B82F6),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Text('Add Another', style: TextStyle(color: Colors.white)),
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _clearForm() {
    _amountController.clear();
    _referenceController.clear();
    _notesController.clear();
    _selectedDate = DateTime.now();
    _paymentMethod = 'Cash';
    setState(() {
      _isSaving = false;
      if (widget.supplier == null) {
        _selectedSupplier = null;
      }
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3B82F6),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectSupplier() async {
    final suppliers = await DatabaseHelper.instance.getAllSuppliers();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          height: 600,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.business_outlined, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 12),
                  const Text(
                    'Select Supplier',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: suppliers.length,
                  itemBuilder: (context, index) {
                    final supplier = suppliers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF3B82F6).withOpacity(0.1),
                        child: Text(
                          supplier.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      title: Text(
                        supplier.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(supplier.phone),
                      trailing: supplier.openingBalance > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Rs. ${supplier.openingBalance.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedSupplier = supplier;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
        ),
        title: const Text(
          'Supplier Payment',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Row(
        children: [
          // Main Form
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildSupplierSelectionCard(),
                    const SizedBox(height: 20),
                    _buildPaymentDetailsCard(),
                    const SizedBox(height: 20),
                    _buildAdditionalInfoCard(),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),

          // Side Panel
          if (_selectedSupplier != null)
            Container(
              width: 320,
              margin: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildSupplierInfoCard(),
                  const SizedBox(height: 20),
                  _buildBalanceBreakdownCard(),
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
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.payment_outlined,
            color: Color(0xFF3B82F6),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Make Payment',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Record payment made to supplier',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSupplierSelectionCard() {
    return _buildSectionCard(
      title: 'Supplier Information',
      icon: Icons.business_outlined,
      iconColor: const Color(0xFF3B82F6),
      child: _selectedSupplier == null
          ? _buildSupplierSelector()
          : _buildSelectedSupplierInfo(),
    );
  }

  Widget _buildSupplierSelector() {
    return InkWell(
      onTap: _selectSupplier,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0), width: 2, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.add_business_outlined, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Supplier',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Choose supplier to make payment to',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedSupplierInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF3B82F6),
            child: Text(
              _selectedSupplier!.name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedSupplier!.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _selectedSupplier!.phone,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          if (widget.supplier == null)
            IconButton(
              onPressed: _selectSupplier,
              icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF3B82F6)),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailsCard() {
    return _buildSectionCard(
      title: 'Payment Details',
      icon: Icons.account_balance_wallet_outlined,
      iconColor: const Color(0xFF10B981),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _amountController,
                  label: 'Amount',
                  hint: '0.00',
                  icon: Icons.attach_money_outlined,
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  prefix: 'Rs.',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Amount is required';
                    final amount = double.tryParse(v);
                    if (amount == null || amount <= 0) return 'Enter valid amount';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildDatePicker()),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildPaymentMethodDropdown()),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _referenceController,
                  label: 'Reference No. (Optional)',
                  hint: 'Cheque/Transaction #',
                  icon: Icons.numbers_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoCard() {
    return _buildSectionCard(
      title: 'Additional Information',
      icon: Icons.note_outlined,
      iconColor: const Color(0xFFF59E0B),
      child: _buildTextField(
        controller: _notesController,
        label: 'Notes (Optional)',
        hint: 'Add any additional notes...',
        icon: Icons.edit_note_outlined,
        maxLines: 3,
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
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
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    String? prefix,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
              ),
            ),
            if (isRequired)
              const Text(' *', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13),
          inputFormatters: keyboardType == TextInputType.number
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
              : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
            prefixText: prefix != null ? '$prefix ' : null,
            prefixStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13),
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
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            errorStyle: const TextStyle(fontSize: 11),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _selectDate,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey.shade500),
                const SizedBox(width: 12),
                Text(
                  DateFormat('dd MMM yyyy').format(_selectedDate),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonFormField<String>(
            value: _paymentMethod,
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade500, size: 20),
            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.payment_outlined, size: 18, color: Colors.grey.shade500),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: InputBorder.none,
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(8),
            items: _paymentMethods
                .map((method) => DropdownMenuItem(
                      value: method,
                      child: Text(method, style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _paymentMethod = value);
              }
            },
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
            onPressed: _isSaving ? null : _savePayment,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline, size: 18),
            label: Text(_isSaving ? 'Saving...' : 'Make Payment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
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

  Widget _buildSupplierInfoCard() {
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
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: Text(
                    _selectedSupplier!.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _selectedSupplier!.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedSupplier!.phone,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
              Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_selectedSupplier!.email != null) ...[
                  _buildInfoRow(Icons.email_outlined, _selectedSupplier!.email!),
                  const SizedBox(height: 12),
                ],
                if (_selectedSupplier!.company != null) ...[
                  _buildInfoRow(Icons.business_outlined, _selectedSupplier!.company!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceBreakdownCard() {
    return FutureBuilder<double>(
      future: _calculateCurrentBalance(),
      builder: (context, snapshot) {
        final currentBalance = snapshot.data ?? 0.0;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  children: const [
                    Icon(Icons.account_balance_outlined, size: 18, color: Color(0xFF64748B)),
                    SizedBox(width: 8),
                    Text(
                      'Balance Details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildBalanceRow(
                      'Opening Balance',
                      _selectedSupplier!.openingBalance,
                      const Color(0xFF64748B),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    _buildBalanceRow(
                      'Current Payable',
                      currentBalance,
                      currentBalance > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                      isTotal: true,
                    ),
                    if (_amountController.text.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      _buildBalanceRow(
                        'After Payment',
                        currentBalance - (double.tryParse(_amountController.text) ?? 0),
                        const Color(0xFF10B981),
                        isTotal: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBalanceRow(String label, double amount, Color color, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 13 : 12,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
            color: isTotal ? const Color(0xFF1E293B) : const Color(0xFF64748B),
          ),
        ),
        Text(
          'Rs. ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 15 : 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}