import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/models/product.dart';
import 'package:medical_app/models/sale_item.dart';
import 'package:medical_app/services/database_helper.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InventoryLedgerReport extends StatefulWidget {
  const InventoryLedgerReport({super.key});

  @override
  State<InventoryLedgerReport> createState() => _InventoryLedgerReportState();
}

class _InventoryLedgerReportState extends State<InventoryLedgerReport> {
  // ── State ──────────────────────────────────────────────────────────────────
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();
  Product? selectedProduct;
  bool isAllProducts = false;

  List<Product> allProducts = [];
  List<Map<String, dynamic>> ledgerEntries = [];
  List<Map<String, dynamic>> filteredEntries = [];

  bool isLoading = false;
  bool isExporting = false;
  bool hasGenerated = false;
  String entrySearchQuery = '';
  String selectedFilter = 'All';

  // ── Summary ────────────────────────────────────────────────────────────────
  int totalIn = 0;
  int totalOut = 0;
  int openingStock = 0;
  int closingStock = 0;

  // ── Formatters ─────────────────────────────────────────────────────────────
  final _date = DateFormat('dd MMM yyyy');
  final _dateShort = DateFormat('dd/MM/yyyy');
  final _dateFile = DateFormat('yyyyMMdd_HHmmss');

  // ── Controllers ────────────────────────────────────────────────────────────
  final TextEditingController _entrySearchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  // ── Filters ────────────────────────────────────────────────────────────────
  final List<String> _txnFilters = [
    'All',
    'Purchases',
    'Sales',
    'Opening',
  ];

  final List<String> _presets = [
    'Today',
    'This Week',
    'This Month',
    'Last Month',
    'Last 30 Days',
    'This Year',
  ];

  // ── Theme ──────────────────────────────────────────────────────────────────
  static const _primary = Color(0xFF10B981);
  static const _blue = Color(0xFF3B82F6);
  static const _red = Color(0xFFEF4444);
  static const _purple = Color(0xFF6366F1);
  static const _orange = Color(0xFFF59E0B);
  static const _dark = Color(0xFF1E293B);
  static const _muted = Color(0xFF64748B);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = Color(0xFFE2E8F0);

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _entrySearchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATA
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadProducts() async {
    final products = await DatabaseHelper.instance.getAllProducts();
    setState(() => allProducts = products);
  }

