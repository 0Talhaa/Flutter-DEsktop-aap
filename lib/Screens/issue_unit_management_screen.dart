// lib/screens/issue_unit_management_screen.dart

import 'package:flutter/material.dart';
import 'package:medical_app/models/issue_unit.dart';
import 'package:medical_app/services/database_helper.dart';

class IssueUnitManagementScreen extends StatefulWidget {
  const IssueUnitManagementScreen({super.key});

  @override
  State<IssueUnitManagementScreen> createState() => _IssueUnitManagementScreenState();
}

class _IssueUnitManagementScreenState extends State<IssueUnitManagementScreen> {
  List<IssueUnit> units = [];
  List<IssueUnit> filteredUnits = [];
  bool isLoading = true;
  String searchQuery = '';
  
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<void> _loadUnits() async {
    setState(() => isLoading = true);
    try {
      final result = await DatabaseHelper.instance.getAllIssueUnits(activeOnly: false);
      setState(() {
        units = result;
        filteredUnits = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Failed to load units: $e');
    }
  }

  void _filterUnits(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredUnits = units;
      } else {
        filteredUnits = units
            .where((u) =>
                u.name.toLowerCase().contains(query.toLowerCase()) ||
                (u.abbreviation?.toLowerCase().contains(query.toLowerCase()) ?? false))
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
        title: const Text('Issue Unit Management'),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUnits, tooltip: 'Refresh'),
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
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.05),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.straighten, color: Color(0xFF8B5CF6)),
                        const SizedBox(width: 8),
                        const Text('Issue Units', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFF8B5CF6), borderRadius: BorderRadius.circular(20)),
                          child: Text('${filteredUnits.length} items', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                  // Search
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: searchController,
                      onChanged: _filterUnits,
                      decoration: InputDecoration(
                        hintText: 'Search units...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () { searchController.clear(); _filterUnits(''); })
                            : null,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                  ),

                  // List
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filteredUnits.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.straighten_outlined, size: 64, color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    Text(searchQuery.isEmpty ? 'No units found' : 'No results for "$searchQuery"', style: TextStyle(color: Colors.grey.shade600)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: filteredUnits.length,
                                itemBuilder: (context, index) {
                                  final unit = filteredUnits[index];
                                  final isActive = unit.isActive == 1;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
                                    child: ListTile(
                                      leading: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: isActive ? const Color(0xFF8B5CF6).withOpacity(0.1) : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            unit.abbreviation ?? unit.name.substring(0, 2).toUpperCase(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isActive ? const Color(0xFF8B5CF6) : Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        unit.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isActive ? const Color(0xFF1E293B) : Colors.grey,
                                          decoration: isActive ? null : TextDecoration.lineThrough,
                                        ),
                                      ),
                                      subtitle: unit.abbreviation != null
                                          ? Text('Abbreviation: ${unit.abbreviation}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
                                          : null,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (!isActive)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                                              child: Text('Inactive', style: TextStyle(fontSize: 10, color: Colors.red.shade700)),
                                            ),
                                          const SizedBox(width: 8),
                                          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), color: Colors.blue, onPressed: () => _showEditDialog(unit)),
                                          IconButton(
                                            icon: Icon(isActive ? Icons.delete_outline : Icons.restore, size: 20),
                                            color: isActive ? Colors.red : Colors.green,
                                            onPressed: () => _toggleStatus(unit),
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

          // Right Panel - Add
          Container(
            width: 400,
            margin: const EdgeInsets.all(16),
            child: _AddUnitPanel(onSaved: _loadUnits),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(IssueUnit unit) {
    final nameController = TextEditingController(text: unit.name);
    final abbrController = TextEditingController(text: unit.abbreviation ?? '');
    final descController = TextEditingController(text: unit.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.edit, color: Color(0xFF8B5CF6))),
            const SizedBox(width: 12),
            const Text('Edit Unit'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Unit Name *', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: abbrController, decoration: const InputDecoration(labelText: 'Abbreviation', border: OutlineInputBorder(), hintText: 'e.g., Pc, Str, Tab')),
              const SizedBox(height: 16),
              TextField(controller: descController, maxLines: 2, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) { _showError('Name is required'); return; }
              final updated = unit.copyWith(name: nameController.text.trim(), abbreviation: abbrController.text.trim(), description: descController.text.trim());
              await DatabaseHelper.instance.updateIssueUnit(updated);
              Navigator.pop(context);
              _loadUnits();
              _showSuccess('Unit updated successfully');
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _toggleStatus(IssueUnit unit) async {
    final isActive = unit.isActive == 1;
    if (isActive) {
      await DatabaseHelper.instance.deleteIssueUnit(unit.id!);
      _showSuccess('Unit deactivated');
    } else {
      final updated = unit.copyWith(isActive: 1);
      await DatabaseHelper.instance.updateIssueUnit(updated);
      _showSuccess('Unit activated');
    }
    _loadUnits();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

class _AddUnitPanel extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddUnitPanel({required this.onSaved});

  @override
  State<_AddUnitPanel> createState() => _AddUnitPanelState();
}

class _AddUnitPanelState extends State<_AddUnitPanel> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final abbrController = TextEditingController();
  final descController = TextEditingController();
  bool isSaving = false;

  Future<void> _saveUnit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => isSaving = true);

    try {
      final unit = IssueUnit(
        name: nameController.text.trim(),
        abbreviation: abbrController.text.trim().isNotEmpty ? abbrController.text.trim() : null,
        description: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
      );
      await DatabaseHelper.instance.addIssueUnit(unit);
      nameController.clear();
      abbrController.clear();
      descController.clear();
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unit added successfully!'), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => isSaving = false);
    }
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
              gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)]),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.add, color: Colors.white)),
                const SizedBox(width: 12),
                const Text('Add New Unit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
                    const Text('Unit Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: nameController,
                      decoration: _inputDecoration('Enter unit name', Icons.straighten),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('Abbreviation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: abbrController,
                      decoration: _inputDecoration('e.g., Pc, Str, Tab', Icons.short_text),
                    ),
                    const SizedBox(height: 16),
                    const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: descController,
                      maxLines: 3,
                      decoration: _inputDecoration('Enter description', null),
                    ),
                    const SizedBox(height: 24),

                    // Common Units Suggestions
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Quick Add:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _quickAddChip('Tablet', 'Tab'),
                              _quickAddChip('Capsule', 'Cap'),
                              _quickAddChip('Strip', 'Str'),
                              _quickAddChip('Bottle', 'Btl'),
                              _quickAddChip('Sachet', 'Sch'),
                              _quickAddChip('Vial', 'Vl'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () { nameController.clear(); abbrController.clear(); descController.clear(); },
                            child: const Text('Clear'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: isSaving ? null : _saveUnit,
                            icon: isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                            label: Text(isSaving ? 'Saving...' : 'Save Unit'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white),
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

  Widget _quickAddChip(String name, String abbr) {
    return ActionChip(
      label: Text('$name ($abbr)', style: const TextStyle(fontSize: 11)),
      onPressed: () {
        nameController.text = name;
        abbrController.text = abbr;
      },
      backgroundColor: Colors.white,
      side: BorderSide(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData? icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 2)),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    abbrController.dispose();
    descController.dispose();
    super.dispose();
  }
}