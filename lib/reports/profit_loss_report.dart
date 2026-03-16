// lib/screens/profit_loss_report.dart
//
// ─────────────────────────────────────────────────────────────────────────────
// DEPENDENCIES – add these to pubspec.yaml under dependencies:
//
//   pdf: ^3.11.0
//   printing: ^5.12.0
//   excel: ^4.0.6
//   path_provider: ^2.1.3
//   share_plus: ^9.0.0
//   open_file: ^3.3.2
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/models/sale_item.dart';
import 'package:medical_app/services/database_helper.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

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
  double get marginPercent =>
      sales > 0 ? (netProfit / sales) * 100 : 0.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class ProfitLossReport extends StatefulWidget {
  const ProfitLossReport({super.key});

  @override
  State<ProfitLossReport> createState() => _ProfitLossReportState();
}

class _ProfitLossReportState extends State<ProfitLossReport> {
  // ── Filters ──────────────────────────────────────────────────────────────
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();
  String sortBy = 'Date (Newest)';

  // ── Data ─────────────────────────────────────────────────────────────────
  List<DailyFinancials> dailyBreakdown = [];
  bool isLoading = true;
  bool isExporting = false;

  // ── Totals ────────────────────────────────────────────────────────────────
  double totalSales = 0.0;
  double totalCost = 0.0;
  double totalGrossProfit = 0.0;
  double totalExpenses = 0.0;
  double totalNetProfit = 0.0;
  double profitMargin = 0.0;

  // ── Formatters ────────────────────────────────────────────────────────────
  final currencyFormat = NumberFormat.currency(
      locale: 'en_PK', symbol: 'Rs. ', decimalDigits: 0);
  final dateFormat = DateFormat('dd MMM yyyy');
  final dateKey = DateFormat('yyyy-MM-dd');

