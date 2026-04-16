import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/models/sale_item.dart';
import 'package:medical_app/services/database_helper.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ═════════════════════════════════════════════════════════════════════════════
// DATA MODEL
// ═════════════════════════════════════════════════════════════════════════════

class DailyFinancials {
  final DateTime date;
  double sales;
  double cost;
  double expenses;

  DailyFinancials({
    required this.date,
    this.sales = 0.0,
    this.cost = 0.0,
    this.expenses = 0.0,
  });

  double get grossProfit => sales - cost;
  double get netProfit => grossProfit - expenses;
  double get marginPercent => sales > 0 ? (netProfit / sales) * 100 : 0.0;
}

// ═════════════════════════════════════════════════════════════════════════════
// WIDGET
// ═════════════════════════════════════════════════════════════════════════════

class ProfitLossReport extends StatefulWidget {
  const ProfitLossReport({super.key});

  @override
  State<ProfitLossReport> createState() => _ProfitLossReportState();
}

class _ProfitLossReportState extends State<ProfitLossReport> {
  // ── Filters ────────────────────────────────────────────────────────────────
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();
  String sortBy = 'Date (Newest)';

  // ── Data ───────────────────────────────────────────────────────────────────
  List<DailyFinancials> dailyBreakdown = [];
  bool isLoading = true;
  bool isExporting = false;

  // ── Totals ─────────────────────────────────────────────────────────────────
  double totalSales = 0.0;
  double totalCost = 0.0;
  double totalGrossProfit = 0.0;
  double totalExpenses = 0.0;
  double totalNetProfit = 0.0;
  double profitMargin = 0.0;

  // ── Formatters ─────────────────────────────────────────────────────────────
  final _currency =
      NumberFormat.currency(locale: 'en_PK', symbol: 'Rs. ', decimalDigits: 0);
  final _date = DateFormat('dd MMM yyyy');
  final _dateKey = DateFormat('yyyy-MM-dd');
  final _dateFile = DateFormat('yyyyMMdd_HHmmss');

  // ── Controllers ────────────────────────────────────────────────────────────
  final ScrollController _scrollCtrl = ScrollController();

  // ── Sort options ───────────────────────────────────────────────────────────
  final List<String> _sortOptions = [
    'Date (Newest)',
    'Date (Oldest)',
    'Net Profit (High to Low)',
    'Sales (High to Low)',
  ];

  // ── Quick presets ──────────────────────────────────────────────────────────
  final List<String> _presets = [
    'Today',
    'This Week',
    'This Month',
    'Last Month',
    'Last 30 Days',
    'This Year',
  ];

