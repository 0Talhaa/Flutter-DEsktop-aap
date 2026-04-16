import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/services/database_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'dart:io';

class PurchaseReport extends StatefulWidget {
  const PurchaseReport({super.key});

  @override
  State<PurchaseReport> createState() => _PurchaseReportState();
}

class _PurchaseReportState extends State<PurchaseReport> {
  // ─── State ───────────────────────────────────────────────────────────────────
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate   = DateTime.now();

  List<Map<String, dynamic>> allPurchases      = [];
  List<Map<String, dynamic>> filteredPurchases = [];
  bool   isLoading   = true;
  bool   isExporting = false;
  String searchQuery = '';
  String sortBy      = 'Date (Newest)';

  // ─── Controllers ─────────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController       _scrollCtrl = ScrollController();

  // ─── Metrics ─────────────────────────────────────────────────────────────────
  double totalPurchaseAmount = 0.0;
  int    totalInvoices       = 0;
  int    totalItemsBought    = 0;
  double avgInvoiceValue     = 0.0;
  String topSupplier         = '-';
  int    uniqueSuppliers     = 0;

  // ─── Formats ─────────────────────────────────────────────────────────────────
  final _currency = NumberFormat.currency(locale: 'en_PK', symbol: 'Rs. ', decimalDigits: 0);
  final _date     = DateFormat('dd MMM yyyy');
  final _dateFile = DateFormat('yyyyMMdd_HHmmss');

  // ─── Sort options ─────────────────────────────────────────────────────────────
  final List<String> _sortOptions = [
    'Date (Newest)',
    'Date (Oldest)',
    'Amount (High to Low)',
    'Amount (Low to High)',
    'Supplier (A-Z)',
  ];

  // ─── Theme colors ─────────────────────────────────────────────────────────────
  static const _primary   = Color(0xFF009688);
  static const _dark      = Color(0xFF1E293B);
  static const _muted     = Color(0xFF64748B);
  static const _surface   = Color(0xFFF8FAFC);
  static const _border    = Color(0xFFE2E8F0);

  // ─── Font ─────────────────────────────────────────────────────────────────────
  pw.Font? _pdfFont;
  pw.Font? _pdfFontItalic;

  @override
  void initState() {
    super.initState();
    _loadFonts();
    _loadReport();
  }

  Future<void> _loadFonts() async {
    final regular = await rootBundle.load('assets/fonts/Roboto/static/Roboto_Condensed-Italic.ttf');
    _pdfFontItalic = pw.Font.ttf(regular);
    // Roboto regular fallback (use same file or add another)
    _pdfFont = _pdfFontItalic;
  }

