// lib/widgets/print_settings_dialog.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medical_app/services/dot_matrix_print_service.dart';

class PrintSettingsDialog extends StatefulWidget {
  const PrintSettingsDialog({super.key});

  @override
  State<PrintSettingsDialog> createState() => _PrintSettingsDialogState();
}

class _PrintSettingsDialogState extends State<PrintSettingsDialog> {
  List<String> printers = [];
  String? selectedPrinter;
  bool loading = true;
  
  final shopNameController = TextEditingController(text: 'MEDICAL STORE');
  final shopAddressController = TextEditingController(text: '123 Main Street, City');
  final shopPhoneController = TextEditingController(text: '0300-1234567');

  @override
  void initState() {
    super.initState();
    _loadPrinters();
    _loadSettings();
  }

  Future<void> _loadPrinters() async {
    final list = await DotMatrixPrintService.getAvailablePrinters();
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      printers = list;
      selectedPrinter = prefs.getString('selected_printer');
      loading = false;
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      shopNameController.text = prefs.getString('shop_name') ?? 'MEDICAL STORE';
      shopAddressController.text = prefs.getString('shop_address') ?? '123 Main Street, City';
      shopPhoneController.text = prefs.getString('shop_phone') ?? '0300-1234567';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_printer', selectedPrinter ?? '');
    await prefs.setString('shop_name', shopNameController.text);
    await prefs.setString('shop_address', shopAddressController.text);
    await prefs.setString('shop_phone', shopPhoneController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.print, color: Color(0xFF3B82F6), size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Print Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Printer Selection
            const Text('Select Printer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            if (loading)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedPrinter,
                    hint: const Text('Select printer...'),
                    isExpanded: true,
                    items: printers.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p, style: const TextStyle(fontSize: 13)),
                    )).toList(),
                    onChanged: (v) => setState(() => selectedPrinter = v),
                  ),
                ),
              ),
            
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() => loading = true);
                _loadPrinters();
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh Printers', style: TextStyle(fontSize: 12)),
            ),
            
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            // Shop Details
            const Text('Shop Details (for Invoice)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            
            _buildTextField('Shop Name', shopNameController),
            const SizedBox(height: 12),
            _buildTextField('Address', shopAddressController),
            const SizedBox(height: 12),
            _buildTextField('Phone', shopPhoneController),
            
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _saveSettings();
                      if (mounted) {
                        Navigator.pop(context, {
                          'printer': selectedPrinter,
                          'shopName': shopNameController.text,
                          'shopAddress': shopAddressController.text,
                          'shopPhone': shopPhoneController.text,
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Save Settings'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
    );
  }

  @override
  void dispose() {
    shopNameController.dispose();
    shopAddressController.dispose();
    shopPhoneController.dispose();
    super.dispose();
  }
}