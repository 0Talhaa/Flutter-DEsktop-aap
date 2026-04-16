// lib/widgets/print_settings_dialog.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medical_app/services/printer_service.dart';

class PrintSettingsDialog extends StatefulWidget {
  const PrintSettingsDialog({super.key});

  @override
  State<PrintSettingsDialog> createState() => _PrintSettingsDialogState();
}

class _PrintSettingsDialogState extends State<PrintSettingsDialog> {
  final _printerService = PrinterService();

  // ── State ──────────────────────────────────────────────
  List<UsbPrinterInfo> _printers = [];
  UsbPrinterInfo? _selectedPrinter;
  bool _loading = true;
  bool _connecting = false;
  bool _testPrinting = false;
  String? _statusMessage;
  Color _statusColor = Colors.grey;

  // ── Shop controllers ──────────────────────────────────
  final _shopNameCtrl    = TextEditingController();
  final _shopAddressCtrl = TextEditingController();
  final _shopPhoneCtrl   = TextEditingController();
  final _shopTaglineCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _scanPrinters();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shopNameCtrl.text    = prefs.getString('shop_name')    ?? 'MEDICAL STORE';
      _shopAddressCtrl.text = prefs.getString('shop_address') ?? '123 Main Street, City';
      _shopPhoneCtrl.text   = prefs.getString('shop_phone')   ?? '0300-1234567';
      _shopTaglineCtrl.text = prefs.getString('shop_tagline') ?? 'Thank you for your purchase!';
    });
  }

  Future<void> _scanPrinters() async {
    setState(() {
      _loading = true;
      _statusMessage = 'Scanning USB printers…';
      _statusColor = Colors.blue;
    });

    final printers = await _printerService.discoverPrinters();

    setState(() {
      _printers = printers;
      _loading = false;

      if (printers.isEmpty) {
        _statusMessage = '❌ No USB printers found.\nMake sure printer is ON and plugged in.';
        _statusColor = Colors.orange;
      } else {
        _statusMessage = '✅ Found ${printers.length} USB printer(s)';
        _statusColor = Colors.green;

        // Auto-select if only one
        if (printers.length == 1) {
          _selectedPrinter = printers.first;
        }
      }
    });
  }

  Future<void> _connectPrinter() async {
    if (_selectedPrinter == null) {
      setState(() {
        _statusMessage = '⚠️ Please select a printer first';
        _statusColor = Colors.orange;
      });
      return;
    }

    setState(() {
      _connecting = true;
      _statusMessage = 'Connecting to ${_selectedPrinter!.name}…';
      _statusColor = Colors.blue;
    });

    final success = await _printerService.connect(_selectedPrinter!);

    setState(() {
      _connecting = false;
      if (success) {
        _statusMessage = '✅ Connected to ${_selectedPrinter!.name}';
        _statusColor = Colors.green;
      } else {
        _statusMessage = '❌ Connection failed. Try again.';
        _statusColor = Colors.red;
      }
    });
  }

  Future<void> _testPrint() async {
    if (!_printerService.isConnected) {
      setState(() {
        _statusMessage = '⚠️ Connect to a printer first';
        _statusColor = Colors.orange;
      });
      return;
    }

    setState(() {
      _testPrinting = true;
      _statusMessage = '🖨️ Sending test print…';
      _statusColor = Colors.blue;
    });

    final success = await _printerService.testPrint();

    setState(() {
      _testPrinting = false;
      if (success) {
        _statusMessage = '✅ Test print sent!';
        _statusColor = Colors.green;
      } else {
        _statusMessage = '❌ Test print failed';
        _statusColor = Colors.red;
      }
    });
  }

  Future<void> _saveAndClose() async {
    // Auto-connect if selected but not connected
    if (_selectedPrinter != null && !_printerService.isConnected) {
      await _connectPrinter();
      if (!_printerService.isConnected) return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shop_name',    _shopNameCtrl.text);
    await prefs.setString('shop_address', _shopAddressCtrl.text);
    await prefs.setString('shop_phone',   _shopPhoneCtrl.text);
    await prefs.setString('shop_tagline', _shopTaglineCtrl.text);

    if (_selectedPrinter != null) {
      await prefs.setString('selected_printer_name', _selectedPrinter!.name);
      await prefs.setString('selected_printer_id',   _selectedPrinter!.identifier);
    }

    if (mounted) {
      Navigator.pop(context, {
        'printer': _selectedPrinter?.name,
        'connected': _printerService.isConnected,
        'shopName': _shopNameCtrl.text,
        'shopAddress': _shopAddressCtrl.text,
        'shopPhone': _shopPhoneCtrl.text,
        'shopTagline': _shopTaglineCtrl.text,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 420,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.usb, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'USB Printer Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ── Content ─────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Status ───────────────────────────
                    if (_statusMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.1),
                          border: Border.all(
                              color: _statusColor.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            color: _statusColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // ── Connection indicator ────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: _printerService.isConnected
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _printerService.isConnected
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _printerService.isConnected
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: _printerService.isConnected
                                ? Colors.green
                                : Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _printerService.isConnected
                                  ? 'Connected: ${_printerService.connectedPrinterName}'
                                  : 'Not connected',
                              style: TextStyle(
                                fontSize: 12,
                                color: _printerService.isConnected
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Printer dropdown ────────────────
                    const Text(
                      'Select USB Printer',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),

                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(strokeWidth: 2),
                              SizedBox(height: 8),
                              Text('Scanning USB devices…',
                                  style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<UsbPrinterInfo>(
                            value: _selectedPrinter,
                            hint: Text(
                              _printers.isEmpty
                                  ? 'No USB printers found'
                                  : 'Select printer…',
                              style: TextStyle(
                                fontSize: 13,
                                color: _printers.isEmpty
                                    ? Colors.red
                                    : Colors.grey,
                              ),
                            ),
                            isExpanded: true,
                            items: _printers.map((p) {
                              return DropdownMenuItem<UsbPrinterInfo>(
                                value: p,
                                child: Row(
                                  children: [
                                    const Icon(Icons.usb,
                                        size: 18, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(p.name,
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                          Text(
                                            p.identifier,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedPrinter = v),
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),

                    // ── Action buttons ──────────────────
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _loading ? null : _scanPrinters,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Refresh',
                              style: TextStyle(fontSize: 12)),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: (_connecting || _selectedPrinter == null)
                              ? null
                              : _connectPrinter,
                          icon: _connecting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.link, size: 16),
                          label: Text(
                            _connecting ? 'Connecting…' : 'Connect',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          onPressed:
                              (_testPrinting || !_printerService.isConnected)
                                  ? null
                                  : _testPrint,
                          icon: _testPrinting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.print, size: 16),
                          label: Text(
                            _testPrinting ? 'Printing…' : 'Test',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    // ── Shop Details ────────────────────
                    const Text(
                      'Shop Details',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),

                    _buildField('Shop Name', _shopNameCtrl),
                    const SizedBox(height: 10),
                    _buildField('Address', _shopAddressCtrl),
                    const SizedBox(height: 10),
                    _buildField('Phone', _shopPhoneCtrl),
                    const SizedBox(height: 10),
                    _buildField('Tagline', _shopTaglineCtrl),
                  ],
                ),
              ),
            ),

            // ── Bottom buttons ──────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  if (_printerService.isConnected)
                    TextButton.icon(
                      onPressed: () async {
                        await _printerService.disconnect();
                        setState(() {
                          _statusMessage = 'Disconnected';
                          _statusColor = Colors.grey;
                        });
                      },
                      icon: const Icon(Icons.link_off,
                          size: 16, color: Colors.red),
                      label: const Text('Disconnect',
                          style:
                              TextStyle(fontSize: 12, color: Colors.red)),
                    ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saveAndClose,
                    icon: const Icon(Icons.save, size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    label: const Text('Save & Connect'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 12),
        isDense: true,
      ),
    );
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _shopAddressCtrl.dispose();
    _shopPhoneCtrl.dispose();
    _shopTaglineCtrl.dispose();
    super.dispose();
  }
}