  // ─── Data ─────────────────────────────────────────────────────────────────────
  Future<void> _loadReport() async {
    setState(() => isLoading = true);

    final from = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final to   = DateTime(toDate.year, toDate.month, toDate.day)
        .add(const Duration(days: 1));

    try {
      final data = await DatabaseHelper.instance.getPurchasesInDateRange(
        from.toIso8601String(),
        to.toIso8601String(),
      );
      allPurchases = data;
      _applyFiltersAndSort();
    } catch (e) {
      _showSnack('Error loading purchases: $e', isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _applyFiltersAndSort() {
    List<Map<String, dynamic>> temp = List.from(allPurchases);

    // Search
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      temp = temp.where((p) {
        final supplier = (p['supplierName'] ?? '').toString().toLowerCase();
        final invoice  = (p['invoiceNumber'] ?? '').toString().toLowerCase();
        return supplier.contains(q) || invoice.contains(q);
      }).toList();
    }

    // Sort
    switch (sortBy) {
      case 'Date (Newest)':
        temp.sort((a, b) =>
            DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
        break;
      case 'Date (Oldest)':
        temp.sort((a, b) =>
            DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));
        break;
      case 'Amount (High to Low)':
        temp.sort((a, b) =>
            (b['totalAmount'] as double).compareTo(a['totalAmount'] as double));
        break;
      case 'Amount (Low to High)':
        temp.sort((a, b) =>
            (a['totalAmount'] as double).compareTo(b['totalAmount'] as double));
        break;
      case 'Supplier (A-Z)':
        temp.sort((a, b) =>
            (a['supplierName'] ?? '').compareTo(b['supplierName'] ?? ''));
        break;
    }

    // Metrics
    double  totalAmt = 0.0;
    int     items    = 0;
    final   Map<String, int> freq = {};

    for (final p in temp) {
      totalAmt += (p['totalAmount'] as double);
      items    += (p['items'] as List).length;
      final s  = p['supplierName'] ?? 'Unknown';
      freq[s]  = (freq[s] ?? 0) + 1;
    }

    String topSup = '-';
    if (freq.isNotEmpty) {
      topSup = freq.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    setState(() {
      filteredPurchases  = temp;
      totalPurchaseAmount = totalAmt;
      totalInvoices      = temp.length;
      totalItemsBought   = items;
      avgInvoiceValue    = temp.isNotEmpty ? totalAmt / temp.length : 0.0;
      topSupplier        = topSup;
      uniqueSuppliers    = temp.map((e) => e['supplierName']).toSet().length;
    });
  }

  // ─── Date Picker ──────────────────────────────────────────────────────────────
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
    if (picked == null) return;
    setState(() {
      if (isFrom) fromDate = picked;
      else        toDate   = picked;
    });
  }

  // ─── Export PDF ───────────────────────────────────────────────────────────────
  Future<void> _exportPDF() async {
    setState(() => isExporting = true);
    try {
      final doc = pw.Document();
      final font       = _pdfFont;
      final fontItalic = _pdfFontItalic;

      final baseStyle   = pw.TextStyle(font: font, fontSize: 9);
      final headerStyle = pw.TextStyle(
          font: font, fontSize: 8, color: PdfColors.white,
          fontWeight: pw.FontWeight.bold);
      final titleStyle  = pw.TextStyle(
          font: font, fontSize: 16, fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('009688'));
      final subStyle    = pw.TextStyle(
          font: fontItalic, fontSize: 8, color: PdfColors.grey600);

      // Summary rows
      final summaryData = [
        ['Total Purchases', _currency.format(totalPurchaseAmount)],
        ['Total Invoices',  totalInvoices.toString()],
        ['Items Bought',    totalItemsBought.toString()],
        ['Unique Suppliers',uniqueSuppliers.toString()],
        ['Avg Invoice',     _currency.format(avgInvoiceValue)],
        ['Top Supplier',    topSupplier],
      ];

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          header: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Purchase Report', style: titleStyle),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '${_date.format(fromDate)}  →  ${_date.format(toDate)}',
                        style: subStyle,
                      ),
                    ],
                  ),
                  pw.Text(
                    'Generated: ${_date.format(DateTime.now())}',
                    style: subStyle,
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColor.fromHex('009688'), thickness: 1.5),
              pw.SizedBox(height: 8),
              // Summary grid
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: summaryData.map((s) => _pdfSummaryBox(s[0], s[1], font)).toList(),
              ),
              pw.SizedBox(height: 12),
            ],
          ),
          build: (ctx) => [
            // Table
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(2),
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('1E293B')),
                  children: ['Date', 'Invoice #', 'Supplier', 'Items', 'Amount']
                      .map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6, vertical: 6),
                            child: pw.Text(h, style: headerStyle),
                          ))
                      .toList(),
                ),
                // Data rows
                ...filteredPurchases.asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  final bg = i.isEven ? PdfColors.white : PdfColor.fromHex('F8FAFC');
                  final itemCount = (p['items'] as List).length;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      _pdfCell(_date.format(DateTime.parse(p['date'])), baseStyle),
                      _pdfCell(p['invoiceNumber'] ?? '-', baseStyle),
                      _pdfCell(p['supplierName'] ?? '-', baseStyle),
                      _pdfCell('$itemCount', baseStyle, align: pw.TextAlign.center),
                      _pdfCell(
                        _currency.format(p['totalAmount']),
                        baseStyle.copyWith(
                            color: PdfColor.fromHex('009688'),
                            fontWeight: pw.FontWeight.bold),
                        align: pw.TextAlign.right,
                      ),
                    ],
                  );
                }),
                // Total row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('E2E8F0')),
                  children: [
                    _pdfCell('TOTAL', pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), span: 4),
                    pw.SizedBox(),
                    pw.SizedBox(),
                    pw.SizedBox(),
                    _pdfCell(
                      _currency.format(totalPurchaseAmount),
                      pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('009688')),
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      final dir   = await getApplicationDocumentsDirectory();
      final file  = File('${dir.path}/purchase_report_${_dateFile.format(DateTime.now())}.pdf');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      _showExportDialog(file.path, 'PDF');
    } catch (e) {
      _showSnack('PDF export failed: $e', isError: true);
    } finally {
      setState(() => isExporting = false);
    }
  }

  pw.Widget _pdfSummaryBox(String label, String value, pw.Font? font) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('F0FDF4'),
        border: pw.Border.all(color: PdfColor.fromHex('009688'), width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey600)),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: pw.TextStyle(
                  font: font, fontSize: 9, fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('009688'))),
        ],
      ),
    );
  }

  pw.Widget _pdfCell(String text, pw.TextStyle style,
      {pw.TextAlign align = pw.TextAlign.left, int span = 1}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(text, style: style, textAlign: align),
    );
  }

  // ─── Export Excel ─────────────────────────────────────────────────────────────
  Future<void> _exportExcel() async {
    setState(() => isExporting = true);
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Purchase Report'];

      // Remove default Sheet1
      excel.delete('Sheet1');

      // Title
      sheet.merge(
        CellIndex.indexByString('A1'),
        CellIndex.indexByString('E1'),
      );
      final titleCell = sheet.cell(CellIndex.indexByString('A1'));
      titleCell.value = TextCellValue('PURCHASE REPORT');
      titleCell.cellStyle = CellStyle(
        bold: true,
        fontSize: 14,
        fontColorHex: ExcelColor.fromHexString('009688'),
        horizontalAlign: HorizontalAlign.Center,
      );

      // Date range
      sheet.merge(
        CellIndex.indexByString('A2'),
        CellIndex.indexByString('E2'),
      );
      final rangeCell = sheet.cell(CellIndex.indexByString('A2'));
      rangeCell.value = TextCellValue(
          '${_date.format(fromDate)}  to  ${_date.format(toDate)}');
      rangeCell.cellStyle = CellStyle(
        italic: true,
        fontSize: 9,
        horizontalAlign: HorizontalAlign.Center,
      );

      // Gap
      sheet.appendRow([TextCellValue('')]);

      // Summary header
      final summaryHeader = sheet.cell(CellIndex.indexByString('A4'));
      summaryHeader.value = TextCellValue('SUMMARY');
      summaryHeader.cellStyle = CellStyle(bold: true, fontSize: 10);

      final summaryRows = [
        ['Total Purchases', _currency.format(totalPurchaseAmount)],
        ['Total Invoices',  totalInvoices.toString()],
        ['Items Bought',    totalItemsBought.toString()],
        ['Unique Suppliers',uniqueSuppliers.toString()],
        ['Avg Invoice Value',_currency.format(avgInvoiceValue)],
        ['Top Supplier',    topSupplier],
      ];

      int row = 5;
      for (final s in summaryRows) {
        final labelCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row - 1));
        labelCell.value = TextCellValue(s[0]);
        labelCell.cellStyle = CellStyle(bold: true, fontSize: 9);

        final valueCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row - 1));
        valueCell.value = TextCellValue(s[1]);
        valueCell.cellStyle = CellStyle(fontSize: 9);
        row++;
      }

      // Gap before table
      row += 1;

      // Table headers
      final headers = ['Date', 'Invoice #', 'Supplier', 'Items', 'Total Amount'];
      for (int c = 0; c < headers.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row - 1));
        cell.value = TextCellValue(headers[c]);
        cell.cellStyle = CellStyle(
          bold: true,
          fontSize: 9,
          fontColorHex: ExcelColor.fromHexString('FFFFFF'),
          backgroundColorHex: ExcelColor.fromHexString('1E293B'),
          horizontalAlign: HorizontalAlign.Center,
        );
      }
      row++;

      // Data rows
      for (int i = 0; i < filteredPurchases.length; i++) {
        final p = filteredPurchases[i];
        final bg = i.isEven
            ? ExcelColor.fromHexString('FFFFFF')
            : ExcelColor.fromHexString('F8FAFC');

        final rowData = [
          _date.format(DateTime.parse(p['date'])),
          p['invoiceNumber'] ?? '-',
          p['supplierName'] ?? '-',
          '${(p['items'] as List).length}',
          _currency.format(p['totalAmount']),
        ];

        for (int c = 0; c < rowData.length; c++) {
          final cell = sheet.cell(
              CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row - 1));
          cell.value = TextCellValue(rowData[c]);
          cell.cellStyle = CellStyle(
            fontSize: 9,
            backgroundColorHex: bg,
            fontColorHex: c == 4
                ? ExcelColor.fromHexString('009688')
                : ExcelColor.fromHexString('1E293B'),
            bold: c == 4,
          );
        }
        row++;
      }

      // Total row
      final totalLabel = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row - 1));
      totalLabel.value = TextCellValue('TOTAL');
      totalLabel.cellStyle = CellStyle(
        bold: true,
        fontSize: 9,
        backgroundColorHex: ExcelColor.fromHexString('E2E8F0'),
      );

      // Merge total label across cols 0-3
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row - 1),
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row - 1),
      );

      final totalValue = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row - 1));
      totalValue.value = TextCellValue(_currency.format(totalPurchaseAmount));
      totalValue.cellStyle = CellStyle(
        bold: true,
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('009688'),
        backgroundColorHex: ExcelColor.fromHexString('E2E8F0'),
      );

      // Column widths
      sheet.setColumnWidth(0, 15);
      sheet.setColumnWidth(1, 15);
      sheet.setColumnWidth(2, 30);
      sheet.setColumnWidth(3, 10);
      sheet.setColumnWidth(4, 20);

      // Save
      final bytes = excel.save();
      if (bytes == null) throw Exception('Failed to generate Excel');

      final dir  = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/purchase_report_${_dateFile.format(DateTime.now())}.xlsx');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      _showExportDialog(file.path, 'Excel');
    } catch (e) {
      _showSnack('Excel export failed: $e', isError: true);
    } finally {
      setState(() => isExporting = false);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────
  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : _primary,
    ));
  }

  void _showExportDialog(String path, String type) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(type == 'PDF' ? Icons.picture_as_pdf : Icons.table_chart,
                color: _primary),
            const SizedBox(width: 8),
            Text('$type Exported', style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('File saved successfully.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: Text(path,
                  style: const TextStyle(fontSize: 11, color: _muted)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              OpenFilex.open(path);
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow    = screenWidth < 900;

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _primary))
            : Column(
                children: [
                  _buildTopBar(isNarrow),
                  _buildSummaryStrip(isNarrow),
                  _buildToolbar(isNarrow),
                  Expanded(child: _buildTable()),
                  _buildFooter(),
                ],
              ),
      ),
    );
  }

  // ─── Top Bar ──────────────────────────────────────────────────────────────────
  Widget _buildTopBar(bool isNarrow) {
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
                _buildTitleSection(),
                const SizedBox(height: 12),
                _buildDateAndActions(isNarrow),
              ],
            )
          : Row(
              children: [
                _buildTitleSection(),
                const Spacer(),
                _buildDateAndActions(isNarrow),
              ],
            ),
    );
  }

  Widget _buildTitleSection() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.shopping_cart_outlined,
              color: _primary, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Purchase Report',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _dark)),
            Text(
              '${_date.format(fromDate)}  →  ${_date.format(toDate)}',
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateAndActions(bool isNarrow) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // From date
        _buildDateChip('From', fromDate, () => _selectDate(true)),
        const Icon(Icons.arrow_forward, size: 14, color: _muted),
        // To date
        _buildDateChip('To', toDate, () => _selectDate(false)),

        const SizedBox(width: 4),

        // Generate
        _buildActionBtn(
          icon: Icons.refresh,
          label: 'Generate',
          color: _primary,
          onTap: _loadReport,
        ),

        // Export Excel
        _buildActionBtn(
          icon: Icons.table_chart_outlined,
          label: 'Excel',
          color: const Color(0xFF16A34A),
          onTap: isExporting ? null : _exportExcel,
        ),

        // Export PDF
        _buildActionBtn(
          icon: Icons.picture_as_pdf_outlined,
          label: 'PDF',
          color: const Color(0xFFDC2626),
          onTap: isExporting ? null : _exportPDF,
        ),
      ],
    );
  }

  Widget _buildDateChip(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label: ',
                style:
                    const TextStyle(fontSize: 10, color: _muted)),
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
  }) {
    final disabled = onTap == null;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: disabled ? Colors.grey.shade100 : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: disabled ? Colors.grey.shade300 : color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            disabled
                ? SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: color))
                : Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: disabled ? Colors.grey : color)),
          ],
        ),
      ),
    );
  }

  // ─── Summary Strip ────────────────────────────────────────────────────────────
  Widget _buildSummaryStrip(bool isNarrow) {
    final cards = [
      _SummaryCard('Total Purchases', _currency.format(totalPurchaseAmount),
          Icons.monetization_on_outlined, _primary, highlighted: true),
      _SummaryCard('Total Invoices', totalInvoices.toString(),
          Icons.receipt_long_outlined, const Color(0xFFF59E0B)),
      _SummaryCard('Items Bought', totalItemsBought.toString(),
          Icons.dashboard_outlined, const Color(0xFF3B82F6)),
      _SummaryCard('Unique Suppliers', uniqueSuppliers.toString(),
          Icons.people_outline, const Color(0xFF8B5CF6)),
      _SummaryCard('Avg Invoice', _currency.format(avgInvoiceValue),
          Icons.analytics_outlined, const Color(0xFF06B6D4)),
      _SummaryCard('Top Supplier', topSupplier,
          Icons.local_shipping_outlined, const Color(0xFFF97316)),
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
                      width: (MediaQuery.of(context).size.width - 56) / 2,
                      child: _buildSummaryCard(c)))
                  .toList(),
            )
          : Row(
              children: cards
                  .map((c) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _buildSummaryCard(c),
                        ),
                      ))
                  .toList(),
            ),
    );
  }

  Widget _buildSummaryCard(_SummaryCard c) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:
            c.highlighted ? c.color.withOpacity(0.06) : _surface,
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
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(c.icon, color: c.color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.label,
                    style: const TextStyle(fontSize: 9, color: _muted)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    c.value,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.highlighted ? c.color : _dark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Toolbar ──────────────────────────────────────────────────────────────────
  Widget _buildToolbar(bool isNarrow) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: _border),
          bottom: BorderSide(color: _border),
        ),
      ),
      child: Row(
        children: [
          // Search
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search by supplier or invoice…',
                  hintStyle:
                      TextStyle(fontSize: 11, color: Colors.grey.shade400),
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
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () {
                            _searchCtrl.clear();
                            searchQuery = '';
                            _applyFiltersAndSort();
                          },
                        )
                      : null,
                ),
                onChanged: (v) {
                  searchQuery = v;
                  _applyFiltersAndSort();
                },
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Sort
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: sortBy,
                isDense: true,
                style: const TextStyle(fontSize: 11, color: _dark),
                icon: const Icon(Icons.unfold_more,
                    size: 14, color: _muted),
                items: _sortOptions
                    .map((o) => DropdownMenuItem(
                        value: o,
                        child: Text(o,
                            style: const TextStyle(fontSize: 11))))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  sortBy = v;
                  _applyFiltersAndSort();
                },
              ),
            ),
          ),

          const SizedBox(width: 12),
          Text(
            '${filteredPurchases.length} record${filteredPurchases.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 11, color: _muted),
          ),
        ],
      ),
    );
  }

  // ─── Table ────────────────────────────────────────────────────────────────────
  Widget _buildTable() {
    if (filteredPurchases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.remove_shopping_cart_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No purchases found',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text('Try adjusting the date range or search term',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: _dark,
          child: Row(
            children: [
              _th('Date', flex: 2),
              _th('Invoice #', flex: 2),
              _th('Supplier', flex: 4),
              _th('Items', flex: 1, align: TextAlign.center),
              _th('Amount', flex: 2, align: TextAlign.right),
            ],
          ),
        ),

        // Rows
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            itemCount: filteredPurchases.length,
            itemBuilder: (ctx, i) {
              final p    = filteredPurchases[i];
              final isEven = i % 2 == 0;
              final items  = (p['items'] as List).length;

              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  color: isEven ? Colors.white : _surface,
                  border: const Border(
                      bottom: BorderSide(color: _border, width: 0.5)),
                ),
                child: Row(
                  children: [
                    // Date
                    Expanded(
                      flex: 2,
                      child: Text(
                        _date.format(DateTime.parse(p['date'])),
                        style: const TextStyle(
                            fontSize: 12, color: _muted),
                      ),
                    ),
                    // Invoice
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Icon(Icons.description_outlined,
                              size: 13,
                              color: Colors.grey.shade400),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              p['invoiceNumber'] ?? '-',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _dark),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Supplier
                    Expanded(
                      flex: 4,
                      child: Text(
                        p['supplierName'] ?? '-',
                        style: const TextStyle(
                            fontSize: 12, color: _dark),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Items badge
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$items',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3B82F6))),
                        ),
                      ),
                    ),
                    // Amount
                    Expanded(
                      flex: 2,
                      child: Text(
                        _currency.format(p['totalAmount']),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _primary),
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
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
            letterSpacing: 0.6),
      ),
    );
  }

  // ─── Footer ───────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Text(
            '${filteredPurchases.length} of ${allPurchases.length} records',
            style: const TextStyle(fontSize: 11, color: _muted),
          ),
          const Spacer(),
          const Text('Total:  ',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _dark)),
          Text(
            _currency.format(totalPurchaseAmount),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: _primary),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
}

// ─── Helper model ─────────────────────────────────────────────────────────────
class _SummaryCard {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  final bool     highlighted;

  const _SummaryCard(
      this.label, this.value, this.icon, this.color,
      {this.highlighted = false});
}