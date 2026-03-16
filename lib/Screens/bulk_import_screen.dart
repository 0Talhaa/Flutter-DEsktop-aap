// lib/screens/bulk_import_screen.dart
//
// Required packages (add to pubspec.yaml):
//   file_picker: ^6.1.1
//   excel: ^4.0.6        ← parses .xlsx files
//
// Then run: flutter pub get

import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/database_helper.dart';

// ─────────────────────────────────────────────────────────────
//  COLUMN MAPPING (row 1 = headers, data starts at row 2)
// ─────────────────────────────────────────────────────────────
//  A  itemName      *required*
//  B  itemCode
//  C  barcode
//  D  category
//  E  companyName
//  F  issueUnit
//  G  tradePrice    *required*
//  H  retailPrice   *required*
//  I  taxPercent
//  J  discountPercent
//  K  parLevel
//  L  stock
//  M  description

class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({super.key});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  // ── State ────────────────────────────────────────────────
  bool _isPicking = false;
  bool _isImporting = false;
  String? _fileName;
  List<_RowPreview> _rows = [];
  int _successCount = 0;
  int _errorCount = 0;
  String _statusMessage = '';

  final _accentColor = const Color(0xFF1565C0);

  // ── File picking ─────────────────────────────────────────
  Future<void> _pickAndParseFile() async {
    setState(() {
      _isPicking = true;
      _rows = [];
      _statusMessage = '';
      _successCount = 0;
      _errorCount = 0;
      _fileName = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: false,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isPicking = false);
        return;
      }

      final file = result.files.first;
      final path = file.path;
      if (path == null) {
        _showSnack('Could not read file path.');
        setState(() => _isPicking = false);
        return;
      }

      setState(() => _fileName = file.name);
      await _parseExcel(path);
    } catch (e) {
      _showSnack('Error picking file: $e');
    } finally {
      setState(() => _isPicking = false);
    }
  }

  Future<void> _parseExcel(String path) async {
    final bytes = await File(path).readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    // Use first sheet
    final sheet = excel.tables[excel.tables.keys.first];
    if (sheet == null) {
      setState(() => _statusMessage = '⚠️ No sheet found in the Excel file.');
      return;
    }

    final rows = sheet.rows;
    if (rows.length < 2) {
      setState(() => _statusMessage = '⚠️ File has no data rows (only header or empty).');
      return;
    }

    final previews = <_RowPreview>[];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];

      // Helper to read cell safely
      String cell(int col) {
        if (col >= row.length) return '';
        return row[col]?.value?.toString().trim() ?? '';
      }

      double? num(int col) => double.tryParse(cell(col));
      int? intVal(int col) => int.tryParse(cell(col));

      final itemName = cell(0);
      final tradePriceStr = cell(6);
      final retailPriceStr = cell(7);

      // Validate required fields
      final errors = <String>[];
      if (itemName.isEmpty) errors.add('itemName is required');
      if (num(6) == null) errors.add('tradePrice must be a number');
      if (num(7) == null) errors.add('retailPrice must be a number');

      final product = errors.isEmpty
          ? Product(
              itemName: itemName,
              itemCode: cell(1).isEmpty ? null : cell(1),
              barcode: cell(2).isEmpty ? null : cell(2),
              category: cell(3).isEmpty ? null : cell(3),
              companyName: cell(4).isEmpty ? null : cell(4),
              issueUnit: cell(5).isEmpty ? null : cell(5),
              tradePrice: num(6)!,
              retailPrice: num(7)!,
              taxPercent: num(8) ?? 0.0,
              discountPercent: num(9) ?? 0.0,
              parLevel: intVal(10) ?? 0,
              stock: intVal(11) ?? 0,
              description: cell(12).isEmpty ? null : cell(12),
              createdAt: DateTime.now().toIso8601String(),
              updatedAt: DateTime.now().toIso8601String(),
            )
          : null;

      previews.add(_RowPreview(
        rowNumber: i + 1,
        itemName: itemName.isEmpty ? '(empty)' : itemName,
        tradePrice: tradePriceStr,
        retailPrice: retailPriceStr,
        errors: errors,
        product: product,
      ));
    }

    setState(() {
      _rows = previews;
      final valid = previews.where((r) => r.errors.isEmpty).length;
      final invalid = previews.length - valid;
      _statusMessage =
          '📋 Found ${previews.length} rows — $valid valid, $invalid with errors.';
    });
  }

  // ── Import to DB ─────────────────────────────────────────
  Future<void> _importToDatabase() async {
    final toImport = _rows.where((r) => r.errors.isEmpty && r.product != null).toList();
    if (toImport.isEmpty) {
      _showSnack('No valid rows to import.');
      return;
    }

    setState(() {
      _isImporting = true;
      _successCount = 0;
      _errorCount = 0;
    });

    for (final row in toImport) {
      try {
        await DatabaseHelper.instance.addProduct(row.product!);
        _successCount++;
      } catch (e) {
        _errorCount++;
        row.importError = e.toString();
      }
    }

    setState(() {
      _isImporting = false;
      _statusMessage =
          '✅ Import complete: $_successCount saved, $_errorCount failed.';
    });

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600),
              const SizedBox(width: 8),
              const Text('Import Complete'),
            ],
          ),
          content: Text(
            '$_successCount product(s) imported successfully.'
            '${_errorCount > 0 ? '\n$_errorCount failed — check rows for details.' : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── UI ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final validRows = _rows.where((r) => r.errors.isEmpty).length;
    final invalidRows = _rows.length - validRows;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Bulk Import Products'),
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Top banner ──
          _TopBanner(accentColor: _accentColor),

          // ── Action bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isPicking || _isImporting ? null : _pickAndParseFile,
                    icon: _isPicking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.upload_file),
                    label: Text(_isPicking ? 'Loading…' : 'Choose Excel File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                if (_rows.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isImporting || validRows == 0
                        ? null
                        : _importToDatabase,
                    icon: _isImporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_alt),
                    label: Text(_isImporting
                        ? 'Saving…'
                        : 'Import $validRows Valid'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── File name chip ──
          if (_fileName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.description,
                      size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _fileName!,
                      style: const TextStyle(
                          color: Colors.blueGrey, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // ── Status message ──
          if (_statusMessage.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _statusMessage.contains('✅')
                      ? Colors.green.shade50
                      : _statusMessage.contains('⚠️')
                          ? Colors.orange.shade50
                          : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _statusMessage.contains('✅')
                        ? Colors.green.shade200
                        : _statusMessage.contains('⚠️')
                            ? Colors.orange.shade200
                            : Colors.blue.shade200,
                  ),
                ),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    fontSize: 13,
                    color: _statusMessage.contains('✅')
                        ? Colors.green.shade800
                        : _statusMessage.contains('⚠️')
                            ? Colors.orange.shade800
                            : Colors.blue.shade800,
                  ),
                ),
              ),
            ),

          // ── Summary chips ──
          if (_rows.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _Chip(
                      label: '$validRows Valid',
                      color: Colors.green.shade600),
                  const SizedBox(width: 8),
                  if (invalidRows > 0)
                    _Chip(
                        label: '$invalidRows Errors',
                        color: Colors.red.shade600),
                ],
              ),
            ),

          const SizedBox(height: 4),

          // ── Preview list ──
          Expanded(
            child: _rows.isEmpty
                ? _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _rows.length,
                    itemBuilder: (ctx, i) => _RowCard(row: _rows[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  WIDGETS
// ─────────────────────────────────────────────────────────────

class _TopBanner extends StatelessWidget {
  final Color accentColor;
  const _TopBanner({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: accentColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Excel Template Columns (in order):',
            style: TextStyle(
                color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _ColChip('A: Item Name*'),
              _ColChip('B: Item Code'),
              _ColChip('C: Barcode'),
              _ColChip('D: Category'),
              _ColChip('E: Company'),
              _ColChip('F: Issue Unit'),
              _ColChip('G: Trade Price*'),
              _ColChip('H: Retail Price*'),
              _ColChip('I: Tax %'),
              _ColChip('J: Discount %'),
              _ColChip('K: Par Level'),
              _ColChip('L: Stock'),
              _ColChip('M: Description'),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '* Required fields. Row 1 = headers, data starts from Row 2.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ColChip extends StatelessWidget {
  final String label;
  const _ColChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.table_chart_outlined,
              size: 72, color: Colors.blueGrey.shade200),
          const SizedBox(height: 16),
          Text(
            'No file selected',
            style: TextStyle(
                fontSize: 18,
                color: Colors.blueGrey.shade400,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Choose Excel File" to pick a .xlsx file\nand preview products before importing.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade300),
          ),
        ],
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  final _RowPreview row;
  const _RowCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final hasError = row.errors.isNotEmpty;
    final hasImportError = row.importError != null;

    Color borderColor = hasError
        ? Colors.red.shade300
        : hasImportError
            ? Colors.orange.shade300
            : Colors.green.shade300;

    Color bgColor = hasError
        ? Colors.red.shade50
        : hasImportError
            ? Colors.orange.shade50
            : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasError
                        ? Colors.red.shade100
                        : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Row ${row.rowNumber}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: hasError
                            ? Colors.red.shade800
                            : Colors.blue.shade800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    row.itemName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  hasError
                      ? Icons.error_outline
                      : hasImportError
                          ? Icons.warning_amber
                          : Icons.check_circle,
                  size: 18,
                  color: hasError
                      ? Colors.red.shade500
                      : hasImportError
                          ? Colors.orange.shade600
                          : Colors.green.shade600,
                ),
              ],
            ),

            // ── Price info (only if no parse errors) ──
            if (!hasError) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  _InfoBadge(
                      label: 'Trade',
                      value: 'Rs ${row.tradePrice}'),
                  const SizedBox(width: 8),
                  _InfoBadge(
                      label: 'Retail',
                      value: 'Rs ${row.retailPrice}'),
                ],
              ),
            ],

            // ── Validation errors ──
            if (row.errors.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...row.errors.map((e) => Row(
                    children: [
                      Icon(Icons.cancel,
                          size: 13, color: Colors.red.shade400),
                      const SizedBox(width: 4),
                      Text(e,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700)),
                    ],
                  )),
            ],

            // ── Import errors ──
            if (row.importError != null) ...[
              const SizedBox(height: 4),
              Text(
                '⚠️ DB error: ${row.importError}',
                style: TextStyle(
                    fontSize: 11, color: Colors.orange.shade800),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final String value;
  const _InfoBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────────────────────

class _RowPreview {
  final int rowNumber;
  final String itemName;
  final String tradePrice;
  final String retailPrice;
  final List<String> errors;
  final Product? product;
  String? importError;

  _RowPreview({
    required this.rowNumber,
    required this.itemName,
    required this.tradePrice,
    required this.retailPrice,
    required this.errors,
    required this.product,
    this.importError,
  });
}
