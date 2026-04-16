// lib/screens/add_customer_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medical_app/Screens/dashboardScreen.dart';
import 'package:medical_app/models/customer.dart';
import 'package:medical_app/services/database_helper.dart';

class AddCustomerScreen extends StatefulWidget {
  final Customer? customer;

  const AddCustomerScreen({super.key, this.customer});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _balanceController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _emailController;
  late TextEditingController _cnicController;
  late TextEditingController _notesController;

  String? _selectedCustomerType;

  final List<String> customerTypes = [
    'Regular',
    'Wholesale',
    'Retail',
    'Hospital',
    'Clinic',
    'Pharmacy',
    'Other',
  ];

  final List<String> cities = [
    'Karachi',
    'Lahore',
    'Islamabad',
    'Rawalpindi',
    'Faisalabad',
    'Multan',
    'Peshawar',
    'Quetta',
    'Hyderabad',
    'Sialkot',
    'Other',
  ];

  bool get isEditMode => widget.customer != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController =
        TextEditingController(text: widget.customer?.phone ?? '');
    _balanceController = TextEditingController(
      text: widget.customer?.openingBalance.toStringAsFixed(0) ?? '0',
    );
    _addressController =
        TextEditingController(text: widget.customer?.address ?? '');
    _cityController = TextEditingController(text: widget.customer?.city ?? '');
    _emailController =
        TextEditingController(text: widget.customer?.email ?? '');
    _cnicController = TextEditingController(text: widget.customer?.cnic ?? '');
    _notesController = TextEditingController();

