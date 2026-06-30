

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../services/database_helper.dart';
import '../models/purchase.dart';
import '../models/supplier.dart';

class PurchaseListScreen extends StatefulWidget {
  const PurchaseListScreen({super.key});

  @override
  State<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends State<PurchaseListScreen> {
  // ── Controllers ────────────────────────────────────────────────────────────
  final TextEditingController _invoiceSearchController =
      TextEditingController();

  // ── State ──────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _allPurchases = [];
  List<Map<String, dynamic>> _filtered = [];
  List<Supplier> _suppliers = [];
  Supplier? _selectedSupplier;

  DateTime? _fromDate;
  DateTime? _toDate;
  String _invoiceQuery = '';
  bool _isLoading = true;
  bool _isExporting = false;

  // ── Format ─────────────────────────────────────────────────────────────────
  final _currency = NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'Rs. ',
    decimalDigits: 0,
  );
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _dateTimeFmt = DateFormat('dd MMM yyyy, hh:mm a');

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime.now().subtract(const Duration(days: 30));
    _toDate = DateTime.now();
    _loadData();
    _invoiceSearchController.addListener(() {
      setState(() => _invoiceQuery = _invoiceSearchController.text.trim());
      _applyFilters();
    });
  }

  @override
  void dispose() {
    _invoiceSearchController.dispose();
    super.dispose();
  }

  // ============================================================
  // DATA
  // ============================================================

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final db = DatabaseHelper.instance;
      final suppliers = await db.getAllSuppliers();

      // Load ALL purchases (wide range) then filter in-memory for speed
      final from = '2000-01-01';
      final to = '2099-12-31';
      final purchases = await db.getPurchasesInDateRange(from, to);

      setState(() {
        _suppliers = suppliers;
        _allPurchases = purchases;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error loading purchases: $e');
    }
  }

  void _applyFilters() {
    final from = _fromDate != null
        ? DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day)
        : null;
    final to = _toDate != null
        ? DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59)
        : null;

    setState(() {
      _filtered = _allPurchases.where((p) {
        // Date filter
        if (from != null || to != null) {
          final rawDate = p['date'] as String? ?? '';
          DateTime? pDate;
          try {
            pDate = DateTime.parse(rawDate);
          } catch (_) {}
          if (pDate != null) {
            if (from != null && pDate.isBefore(from)) return false;
            if (to != null && pDate.isAfter(to)) return false;
          }
        }

        // Supplier filter
        if (_selectedSupplier != null) {
          if ((p['supplierName'] as String? ?? '') !=
              _selectedSupplier!.name) {
            return false;
          }
        }

        // Invoice search
        if (_invoiceQuery.isNotEmpty) {
          final inv = (p['invoiceNumber'] as String? ?? '').toLowerCase();
          if (!inv.contains(_invoiceQuery.toLowerCase())) return false;
        }

        return true;
      }).toList()
        ..sort((a, b) {
          final aDate = a['date'] as String? ?? '';
          final bDate = b['date'] as String? ?? '';
          return bDate.compareTo(aDate); // newest first
        });
    });
  }

  // ============================================================
  // FIND BY INVOICE (called from Find button in Purchase entry)
  // ============================================================

  /// Call this from PurchaseScreenDesktop's _showFindDialog
  static Future<Map<String, dynamic>?> findByInvoice(
      BuildContext context, String invoiceNumber) async {
    try {
      final db = DatabaseHelper.instance;
      final purchases =
          await db.getPurchasesInDateRange('2000-01-01', '2099-12-31');
      final match = purchases.where((p) {
        return (p['invoiceNumber'] as String? ?? '')
            .toLowerCase()
            .contains(invoiceNumber.toLowerCase());
      }).toList();

      if (match.isEmpty) return null;
      if (match.length == 1) return match.first;

      // Show picker if multiple results
      return await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _InvoicePickerDialog(results: match),
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // DATE PICKERS
  // ============================================================

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
      _applyFilters();
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
      _applyFilters();
    }
  }

  void _setQuickRange(String range) {
    final now = DateTime.now();
    setState(() {
      switch (range) {
        case 'today':
          _fromDate = DateTime(now.year, now.month, now.day);
          _toDate = now;
          break;
        case 'week':
          _fromDate = now.subtract(const Duration(days: 7));
          _toDate = now;
          break;
        case 'month':
          _fromDate = DateTime(now.year, now.month, 1);
          _toDate = now;
          break;
        case 'all':
          _fromDate = null;
          _toDate = null;
          break;
      }
    });
    _applyFilters();
  }

  // ============================================================
  // PDF EXPORT
  // ============================================================

  Future<void> _exportToPdf(Map<String, dynamic> purchase) async {
    setState(() => _isExporting = true);
    try {
      // Get items for this purchase
      final items = purchase['items'] as List? ?? [];
      final companySettings =
          await DatabaseHelper.instance.getCompanySettings();

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            _pdfHeader(companySettings, purchase),
            pw.SizedBox(height: 16),
            _pdfPurchaseInfo(purchase),
            pw.SizedBox(height: 16),
            _pdfItemsTable(items),
            pw.SizedBox(height: 16),
            _pdfTotals(purchase),
            pw.SizedBox(height: 24),
            _pdfFooter(),
          ],
        ),
      );

      // Save to temp directory
      final dir = await getTemporaryDirectory();
      final invoiceNo =
          (purchase['invoiceNumber'] as String? ?? 'purchase').replaceAll(
              RegExp(r'[^\w]'), '_');
      final file = File('${dir.path}/purchase_$invoiceNo.pdf');
      await file.writeAsBytes(await pdf.save());

      // Open the PDF
      await OpenFile.open(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved: ${file.path}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      _showError('PDF export failed: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── PDF building blocks ────────────────────────────────────────────────────

  pw.Widget _pdfHeader(
      Map<String, String?> company, Map<String, dynamic> purchase) {
    final shopName = company['shop_name'] ?? 'Medical Store';
    final shopAddress = company['shop_address'] ?? '';
    final shopPhone = company['shop_phone'] ?? '';

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal700,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(shopName,
                    style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
                if (shopAddress.isNotEmpty)
                  pw.Text(shopAddress,
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.white)),
                if (shopPhone.isNotEmpty)
                  pw.Text('Tel: $shopPhone',
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.white)),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('PURCHASE INVOICE',
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
              pw.Text(
                  '#${purchase['invoiceNumber'] ?? ''}',
                  style: const pw.TextStyle(
                      fontSize: 12, color: PdfColors.white)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfPurchaseInfo(Map<String, dynamic> purchase) {
    String formattedDate = '';
    try {
      formattedDate =
          _dateTimeFmt.format(DateTime.parse(purchase['date'] as String));
    } catch (_) {
      formattedDate = purchase['date'] as String? ?? '';
    }

    final balance = (purchase['balance'] as num?)?.toDouble() ?? 0.0;
    final status = balance <= 0 ? 'PAID' : 'PENDING';
    final statusColor = balance <= 0 ? PdfColors.green : PdfColors.orange;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('SUPPLIER',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey600)),
                pw.Text(purchase['supplierName'] as String? ?? '',
                    style: pw.TextStyle(
                        fontSize: 13, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _pdfInfoRow('Date:', formattedDate),
                _pdfInfoRow('Invoice:', purchase['invoiceNumber'] ?? ''),
                _pdfInfoRow('Notes:', purchase['notes'] ?? '-'),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('STATUS',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey600)),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: statusColor,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(status,
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700)),
          pw.SizedBox(width: 4),
          pw.Text(value,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
        ],
      ),
    );
  }

  pw.Widget _pdfItemsTable(List items) {
    final headers = [
      '#',
      'Product Name',
      'Unit',
      'Qty',
      'Trade Price',
      'Discount',
      'Amount'
    ];
    final colWidths = [
      0.04,
      0.30,
      0.10,
      0.08,
      0.16,
      0.12,
      0.18,
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        for (int i = 0; i < colWidths.length; i++)
          i: pw.FlexColumnWidth(colWidths[i] * 100),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.teal700),
          children: headers
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6, vertical: 6),
                    child: pw.Text(h,
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9),
                        textAlign: pw.TextAlign.center),
                  ))
              .toList(),
        ),
        // Rows
        ...items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final qty = (item['quantity'] as num?)?.toInt() ?? 0;
          final tp = (item['tradePrice'] as num?)?.toDouble() ?? 0.0;
          final disc = (item['discount'] as num?)?.toDouble() ?? 0.0;
          final lineTotal = (item['lineTotal'] as num?)?.toDouble() ??
              (tp * qty * (1 - disc / 100));
          final bg =
              i.isEven ? PdfColors.white : const PdfColor(0.96, 0.97, 0.97);

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              _pdfCell('${i + 1}', center: true),
              _pdfCell(item['productName'] as String? ?? ''),
              _pdfCell(item['unitType'] as String? ?? item['packing'] as String? ?? 'Pc',
                  center: true),
              _pdfCell('$qty', center: true),
              _pdfCell(_currency.format(tp), center: true),
              _pdfCell(disc > 0 ? '${disc.toStringAsFixed(0)}%' : '-',
                  center: true),
              _pdfCell(_currency.format(lineTotal), center: true),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _pdfCell(String text,
      {bool center = false, bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? PdfColors.black),
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  pw.Widget _pdfTotals(Map<String, dynamic> purchase) {
    final total = (purchase['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final paid = (purchase['amountPaid'] as num?)?.toDouble() ?? 0.0;
    final balance = (purchase['balance'] as num?)?.toDouble() ?? 0.0;

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 260,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          children: [
            _pdfTotalRow('Total Amount', _currency.format(total),
                bold: true, bgColor: PdfColors.grey200),
            _pdfTotalRow('Amount Paid', _currency.format(paid),
                textColor: PdfColors.green700),
            _pdfTotalRow('Balance Due', _currency.format(balance),
                bold: true,
                textColor: balance > 0 ? PdfColors.red700 : PdfColors.green700,
                bgColor: balance > 0
                    ? const PdfColor(1, 0.93, 0.93)
                    : const PdfColor(0.93, 1, 0.93)),
          ],
        ),
      ),
    );
  }

  pw.Widget _pdfTotalRow(String label, String value,
      {bool bold = false, PdfColor? textColor, PdfColor? bgColor}) {
    return pw.Container(
      color: bgColor,
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: bold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  color: PdfColors.grey800)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: textColor ?? PdfColors.black)),
        ],
      ),
    );
  }

  pw.Widget _pdfFooter() {
    return pw.Center(
      child: pw.Text(
        'Thank you for your business! — Generated on ${_dateTimeFmt.format(DateTime.now())}',
        style:
            const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
    );
  }

  // ============================================================
  // SUMMARY STATS
  // ============================================================

  double get _totalFiltered =>
      _filtered.fold(0.0, (s, p) => s + ((p['totalAmount'] as num?)?.toDouble() ?? 0.0));

  double get _totalPaid =>
      _filtered.fold(0.0, (s, p) => s + ((p['amountPaid'] as num?)?.toDouble() ?? 0.0));

  double get _totalBalance =>
      _filtered.fold(0.0, (s, p) => s + ((p['balance'] as num?)?.toDouble() ?? 0.0));

  // ============================================================
  // HELPERS
  // ============================================================

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      return _dateFmt.format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  String _statusLabel(Map<String, dynamic> p) {
    final balance = (p['balance'] as num?)?.toDouble() ?? 0.0;
    final paid = (p['amountPaid'] as num?)?.toDouble() ?? 0.0;
    final total = (p['totalAmount'] as num?)?.toDouble() ?? 0.0;
    if (balance <= 0) return 'PAID';
    if (paid > 0 && paid < total) return 'PARTIAL';
    return 'CREDIT';
  }

  Color _statusColor(Map<String, dynamic> p) {
    switch (_statusLabel(p)) {
      case 'PAID':
        return Colors.green;
      case 'PARTIAL':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F6),
      appBar: AppBar(
        title: const Text('Purchase History',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0D6E6E),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterBar(),
                _buildSummaryCards(),
                Expanded(child: _buildTable()),
              ],
            ),
    );
  }

  // ── Filter Bar ─────────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          // Row 1: Invoice search + Supplier dropdown
          Row(
            children: [
              // Invoice search
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _invoiceSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search by Invoice No...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _invoiceQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _invoiceSearchController.clear();
                              _applyFilters();
                            })
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Supplier dropdown
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<Supplier?>(
                  value: _selectedSupplier,
                  hint: const Text('All Suppliers'),
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    prefixIcon:
                        const Icon(Icons.business, size: 18),
                  ),
                  items: [
                    const DropdownMenuItem<Supplier?>(
                        value: null, child: Text('All Suppliers')),
                    ..._suppliers.map((s) => DropdownMenuItem<Supplier?>(
                        value: s, child: Text(s.name))),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedSupplier = val);
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2: Date range + quick filters
          Row(
            children: [
              // From date
              Expanded(
                child: _DatePickerButton(
                  label: 'From',
                  date: _fromDate,
                  onTap: _pickFromDate,
                ),
              ),
              const SizedBox(width: 8),
              // To date
              Expanded(
                child: _DatePickerButton(
                  label: 'To',
                  date: _toDate,
                  onTap: _pickToDate,
                ),
              ),
              const SizedBox(width: 12),
              // Quick buttons
              _QuickFilter(
                  label: 'Today',
                  onTap: () => _setQuickRange('today')),
              const SizedBox(width: 6),
              _QuickFilter(
                  label: '7 Days',
                  onTap: () => _setQuickRange('week')),
              const SizedBox(width: 6),
              _QuickFilter(
                  label: 'This Month',
                  onTap: () => _setQuickRange('month')),
              const SizedBox(width: 6),
              _QuickFilter(
                  label: 'All Time',
                  color: Colors.grey,
                  onTap: () => _setQuickRange('all')),
            ],
          ),
        ],
      ),
    );
  }

  // ── Summary Cards ──────────────────────────────────────────────────────────

  Widget _buildSummaryCards() {
    return Container(
      color: const Color(0xFFEEF2F6),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          _SummaryCard(
            label: 'Total Purchases',
            value: '${_filtered.length}',
            icon: Icons.receipt_long,
            color: const Color(0xFF0D6E6E),
          ),
          const SizedBox(width: 12),
          _SummaryCard(
            label: 'Total Amount',
            value: _currency.format(_totalFiltered),
            icon: Icons.attach_money,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 12),
          _SummaryCard(
            label: 'Total Paid',
            value: _currency.format(_totalPaid),
            icon: Icons.check_circle_outline,
            color: Colors.green.shade700,
          ),
          const SizedBox(width: 12),
          _SummaryCard(
            label: 'Outstanding',
            value: _currency.format(_totalBalance),
            icon: Icons.pending_actions,
            color: _totalBalance > 0
                ? Colors.red.shade700
                : Colors.green.shade700,
          ),
        ],
      ),
    );
  }

  // ── Table ──────────────────────────────────────────────────────────────────

  Widget _buildTable() {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No purchases found',
                style: TextStyle(
                    fontSize: 16, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D6E6E),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(10)),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _hCell('#', flex: 1),
                _hCell('Date', flex: 2),
                _hCell('Invoice', flex: 2),
                _hCell('Supplier', flex: 3),
                _hCell('Total', flex: 2),
                _hCell('Paid', flex: 2),
                _hCell('Balance', flex: 2),
                _hCell('Status', flex: 2),
                _hCell('Action', flex: 2),
              ],
            ),
          ),
          // Body
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final p = _filtered[index];
                final isEven = index.isEven;
                final total =
                    (p['totalAmount'] as num?)?.toDouble() ?? 0.0;
                final paid =
                    (p['amountPaid'] as num?)?.toDouble() ?? 0.0;
                final balance =
                    (p['balance'] as num?)?.toDouble() ?? 0.0;
                final status = _statusLabel(p);
                final statusColor = _statusColor(p);

                return InkWell(
                  onTap: () => _showDetailDialog(p),
                  child: Container(
                    color: isEven
                        ? Colors.white
                        : Colors.grey.shade50,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        _dCell('${index + 1}', flex: 1),
                        _dCell(_formatDate(p['date'] as String?),
                            flex: 2),
                        _dCell(p['invoiceNumber'] as String? ?? '-',
                            flex: 2, bold: true),
                        _dCell(p['supplierName'] as String? ?? '-',
                            flex: 3),
                        _dCell(_currency.format(total),
                            flex: 2, color: Colors.blue.shade700),
                        _dCell(_currency.format(paid),
                            flex: 2, color: Colors.green.shade700),
                        _dCell(_currency.format(balance),
                            flex: 2,
                            color: balance > 0
                                ? Colors.red.shade700
                                : Colors.green.shade700),
                        // Status badge
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    statusColor.withOpacity(0.12),
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: Border.all(
                                    color: statusColor
                                        .withOpacity(0.4)),
                              ),
                              child: Text(status,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor)),
                            ),
                          ),
                        ),
                        // Actions
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 18),
                                tooltip: 'View Details',
                                color: Colors.blue.shade700,
                                onPressed: () =>
                                    _showDetailDialog(p),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 32, minHeight: 32),
                              ),
                              IconButton(
                                icon: _isExporting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child:
                                            CircularProgressIndicator(
                                                strokeWidth: 2))
                                    : const Icon(
                                        Icons.picture_as_pdf,
                                        size: 18),
                                tooltip: 'Export PDF',
                                color: Colors.red.shade600,
                                onPressed: _isExporting
                                    ? null
                                    : () => _exportToPdf(p),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                    minWidth: 32, minHeight: 32),
                              ),
                            ],
                          ),
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

  Widget _hCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white)),
    );
  }

  Widget _dCell(String text,
      {int flex = 1, bool bold = false, Color? color}) {
    return Expanded(
      flex: flex,
      child: Text(text,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black87)),
    );
  }

  // ============================================================
  // DETAIL DIALOG
  // ============================================================

  void _showDetailDialog(Map<String, dynamic> purchase) {
    final items = purchase['items'] as List? ?? [];
    final total =
        (purchase['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final paid =
        (purchase['amountPaid'] as num?)?.toDouble() ?? 0.0;
    final balance =
        (purchase['balance'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: 700,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D6E6E),
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long,
                        color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Invoice: ${purchase['invoiceNumber'] ?? ''}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Text(
                              '${purchase['supplierName'] ?? ''} • ${_formatDate(purchase['date'] as String?)}',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _exportToPdf(purchase);
                      },
                      icon: const Icon(Icons.picture_as_pdf,
                          color: Colors.white),
                      label: const Text('Export PDF',
                          style: TextStyle(color: Colors.white)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Items
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No items found'),
                        )
                      else
                        Table(
                          border: TableBorder.all(
                              color: Colors.grey.shade300),
                          columnWidths: const {
                            0: FlexColumnWidth(0.5),
                            1: FlexColumnWidth(3),
                            2: FlexColumnWidth(1),
                            3: FlexColumnWidth(1),
                            4: FlexColumnWidth(1.5),
                            5: FlexColumnWidth(1),
                            6: FlexColumnWidth(1.5),
                          },
                          children: [
                            // Header
                            TableRow(
                              decoration: const BoxDecoration(
                                  color: Color(0xFFEEF2F6)),
                              children: [
                                '#',
                                'Product',
                                'Unit',
                                'Qty',
                                'T.Price',
                                'Disc%',
                                'Amount'
                              ]
                                  .map((h) => Padding(
                                        padding:
                                            const EdgeInsets.all(8),
                                        child: Text(h,
                                            textAlign:
                                                TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.bold)),
                                      ))
                                  .toList(),
                            ),
                            // Item rows
                            ...items.asMap().entries.map((e) {
                              final i = e.key;
                              final item = e.value;
                              final qty =
                                  (item['quantity'] as num?)
                                          ?.toInt() ??
                                      0;
                              final tp =
                                  (item['tradePrice'] as num?)
                                          ?.toDouble() ??
                                      0.0;
                              final disc =
                                  (item['discount'] as num?)
                                          ?.toDouble() ??
                                      0.0;
                              final lt =
                                  (item['lineTotal'] as num?)
                                          ?.toDouble() ??
                                      (tp *
                                          qty *
                                          (1 - disc / 100));
                              return TableRow(
                                decoration: BoxDecoration(
                                    color: i.isEven
                                        ? Colors.white
                                        : Colors.grey.shade50),
                                children: [
                                  '${i + 1}',
                                  item['productName'] as String? ??
                                      '',
                                  item['unitType'] as String? ??
                                      item['packing'] as String? ??
                                      'Pc',
                                  '$qty',
                                  _currency.format(tp),
                                  disc > 0
                                      ? '${disc.toStringAsFixed(0)}%'
                                      : '-',
                                  _currency.format(lt),
                                ]
                                    .map((val) => Padding(
                                          padding:
                                              const EdgeInsets.all(
                                                  7),
                                          child: Text(val,
                                              textAlign:
                                                  TextAlign.center,
                                              style: const TextStyle(
                                                  fontSize: 11)),
                                        ))
                                    .toList(),
                              );
                            }),
                          ],
                        ),
                      const SizedBox(height: 16),
                      // Totals
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 280,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Colors.grey.shade300),
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              _dialogTotalRow(
                                  'Total Amount',
                                  _currency.format(total),
                                  bold: true),
                              _dialogTotalRow(
                                  'Amount Paid',
                                  _currency.format(paid),
                                  color: Colors.green.shade700),
                              _dialogTotalRow(
                                'Balance Due',
                                _currency.format(balance),
                                bold: true,
                                color: balance > 0
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                                bgColor: balance > 0
                                    ? Colors.red.shade50
                                    : Colors.green.shade50,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogTotalRow(String label, String value,
      {bool bold = false, Color? color, Color? bgColor}) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal,
                  color: Colors.grey.shade700)),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.normal,
                  color: color ?? Colors.black87)),
        ],
      ),
    );
  }
}

// ============================================================
// INVOICE PICKER (for Find dialog multiple results)
// ============================================================

class _InvoicePickerDialog extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  const _InvoicePickerDialog({required this.results});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Multiple Results Found'),
      content: SizedBox(
        width: 400,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: results.length,
          itemBuilder: (_, i) {
            final p = results[i];
            return ListTile(
              leading: const Icon(Icons.receipt),
              title: Text(p['invoiceNumber'] ?? ''),
              subtitle:
                  Text('${p['supplierName']} • ${p['date']}'),
              onTap: () => Navigator.pop(context, p),
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel')),
      ],
    );
  }
}

// ============================================================
// SMALL REUSABLE WIDGETS
// ============================================================

class _DatePickerButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DatePickerButton(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today,
                size: 16, color: const Color(0xFF0D6E6E)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                date != null ? '${label}: ${fmt.format(date!)}' : '$label: Any',
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickFilter extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _QuickFilter(
      {required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? const Color(0xFF0D6E6E),
        foregroundColor: Colors.white,
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 11),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(label),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade600)),
                  Text(value,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: color),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}