  final List<String> sortOptions = [
    'Date (Newest)',
    'Date (Oldest)',
    'Net Profit (High to Low)',
    'Sales (High to Low)',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOAD REPORT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadReport() async {
    setState(() => isLoading = true);
    final from = fromDate.toIso8601String();
    final to = toDate.toIso8601String();

    try {
      final salesData =
          await DatabaseHelper.instance.getSalesInDateRange(from, to);
      final expenseData =
          await DatabaseHelper.instance.getExpensesInDateRange(from, to);

      // Pre-fill every day in range with zero values
      final Map<String, DailyFinancials> dailyMap = {};
      for (int i = 0; i <= toDate.difference(fromDate).inDays; i++) {
        final d = fromDate.add(Duration(days: i));
        dailyMap[dateKey.format(d)] = DailyFinancials(date: d);
      }

      // Process sales & COGS
      for (final sale in salesData) {
        final rawDate =
            sale['dateTime'] ?? sale['saleDate'] ?? sale['date'];
        if (rawDate == null) continue;
        final saleDate = DateTime.tryParse(rawDate.toString());
        if (saleDate == null) continue;
        final key = dateKey.format(saleDate);
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

      // Process expenses
      for (final expense in expenseData) {
        final rawDate = expense['date'];
        if (rawDate == null) continue;
        final expDate = DateTime.tryParse(rawDate.toString());
        if (expDate == null) continue;
        final key = dateKey.format(expDate);
        dailyMap.putIfAbsent(key, () => DailyFinancials(date: expDate));
        dailyMap[key]!.expenses +=
            (expense['amount'] as num?)?.toDouble() ?? 0.0;
      }

      // Grand totals
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
      _snack('Error loading report: $e', Colors.red);
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

  // ─────────────────────────────────────────────────────────────────────────
  // DATE PICKER
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _selectDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate : toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: Color(0xFF3B82F6)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => isFrom ? fromDate = picked : toDate = picked);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // QUICK DATE PRESETS
  // ─────────────────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────────────────
  // PDF EXPORT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _exportPDF() async {
    setState(() => isExporting = true);
    try {
      final pdf = pw.Document();

      // ── Colour palette ────────────────────────────────────────────────
      const headerBg = PdfColor.fromInt(0xFF1E293B);
      const accentBlue = PdfColor.fromInt(0xFF3B82F6);
      const pGreen = PdfColor.fromInt(0xFF10B981);
      const pRed = PdfColor.fromInt(0xFFEF4444);
      const pOrange = PdfColor.fromInt(0xFFF59E0B);
      const lightGrey = PdfColor.fromInt(0xFFF8FAFC);
      const borderCol = PdfColor.fromInt(0xFFE2E8F0);

      // ── Text cell helper ─────────────────────────────────────────────
      pw.Widget pCell(String text,
          {PdfColor color = PdfColors.black,
          bool bold = false,
          pw.TextAlign align = pw.TextAlign.right,
          double fs = 8}) {
        return pw.Padding(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: pw.Text(
            text,
            textAlign: align as pw.TextAlign?,
            style: pw.TextStyle(
              fontSize: fs,
              fontWeight:
                  bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        );
      }

      // ── Summary card helper ──────────────────────────────────────────
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

      // ── Paginate rows ────────────────────────────────────────────────
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
                // ── Page header ─────────────────────────────────────
                pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: headerBg,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
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
                            '${dateFormat.format(fromDate)}  –  ${dateFormat.format(toDate)}',
                            style: const pw.TextStyle(
                                fontSize: 9.5, color: PdfColors.grey300),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Generated: ${DateFormat('dd MMM yyyy  HH:mm').format(DateTime.now())}',
                            style: const pw.TextStyle(
                                fontSize: 8, color: PdfColors.grey400),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Page ${pageIdx + 1} of ${chunks.length}',
                            style: const pw.TextStyle(
                                fontSize: 8, color: PdfColors.grey400),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 10),

                // ── Summary cards – first page only ─────────────────
                if (pageIdx == 0) ...[
                  pw.Row(children: [
                    sumBox('Total Sales',
                        currencyFormat.format(totalSales), accentBlue),
                    sumBox('Cost of Goods',
                        currencyFormat.format(totalCost), pOrange),
                    sumBox('Gross Profit',
                        currencyFormat.format(totalGrossProfit),
                        totalGrossProfit >= 0 ? pGreen : pRed),
                    sumBox('Total Expenses',
                        currencyFormat.format(totalExpenses), pRed),
                    sumBox('Net Profit',
                        currencyFormat.format(totalNetProfit),
                        totalNetProfit >= 0 ? pGreen : pRed),
                    sumBox('Margin',
                        '${profitMargin.toStringAsFixed(1)}%',
                        totalNetProfit >= 0 ? pGreen : pRed),
                  ]),
                  pw.SizedBox(height: 10),
                ],

                // ── Table ────────────────────────────────────────────
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      // Table header row
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          color: headerBg,
                          borderRadius: const pw.BorderRadius.only(
                            topLeft: pw.Radius.circular(6),
                            topRight: pw.Radius.circular(6),
                          ),
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
                            'Margin',
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
                                        fontWeight:
                                            pw.FontWeight.bold)),
                              ),
                            ),
                        ]),
                      ),

                      // Data rows
                      pw.Flexible(
                        child: pw.ListView.builder(
                          itemCount: chunk.length,
                          itemBuilder: (ctx2, i) {
                            final day = chunk[i];
                            final even = i % 2 == 0;
                            final profit = day.netProfit >= 0;
                            return pw.Container(
                              decoration: pw.BoxDecoration(
                                color: even ? PdfColors.white : lightGrey,
                                border: pw.Border(
                                    bottom:
                                        pw.BorderSide(color: borderCol)),
                              ),
                              child: pw.Row(children: [
                                pw.Expanded(
                                  flex: 3,
                                  child: pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 5),
                                    child: pw.Text(
                                        dateFormat.format(day.date),
                                        style: const pw.TextStyle(
                                            fontSize: 8)),
                                  ),
                                ),
                                pw.Expanded(
                                    flex: 2,
                                    child: pCell(
                                        currencyFormat.format(day.sales),
                                        color: accentBlue)),
                                pw.Expanded(
                                    flex: 2,
                                    child: pCell(
                                        currencyFormat.format(day.cost))),
                                pw.Expanded(
                                    flex: 2,
                                    child: pCell(
                                      currencyFormat
                                          .format(day.grossProfit),
                                      color: day.grossProfit >= 0
                                          ? pGreen
                                          : pRed,
                                    )),
                                pw.Expanded(
                                    flex: 2,
                                    child: pCell(
                                        currencyFormat
                                            .format(day.expenses),
                                        color: pRed)),
                                pw.Expanded(
                                    flex: 2,
                                    child: pCell(
                                      currencyFormat
                                          .format(day.netProfit),
                                      color: profit ? pGreen : pRed,
                                      bold: true,
                                    )),
                                pw.Expanded(
                                  flex: 2,
                                  child: pw.Padding(
                                    padding: const pw.EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 5),
                                    child: pw.Align(
                                      alignment: pw.Alignment.centerRight,
                                      child: pw.Container(
                                        padding:
                                            const pw.EdgeInsets.symmetric(
                                                horizontal: 5,
                                                vertical: 2),
                                        decoration: pw.BoxDecoration(
                                          color: PdfColor(
                                            profit ? pGreen.red : pRed.red,
                                            profit
                                                ? pGreen.green
                                                : pRed.green,
                                            profit
                                                ? pGreen.blue
                                                : pRed.blue,
                                            0.12,
                                          ),
                                          borderRadius:
                                              pw.BorderRadius.circular(3),
                                        ),
                                        child: pw.Text(
                                          '${day.marginPercent.toStringAsFixed(1)}%',
                                          style: pw.TextStyle(
                                            fontSize: 7.5,
                                            fontWeight: pw.FontWeight.bold,
                                            color:
                                                profit ? pGreen : pRed,
                                          ),
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

                      // Totals footer – last page only
                      if (pageIdx == chunks.length - 1)
                        pw.Container(
                          decoration: pw.BoxDecoration(
                            color: headerBg,
                            borderRadius: const pw.BorderRadius.only(
                              bottomLeft: pw.Radius.circular(6),
                              bottomRight: pw.Radius.circular(6),
                            ),
                          ),
                          child: pw.Row(children: [
                            pw.Expanded(
                              flex: 3,
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                child: pw.Text('GRAND TOTAL',
                                    style: pw.TextStyle(
                                        fontSize: 9,
                                        color: PdfColors.white,
                                        fontWeight: pw.FontWeight.bold)),
                              ),
                            ),
                            pw.Expanded(
                                flex: 2,
                                child: pCell(
                                    currencyFormat.format(totalSales),
                                    color: PdfColors.white,
                                    bold: true)),
                            pw.Expanded(
                                flex: 2,
                                child: pCell(
                                    currencyFormat.format(totalCost),
                                    color: PdfColors.white,
                                    bold: true)),
                            pw.Expanded(
                                flex: 2,
                                child: pCell(
                                    currencyFormat
                                        .format(totalGrossProfit),
                                    color: PdfColors.white,
                                    bold: true)),
                            pw.Expanded(
                                flex: 2,
                                child: pCell(
                                    currencyFormat.format(totalExpenses),
                                    color: PdfColors.white,
                                    bold: true)),
                            pw.Expanded(
                                flex: 2,
                                child: pCell(
                                    currencyFormat.format(totalNetProfit),
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

      // ── Save & share ────────────────────────────────────────────────────
      final bytes = await pdf.save();
      await _shareFile(
        bytes: bytes,
        fileName:
            'ProfitLoss_${DateFormat('yyyyMMdd').format(fromDate)}_${DateFormat('yyyyMMdd').format(toDate)}.pdf',
        mimeType: 'application/pdf',
        label: 'PDF',
      );
    } catch (e) {
      _snack('PDF export failed: $e', Colors.red);
    } finally {
      setState(() => isExporting = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EXCEL EXPORT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _exportExcel() async {
    setState(() => isExporting = true);
    try {
      final excel = ex.Excel.createExcel();
      excel.delete('Sheet1'); // remove default blank sheet

      // ── Shared style helpers ─────────────────────────────────────────
      ex.CellStyle headerStyle() => ex.CellStyle(
            backgroundColorHex:
                ex.ExcelColor.fromHexString('#1E293B'),
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

      // ════════════════════════════════════════════════════════════════
      // SHEET 1 – Summary
      // ════════════════════════════════════════════════════════════════
      final summarySheet = excel['Summary'];

      // Title
      _xlCell(summarySheet, 0, 0, 'Profit & Loss Statement',
          style: headerStyle());
      summarySheet.merge(
          ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          ex.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0));

      _xlCell(summarySheet, 1, 0,
          'Period: ${dateFormat.format(fromDate)} – ${dateFormat.format(toDate)}',
          style: ex.CellStyle(bold: true, fontSize: 10, italic: true));
      summarySheet.merge(
          ex.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
          ex.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 1));

      _xlCell(summarySheet, 2, 0, ''); // gap row

      // Column headers
      for (int c = 0; c < ['Metric', 'Value'].length; c++) {
        _xlCell(summarySheet, 3, c, ['Metric', 'Value'][c],
            style: headerStyle());
      }

      // Summary data rows
      final summaryRows = [
        ['Total Sales', currencyFormat.format(totalSales), '#3B82F6'],
        ['Cost of Goods Sold (COGS)', currencyFormat.format(totalCost), '#F59E0B'],
        ['Gross Profit', currencyFormat.format(totalGrossProfit),
          totalGrossProfit >= 0 ? '#10B981' : '#EF4444'],
        ['Total Operating Expenses', currencyFormat.format(totalExpenses), '#EF4444'],
        ['Net Profit / (Loss)', currencyFormat.format(totalNetProfit),
          totalNetProfit >= 0 ? '#10B981' : '#EF4444'],
        ['Profit Margin', '${profitMargin.toStringAsFixed(1)}%',
          totalNetProfit >= 0 ? '#10B981' : '#EF4444'],
        ['Report Period (Days)',
          '${toDate.difference(fromDate).inDays + 1}', '#1E293B'],
        ['Average Daily Sales',
          dailyBreakdown.isNotEmpty
              ? currencyFormat.format(totalSales / dailyBreakdown.length)
              : '-',
          '#8B5CF6'],
        ['Profitable Days',
          '${dailyBreakdown.where((d) => d.netProfit > 0).length}',
          '#10B981'],
        ['Loss Days',
          '${dailyBreakdown.where((d) => d.netProfit < 0).length}',
          '#EF4444'],
      ];

      for (int r = 0; r < summaryRows.length; r++) {
        _xlCell(summarySheet, 4 + r, 0, summaryRows[r][0],
            style: labelStyle());
        _xlCell(summarySheet, 4 + r, 1, summaryRows[r][1],
            style: valueStyle(summaryRows[r][2]));
      }

      summarySheet.setColumnWidth(0, 38);
      summarySheet.setColumnWidth(1, 26);

      // ════════════════════════════════════════════════════════════════
      // SHEET 2 – Daily Breakdown
      // ════════════════════════════════════════════════════════════════
      final detailSheet = excel['Daily Breakdown'];

      final colHeaders = [
        'Date', 'Sales (Rs.)', 'COGS (Rs.)', 'Gross Profit (Rs.)',
        'Expenses (Rs.)', 'Net Profit (Rs.)', 'Margin %', 'P/L Status',
      ];
      for (int c = 0; c < colHeaders.length; c++) {
        _xlCell(detailSheet, 0, c, colHeaders[c], style: headerStyle());
      }

      for (int r = 0; r < dailyBreakdown.length; r++) {
        final day = dailyBreakdown[r];
        final profit = day.netProfit >= 0;
        final rowBg = r % 2 == 0 ? '#FFFFFF' : '#F8FAFC';

        ex.CellStyle rs({
          bool bold = false,
          String color = '#1E293B',
          ex.HorizontalAlign align = ex.HorizontalAlign.Right,
        }) =>
            ex.CellStyle(
              backgroundColorHex: ex.ExcelColor.fromHexString(rowBg),
              fontColorHex: ex.ExcelColor.fromHexString(color),
              bold: bold,
              fontSize: 10,
              horizontalAlign: align,
            );

        _xlCell(detailSheet, r + 1, 0, dateFormat.format(day.date),
            style: rs(align: ex.HorizontalAlign.Left));
        _xlCell(detailSheet, r + 1, 1, day.sales,
            style: rs(color: '#3B82F6'));
        _xlCell(detailSheet, r + 1, 2, day.cost,
            style: rs(color: '#64748B'));
        _xlCell(detailSheet, r + 1, 3, day.grossProfit,
            style: rs(color: day.grossProfit >= 0 ? '#10B981' : '#EF4444'));
        _xlCell(detailSheet, r + 1, 4, day.expenses,
            style: rs(color: '#EF4444'));
        _xlCell(detailSheet, r + 1, 5, day.netProfit,
            style: rs(bold: true, color: profit ? '#10B981' : '#EF4444'));
        _xlCell(detailSheet, r + 1, 6,
            '${day.marginPercent.toStringAsFixed(1)}%',
            style: rs(color: profit ? '#10B981' : '#EF4444'));
        _xlCell(detailSheet, r + 1, 7, profit ? 'PROFIT' : 'LOSS',
            style: rs(bold: true, color: profit ? '#10B981' : '#EF4444'));
      }

      // Grand totals row
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
              backgroundColorHex: ex.ExcelColor.fromHexString('#1E293B'),
              fontColorHex: ex.ExcelColor.fromHexString('#FFFFFF'),
              bold: true,
              fontSize: 10,
              horizontalAlign: ex.HorizontalAlign.Left));
      _xlCell(detailSheet, tr, 1, totalSales, style: ts('#60A5FA'));
      _xlCell(detailSheet, tr, 2, totalCost, style: ts('#FFFFFF'));
      _xlCell(detailSheet, tr, 3, totalGrossProfit,
          style: ts('#34D399'));
      _xlCell(detailSheet, tr, 4, totalExpenses, style: ts('#FCA5A5'));
      _xlCell(detailSheet, tr, 5, totalNetProfit,
          style: ts(totalNetProfit >= 0 ? '#34D399' : '#FCA5A5'));
      _xlCell(detailSheet, tr, 6,
          '${profitMargin.toStringAsFixed(1)}%',
          style: ts(totalNetProfit >= 0 ? '#34D399' : '#FCA5A5'));
      _xlCell(detailSheet, tr, 7, '',
          style: ts('#FFFFFF'));

      // Column widths
      for (final e in {
        0: 18.0, 1: 18.0, 2: 18.0, 3: 20.0,
        4: 18.0, 5: 18.0, 6: 12.0, 7: 12.0,
      }.entries) {
        detailSheet.setColumnWidth(e.key, e.value);
      }

      // ════════════════════════════════════════════════════════════════
      // SHEET 3 – Chart Data (sorted by date for easy charting)
      // ════════════════════════════════════════════════════════════════
      final chartSheet = excel['Chart Data'];
      final chartHeaders = ['Date', 'Sales', 'Net Profit', 'Expenses', 'Gross Profit'];
      for (int c = 0; c < chartHeaders.length; c++) {
        _xlCell(chartSheet, 0, c, chartHeaders[c], style: headerStyle());
      }

      final byDate = [...dailyBreakdown]
        ..sort((a, b) => a.date.compareTo(b.date));

      for (int r = 0; r < byDate.length; r++) {
        final day = byDate[r];
        _xlCell(chartSheet, r + 1, 0,
            DateFormat('dd MMM yyyy').format(day.date),
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
                fontColorHex: ex.ExcelColor.fromHexString('#EF4444')));
        _xlCell(chartSheet, r + 1, 4, day.grossProfit,
            style: ex.CellStyle(fontSize: 10));
      }

      for (int c = 0; c < 5; c++) {
        chartSheet.setColumnWidth(c, c == 0 ? 20 : 16);
      }

      // ── Encode & share ──────────────────────────────────────────────
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Excel encoding failed');

      await _shareFile(
        bytes: Uint8List.fromList(bytes),
        fileName:
            'ProfitLoss_${DateFormat('yyyyMMdd').format(fromDate)}_${DateFormat('yyyyMMdd').format(toDate)}.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        label: 'Excel',
      );
    } catch (e) {
      _snack('Excel export failed: $e', Colors.red);
    } finally {
      setState(() => isExporting = false);
    }
  }

  // Helper – write a value into an Excel cell with optional style
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

  // ─────────────────────────────────────────────────────────────────────────
  // FILE SHARING HELPER
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _shareFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String label,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text('$label Ready',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(fileName,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await OpenFile.open(file.path);
                    },
                    icon: Icon(label == 'PDF'
                        ? Icons.picture_as_pdf
                        : Icons.table_chart),
                    label: const Text('Open'),
                    style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await Share.shareXFiles(
                        [XFile(file.path, mimeType: mimeType)],
                        subject: 'Profit & Loss Report',
                      );
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ]),
              if (label == 'PDF') ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await Printing.layoutPdf(
                        onLayout: (_) async => bytes,
                        name: fileName,
                      );
                    },
                    icon: const Icon(Icons.print),
                    label: const Text('Print'),
                    style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ],
          ),
        ),
      );

      _snack('$label exported successfully!', Colors.green);
    } catch (e) {
      _snack('Could not save file: $e', Colors.red);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SNACK BAR
  // ─────────────────────────────────────────────────────────────────────────

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Row(
            children: [
              // ── Left panel ──────────────────────────────────────────────
              Container(
                width: 280,
                margin: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildControlPanel(),
                    const SizedBox(height: 16),
                    if (!isLoading) _buildQuickStats(),
                  ],
                ),
              ),

              // ── Main content ─────────────────────────────────────────────
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      _buildSummaryCards(),
                      const SizedBox(height: 16),
                      _buildToolbar(),
                      const SizedBox(height: 12),
                      Expanded(child: _buildDetailedTable()),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Loading overlay during export ────────────────────────────────
          if (isExporting)
            Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: const Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Generating export…',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONTROL PANEL
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _iconBox(Icons.calendar_month, const Color(0xFF3B82F6)),
            const SizedBox(width: 10),
            const Text('Report Period',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B))),
          ]),
          const SizedBox(height: 16),

          // Quick presets
          const Text('Quick Select',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              'Today', 'This Week', 'This Month',
              'Last Month', 'Last 30 Days', 'This Year',
            ].map(_presetChip).toList(),
          ),

          const SizedBox(height: 16),
          _datePicker('From Date', fromDate, () => _selectDate(true)),
          const SizedBox(height: 12),
          _datePicker('To Date', toDate, () => _selectDate(false)),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loadReport,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Generate Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label) {
    return InkWell(
      onTap: () => _setPreset(label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFF3B82F6).withOpacity(0.3)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF3B82F6),
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _datePicker(String label, DateTime date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFFF8FAFC),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(dateFormat.format(date),
                  style: const TextStyle(fontSize: 12)),
            ]),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // QUICK STATS PANEL
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildQuickStats() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Performance Metrics',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 14),
            _statItem('Profit Margin',
                '${profitMargin.toStringAsFixed(1)}%',
                profitMargin > 0
                    ? Icons.trending_up
                    : Icons.trending_down,
                profitMargin > 0
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444)),
            const SizedBox(height: 8),
            _statItem(
                'Total Days',
                '${toDate.difference(fromDate).inDays + 1}',
                Icons.date_range,
                const Color(0xFF64748B)),
            const SizedBox(height: 8),
            _statItem(
                'Avg Daily Sale',
                dailyBreakdown.isNotEmpty
                    ? currencyFormat.format(
                        totalSales / dailyBreakdown.length)
                    : 'Rs. 0',
                Icons.bar_chart,
                const Color(0xFF8B5CF6)),
            const SizedBox(height: 8),
            _statItem(
                'Profitable Days',
                '${dailyBreakdown.where((d) => d.netProfit > 0).length}',
                Icons.thumb_up_outlined,
                const Color(0xFF10B981)),
            const SizedBox(height: 8),
            _statItem(
                'Loss Days',
                '${dailyBreakdown.where((d) => d.netProfit < 0).length}',
                Icons.thumb_down_outlined,
                const Color(0xFFEF4444)),
          ],
        ),
      ),
    );
  }

  Widget _statItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
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
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER ROW (with export buttons)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Row(children: [
        _iconBox(Icons.account_balance_wallet_outlined,
            const Color(0xFF10B981),
            size: 24, pad: 10),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Profit & Loss Statement',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
            Text(
              '${dateFormat.format(fromDate)} – ${dateFormat.format(toDate)}',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
        const Spacer(),

        // Export buttons
        _exportBtn(
            icon: Icons.picture_as_pdf,
            label: 'Export PDF',
            color: const Color(0xFFEF4444),
            onTap: isExporting ? null : _exportPDF),
        const SizedBox(width: 8),
        _exportBtn(
            icon: Icons.table_chart_outlined,
            label: 'Export Excel',
            color: const Color(0xFF10B981),
            onTap: isExporting ? null : _exportExcel),
      ]),
    );
  }

  Widget _exportBtn({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: onTap == null
              ? Colors.grey.shade200
              : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: onTap == null
                  ? Colors.grey.shade300
                  : color.withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 16, color: onTap == null ? Colors.grey : color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: onTap == null ? Colors.grey : color)),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SUMMARY CARDS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSummaryCards() {
    return Row(children: [
      _sumCard('Total Sales', currencyFormat.format(totalSales),
          Icons.shopping_bag_outlined, const Color(0xFF3B82F6)),
      const SizedBox(width: 12),
      _sumCard('Cost of Goods', currencyFormat.format(totalCost),
          Icons.inventory_2_outlined, const Color(0xFFF59E0B)),
      const SizedBox(width: 12),
      _sumCard('Gross Profit', currencyFormat.format(totalGrossProfit),
          Icons.trending_up,
          totalGrossProfit >= 0
              ? const Color(0xFF10B981)
              : const Color(0xFFEF4444)),
      const SizedBox(width: 12),
      _sumCard('Operating Expenses', currencyFormat.format(totalExpenses),
          Icons.receipt_long_outlined, const Color(0xFFEF4444)),
      const SizedBox(width: 12),
      _sumCard(
          'Net Profit', currencyFormat.format(totalNetProfit),
          Icons.monetization_on_outlined,
          totalNetProfit >= 0
              ? const Color(0xFF10B981)
              : const Color(0xFFEF4444),
          highlighted: true),
    ]);
  }

  Widget _sumCard(String title, String value, IconData icon, Color color,
      {bool highlighted = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: highlighted ? color.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: highlighted
                  ? color.withOpacity(0.3)
                  : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _iconBox(icon, color),
            const SizedBox(height: 10),
            Text(title,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: highlighted
                          ? color
                          : const Color(0xFF1E293B))),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TOOLBAR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildToolbar() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: _cardDeco(),
      child: Row(children: [
        const Text('Daily Breakdown',
            style:
                TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('${dailyBreakdown.length} days',
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF3B82F6),
                  fontWeight: FontWeight.w600)),
        ),
        const Spacer(),
        const Text('Sort by:',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButton<String>(
            value: sortBy,
            isDense: true,
            underline: const SizedBox(),
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF1E293B)),
            icon: const Icon(Icons.arrow_drop_down,
                color: Color(0xFF64748B)),
            items: sortOptions
                .map((o) =>
                    DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  sortBy = v;
                  _applySorting(dailyBreakdown);
                });
              }
            },
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DETAILED TABLE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDetailedTable() {
    if (isLoading) {
      return Container(
          decoration: _cardDeco(),
          child: const Center(child: CircularProgressIndicator()));
    }

    return Container(
      decoration: _cardDeco(),
      child: Column(children: [
        // ── Table header ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12)),
          ),
          child: Row(children: [
            _th('Date', flex: 3, align: TextAlign.left),
            _th('Sales', flex: 2),
            _th('COGS', flex: 2),
            _th('Gross P/L', flex: 2),
            _th('Expenses', flex: 2),
            _th('Net Profit', flex: 2),
            _th('Margin', flex: 2, align: TextAlign.center),
            _th('Status', flex: 2, align: TextAlign.center),
          ]),
        ),

        // ── Body rows ────────────────────────────────────────────────
        Expanded(
          child: dailyBreakdown.isEmpty
              ? const Center(
                  child: Text('No records found for this period',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: dailyBreakdown.length,
                  itemBuilder: (ctx, i) {
                    final day = dailyBreakdown[i];
                    final even = i % 2 == 0;
                    final profit = day.netProfit >= 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: even
                            ? Colors.white
                            : const Color(0xFFFAFAFA),
                        border: Border(
                            bottom: BorderSide(
                                color: Colors.grey.shade100)),
                      ),
                      child: Row(children: [
                        // Date
                        Expanded(
                          flex: 3,
                          child: Row(children: [
                            Icon(Icons.calendar_today,
                                size: 11,
                                color: Colors.grey.shade400),
                            const SizedBox(width: 6),
                            Text(dateFormat.format(day.date),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1E293B))),
                          ]),
                        ),
                        // Sales
                        _tdVal(currencyFormat.format(day.sales),
                            const Color(0xFF3B82F6)),
                        // COGS
                        _tdVal(currencyFormat.format(day.cost),
                            const Color(0xFF64748B)),
                        // Gross P/L
                        _tdVal(
                            currencyFormat.format(day.grossProfit),
                            day.grossProfit >= 0
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444)),
                        // Expenses
                        _tdVal(currencyFormat.format(day.expenses),
                            const Color(0xFFEF4444)),
                        // Net Profit
                        Expanded(
                          flex: 2,
                          child: Text(
                            currencyFormat.format(day.netProfit),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: profit
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444)),
                          ),
                        ),
                        // Margin badge
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (profit
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444))
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
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444)),
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
                                color: profit
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
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
                      ]),
                    );
                  },
                ),
        ),

        // ── Grand totals footer ──────────────────────────────────────
        if (!isLoading && dailyBreakdown.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12)),
            ),
            child: Row(children: [
              const Expanded(
                flex: 3,
                child: Text('GRAND TOTAL',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
              _tdFt(currencyFormat.format(totalSales),
                  const Color(0xFF60A5FA)),
              _tdFt(currencyFormat.format(totalCost),
                  Colors.white70),
              _tdFt(currencyFormat.format(totalGrossProfit),
                  const Color(0xFF34D399)),
              _tdFt(currencyFormat.format(totalExpenses),
                  const Color(0xFFFCA5A5)),
              _tdFt(
                  currencyFormat.format(totalNetProfit),
                  totalNetProfit >= 0
                      ? const Color(0xFF34D399)
                      : const Color(0xFFFCA5A5),
                  bold: true),
              _tdFt(
                  '${profitMargin.toStringAsFixed(1)}%',
                  totalNetProfit >= 0
                      ? const Color(0xFF34D399)
                      : const Color(0xFFFCA5A5)),
              const Expanded(flex: 2, child: SizedBox()),
            ]),
          ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SMALL PRIVATE HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      );

  Widget _iconBox(IconData icon, Color color,
      {double size = 16, double pad = 8}) {
    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: size),
    );
  }

  Widget _th(String text,
      {int flex = 1, TextAlign align = TextAlign.right}) {
    return Expanded(
      flex: flex,
      child: Text(text,
          textAlign: align,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white70)),
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

  Widget _tdFt(String text, Color color, {bool bold = false}) {
    return Expanded(
      flex: 2,
      child: Text(text,
          textAlign: TextAlign.right,
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight:
                  bold ? FontWeight.bold : FontWeight.normal)),
    );
  }
}