    // Listen to changes for preview
    _nameController.addListener(_updatePreview);
    _phoneController.addListener(_updatePreview);
    _balanceController.addListener(_updatePreview);
    _cityController.addListener(_updatePreview);
  }

  void _updatePreview() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _balanceController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _emailController.dispose();
    _cnicController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final customer = Customer(
        id: widget.customer?.id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        openingBalance: double.tryParse(_balanceController.text) ?? 0.0,
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        city: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        cnic: _cnicController.text.trim().isEmpty
            ? null
            : _cnicController.text.trim(),
      );

      if (isEditMode) {
        await DatabaseHelper.instance.updateCustomer(customer);
      } else {
        await DatabaseHelper.instance.addCustomer(customer);
      }

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
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
                child: const Icon(Icons.check_circle,
                    color: Color(0xFF10B981), size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                isEditMode ? 'Customer Updated!' : 'Customer Added!',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Text(
                _nameController.text,
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const PremiumDashboardScreen()));
                        // Navigator.pop(context, true);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: const Text('Done',
                          style: TextStyle(color: Color(0xFF64748B))),
                    ),
                  ),
                  if (!isEditMode) ...[
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: const Text('Add Another',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearForm() {
    _nameController.clear();
    _phoneController.clear();
    _balanceController.text = '0';
    _addressController.clear();
    _cityController.clear();
    _emailController.clear();
    _cnicController.clear();
    _notesController.clear();
    _selectedCustomerType = null;
    setState(() => _isSaving = false);
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(),
                    const SizedBox(height: 24),

                    // Basic Information Card
                    _buildSectionCard(
                      title: 'Basic Information',
                      icon: Icons.person_outline,
                      iconColor: const Color(0xFF3B82F6),
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: 'Customer Name',
                          hint: 'Enter full name',
                          icon: Icons.person_outline,
                          isRequired: true,
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Name is required'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _phoneController,
                                label: 'Phone Number',
                                hint: '03001234567',
                                icon: Icons.phone_outlined,
                                isRequired: true,
                                keyboardType: TextInputType.phone,
                                maxLength: 11,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Phone is required';
                                  }
                                  if (!RegExp(r'^[0-9]{11}$')
                                      .hasMatch(value.trim())) {
                                    return 'Enter valid 11-digit number';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _cnicController,
                                label: 'CNIC (Optional)',
                                hint: '12345-1234567-1',
                                icon: Icons.credit_card_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _emailController,
                                label: 'Email (Optional)',
                                hint: 'email@example.com',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildDropdown(
                                value: _selectedCustomerType,
                                label: 'Customer Type',
                                hint: 'Select type',
                                icon: Icons.category_outlined,
                                items: customerTypes,
                                onChanged: (v) =>
                                    setState(() => _selectedCustomerType = v),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Address Card
                    _buildSectionCard(
                      title: 'Address Details',
                      icon: Icons.location_on_outlined,
                      iconColor: const Color(0xFF8B5CF6),
                      children: [
                        _buildTextField(
                          controller: _addressController,
                          label: 'Shop / Business Address',
                          hint: 'Enter complete address',
                          icon: Icons.store_outlined,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildCityDropdown(),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: TextEditingController(),
                                label: 'Area / Sector',
                                hint: 'e.g., DHA Phase 5',
                                icon: Icons.map_outlined,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    const SizedBox(height: 20),

                    // Notes Card
                    _buildSectionCard(
                      title: 'Additional Notes',
                      icon: Icons.note_outlined,
                      iconColor: const Color(0xFFF59E0B),
                      children: [
                        _buildTextField(
                          controller: _notesController,
                          label: 'Notes (Optional)',
                          hint:
                              'Add any additional notes about this customer...',
                          icon: Icons.edit_note_outlined,
                          maxLines: 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    _buildActionButtons(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          // Right Side Panel
          Container(
            width: 320,
            margin: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Preview Card
                _buildPreviewCard(),
                const SizedBox(height: 20),
                // Quick Actions
                // _buildQuickActionsCard(),
                const SizedBox(height: 20),
                // Tips Card
                // Expanded(child: _buildTipsCard()),
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
            color: const Color(0xFF8B5CF6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isEditMode ? Icons.edit_outlined : Icons.person_add_outlined,
            color: const Color(0xFF8B5CF6),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditMode ? 'Edit Customer' : 'Add New Customer',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                letterSpacing: -0.3,
              ),
            ),
            Text(
              isEditMode
                  ? 'Update customer information'
                  : 'Fill in the details to register a new customer',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        const Spacer(),
        if (!isEditMode)
          TextButton.icon(
            onPressed: _clearForm,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reset'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
          ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
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
            child: Column(children: children),
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
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    String? prefix,
    String? suffix,
    int maxLines = 1,
    int? maxLength,
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
              const Text(' *',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          style: const TextStyle(fontSize: 13),
          inputFormatters: keyboardType == TextInputType.number
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
              : keyboardType == TextInputType.phone
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
            prefixText: prefix != null ? '$prefix ' : null,
            prefixStyle:
                const TextStyle(color: Color(0xFF475569), fontSize: 13),
            suffixText: suffix,
            suffixStyle:
                const TextStyle(color: Color(0xFF475569), fontSize: 13),
            counterText: '',
            filled: true,
            fillColor: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              borderSide:
                  const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
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

  Widget _buildDropdown({
    required String? value,
    required String label,
    required String hint,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
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
            value: value,
            hint: Text(hint,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down,
                color: Colors.grey.shade500, size: 20),
            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: InputBorder.none,
            ),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(8),
            items: items
                .map((item) => DropdownMenuItem(
                      value: item,
                      child: Text(item, style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildCityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'City',
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
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cityController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Enter or select city',
                    hintStyle:
                        TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    prefixIcon: Icon(Icons.location_city_outlined,
                        size: 18, color: Colors.grey.shade500),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade500),
                onSelected: (value) {
                  _cityController.text = value;
                },
                itemBuilder: (context) => cities
                    .map((city) => PopupMenuItem(
                          value: city,
                          child:
                              Text(city, style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceIndicator() {
    double balance = double.tryParse(_balanceController.text) ?? 0;
    bool hasBalance = balance > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasBalance ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasBalance ? const Color(0xFFFCD34D) : const Color(0xFF6EE7B7),
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasBalance
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            color:
                hasBalance ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
            size: 20,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasBalance
                    ? 'Customer has pending balance'
                    : 'No pending balance',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: hasBalance
                      ? const Color(0xFF92400E)
                      : const Color(0xFF065F46),
                ),
              ),
              if (hasBalance)
                Text(
                  'Rs. ${balance.toStringAsFixed(0)} outstanding',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB45309),
                  ),
                ),
            ],
          ),
        ],
      ),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveCustomer,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    isEditMode
                        ? Icons.save_outlined
                        : Icons.person_add_outlined,
                    size: 18),
            label: Text(_isSaving
                ? 'Saving...'
                : isEditMode
                    ? 'Update Customer'
                    : 'Save Customer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewCard() {
    String name =
        _nameController.text.isEmpty ? 'Customer Name' : _nameController.text;
    String phone =
        _phoneController.text.isEmpty ? '---' : _phoneController.text;
    String city = _cityController.text.isEmpty ? '---' : _cityController.text;
    double balance = double.tryParse(_balanceController.text) ?? 0;

    String initials = name.isNotEmpty
        ? name
            .split(' ')
            .map((e) => e.isNotEmpty ? e[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : 'CN';

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
              children: const [
                Icon(Icons.preview_outlined,
                    size: 18, color: Color(0xFF64748B)),
                SizedBox(width: 8),
                Text(
                  'Customer Preview',
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
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                    ),
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone_outlined,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      phone,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      city,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Balance',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: balance > 0
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Rs. ${balance.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: balance > 0
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Type',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    Text(
                      _selectedCustomerType ?? 'Regular',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildQuickActionsCard() {
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(12),
  //       border: Border.all(color: const Color(0xFFE2E8F0)),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         const Text(
  //           'Quick Actions',
  //           style: TextStyle(
  //             fontSize: 13,
  //             fontWeight: FontWeight.w600,
  //             color: Color(0xFF1E293B),
  //           ),
  //         ),
  //         const SizedBox(height: 12),
  //         _buildQuickActionButton(
  //           icon: Icons.phone_outlined,
  //           label: 'Call Customer',
  //           color: const Color(0xFF10B981),
  //           onTap: () {},
  //         ),
  //         const SizedBox(height: 8),
  //         _buildQuickActionButton(
  //           icon: Icons.message_outlined,
  //           label: 'Send SMS',
  //           color: const Color(0xFF3B82F6),
  //           onTap: () {},
  //         ),
  //         const SizedBox(height: 8),
  //         _buildQuickActionButton(
  //           icon: Icons.history_outlined,
  //           label: 'View History',
  //           color: const Color(0xFF8B5CF6),
  //           onTap: () {},
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, size: 12, color: color),
            ],
          ),
        ),
      ),
    );
  }

  // Widget _buildTipsCard() {
  //   return Container(
  //     decoration: BoxDecoration(
  //       color: const Color(0xFFEFF6FF),
  //       borderRadius: BorderRadius.circular(12),
  //       border: Border.all(color: const Color(0xFFBFDBFE)),
  //     ),
  //     child: Padding(
  //       padding: const EdgeInsets.all(16),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Row(
  //             children: [
  //               Container(
  //                 width: 28,
  //                 height: 28,
  //                 decoration: BoxDecoration(
  //                   color: const Color(0xFF3B82F6).withOpacity(0.2),
  //                   borderRadius: BorderRadius.circular(6),
  //                 ),
  //                 child: const Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFF3B82F6)),
  //               ),
  //               const SizedBox(width: 10),
  //               const Text(
  //                 'Quick Tips',
  //                 style: TextStyle(
  //                   fontSize: 13,
  //                   fontWeight: FontWeight.w600,
  //                   color: Color(0xFF1E40AF),
  //                 ),
  //               ),
  //             ],
  //           ),
  //           const SizedBox(height: 16),
  //           _buildTipItem('Add phone number for SMS notifications'),
  //           _buildTipItem('Set opening balance for credit customers'),
  //           _buildTipItem('Add address for delivery orders'),
  //           _buildTipItem('Use customer type for better reporting'),
  //           _buildTipItem('Email is useful for sending invoices'),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 14, color: Color(0xFF3B82F6)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF1E40AF), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