  Future<void> _generateLedger() async {
    if (!isAllProducts && selectedProduct == null) {
      _snack('Please select a product or "All Products"', isError: true);
      return;
    }

    setState(() {
      isLoading = true;
      hasGenerated = false;
    });

    try {
      ledgerEntries = [];
      final from = fromDate.toIso8601String().substring(0, 10);
      final to = toDate.toIso8601String().substring(0, 10);

      if (isAllProducts) {
        await _generateAllProductsLedger(from, to);
      } else {
        await _generateSingleProductLedger(from, to);
      }

      ledgerEntries.sort((a, b) => a['date'].compareTo(b['date']));
      _calculateBalances();
      filteredEntries = List.from(ledgerEntries);

      setState(() {
        isLoading = false;
        hasGenerated = true;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _snack('Error generating ledger: $e', isError: true);
    }
  }

  Future<void> _generateSingleProductLedger(String from, String to) async {
    final selectedId = selectedProduct!.id;
    openingStock = selectedProduct!.stock;

    final purchases =
        await DatabaseHelper.instance.getPurchasesInDateRange(from, to);
    for (var purchase in purchases) {
      final List items = purchase['items'];
      for (var item in items) {
        if (item['productId'] == selectedId) {
          ledgerEntries.add({
            'productId': item['productId'],
            'productName': item['productName'] ?? selectedProduct!.itemName,
            'date': DateTime.parse(purchase['date']),
            'type': 'Purchase',
            'reference': 'PUR-${purchase['invoiceNumber']}',
            'detail': purchase['supplierName'] ?? '-',
            'inQty': item['quantity'] as int,
            'outQty': 0,
            'rate': (item['tradePrice'] as num?)?.toDouble() ?? 0,
            'balance': 0,
            'color': _primary,
          });
        }
      }
    }

    final sales =
        await DatabaseHelper.instance.getSalesInDateRange(from, to);
    for (var sale in sales) {
      final List<SaleItem> items = sale['items'];
      for (var item in items) {
        if (item.productId == selectedId) {
          ledgerEntries.add({
            'productId': item.productId,
            'productName': item.productName,
            'date': DateTime.parse(sale['dateTime']),
            'type': 'Sale',
            'reference': 'INV-${sale['invoiceId']}',
            'detail': sale['customerName'] ?? 'Walk-in',
            'inQty': 0,
            'outQty': item.quantity,
            'rate': item.price,
            'balance': 0,
            'color': _red,
          });
        }
      }
    }

    ledgerEntries.insert(0, {
      'productId': selectedId,
      'productName': selectedProduct!.itemName,
      'date': fromDate,
      'type': 'Opening',
      'reference': 'Opening Stock',
      'detail': '-',
      'inQty': openingStock,
      'outQty': 0,
      'rate': selectedProduct!.tradePrice,
      'balance': openingStock,
      'color': _purple,
    });
  }

  Future<void> _generateAllProductsLedger(String from, String to) async {
    openingStock = 0;
    for (var p in allProducts) {
      openingStock += p.stock;
    }

    final purchases =
        await DatabaseHelper.instance.getPurchasesInDateRange(from, to);
    for (var purchase in purchases) {
      final List items = purchase['items'];
      for (var item in items) {
        ledgerEntries.add({
          'productId': item['productId'],
          'productName': item['productName'] ?? 'Unknown',
          'date': DateTime.parse(purchase['date']),
          'type': 'Purchase',
          'reference': 'PUR-${purchase['invoiceNumber']}',
          'detail': purchase['supplierName'] ?? '-',
          'inQty': item['quantity'] as int,
          'outQty': 0,
          'rate': (item['tradePrice'] as num?)?.toDouble() ?? 0,
          'balance': 0,
          'color': _primary,
        });
      }
    }

    final sales =
        await DatabaseHelper.instance.getSalesInDateRange(from, to);
    for (var sale in sales) {
      final List<SaleItem> items = sale['items'];
      for (var item in items) {
        ledgerEntries.add({
          'productId': item.productId,
          'productName': item.productName,
          'date': DateTime.parse(sale['dateTime']),
          'type': 'Sale',
          'reference': 'INV-${sale['invoiceId']}',
          'detail': sale['customerName'] ?? 'Walk-in',
          'inQty': 0,
          'outQty': item.quantity,
          'rate': item.price,
          'balance': 0,
          'color': _red,
        });
      }
    }

    ledgerEntries.insert(0, {
      'productId': null,
      'productName': 'All Products',
      'date': fromDate,
      'type': 'Opening',
      'reference': 'Opening Stock',
      'detail': '-',
      'inQty': openingStock,
      'outQty': 0,
      'rate': 0,
      'balance': openingStock,
      'color': _purple,
    });
  }

  void _calculateBalances() {
    int running = openingStock;
    totalIn = 0;
    totalOut = 0;

    for (int i = 1; i < ledgerEntries.length; i++) {
      final e = ledgerEntries[i];
      final inQ = e['inQty'] as int;
      final outQ = e['outQty'] as int;
      totalIn += inQ;
      totalOut += outQ;
      running = running + inQ - outQ;
      e['balance'] = running;
    }
    closingStock = running;
  }

  void _filterEntries() {
    setState(() {
      filteredEntries = ledgerEntries.where((entry) {
        bool matchesFilter = selectedFilter == 'All' ||
            entry['type']
                .toString()
                .toLowerCase()
                .startsWith(selectedFilter.toLowerCase().replaceAll('s', ''));
        bool matchesSearch = entrySearchQuery.isEmpty ||
            entry['reference']
                .toString()
                .toLowerCase()
                .contains(entrySearchQuery.toLowerCase()) ||
            entry['productName']
                .toString()
                .toLowerCase()
                .contains(entrySearchQuery.toLowerCase());
        return matchesFilter && matchesSearch;
      }).toList();
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATE / PRESETS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _selectDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate : toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => isFrom ? fromDate = picked : toDate = picked);
    }
  }

  void _setPreset(String preset) {
    final now = DateTime.now();
    switch (preset) {
      case 'Today':
        fromDate = toDate = now;
      case 'This Week':
        fromDate = now.subtract(Duration(days: now.weekday - 1));
        toDate = now;
      case 'This Month':
        fromDate = DateTime(now.year, now.month, 1);
        toDate = now;
      case 'Last Month':
        fromDate = DateTime(now.year, now.month - 1, 1);
        toDate = DateTime(now.year, now.month, 0);
      case 'Last 30 Days':
        fromDate = now.subtract(const Duration(days: 30));
        toDate = now;
      case 'This Year':
        fromDate = DateTime(now.year, 1, 1);
        toDate = now;
    }
    setState(() {});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRODUCT SELECTOR DIALOG
  // ═══════════════════════════════════════════════════════════════════════════

  void _showProductSelector() {
    String searchQ = '';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setDialogState) {
            final filtered = searchQ.isEmpty
                ? allProducts
                : allProducts.where((p) {
                    return p.itemName
                            .toLowerCase()
                            .contains(searchQ.toLowerCase()) ||
                        (p.itemCode
                                ?.toLowerCase()
                                .contains(searchQ.toLowerCase()) ??
                            false);
                  }).toList();

            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 500,
                height: 550,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2_outlined,
                              color: _primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text('Select Product',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _dark)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Search
                    SizedBox(
                      height: 40,
                      child: TextField(
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search by name or code…',
                          hintStyle: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400),
                          prefixIcon: Icon(Icons.search,
                              size: 16, color: Colors.grey.shade400),
                          filled: true,
                          fillColor: _surface,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: _primary),
                          ),
                        ),
                        onChanged: (v) =>
                            setDialogState(() => searchQ = v),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // All Products option
                    InkWell(
                      onTap: () {
                        setState(() {
                          isAllProducts = true;
                          selectedProduct = null;
                        });
                        Navigator.pop(ctx2);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isAllProducts
                              ? _purple.withOpacity(0.08)
                              : _surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isAllProducts
                                ? _purple.withOpacity(0.4)
                                : _border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isAllProducts
                                    ? _purple
                                    : _surface,
                                borderRadius:
                                    BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.apps,
                                  size: 18,
                                  color: isAllProducts
                                      ? Colors.white
                                      : _muted),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('All Products',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isAllProducts
                                              ? _purple
                                              : _dark)),
                                  Text('Consolidated ledger',
                                      style: TextStyle(
                                          fontSize: 9,
                                          color:
                                              Colors.grey.shade500)),
                                ],
                              ),
                            ),
                            Text(
                              '${allProducts.length} items',
                              style: const TextStyle(
                                  fontSize: 10, color: _muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),

                    // Product list
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text('No products found',
                                  style: TextStyle(
                                      color: Colors.grey.shade400)))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final p = filtered[i];
                                final isSel = !isAllProducts &&
                                    selectedProduct?.id == p.id;
                                final isLow =
                                    p.stock <= (p.parLevel ?? 10);

                                return Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 4),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        selectedProduct = p;
                                        isAllProducts = false;
                                      });
                                      Navigator.pop(ctx2);
                                    },
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    child: Container(
                                      padding:
                                          const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isSel
                                            ? _primary
                                                .withOpacity(0.08)
                                            : Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSel
                                              ? _primary
                                                  .withOpacity(0.4)
                                              : Colors.transparent,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: isSel
                                                  ? _primary
                                                  : _surface,
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(8),
                                            ),
                                            child: Icon(
                                              Icons
                                                  .medication_outlined,
                                              size: 18,
                                              color: isSel
                                                  ? Colors.white
                                                  : _muted,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .start,
                                              children: [
                                                Text(p.itemName,
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight
                                                                .w600,
                                                        color: isSel
                                                            ? _primary
                                                            : _dark),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow
                                                            .ellipsis),
                                                Row(
                                                  children: [
                                                    Text(
                                                        p.issueUnit ??
                                                            '-',
                                                        style: TextStyle(
                                                            fontSize:
                                                                9,
                                                            color: Colors
                                                                .grey
                                                                .shade500)),
                                                    if (p.itemCode !=
                                                        null) ...[
                                                      Text(' • ',
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .grey
                                                                  .shade400)),
                                                      Text(
                                                          p.itemCode!,
                                                          style: TextStyle(
                                                              fontSize:
                                                                  9,
                                                              color: Colors
                                                                  .grey
                                                                  .shade500)),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding:
                                                const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 8,
                                                    vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isLow
                                                  ? _red.withOpacity(
                                                      0.1)
                                                  : _primary
                                                      .withOpacity(
                                                          0.1),
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(6),
                                            ),
                                            child: Text(
                                              '${p.stock}',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  color: isLow
                                                      ? _red
                                                      : _primary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF EXPORT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _exportPDF() async {
    if (!hasGenerated) return;
    setState(() => isExporting = true);

    try {
      final pdf = pw.Document();

      const headerBg = PdfColor.fromInt(0xFF1E293B);
      const green = PdfColor.fromInt(0xFF10B981);
      const red = PdfColor.fromInt(0xFFEF4444);
      const purple = PdfColor.fromInt(0xFF6366F1);
      const blue = PdfColor.fromInt(0xFF3B82F6);
      const lightGrey = PdfColor.fromInt(0xFFF8FAFC);
      const borderC = PdfColor.fromInt(0xFFE2E8F0);

      final productLabel = isAllProducts
          ? 'All Products'
          : selectedProduct?.itemName ?? '-';

      pw.Widget pCell(String text,
          {PdfColor color = PdfColors.black,
          bool bold = false,
          pw.TextAlign align = pw.TextAlign.left,
          double fs = 8}) {
        return pw.Padding(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: pw.Text(text,
              textAlign: align,
              style: pw.TextStyle(
                  fontSize: fs,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: color)),
        );
      }

      pw.Widget sumBox(
          String label, String value, PdfColor col) {
        return pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.symmetric(horizontal: 3),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor(col.red, col.green, col.blue, 0.07),
              border: pw.Border.all(
                  color: PdfColor(col.red, col.green, col.blue, 0.35)),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label,
                    style: pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey600,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(value,
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: col)),
              ],
            ),
          ),
        );
      }

      const int rowsPerPage = 30;
      final chunks = <List<Map<String, dynamic>>>[];
      for (int i = 0; i < filteredEntries.length; i += rowsPerPage) {
        chunks
            .add(filteredEntries.skip(i).take(rowsPerPage).toList());
      }
      if (chunks.isEmpty) chunks.add([]);

      final headers = [
        'Date',
        'Type',
        if (isAllProducts) 'Product',
        'Reference',
        'Details',
        'In',
        'Out',
        'Balance',
      ];

      for (int pageIdx = 0; pageIdx < chunks.length; pageIdx++) {
        final chunk = chunks[pageIdx];

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(20),
            build: (ctx) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                      color: headerBg,
                      borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment:
                            pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Inventory Ledger Report',
                              style: pw.TextStyle(
                                  fontSize: 17,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white)),
                          pw.SizedBox(height: 3),
                          pw.Text(
                              'Product: $productLabel  •  ${_date.format(fromDate)} – ${_date.format(toDate)}',
                              style: const pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.grey300)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                              'Generated: ${_date.format(DateTime.now())}',
                              style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.grey400)),
                          pw.SizedBox(height: 3),
                          pw.Text(
                              'Page ${pageIdx + 1} of ${chunks.length}',
                              style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.grey400)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),

                // Summary – first page
                if (pageIdx == 0) ...[
                  pw.Row(children: [
                    sumBox('Opening Stock', '$openingStock', purple),
                    sumBox('Stock In', '+$totalIn', green),
                    sumBox('Stock Out', '-$totalOut', red),
                    sumBox('Closing Stock', '$closingStock',
                        closingStock > 0 ? green : red),
                  ]),
                  pw.SizedBox(height: 10),
                ],

                // Table
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Table header
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          color: headerBg,
                          borderRadius: const pw.BorderRadius.only(
                            topLeft: pw.Radius.circular(6),
                            topRight: pw.Radius.circular(6),
                          ),
                        ),
                        child: pw.Row(
                          children: headers
                              .map((h) => pw.Expanded(
                                    flex: h == 'Product' || h == 'Details'
                                        ? 3
                                        : h == 'Reference'
                                            ? 3
                                            : 2,
                                    child: pw.Padding(
                                      padding:
                                          const pw.EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 6),
                                      child: pw.Text(h,
                                          style: pw.TextStyle(
                                              fontSize: 8,
                                              color: PdfColors.white,
                                              fontWeight:
                                                  pw.FontWeight.bold)),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),

                      // Rows
                      pw.Flexible(
                        child: pw.ListView.builder(
                          itemCount: chunk.length,
                          itemBuilder: (_, i) {
                            final e = chunk[i];
                            final even = i % 2 == 0;
                            final inQ = e['inQty'] as int;
                            final outQ = e['outQty'] as int;
                            final bal = e['balance'] as int;

                            return pw.Container(
                              decoration: pw.BoxDecoration(
                                color: even
                                    ? PdfColors.white
                                    : lightGrey,
                                border: pw.Border(
                                    bottom: pw.BorderSide(
                                        color: borderC)),
                              ),
                              child: pw.Row(
                                children: [
                                  pw.Expanded(
                                      flex: 2,
                                      child: pCell(_dateShort
                                          .format(e['date']))),
                                  pw.Expanded(
                                      flex: 2,
                                      child: pCell(e['type'],
                                          color: e['type'] ==
                                                  'Purchase'
                                              ? green
                                              : e['type'] == 'Sale'
                                                  ? red
                                                  : purple,
                                          bold: true)),
                                  if (isAllProducts)
                                    pw.Expanded(
                                        flex: 3,
                                        child: pCell(
                                            e['productName'])),
                                  pw.Expanded(
                                      flex: 3,
                                      child: pCell(
                                          e['reference'],
                                          color: blue)),
                                  pw.Expanded(
                                      flex: 3,
                                      child:
                                          pCell(e['detail'] ?? '-')),
                                  pw.Expanded(
                                      flex: 2,
                                      child: pCell(
                                          inQ > 0 ? '+$inQ' : '-',
                                          color: green,
                                          bold: inQ > 0)),
                                  pw.Expanded(
                                      flex: 2,
                                      child: pCell(
                                          outQ > 0
                                              ? '-$outQ'
                                              : '-',
                                          color: red,
                                          bold: outQ > 0)),
                                  pw.Expanded(
                                      flex: 2,
                                      child: pCell('$bal',
                                          bold: true)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      // Footer on last page
                      if (pageIdx == chunks.length - 1)
                        pw.Container(
                          decoration: pw.BoxDecoration(
                            color: headerBg,
                            borderRadius: const pw.BorderRadius.only(
                              bottomLeft: pw.Radius.circular(6),
                              bottomRight: pw.Radius.circular(6),
                            ),
                          ),
                          child: pw.Row(
                            children: [
                              pw.Expanded(
                                flex: isAllProducts ? 13 : 10,
                                child: pw.Padding(
                                  padding:
                                      const pw.EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6),
                                  child: pw.Text('TOTALS',
                                      style: pw.TextStyle(
                                          fontSize: 9,
                                          color: PdfColors.white,
                                          fontWeight:
                                              pw.FontWeight.bold)),
                                ),
                              ),
                              pw.Expanded(
                                  flex: 2,
                                  child: pCell('+$totalIn',
                                      color: green, bold: true)),
                              pw.Expanded(
                                  flex: 2,
                                  child: pCell('-$totalOut',
                                      color: red, bold: true)),
                              pw.Expanded(
                                  flex: 2,
                                  child: pCell('$closingStock',
                                      color: PdfColors.white,
                                      bold: true)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final bytes = await pdf.save();
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'InventoryLedger_${_dateFile.format(DateTime.now())}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      _showExportDialog(file.path, 'PDF', bytes);
    } catch (e) {
      _snack('PDF export failed: $e', isError: true);
    } finally {
      setState(() => isExporting = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXCEL EXPORT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _exportExcel() async {
    if (!hasGenerated) return;
    setState(() => isExporting = true);

    try {
      final excel = ex.Excel.createExcel();
      excel.delete('Sheet1');

      final productLabel = isAllProducts
          ? 'All Products'
          : selectedProduct?.itemName ?? '-';

      ex.CellStyle headerStyle() => ex.CellStyle(
            backgroundColorHex: ex.ExcelColor.fromHexString('#1E293B'),
            fontColorHex: ex.ExcelColor.fromHexString('#FFFFFF'),
            bold: true,
            fontSize: 11,
            horizontalAlign: ex.HorizontalAlign.Center,
          );

      ex.CellStyle labelStyle() => ex.CellStyle(
            bold: true,
            fontSize: 10,
            fontColorHex: ex.ExcelColor.fromHexString('#1E293B'),
          );

      ex.CellStyle valStyle(String hex) => ex.CellStyle(
            bold: true,
            fontSize: 11,
            fontColorHex: ex.ExcelColor.fromHexString(hex),
            horizontalAlign: ex.HorizontalAlign.Right,
          );

      // ── Sheet 1: Summary ──────────────────────────────────────────
      final summarySheet = excel['Summary'];

      _xlCell(summarySheet, 0, 0, 'Inventory Ledger Report',
          style: headerStyle());
      summarySheet.merge(
          ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          ex.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0));

      _xlCell(summarySheet, 1, 0,
          'Product: $productLabel  |  ${_date.format(fromDate)} – ${_date.format(toDate)}',
          style: ex.CellStyle(bold: true, fontSize: 10, italic: true));
      summarySheet.merge(
          ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
          ex.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 1));

      _xlCell(summarySheet, 2, 0, '');

      for (int c = 0; c < ['Metric', 'Value'].length; c++) {
        _xlCell(summarySheet, 3, c, ['Metric', 'Value'][c],
            style: headerStyle());
      }

      final summaryRows = [
        ['Opening Stock', '$openingStock', '#6366F1'],
        ['Total Stock In', '+$totalIn', '#10B981'],
        ['Total Stock Out', '-$totalOut', '#EF4444'],
        [
          'Closing Stock',
          '$closingStock',
          closingStock > 0 ? '#10B981' : '#EF4444'
        ],
        [
          'Net Movement',
          '${totalIn - totalOut}',
          (totalIn - totalOut) >= 0 ? '#10B981' : '#EF4444'
        ],
        ['Total Transactions', '${filteredEntries.length}', '#3B82F6'],
        [
          'Report Period',
          '${toDate.difference(fromDate).inDays + 1} days',
          '#1E293B'
        ],
      ];

      for (int r = 0; r < summaryRows.length; r++) {
        _xlCell(summarySheet, 4 + r, 0, summaryRows[r][0],
            style: labelStyle());
        _xlCell(summarySheet, 4 + r, 1, summaryRows[r][1],
            style: valStyle(summaryRows[r][2]));
      }

      summarySheet.setColumnWidth(0, 30);
      summarySheet.setColumnWidth(1, 20);

      // ── Sheet 2: Ledger ───────────────────────────────────────────
      final ledgerSheet = excel['Ledger'];

      final colHeaders = [
        'Date',
        'Type',
        if (isAllProducts) 'Product',
        'Reference',
        'Details',
        'Stock In',
        'Stock Out',
        'Balance',
      ];

      for (int c = 0; c < colHeaders.length; c++) {
        _xlCell(ledgerSheet, 0, c, colHeaders[c],
            style: headerStyle());
      }

      for (int r = 0; r < filteredEntries.length; r++) {
        final e = filteredEntries[r];
        final rowBg = r % 2 == 0 ? '#FFFFFF' : '#F8FAFC';
        final inQ = e['inQty'] as int;
        final outQ = e['outQty'] as int;
        final bal = e['balance'] as int;

        ex.CellStyle rs(
                {String color = '#1E293B',
                bool bold = false,
                ex.HorizontalAlign align =
                    ex.HorizontalAlign.Left}) =>
            ex.CellStyle(
              backgroundColorHex: ex.ExcelColor.fromHexString(rowBg),
              fontColorHex: ex.ExcelColor.fromHexString(color),
              bold: bold,
              fontSize: 10,
              horizontalAlign: align,
            );

        int col = 0;
        _xlCell(ledgerSheet, r + 1, col++,
            _dateShort.format(e['date']),
            style: rs());
        _xlCell(ledgerSheet, r + 1, col++, e['type'],
            style: rs(
                color: e['type'] == 'Purchase'
                    ? '#10B981'
                    : e['type'] == 'Sale'
                        ? '#EF4444'
                        : '#6366F1',
                bold: true));
        if (isAllProducts) {
          _xlCell(ledgerSheet, r + 1, col++, e['productName'],
              style: rs());
        }
        _xlCell(ledgerSheet, r + 1, col++, e['reference'],
            style: rs(color: '#3B82F6'));
        _xlCell(ledgerSheet, r + 1, col++, e['detail'] ?? '-',
            style: rs());
        _xlCell(ledgerSheet, r + 1, col++,
            inQ > 0 ? inQ : '',
            style: rs(color: '#10B981', bold: inQ > 0));
        _xlCell(ledgerSheet, r + 1, col++,
            outQ > 0 ? outQ : '',
            style: rs(color: '#EF4444', bold: outQ > 0));
        _xlCell(ledgerSheet, r + 1, col++, bal,
            style: rs(bold: true));
      }

      // Total row
      final tr = filteredEntries.length + 1;
      ex.CellStyle ts(String color) => ex.CellStyle(
            backgroundColorHex: ex.ExcelColor.fromHexString('#1E293B'),
            fontColorHex: ex.ExcelColor.fromHexString(color),
            bold: true,
            fontSize: 10,
          );

      int tc = 0;
      _xlCell(ledgerSheet, tr, tc++, 'TOTALS', style: ts('#FFFFFF'));
      _xlCell(ledgerSheet, tr, tc++, '', style: ts('#FFFFFF'));
      if (isAllProducts) {
        _xlCell(ledgerSheet, tr, tc++, '', style: ts('#FFFFFF'));
      }
      _xlCell(ledgerSheet, tr, tc++, '', style: ts('#FFFFFF'));
      _xlCell(ledgerSheet, tr, tc++, '', style: ts('#FFFFFF'));
      _xlCell(ledgerSheet, tr, tc++, totalIn,
          style: ts('#34D399'));
      _xlCell(ledgerSheet, tr, tc++, totalOut,
          style: ts('#FCA5A5'));
      _xlCell(ledgerSheet, tr, tc++, closingStock,
          style: ts('#FFFFFF'));

      // Column widths
      for (int c = 0; c < colHeaders.length; c++) {
        ledgerSheet.setColumnWidth(c, c <= 1 ? 14 : 20);
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Excel encoding failed');

      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'InventoryLedger_${_dateFile.format(DateTime.now())}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      _showExportDialog(
          file.path, 'Excel', Uint8List.fromList(bytes));
    } catch (e) {
      _snack('Excel export failed: $e', isError: true);
    } finally {
      setState(() => isExporting = false);
    }
  }

  void _xlCell(ex.Sheet sheet, int row, int col, dynamic value,
      {ex.CellStyle? style}) {
    final cell = sheet.cell(
        ex.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
    if (value is double || value is int) {
      cell.value = ex.DoubleCellValue(value.toDouble());
    } else {
      cell.value = ex.TextCellValue(value.toString());
    }
    if (style != null) cell.cellStyle = style;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXPORT DIALOG
  // ═══════════════════════════════════════════════════════════════════════════

  void _showExportDialog(
      String path, String type, Uint8List bytes) {
    final color = type == 'PDF' ? _red : _primary;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: Icon(
                  type == 'PDF'
                      ? Icons.picture_as_pdf
                      : Icons.table_chart,
                  color: color,
                  size: 32),
            ),
            const SizedBox(height: 16),
            Text('$type Exported!',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('File saved successfully',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border)),
              child: Text(path.split('/').last,
                  style: const TextStyle(fontSize: 11, color: _muted),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      OpenFilex.open(path);
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8))),
                  ),
                ),
                const SizedBox(width: 10),
                if (type == 'PDF')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Printing.layoutPdf(
                          onLayout: (_) async => bytes,
                          name: path.split('/').last,
                        );
                      },
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Print'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8))),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SNACK
  // ═══════════════════════════════════════════════════════════════════════════

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _red : _primary,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopBar(),
                if (hasGenerated && !isLoading) _buildSummaryStrip(),
                if (hasGenerated && !isLoading) _buildMovementBar(),
                if (hasGenerated && !isLoading) _buildToolbar(),
                Expanded(child: _buildTable()),
                if (hasGenerated && !isLoading) _buildFooter(),
              ],
            ),
            if (isLoading)
              Container(
                color: Colors.black26,
                child: const Center(
                    child: CircularProgressIndicator(color: _primary)),
              ),
            if (isExporting)
              Container(
                color: Colors.black38,
                child: Center(
                  child: Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: _primary),
                          SizedBox(height: 16),
                          Text('Generating export…',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TOP BAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTopBar() {
    final screenW = MediaQuery.of(context).size.width;
    final isNarrow = screenW < 1000;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitle(),
                const SizedBox(height: 12),
                _buildControls(isNarrow),
              ],
            )
          : Row(
              children: [
                _buildTitle(),
                const Spacer(),
                _buildControls(isNarrow),
              ],
            ),
    );
  }

  Widget _buildTitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.inventory_outlined,
              color: _primary, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Inventory Ledger',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _dark)),
            Row(
              children: [
                if (isAllProducts)
                  const Text('All Products',
                      style: TextStyle(
                          fontSize: 11,
                          color: _purple,
                          fontWeight: FontWeight.w600))
                else if (selectedProduct != null)
                  Text(selectedProduct!.itemName,
                      style: const TextStyle(
                          fontSize: 11,
                          color: _primary,
                          fontWeight: FontWeight.w600))
                else
                  const Text('No product selected',
                      style: TextStyle(
                          fontSize: 11, color: _muted)),
                Text(
                    '  •  ${_date.format(fromDate)} → ${_date.format(toDate)}',
                    style: const TextStyle(
                        fontSize: 11, color: _muted)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControls(bool isNarrow) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Product selector
        _buildActionBtn(
          icon: Icons.inventory_2_outlined,
          label: isAllProducts
              ? 'All Products'
              : selectedProduct?.itemName ?? 'Select Product',
          color: _purple,
          onTap: _showProductSelector,
          maxWidth: 180,
        ),

        // Presets dropdown
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              hint: const Text('Quick Select',
                  style: TextStyle(fontSize: 11, color: _muted)),
              isDense: true,
              style: const TextStyle(fontSize: 11, color: _dark),
              icon: const Icon(Icons.expand_more,
                  size: 16, color: _muted),
              items: _presets
                  .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p,
                          style: const TextStyle(fontSize: 11))))
                  .toList(),
              onChanged: (v) {
                if (v != null) _setPreset(v);
              },
            ),
          ),
        ),

        // From date
        _buildDateChip('From', fromDate, () => _selectDate(true)),
        const Icon(Icons.arrow_forward, size: 14, color: _muted),
        _buildDateChip('To', toDate, () => _selectDate(false)),

        const SizedBox(width: 4),

        // Generate
        _buildActionBtn(
          icon: Icons.play_arrow,
          label: 'Generate',
          color: _primary,
          onTap: isLoading ? null : _generateLedger,
        ),

        // Excel
        _buildActionBtn(
          icon: Icons.table_chart_outlined,
          label: 'Excel',
          color: const Color(0xFF16A34A),
          onTap: (isExporting || !hasGenerated) ? null : _exportExcel,
        ),

        // PDF
        _buildActionBtn(
          icon: Icons.picture_as_pdf_outlined,
          label: 'PDF',
          color: _red,
          onTap: (isExporting || !hasGenerated) ? null : _exportPDF,
        ),
      ],
    );
  }

  Widget _buildDateChip(
      String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label: ',
                style: const TextStyle(fontSize: 10, color: _muted)),
            const Icon(Icons.calendar_today_outlined,
                size: 12, color: _muted),
            const SizedBox(width: 4),
            Text(_date.format(date),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _dark)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    double? maxWidth,
  }) {
    final disabled = onTap == null;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints:
            maxWidth != null ? BoxConstraints(maxWidth: maxWidth) : null,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: disabled
              ? Colors.grey.shade100
              : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: disabled
                  ? Colors.grey.shade300
                  : color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            disabled && isExporting
                ? SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: color))
                : Icon(icon, size: 14, color: disabled ? Colors.grey : color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: disabled ? Colors.grey : color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUMMARY STRIP
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSummaryStrip() {
    final netMovement = totalIn - totalOut;
    final screenW = MediaQuery.of(context).size.width;
    final isNarrow = screenW < 900;

    final cards = [
      _CardData('Opening Stock', '$openingStock',
          Icons.inventory_2_outlined, _purple),
      _CardData(
          'Stock In', '+$totalIn', Icons.add_circle_outline, _primary),
      _CardData(
          'Stock Out', '-$totalOut', Icons.remove_circle_outline, _red),
      _CardData(
          'Closing Stock',
          '$closingStock',
          Icons.inventory_outlined,
          closingStock > 0 ? _primary : _red,
          highlighted: true),
      _CardData(
          'Net Movement',
          '${netMovement >= 0 ? '+' : ''}$netMovement',
          netMovement >= 0 ? Icons.trending_up : Icons.trending_down,
          netMovement >= 0 ? _primary : _red),
      _CardData('Transactions', '${filteredEntries.length}',
          Icons.receipt_long_outlined, _blue),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: isNarrow
          ? Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cards
                  .map((c) => SizedBox(
                      width: (screenW - 56) / 2,
                      child: _buildCard(c)))
                  .toList(),
            )
          : Row(
              children: cards
                  .map((c) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4),
                          child: _buildCard(c),
                        ),
                      ))
                  .toList(),
            ),
    );
  }

  Widget _buildCard(_CardData c) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.highlighted ? c.color.withOpacity(0.06) : _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: c.highlighted
                ? c.color.withOpacity(0.3)
                : _border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: c.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6)),
            child: Icon(c.icon, color: c.color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.label,
                    style: const TextStyle(
                        fontSize: 9, color: _muted)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(c.value,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color:
                              c.highlighted ? c.color : _dark)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOVEMENT BAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMovementBar() {
    final total = totalIn + totalOut;
    final inPct = total > 0 ? (totalIn / total) : 0.5;
    final outPct = total > 0 ? (totalOut / total) : 0.5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: _border),
          bottom: BorderSide(color: _border),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics_outlined,
              size: 14, color: _muted),
          const SizedBox(width: 8),
          const Text('Movement',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _dark)),
          const SizedBox(width: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: (inPct * 100).toInt().clamp(1, 99),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                              colors: [_primary, Color(0xFF34D399)]),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: (outPct * 100).toInt().clamp(1, 99),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                              colors: [_red, Color(0xFFF87171)]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _moveLegend('In', totalIn, _primary),
          const SizedBox(width: 12),
          _moveLegend('Out', totalOut, _red),
        ],
      ),
    );
  }

  Widget _moveLegend(String label, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text('$label: $value',
            style: const TextStyle(fontSize: 10, color: _muted)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TOOLBAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          // Search
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _entrySearchCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search transactions or products…',
                  hintStyle: TextStyle(
                      fontSize: 11, color: Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search,
                      size: 16, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: _surface,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _primary),
                  ),
                  suffixIcon: entrySearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () {
                            _entrySearchCtrl.clear();
                            entrySearchQuery = '';
                            _filterEntries();
                          },
                        )
                      : null,
                ),
                onChanged: (v) {
                  entrySearchQuery = v;
                  _filterEntries();
                },
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Filter chips
          ..._txnFilters.map((f) {
            final isActive = selectedFilter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () {
                  setState(() => selectedFilter = f);
                  _filterEntries();
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? _primary : _surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isActive ? _primary : _border),
                  ),
                  child: Text(f,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? Colors.white
                              : _muted)),
                ),
              ),
            );
          }),

          const SizedBox(width: 8),
          Text('${filteredEntries.length} entries',
              style: const TextStyle(fontSize: 11, color: _muted)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TABLE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTable() {
    if (!hasGenerated) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: _surface, shape: BoxShape.circle),
              child: Icon(Icons.inventory_2_outlined,
                  size: 56, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 16),
            Text('No Ledger Generated',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            Text(
                'Select a product and click "Generate" to view stock movement',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    if (filteredEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No transactions found',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 10),
          color: _dark,
          child: Row(
            children: [
              _th('Date', flex: 2, align: TextAlign.left),
              _th('Type', flex: 2, align: TextAlign.left),
              if (isAllProducts)
                _th('Product', flex: 3, align: TextAlign.left),
              _th('Reference', flex: 3, align: TextAlign.left),
              _th('Details', flex: 3, align: TextAlign.left),
              _th('In', flex: 2, align: TextAlign.center),
              _th('Out', flex: 2, align: TextAlign.center),
              _th('Balance', flex: 2, align: TextAlign.center),
            ],
          ),
        ),

        // Rows
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            itemCount: filteredEntries.length,
            itemBuilder: (ctx, i) {
              final e = filteredEntries[i];
              final isEven = i % 2 == 0;
              final inQ = e['inQty'] as int;
              final outQ = e['outQty'] as int;
              final bal = e['balance'] as int;
              final typeColor = e['color'] as Color;

              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isEven ? Colors.white : _surface,
                  border: const Border(
                      bottom:
                          BorderSide(color: _border, width: 0.5)),
                ),
                child: Row(
                  children: [
                    // Date
                    Expanded(
                      flex: 2,
                      child: Text(_dateShort.format(e['date']),
                          style: const TextStyle(
                              fontSize: 12, color: _muted)),
                    ),
                    // Type
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(4),
                            ),
                            child: Icon(
                              e['type'] == 'Purchase'
                                  ? Icons.add_circle_outline
                                  : e['type'] == 'Sale'
                                      ? Icons
                                          .remove_circle_outline
                                      : Icons
                                          .inventory_2_outlined,
                              size: 12,
                              color: typeColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(e['type'],
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: typeColor),
                                overflow:
                                    TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                    // Product (all products mode)
                    if (isAllProducts)
                      Expanded(
                        flex: 3,
                        child: Text(e['productName'],
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _dark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    // Reference
                    Expanded(
                      flex: 3,
                      child: Text(e['reference'],
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _blue),
                          overflow: TextOverflow.ellipsis),
                    ),
                    // Details
                    Expanded(
                      flex: 3,
                      child: Text(e['detail'] ?? '-',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    // In
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: inQ > 0
                            ? Container(
                                padding: const EdgeInsets
                                    .symmetric(
                                    horizontal: 10,
                                    vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      _primary.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: Text('+$inQ',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight:
                                            FontWeight.w700,
                                        color: _primary)),
                              )
                            : Text('-',
                                style: TextStyle(
                                    color:
                                        Colors.grey.shade400)),
                      ),
                    ),
                    // Out
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: outQ > 0
                            ? Container(
                                padding: const EdgeInsets
                                    .symmetric(
                                    horizontal: 10,
                                    vertical: 3),
                                decoration: BoxDecoration(
                                  color: _red.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: Text('-$outQ',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight:
                                            FontWeight.w700,
                                        color: _red)),
                              )
                            : Text('-',
                                style: TextStyle(
                                    color:
                                        Colors.grey.shade400)),
                      ),
                    ),
                    // Balance
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius:
                                BorderRadius.circular(4),
                          ),
                          child: Text('$bal',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _dark)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _th(String text,
      {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(text.toUpperCase(),
          textAlign: align,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
              letterSpacing: 0.6)),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FOOTER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFooter() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: _dark,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          // Product info
          if (isAllProducts) ...[
            const Icon(Icons.apps, size: 16, color: Colors.white54),
            const SizedBox(width: 8),
            const Text('All Products',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600)),
          ] else if (selectedProduct != null) ...[
            const Icon(Icons.medication_outlined,
                size: 16, color: Colors.white54),
            const SizedBox(width: 8),
            Text(selectedProduct!.itemName,
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600)),
          ],
          Text(
            '  •  ${filteredEntries.length} transactions',
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.4)),
          ),

          const Spacer(),

          _footerMetric('Opening', '$openingStock', _purple),
          const SizedBox(width: 16),
          _footerMetric(
              'In', '+$totalIn', const Color(0xFF34D399)),
          const SizedBox(width: 16),
          _footerMetric(
              'Out', '-$totalOut', const Color(0xFFFCA5A5)),
          const SizedBox(width: 16),

          // Closing stock highlight
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _primary.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory,
                    size: 14, color: Colors.white70),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Closing',
                        style: TextStyle(
                            fontSize: 9,
                            color:
                                Colors.white.withOpacity(0.6))),
                    Text('$closingStock',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF34D399))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 9,
                color: Colors.white.withOpacity(0.5))),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color)),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HELPER MODEL
// ═════════════════════════════════════════════════════════════════════════════

class _CardData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool highlighted;

  const _CardData(this.label, this.value, this.icon, this.color,
      {this.highlighted = false});
}