  // ── Theme ──────────────────────────────────────────────────────────────────
  static const _primary = Color(0xFF3B82F6);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);
  static const _orange = Color(0xFFF59E0B);
  static const _purple = Color(0xFF8B5CF6);
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
    _loadReport();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATA LOADING
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadReport() async {
    setState(() => isLoading = true);

    final from = fromDate.toIso8601String();
    final to = toDate.toIso8601String();

    try {
      final salesData =
          await DatabaseHelper.instance.getSalesInDateRange(from, to);
      final expenseData =
          await DatabaseHelper.instance.getExpensesInDateRange(from, to);

      final Map<String, DailyFinancials> dailyMap = {};
      for (int i = 0; i <= toDate.difference(fromDate).inDays; i++) {
        final d = fromDate.add(Duration(days: i));
        dailyMap[_dateKey.format(d)] = DailyFinancials(date: d);
      }

      for (final sale in salesData) {
        final rawDate =
            sale['dateTime'] ?? sale['saleDate'] ?? sale['date'];
        if (rawDate == null) continue;
        final saleDate = DateTime.tryParse(rawDate.toString());
        if (saleDate == null) continue;
        final key = _dateKey.format(saleDate);
        dailyMap.putIfAbsent(key, () => DailyFinancials(date: saleDate));

        final saleTotal = (sale['total'] as num?)?.toDouble() ?? 0.0;
        double saleCost = 0.0;

        final items = sale['items'];
        if (items is List) {
          for (final raw in items) {
            final item = raw is SaleItem ? raw : null;
            if (item == null) continue;
            final product =
                await DatabaseHelper.instance.getProductById(item.productId);
            if (product != null) {
              saleCost += item.quantity * product.tradePrice;
            }
          }
        }

        dailyMap[key]!.sales += saleTotal;
        dailyMap[key]!.cost += saleCost;
      }

      for (final expense in expenseData) {
        final rawDate = expense['date'];
        if (rawDate == null) continue;
        final expDate = DateTime.tryParse(rawDate.toString());
        if (expDate == null) continue;
        final key = _dateKey.format(expDate);
        dailyMap.putIfAbsent(key, () => DailyFinancials(date: expDate));
        dailyMap[key]!.expenses +=
            (expense['amount'] as num?)?.toDouble() ?? 0.0;
      }

      totalSales = totalCost = totalExpenses = 0;
      for (final day in dailyMap.values) {
        totalSales += day.sales;
        totalCost += day.cost;
        totalExpenses += day.expenses;
      }
      totalGrossProfit = totalSales - totalCost;
      totalNetProfit = totalGrossProfit - totalExpenses;
      profitMargin =
          totalSales > 0 ? (totalNetProfit / totalSales) * 100 : 0;

      final list = dailyMap.values.toList();
      _applySorting(list);

      setState(() {
        dailyBreakdown = list;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _snack('Error loading report: $e', isError: true);
    }
  }

  void _applySorting(List<DailyFinancials> list) {
    switch (sortBy) {
      case 'Date (Newest)':
        list.sort((a, b) => b.date.compareTo(a.date));
      case 'Date (Oldest)':
        list.sort((a, b) => a.date.compareTo(b.date));
      case 'Net Profit (High to Low)':
        list.sort((a, b) => b.netProfit.compareTo(a.netProfit));
      case 'Sales (High to Low)':
        list.sort((a, b) => b.sales.compareTo(a.sales));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATE PICKER & PRESETS
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
    _loadReport();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF EXPORT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _exportPDF() async {
    setState(() => isExporting = true);
    try {
      final pdf = pw.Document();

      const headerBg = PdfColor.fromInt(0xFF1E293B);
      const blue = PdfColor.fromInt(0xFF3B82F6);
      const pGreen = PdfColor.fromInt(0xFF10B981);
      const pRed = PdfColor.fromInt(0xFFEF4444);
      const pOrange = PdfColor.fromInt(0xFFF59E0B);
      const lightGrey = PdfColor.fromInt(0xFFF8FAFC);
      const borderC = PdfColor.fromInt(0xFFE2E8F0);

      pw.Widget pCell(String text,
          {PdfColor color = PdfColors.black,
          bool bold = false,
          pw.TextAlign align = pw.TextAlign.right,
          double fs = 8}) {
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: pw.Text(text,
              textAlign: align,
              style: pw.TextStyle(
                  fontSize: fs,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: color)),
        );
      }

      pw.Widget sumBox(String label, String value, PdfColor col) {
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
                        fontSize: 6.5,
                        color: PdfColors.grey600,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(value,
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: col)),
              ],
            ),
          ),
        );
      }

      const int rowsPerPage = 28;
      final chunks = <List<DailyFinancials>>[];
      for (int i = 0; i < dailyBreakdown.length; i += rowsPerPage) {
        chunks.add(dailyBreakdown.skip(i).take(rowsPerPage).toList());
      }
      if (chunks.isEmpty) chunks.add([]);

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
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Profit & Loss Statement',
                              style: pw.TextStyle(
                                  fontSize: 17,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white)),
                          pw.SizedBox(height: 4),
                          pw.Text(
                              '${_date.format(fromDate)}  –  ${_date.format(toDate)}',
                              style: const pw.TextStyle(
                                  fontSize: 9.5,
                                  color: PdfColors.grey300)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                              'Generated: ${DateFormat('dd MMM yyyy  HH:mm').format(DateTime.now())}',
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

                // Summary – first page only
                if (pageIdx == 0) ...[
                  pw.Row(children: [
                    sumBox('Total Sales',
                        _currency.format(totalSales), blue),
                    sumBox('Cost of Goods',
                        _currency.format(totalCost), pOrange),
                    sumBox(
                        'Gross Profit',
                        _currency.format(totalGrossProfit),
                        totalGrossProfit >= 0 ? pGreen : pRed),
                    sumBox('Total Expenses',
                        _currency.format(totalExpenses), pRed),
                    sumBox(
                        'Net Profit',
                        _currency.format(totalNetProfit),
                        totalNetProfit >= 0 ? pGreen : pRed),
                    sumBox(
                        'Margin',
                        '${profitMargin.toStringAsFixed(1)}%',
                        totalNetProfit >= 0 ? pGreen : pRed),
                  ]),
                  pw.SizedBox(height: 10),
                ],

                // Table
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          color: headerBg,
                          borderRadius: const pw.BorderRadius.only(
                              topLeft: pw.Radius.circular(6),
                              topRight: pw.Radius.circular(6)),
                        ),
                        child: pw.Row(children: [
                          pw.Expanded(
                            flex: 3,
                            child: pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              child: pw.Text('Date',
                                  style: pw.TextStyle(
                                      fontSize: 9,
                                      color: PdfColors.white,
                                      fontWeight: pw.FontWeight.bold)),
                            ),
                          ),
                          for (final h in [
                            'Sales',
                            'COGS',
                            'Gross P/L',
                            'Expenses',
                            'Net Profit',
                            'Margin'
                          ])
                            pw.Expanded(
                              flex: 2,
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 6),
                                child: pw.Text(h,
                                    textAlign: pw.TextAlign.right,
                                    style: pw.TextStyle(
                                        fontSize: 9,
                                        color: PdfColors.white,
                                        fontWeight: pw.FontWeight.bold)),
                              ),
                            ),
                        ]),
                      ),
                      pw.Flexible(
                        child: pw.ListView.builder(
                          itemCount: chunk.length,
                          itemBuilder: (ctx2, i) {
                            final day = chunk[i];
                            final even = i % 2 == 0;
                            final profit = day.netProfit >= 0;
                            return pw.Container(
                              decoration: pw.BoxDecoration(
                                color:
                                    even ? PdfColors.white : lightGrey,
                                border: pw.Border(
                                    bottom: pw.BorderSide(
                                        color: borderC)),
                              ),
                              child: pw.Row(children: [
                                pw.Expanded(
                                  flex: 3,
                                  child: pw.Padding(
                                    padding:
                                        const pw.EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 5),
                                    child: pw.Text(
                                        _date.format(day.date),
                                        style: const pw.TextStyle(
                                            fontSize: 8)),
                                  ),
                                ),
                                pw.Expanded(
                                    flex: 2,
                                    child: pCell(
                                        _currency.format(day.sales),
                                        color: blue)),
                                pw.Expanded(
                                    flex: 2,
                                    child: pCell(
                                        _currency.format(day.cost))),
                                pw.Expanded(
                                    flex: 2,
                                    child: pCell(
                                        _currency
                                            .format(day.grossProfit),
                                        color: day.grossProfit >= 0
                                            ? pGreen
                                            : pRed)),
                                pw.Expanded(
                                    flex: 2,
                                    child: pCell(
                                        _currency
                                            .format(day.expenses),
                                        color: pRed)),
                                pw.Expanded(
                                    flex: 2,
                                    child: pCell(
                                        _currency
                                            .format(day.netProfit),
                                        color:
                                            profit ? pGreen : pRed,
                                        bold: true)),
                                pw.Expanded(
                                  flex: 2,
                                  child: pw.Padding(
                                    padding:
                                        const pw.EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 5),
                                    child: pw.Align(
                                      alignment:
                                          pw.Alignment.centerRight,
                                      child: pw.Container(
                                        padding: const pw
                                            .EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2),
                                        decoration: pw.BoxDecoration(
                                          color: PdfColor(
                                            profit
                                                ? pGreen.red
                                                : pRed.red,
                                            profit
                                                ? pGreen.green
                                                : pRed.green,
                                            profit
                                                ? pGreen.blue
                                                : pRed.blue,
                                            0.12,
                                          ),
                                          borderRadius:
                                              pw.BorderRadius
                                                  .circular(3),
                                        ),
                                        child: pw.Text(
                                          '${day.marginPercent.toStringAsFixed(1)}%',
                                          style: pw.TextStyle(
                                              fontSize: 7.5,
                                              fontWeight:
                                                  pw.FontWeight.bold,
                                              color: profit
                                                  ? pGreen
                                                  : pRed),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ]),
                            );
                          },
                        ),
                      ),
                      if (pageIdx == chunks.length - 1)
                        pw.Container(
                          decoration: pw.BoxDecoration(
                            color: headerBg,
                            borderRadius: const pw.BorderRadius.only(
                                bottomLeft: pw.Radius.circular(6),
                                bottomRight: pw.Radius.circular(6)),
                          ),
                          child: pw.Row(children: [
                            pw.Expanded(
                              flex: 3,
                              child: pw.Padding(
                                padding:
                                    const pw.EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                child: pw.Text('GRAND TOTAL',
                                    style: pw.TextStyle(
                                        fontSize: 9,
                                        color: PdfColors.white,
                                        fontWeight:
                                            pw.FontWeight.bold)),
                              ),
                            ),
                            pw.Expanded(
                                flex: 2,
                                child: pCell(
                                    _currency.format(totalSales),
                                    color: PdfColors.white,
                                    bold: true)),
                            pw.Expanded(
                                flex: 2,
                                child: pCell(
                                    _currency.format(totalCost),
                                    color: PdfColors.white,
                                    bold: true)),
                            pw.Expanded(
                                flex: 2,
                                child: pCell(
                                    _currency
                                        .format(totalGrossProfit),
                                    color: PdfColors.white,
                                    bold: true)),
                            pw.Expanded(
                                flex: 2,
                                child: pCell(
                                    _currency.format(totalExpenses),
                                    color: PdfColors.white,
                                    bold: true)),
                            pw.Expanded(
                                flex: 2,
                                child: pCell(
                                    _currency.format(totalNetProfit),
                                    color: totalNetProfit >= 0
                                        ? pGreen
                                        : pRed,
                                    bold: true)),
                            pw.Expanded(
                                flex: 2,
                                child: pCell(
                                    '${profitMargin.toStringAsFixed(1)}%',
                                    color: totalNetProfit >= 0
                                        ? pGreen
                                        : pRed,
                                    bold: true)),
                          ]),
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
          'ProfitLoss_${_dateFile.format(DateTime.now())}.pdf';
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
    setState(() => isExporting = true);
    try {
      final excel = ex.Excel.createExcel();
      excel.delete('Sheet1');

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

      ex.CellStyle valueStyle(String hex) => ex.CellStyle(
            bold: true,
            fontSize: 11,
            fontColorHex: ex.ExcelColor.fromHexString(hex),
            horizontalAlign: ex.HorizontalAlign.Right,
          );

      // ── Sheet 1: Summary ──────────────────────────────────────────────
      final summarySheet = excel['Summary'];

      _xlCell(summarySheet, 0, 0, 'Profit & Loss Statement',
          style: headerStyle());
      summarySheet.merge(
          ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          ex.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0));

      _xlCell(summarySheet, 1, 0,
          'Period: ${_date.format(fromDate)} – ${_date.format(toDate)}',
          style: ex.CellStyle(bold: true, fontSize: 10, italic: true));
      summarySheet.merge(
          ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
          ex.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1));

      _xlCell(summarySheet, 2, 0, '');

      for (int c = 0; c < ['Metric', 'Value'].length; c++) {
        _xlCell(summarySheet, 3, c, ['Metric', 'Value'][c],
            style: headerStyle());
      }

      final summaryRows = [
        ['Total Sales', _currency.format(totalSales), '#3B82F6'],
        ['Cost of Goods Sold', _currency.format(totalCost), '#F59E0B'],
        [
          'Gross Profit',
          _currency.format(totalGrossProfit),
          totalGrossProfit >= 0 ? '#10B981' : '#EF4444'
        ],
        [
          'Total Expenses',
          _currency.format(totalExpenses),
          '#EF4444'
        ],
        [
          'Net Profit / (Loss)',
          _currency.format(totalNetProfit),
          totalNetProfit >= 0 ? '#10B981' : '#EF4444'
        ],
        [
          'Profit Margin',
          '${profitMargin.toStringAsFixed(1)}%',
          totalNetProfit >= 0 ? '#10B981' : '#EF4444'
        ],
        [
          'Report Period (Days)',
          '${toDate.difference(fromDate).inDays + 1}',
          '#1E293B'
        ],
        [
          'Average Daily Sales',
          dailyBreakdown.isNotEmpty
              ? _currency.format(totalSales / dailyBreakdown.length)
              : '-',
          '#8B5CF6'
        ],
        [
          'Profitable Days',
          '${dailyBreakdown.where((d) => d.netProfit > 0).length}',
          '#10B981'
        ],
        [
          'Loss Days',
          '${dailyBreakdown.where((d) => d.netProfit < 0).length}',
          '#EF4444'
        ],
      ];

      for (int r = 0; r < summaryRows.length; r++) {
        _xlCell(summarySheet, 4 + r, 0, summaryRows[r][0],
            style: labelStyle());
        _xlCell(summarySheet, 4 + r, 1, summaryRows[r][1],
            style: valueStyle(summaryRows[r][2]));
      }

      summarySheet.setColumnWidth(0, 38);
      summarySheet.setColumnWidth(1, 26);

      // ── Sheet 2: Daily Breakdown ──────────────────────────────────────
      final detailSheet = excel['Daily Breakdown'];

      final colHeaders = [
        'Date',
        'Sales (Rs.)',
        'COGS (Rs.)',
        'Gross Profit (Rs.)',
        'Expenses (Rs.)',
        'Net Profit (Rs.)',
        'Margin %',
        'P/L Status',
      ];
      for (int c = 0; c < colHeaders.length; c++) {
        _xlCell(detailSheet, 0, c, colHeaders[c], style: headerStyle());
      }

      for (int r = 0; r < dailyBreakdown.length; r++) {
        final day = dailyBreakdown[r];
        final profit = day.netProfit >= 0;
        final rowBg = r % 2 == 0 ? '#FFFFFF' : '#F8FAFC';

        ex.CellStyle rs(
                {bool bold = false,
                String color = '#1E293B',
                ex.HorizontalAlign align = ex.HorizontalAlign.Right}) =>
            ex.CellStyle(
              backgroundColorHex: ex.ExcelColor.fromHexString(rowBg),
              fontColorHex: ex.ExcelColor.fromHexString(color),
              bold: bold,
              fontSize: 10,
              horizontalAlign: align,
            );

        _xlCell(detailSheet, r + 1, 0, _date.format(day.date),
            style: rs(align: ex.HorizontalAlign.Left));
        _xlCell(detailSheet, r + 1, 1, day.sales,
            style: rs(color: '#3B82F6'));
        _xlCell(detailSheet, r + 1, 2, day.cost,
            style: rs(color: '#64748B'));
        _xlCell(detailSheet, r + 1, 3, day.grossProfit,
            style: rs(
                color: day.grossProfit >= 0 ? '#10B981' : '#EF4444'));
        _xlCell(detailSheet, r + 1, 4, day.expenses,
            style: rs(color: '#EF4444'));
        _xlCell(detailSheet, r + 1, 5, day.netProfit,
            style: rs(
                bold: true,
                color: profit ? '#10B981' : '#EF4444'));
        _xlCell(
            detailSheet,
            r + 1,
            6,
            '${day.marginPercent.toStringAsFixed(1)}%',
            style: rs(color: profit ? '#10B981' : '#EF4444'));
        _xlCell(detailSheet, r + 1, 7, profit ? 'PROFIT' : 'LOSS',
            style: rs(
                bold: true,
                color: profit ? '#10B981' : '#EF4444'));
      }

      // Grand totals
      final tr = dailyBreakdown.length + 1;
      ex.CellStyle ts(String color) => ex.CellStyle(
            backgroundColorHex: ex.ExcelColor.fromHexString('#1E293B'),
            fontColorHex: ex.ExcelColor.fromHexString(color),
            bold: true,
            fontSize: 10,
            horizontalAlign: ex.HorizontalAlign.Right,
          );

      _xlCell(detailSheet, tr, 0, 'GRAND TOTAL',
          style: ex.CellStyle(
              backgroundColorHex:
                  ex.ExcelColor.fromHexString('#1E293B'),
              fontColorHex: ex.ExcelColor.fromHexString('#FFFFFF'),
              bold: true,
              fontSize: 10,
              horizontalAlign: ex.HorizontalAlign.Left));
      _xlCell(detailSheet, tr, 1, totalSales, style: ts('#60A5FA'));
      _xlCell(detailSheet, tr, 2, totalCost, style: ts('#FFFFFF'));
      _xlCell(detailSheet, tr, 3, totalGrossProfit,
          style: ts('#34D399'));
      _xlCell(detailSheet, tr, 4, totalExpenses,
          style: ts('#FCA5A5'));
      _xlCell(detailSheet, tr, 5, totalNetProfit,
          style: ts(
              totalNetProfit >= 0 ? '#34D399' : '#FCA5A5'));
      _xlCell(detailSheet, tr, 6,
          '${profitMargin.toStringAsFixed(1)}%',
          style: ts(
              totalNetProfit >= 0 ? '#34D399' : '#FCA5A5'));
      _xlCell(detailSheet, tr, 7, '', style: ts('#FFFFFF'));

      for (final e in {
        0: 18.0,
        1: 18.0,
        2: 18.0,
        3: 20.0,
        4: 18.0,
        5: 18.0,
        6: 12.0,
        7: 12.0,
      }.entries) {
        detailSheet.setColumnWidth(e.key, e.value);
      }

      // ── Sheet 3: Chart Data ───────────────────────────────────────────
      final chartSheet = excel['Chart Data'];
      final chartHeaders = [
        'Date',
        'Sales',
        'Net Profit',
        'Expenses',
        'Gross Profit'
      ];
      for (int c = 0; c < chartHeaders.length; c++) {
        _xlCell(chartSheet, 0, c, chartHeaders[c],
            style: headerStyle());
      }

      final byDate = [...dailyBreakdown]
        ..sort((a, b) => a.date.compareTo(b.date));

      for (int r = 0; r < byDate.length; r++) {
        final day = byDate[r];
        _xlCell(chartSheet, r + 1, 0, _date.format(day.date),
            style: ex.CellStyle(fontSize: 10));
        _xlCell(chartSheet, r + 1, 1, day.sales,
            style: ex.CellStyle(fontSize: 10));
        _xlCell(chartSheet, r + 1, 2, day.netProfit,
            style: ex.CellStyle(
                fontSize: 10,
                fontColorHex: ex.ExcelColor.fromHexString(
                    day.netProfit >= 0 ? '#10B981' : '#EF4444')));
        _xlCell(chartSheet, r + 1, 3, day.expenses,
            style: ex.CellStyle(
                fontSize: 10,
                fontColorHex:
                    ex.ExcelColor.fromHexString('#EF4444')));
        _xlCell(chartSheet, r + 1, 4, day.grossProfit,
            style: ex.CellStyle(fontSize: 10));
      }

      for (int c = 0; c < 5; c++) {
        chartSheet.setColumnWidth(c, c == 0 ? 20 : 16);
      }

      // Save
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Excel encoding failed');

      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'ProfitLoss_${_dateFile.format(DateTime.now())}.xlsx';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      _showExportDialog(file.path, 'Excel', Uint8List.fromList(bytes));
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

  void _showExportDialog(String path, String type, Uint8List bytes) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (type == 'PDF' ? _red : _green).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                type == 'PDF'
                    ? Icons.picture_as_pdf
                    : Icons.table_chart,
                color: type == 'PDF' ? _red : _green,
                size: 32,
              ),
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
              child: Text(
                path.split('/').last,
                style: const TextStyle(fontSize: 11, color: _muted),
                textAlign: TextAlign.center,
              ),
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
  // SNACKBAR
  // ═══════════════════════════════════════════════════════════════════════════

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _red : _green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _primary))
                : Column(
                    children: [
                      _buildTopBar(),
                      _buildSummaryStrip(),
                      _buildToolbar(),
                      Expanded(child: _buildTable()),
                      _buildFooter(),
                    ],
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
    final isNarrow = screenW < 900;

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
          child: const Icon(Icons.account_balance_wallet_outlined,
              color: _primary, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Profit & Loss Statement',
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

  Widget _buildControls(bool isNarrow) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
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
                      child:
                          Text(p, style: const TextStyle(fontSize: 11))))
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
          icon: Icons.refresh,
          label: 'Generate',
          color: _primary,
          onTap: _loadReport,
        ),

        // Excel
        _buildActionBtn(
          icon: Icons.table_chart_outlined,
          label: 'Excel',
          color: _green,
          onTap: isExporting ? null : _exportExcel,
        ),

        // PDF
        _buildActionBtn(
          icon: Icons.picture_as_pdf_outlined,
          label: 'PDF',
          color: _red,
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
  }) {
    final disabled = onTap == null;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // SUMMARY STRIP
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSummaryStrip() {
    final profitableDays =
        dailyBreakdown.where((d) => d.netProfit > 0).length;
    final lossDays =
        dailyBreakdown.where((d) => d.netProfit < 0).length;

    final cards = [
      _CardData('Total Sales', _currency.format(totalSales),
          Icons.shopping_bag_outlined, _primary),
      _CardData('Cost of Goods', _currency.format(totalCost),
          Icons.inventory_2_outlined, _orange),
      _CardData(
          'Gross Profit',
          _currency.format(totalGrossProfit),
          Icons.trending_up,
          totalGrossProfit >= 0 ? _green : _red),
      _CardData('Expenses', _currency.format(totalExpenses),
          Icons.receipt_long_outlined, _red),
      _CardData(
          'Net Profit',
          _currency.format(totalNetProfit),
          Icons.monetization_on_outlined,
          totalNetProfit >= 0 ? _green : _red,
          highlighted: true),
      _CardData(
          'Margin',
          '${profitMargin.toStringAsFixed(1)}%',
          profitMargin >= 0
              ? Icons.trending_up
              : Icons.trending_down,
          profitMargin >= 0 ? _green : _red),
      _CardData('Profitable', '$profitableDays days',
          Icons.thumb_up_outlined, _green),
      _CardData('Loss', '$lossDays days',
          Icons.thumb_down_outlined, _red),
    ];

    final screenW = MediaQuery.of(context).size.width;
    final isNarrow = screenW < 900;

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
                          fontSize: 13,
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
  // TOOLBAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildToolbar() {
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
          const Text('Daily Breakdown',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
                color: _primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Text('${dailyBreakdown.length} days',
                style: const TextStyle(
                    fontSize: 10,
                    color: _primary,
                    fontWeight: FontWeight.w600)),
          ),
          const Spacer(),

          // Sort
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
                value: sortBy,
                isDense: true,
                style: const TextStyle(fontSize: 11, color: _dark),
                icon: const Icon(Icons.unfold_more,
                    size: 14, color: _muted),
                items: _sortOptions
                    .map((o) => DropdownMenuItem(
                        value: o,
                        child: Text(o,
                            style:
                                const TextStyle(fontSize: 11))))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    sortBy = v;
                    _applySorting(dailyBreakdown);
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TABLE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTable() {
    if (dailyBreakdown.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No data found',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text('Try adjusting the date range',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade400)),
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
              _th('Date', flex: 3, align: TextAlign.left),
              _th('Sales', flex: 2),
              _th('COGS', flex: 2),
              _th('Gross P/L', flex: 2),
              _th('Expenses', flex: 2),
              _th('Net Profit', flex: 2),
              _th('Margin', flex: 2, align: TextAlign.center),
              _th('Status', flex: 2, align: TextAlign.center),
            ],
          ),
        ),

        // Rows
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            itemCount: dailyBreakdown.length,
            itemBuilder: (ctx, i) {
              final day = dailyBreakdown[i];
              final isEven = i % 2 == 0;
              final profit = day.netProfit >= 0;

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
                      flex: 3,
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 11,
                              color: Colors.grey.shade400),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(_date.format(day.date),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _dark)),
                          ),
                        ],
                      ),
                    ),
                    // Sales
                    _tdVal(
                        _currency.format(day.sales), _primary),
                    // COGS
                    _tdVal(_currency.format(day.cost), _muted),
                    // Gross P/L
                    _tdVal(
                        _currency.format(day.grossProfit),
                        day.grossProfit >= 0 ? _green : _red),
                    // Expenses
                    _tdVal(
                        _currency.format(day.expenses), _red),
                    // Net Profit
                    Expanded(
                      flex: 2,
                      child: Text(
                        _currency.format(day.netProfit),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: profit ? _green : _red),
                      ),
                    ),
                    // Margin badge
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (profit ? _green : _red)
                                .withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${day.marginPercent.toStringAsFixed(1)}%',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: profit
                                    ? _green
                                    : _red),
                          ),
                        ),
                      ),
                    ),
                    // Status badge
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: profit ? _green : _red,
                            borderRadius:
                                BorderRadius.circular(4),
                          ),
                          child: Text(
                            profit ? '▲ PROFIT' : '▼ LOSS',
                            style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
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
      {int flex = 1, TextAlign align = TextAlign.right}) {
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

  Widget _tdVal(String text, Color color) {
    return Expanded(
      flex: 2,
      child: Text(text,
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 12, color: color)),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FOOTER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: _dark,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Text(
            '${dailyBreakdown.length} days  •  ${_date.format(fromDate)} – ${_date.format(toDate)}',
            style:
                const TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const Spacer(),
          _footerMetric(
              'Sales', _currency.format(totalSales), _primary),
          const SizedBox(width: 20),
          _footerMetric(
              'COGS', _currency.format(totalCost), Colors.white54),
          const SizedBox(width: 20),
          _footerMetric(
              'Gross',
              _currency.format(totalGrossProfit),
              totalGrossProfit >= 0
                  ? const Color(0xFF34D399)
                  : const Color(0xFFFCA5A5)),
          const SizedBox(width: 20),
          _footerMetric('Expenses', _currency.format(totalExpenses),
              const Color(0xFFFCA5A5)),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: (totalNetProfit >= 0
                      ? _green
                      : _red)
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: (totalNetProfit >= 0
                          ? _green
                          : _red)
                      .withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Text('Net: ',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7))),
                Text(_currency.format(totalNetProfit),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: totalNetProfit >= 0
                            ? const Color(0xFF34D399)
                            : const Color(0xFFFCA5A5))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (totalNetProfit >= 0
                            ? _green
                            : _red)
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${profitMargin.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: totalNetProfit >= 0
                            ? const Color(0xFF34D399)
                            : const Color(0xFFFCA5A5)),
                  ),
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