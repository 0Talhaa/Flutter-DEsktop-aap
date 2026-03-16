// lib/screens/brand_management_screen.dart

import 'package:flutter/material.dart';
import 'package:medical_app/models/brand.dart';
import 'package:medical_app/services/database_helper.dart';

class BrandManagementScreen extends StatefulWidget {
  const BrandManagementScreen({super.key});

  @override
  State<BrandManagementScreen> createState() => _BrandManagementScreenState();
}

class _BrandManagementScreenState extends State<BrandManagementScreen> {
  List<Brand> brands = [];
  List<Brand> filteredBrands = [];
  bool isLoading = true;
  String searchQuery = '';
  
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  Future<void> _loadBrands() async {
    setState(() => isLoading = true);
    try {
      final result = await DatabaseHelper.instance.getAllBrands(activeOnly: false);
      setState(() {
        brands = result;
        filteredBrands = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Failed to load brands: $e');
    }
  }

  void _filterBrands(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredBrands = brands;
      } else {
        filteredBrands = brands
            .where((b) => b.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Brand / Company Management'),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBrands,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Row(
        children: [
          // Left Panel - List
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.05),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.business, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        const Text(
                          'Brands / Companies',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${filteredBrands.length} items',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: searchController,
                      onChanged: _filterBrands,
                      decoration: InputDecoration(
                        hintText: 'Search brands...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  searchController.clear();
                                  _filterBrands('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  // List
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filteredBrands.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.business_outlined,
                                        size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    Text(
                                      searchQuery.isEmpty
                                          ? 'No brands found'
                                          : 'No results for "$searchQuery"',
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: filteredBrands.length,
                                itemBuilder: (context, index) {
                                  final brand = filteredBrands[index];
                                  final isActive = brand.isActive == 1;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(color: Colors.grey.shade200),
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? const Color(0xFF10B981).withOpacity(0.1)
                                              : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.business,
                                          color: isActive
                                              ? const Color(0xFF10B981)
                                              : Colors.grey,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        brand.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isActive ? const Color(0xFF1E293B) : Colors.grey,
                                          decoration: isActive ? null : TextDecoration.lineThrough,
                                        ),
                                      ),
                                      subtitle: brand.contactPerson != null
                                          ? Text(
                                              brand.contactPerson!,
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            )
                                          : null,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (!isActive)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Inactive',
                                                style: TextStyle(fontSize: 10, color: Colors.red.shade700),
                                              ),
                                            ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 20),
                                            color: Colors.blue,
                                            onPressed: () => _showEditDialog(brand),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              isActive ? Icons.delete_outline : Icons.restore,
                                              size: 20,
                                            ),
                                            color: isActive ? Colors.red : Colors.green,
                                            onPressed: () => _toggleStatus(brand),
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
            ),
          ),

          // Right Panel - Add New
          Container(
            width: 400,
            margin: const EdgeInsets.all(16),
            child: _AddBrandPanel(onSaved: _loadBrands),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Brand brand) {
    final nameController = TextEditingController(text: brand.name);
    final descController = TextEditingController(text: brand.description ?? '');
    final contactController = TextEditingController(text: brand.contactPerson ?? '');
    final phoneController = TextEditingController(text: brand.phone ?? '');
    final emailController = TextEditingController(text: brand.email ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit, color: Color(0xFF10B981)),
            ),
            const SizedBox(width: 12),
            const Text('Edit Brand'),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Brand Name *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contactController,
                  decoration: const InputDecoration(labelText: 'Contact Person', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                _showError('Name is required');
                return;
              }
              final updated = brand.copyWith(
                name: nameController.text.trim(),
                description: descController.text.trim(),
                contactPerson: contactController.text.trim(),
                phone: phoneController.text.trim(),
                email: emailController.text.trim(),
              );
              await DatabaseHelper.instance.updateBrand(updated);
              Navigator.pop(context);
              _loadBrands();
              _showSuccess('Brand updated successfully');
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _toggleStatus(Brand brand) async {
    final isActive = brand.isActive == 1;
    if (isActive) {
      await DatabaseHelper.instance.deleteBrand(brand.id!);
      _showSuccess('Brand deactivated');
    } else {
      final updated = brand.copyWith(isActive: 1);
      await DatabaseHelper.instance.updateBrand(updated);
      _showSuccess('Brand activated');
    }
    _loadBrands();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

class _AddBrandPanel extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddBrandPanel({required this.onSaved});

  @override
  State<_AddBrandPanel> createState() => _AddBrandPanelState();
}

class _AddBrandPanelState extends State<_AddBrandPanel> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final descController = TextEditingController();
  final contactController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();
  bool isSaving = false;

  Future<void> _saveBrand() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isSaving = true);

    try {
      final brand = Brand(
        name: nameController.text.trim(),
        description: descController.text.trim(),
        contactPerson: contactController.text.trim(),
        phone: phoneController.text.trim(),
        email: emailController.text.trim(),
        address: addressController.text.trim(),
      );
      await DatabaseHelper.instance.addBrand(brand);
      _clearForm();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brand added successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  void _clearForm() {
    nameController.clear();
    descController.clear();
    contactController.clear();
    phoneController.clear();
    emailController.clear();
    addressController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Text('Add New Brand', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Brand Name *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: nameController,
                      decoration: _inputDecoration('Enter brand name', Icons.business),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('Contact Person'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: contactController,
                      decoration: _inputDecoration('Enter contact person', Icons.person),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Phone'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: phoneController,
                                decoration: _inputDecoration('Phone', Icons.phone),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Email'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: emailController,
                                decoration: _inputDecoration('Email', Icons.email),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('Address'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: addressController,
                      maxLines: 2,
                      decoration: _inputDecoration('Enter address', Icons.location_on),
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('Description'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: descController,
                      maxLines: 3,
                      decoration: _inputDecoration('Enter description', null),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(onPressed: _clearForm, child: const Text('Clear')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: isSaving ? null : _saveBrand,
                            icon: isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                            label: Text(isSaving ? 'Saving...' : 'Save Brand'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)));
  }

  InputDecoration _inputDecoration(String hint, IconData? icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    contactController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    super.dispose();
  }
}