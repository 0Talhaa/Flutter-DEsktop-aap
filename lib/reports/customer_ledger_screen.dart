// lib/reports/customer_ledger_report.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as xl;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:medical_app/models/customer.dart';
import 'package:medical_app/services/database_helper.dart';

class CustomerLedgerReport extends StatefulWidget {
  const CustomerLedgerReport({super.key});

  @override
  State<CustomerLedgerReport> createState() => _CustomerLedgerReportState();
}

class _CustomerLedgerReportState extends State<CustomerLedgerReport> {
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();
  Customer? selectedCustomer;
  List<Customer> customers = [];
  List<Map<String, dynamic>> ledgerEntries = [];
  List<Map<String, dynamic>> filteredEntries = [];

  List<CustomerLedgerSummary> allCustomersSummary = [];
  bool showAllCustomers = false;

  double openingBalance = 0.0;
  double totalDebit = 0.0;
  double totalCredit = 0.0;
  double closingBalance = 0.0;

  bool isLoading = false;
  bool isExporting = false;
  bool hasGenerated = false;
  String searchQuery = '';
  String selectedFilter = 'All';

  final currencyFormat =
      NumberFormat.currency(locale: 'en_PK', symbol: 'Rs. ', decimalDigits: 0);
  final TextEditingController searchController = TextEditingController();

  final List<String> transactionFilters = [
    'All',
    'Sales',
    'Payments',
    'Returns',
    'Adjustments'
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  ScreenType _getScreenType(double width) {
    if (width < 600) return ScreenType.mobile;
    if (width < 1024) return ScreenType.tablet;
    return ScreenType.desktop;
  }

  Future<void> _loadCustomers() async {
    final cust = await DatabaseHelper.instance.getAllCustomers();
    setState(() {
      customers = cust;
    });
  }

  Future<void> _generateLedger() async {
    setState(() {
      isLoading = true;
      hasGenerated = false;
      showAllCustomers = selectedCustomer == null;
    });

    try {
      final from = fromDate.toIso8601String().substring(0, 10);
      final to = toDate.toIso8601String().substring(0, 10);

      if (selectedCustomer == null) {
        await _generateAllCustomersLedger(from, to);
      } else {
        await _generateSingleCustomerLedger(from, to);
      }

      setState(() {
        isLoading = false;
        hasGenerated = true;
      });

      // Show ledger in full-screen dialog
      if (mounted) {
        _showLedgerDialog();
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error generating ledger: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FULL SCREEN LEDGER DIALOG
  // ═══════════════════════════════════════════════════════════════════════════

  void _showLedgerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          child: _LedgerDialogContent(
            parent: this,
          ),
        );
      },
    );
  }

  void _goBackToSelection() {
    // Pop the full-screen dialog
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    setState(() {
      hasGenerated = false;
      ledgerEntries = [];
      filteredEntries = [];
      allCustomersSummary = [];
      searchQuery = '';
      selectedFilter = 'All';
      searchController.clear();
    });
  }

  Future<void> _generateAllCustomersLedger(String from, String to) async {
    ledgerEntries = [];
    allCustomersSummary = [];
    totalDebit = 0.0;
    totalCredit = 0.0;
    openingBalance = 0.0;
    closingBalance = 0.0;

    for (var customer in customers) {
      double customerOpeningBalance = customer.openingBalance;
      double customerTotalDebit = 0.0;
      double customerTotalCredit = 0.0;
      double runningBalance = customerOpeningBalance;

      final sales = await DatabaseHelper.instance.getCustomerCreditSales(
        customer.id!,
        from,
        to,
      );

      if (customerOpeningBalance != 0) {
        if (customerOpeningBalance > 0) {
          customerTotalDebit += customerOpeningBalance;
        } else {
          customerTotalCredit += customerOpeningBalance.abs();
        }

        ledgerEntries.add({
          'date': fromDate,
          'customerId': customer.id,
          'customerName': customer.name,
          'customerPhone': customer.phone,
          'type': 'Opening',
          'reference': '-',
          'description': 'Opening Balance',
          'debit': customerOpeningBalance > 0 ? customerOpeningBalance : 0.0,
          'credit':
              customerOpeningBalance < 0 ? customerOpeningBalance.abs() : 0.0,
          'balance': runningBalance,
          'icon': Icons.account_balance_wallet_outlined,
          'color': const Color(0xFF6366F1),
        });
      }

      for (var sale in sales) {
        double saleBalance = (sale['balance'] as num).toDouble();
        double saleTotal = (sale['total'] as num).toDouble();
        double amountPaid = (sale['amountPaid'] as num?)?.toDouble() ?? 0.0;

        runningBalance += saleBalance;
        customerTotalDebit += saleTotal;

        ledgerEntries.add({
          'date': DateTime.parse(sale['dateTime']),
          'customerId': customer.id,
          'customerName': customer.name,
          'customerPhone': customer.phone,
          'type': 'Sale',
          'reference': 'INV-${sale['invoiceId']}',
          'description': 'Sale Invoice',
          'debit': saleTotal,
          'credit': 0.0,
          'balance': runningBalance,
          'details': sale,
          'icon': Icons.shopping_cart_outlined,
          'color': const Color(0xFFEF4444),
        });

        if (amountPaid > 0) {
          runningBalance -= amountPaid;
          customerTotalCredit += amountPaid;

          ledgerEntries.add({
            'date': DateTime.parse(sale['dateTime']),
            'customerId': customer.id,
            'customerName': customer.name,
            'customerPhone': customer.phone,
            'type': 'Payment',
            'reference': 'PAY-${sale['invoiceId']}',
            'description': 'Payment Received',
            'debit': 0.0,
            'credit': amountPaid,
            'balance': runningBalance,
            'icon': Icons.payments_outlined,
            'color': const Color(0xFF10B981),
          });
        }
      }

      double customerClosingBalance = runningBalance;

      allCustomersSummary.add(CustomerLedgerSummary(
        customer: customer,
        openingBalance: customerOpeningBalance,
        totalDebit: customerTotalDebit,
        totalCredit: customerTotalCredit,
        closingBalance: customerClosingBalance,
        transactionCount: sales.length,
      ));

      openingBalance += customerOpeningBalance;
      totalDebit += customerTotalDebit;
      totalCredit += customerTotalCredit;
      closingBalance += customerClosingBalance;
    }

    ledgerEntries.sort(
        (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    allCustomersSummary
        .sort((a, b) => b.closingBalance.compareTo(a.closingBalance));
    filteredEntries = List.from(ledgerEntries);
  }

  Future<void> _generateSingleCustomerLedger(String from, String to) async {
    openingBalance = selectedCustomer!.openingBalance;
    allCustomersSummary = [];

    final sales = await DatabaseHelper.instance.getCustomerCreditSales(
      selectedCustomer!.id!,
      from,
      to,
    );

    ledgerEntries = [];
    totalDebit = 0.0;
    totalCredit = 0.0;

    double runningBalance = openingBalance;

    ledgerEntries.add({
      'date': fromDate,
      'customerId': selectedCustomer!.id,
      'customerName': selectedCustomer!.name,
      'customerPhone': selectedCustomer!.phone,
      'type': 'Opening',
      'reference': '-',
      'description': 'Opening Balance',
      'debit': openingBalance > 0 ? openingBalance : 0.0,
      'credit': openingBalance < 0 ? openingBalance.abs() : 0.0,
      'balance': runningBalance,
      'icon': Icons.account_balance_wallet_outlined,
      'color': const Color(0xFF6366F1),
    });

    if (openingBalance > 0) {
      totalDebit += openingBalance;
    } else {
      totalCredit += openingBalance.abs();
    }

    for (var sale in sales) {
      double saleBalance = (sale['balance'] as num).toDouble();
      double saleTotal = (sale['total'] as num).toDouble();
      double amountPaid = (sale['amountPaid'] as num?)?.toDouble() ?? 0.0;

      runningBalance += saleBalance;
      totalDebit += saleTotal;

      ledgerEntries.add({
        'date': DateTime.parse(sale['dateTime']),
        'customerId': selectedCustomer!.id,
        'customerName': selectedCustomer!.name,
        'customerPhone': selectedCustomer!.phone,
        'type': 'Sale',
        'reference': 'INV-${sale['invoiceId']}',
        'description': 'Sale Invoice',
        'debit': saleTotal,
        'credit': 0.0,
        'balance': runningBalance,
        'details': sale,
        'icon': Icons.shopping_cart_outlined,
        'color': const Color(0xFFEF4444),
      });

      if (amountPaid > 0) {
        runningBalance -= amountPaid;
        totalCredit += amountPaid;

        ledgerEntries.add({
          'date': DateTime.parse(sale['dateTime']),
          'customerId': selectedCustomer!.id,
          'customerName': selectedCustomer!.name,
          'customerPhone': selectedCustomer!.phone,
          'type': 'Payment',
          'reference': 'PAY-${sale['invoiceId']}',
          'description': 'Payment Received',
          'debit': 0.0,
          'credit': amountPaid,
          'balance': runningBalance,
          'icon': Icons.payments_outlined,
          'color': const Color(0xFF10B981),
        });
      }
    }

    closingBalance = runningBalance;
    filteredEntries = List.from(ledgerEntries);
  }

  void _filterEntries() {
    setState(() {
      filteredEntries = ledgerEntries.where((entry) {
        bool matchesFilter =
            selectedFilter == 'All' || entry['type'] == selectedFilter;
        bool matchesSearch = searchQuery.isEmpty ||
            entry['description']
                .toString()
                .toLowerCase()
                .contains(searchQuery.toLowerCase()) ||
            entry['reference']
                .toString()
                .toLowerCase()
                .contains(searchQuery.toLowerCase()) ||
            (entry['customerName']
                    ?.toString()
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase()) ??
                false);
        return matchesFilter && matchesSearch;
      }).toList();
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHOW EXPORT OPTIONS DIALOG
  // ═══════════════════════════════════════════════════════════════════════════

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Export Ledger Report',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose export format',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildExportOption(
                    icon: Icons.picture_as_pdf,
                    title: 'PDF',
                    color: const Color(0xFFEF4444),
                    onTap: () {
                      Navigator.pop(context);
                      _exportToPDF();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildExportOption(
                    icon: Icons.table_chart,
                    title: 'Excel',
                    color: const Color(0xFF10B981),
                    onTap: () {
                      Navigator.pop(context);
                      _exportToExcel();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildExportOption(
                    icon: Icons.print,
                    title: 'Print',
                    color: const Color(0xFF3B82F6),
                    onTap: () {
                      Navigator.pop(context);
                      _printLedger();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildExportOption(
                    icon: Icons.share,
                    title: 'Share',
                    color: const Color(0xFF8B5CF6),
                    onTap: () {
                      Navigator.pop(context);
                      _sharePDF();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF EXPORT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Uint8List> _generatePDFDocument() async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy');

    final fontData = await rootBundle
        .load('assets/fonts/Roboto/static/Roboto_Condensed-Italic.ttf');
    final ttf = pw.Font.ttf(fontData);
    final fontDataBold = await rootBundle
        .load('assets/fonts/Roboto/static/Roboto_Condensed-Medium.ttf');
    final ttfBold = pw.Font.ttf(fontDataBold);

    final title = showAllCustomers
        ? 'All Customers Ledger Report'
        : 'Customer Ledger Report - ${selectedCustomer!.name}';

    final dateRange =
        '${dateFormat.format(fromDate)} to ${dateFormat.format(toDate)}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) =>
            _buildPDFHeader(title, dateRange, ttf, ttfBold),
        footer: (context) => _buildPDFFooter(context, ttf),
        build: (context) => [
          _buildPDFSummary(ttf, ttfBold),
          pw.SizedBox(height: 20),
          _buildPDFTable(ttf, ttfBold, dateFormat),
          pw.SizedBox(height: 20),
          _buildPDFTotals(ttf, ttfBold),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPDFHeader(
      String title, String dateRange, pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MEDICAL STORE',
                  style: pw.TextStyle(
                    font: ttfBold,
                    fontSize: 20,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    font: ttfBold,
                    fontSize: 14,
                    color: PdfColors.grey800,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                  style: pw.TextStyle(
                      font: ttf, fontSize: 9, color: PdfColors.grey600),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Period: $dateRange',
                  style: pw.TextStyle(
                      font: ttf, fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.grey300, thickness: 1),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildPDFFooter(pw.Context context, pw.Font ttf) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style:
            pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey500),
      ),
    );
  }

  pw.Widget _buildPDFSummary(pw.Font ttf, pw.Font ttfBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildPDFSummaryItem(
              'Opening Balance', openingBalance, PdfColors.indigo, ttf, ttfBold),
          _buildPDFSummaryItem(
              'Total Debit', totalDebit, PdfColors.red, ttf, ttfBold),
          _buildPDFSummaryItem(
              'Total Credit', totalCredit, PdfColors.green, ttf, ttfBold),
          _buildPDFSummaryItem(
            'Closing Balance',
            closingBalance,
            closingBalance > 0 ? PdfColors.red : PdfColors.green,
            ttf,
            ttfBold,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFSummaryItem(String label, double amount, PdfColor color,
      pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style:
              pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          currencyFormat.format(amount),
          style: pw.TextStyle(font: ttfBold, fontSize: 12, color: color),
        ),
      ],
    );
  }

  pw.Widget _buildPDFTable(
      pw.Font ttf, pw.Font ttfBold, DateFormat dateFormat) {
    final headers = showAllCustomers
        ? [
            'Date',
            'Customer',
            'Type',
            'Reference',
            'Debit',
            'Credit',
            'Balance'
          ]
        : [
            'Date',
            'Type',
            'Reference',
            'Description',
            'Debit',
            'Credit',
            'Balance'
          ];

    final data = filteredEntries.map((entry) {
      if (showAllCustomers) {
        return [
          dateFormat.format(entry['date']),
          entry['customerName'] ?? '',
          entry['type'],
          entry['reference'],
          entry['debit'] > 0 ? currencyFormat.format(entry['debit']) : '-',
          entry['credit'] > 0 ? currencyFormat.format(entry['credit']) : '-',
          currencyFormat.format(entry['balance']),
        ];
      } else {
        return [
          dateFormat.format(entry['date']),
          entry['type'],
          entry['reference'],
          entry['description'],
          entry['debit'] > 0 ? currencyFormat.format(entry['debit']) : '-',
          entry['credit'] > 0 ? currencyFormat.format(entry['credit']) : '-',
          currencyFormat.format(entry['balance']),
        ];
      }
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
        font: ttfBold,
        fontSize: 9,
        color: PdfColors.white,
      ),
      headerDecoration:
          const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: pw.TextStyle(font: ttf, fontSize: 8),
      cellHeight: 25,
      cellAlignments: showAllCustomers
          ? {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
            }
          : {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
            },
      headerAlignments: showAllCustomers
          ? {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
            }
          : {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
            },
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    );
  }

  pw.Widget _buildPDFTotals(pw.Font ttf, pw.Font ttfBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: closingBalance > 0 ? PdfColors.red50 : PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color:
              closingBalance > 0 ? PdfColors.red200 : PdfColors.green200,
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'TOTAL',
            style: pw.TextStyle(
                font: ttfBold, fontSize: 12, color: PdfColors.grey800),
          ),
          pw.Row(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Total Debit',
                      style: pw.TextStyle(
                          font: ttf,
                          fontSize: 8,
                          color: PdfColors.grey600)),
                  pw.Text(
                    currencyFormat.format(totalDebit),
                    style: pw.TextStyle(
                        font: ttfBold, fontSize: 11, color: PdfColors.red),
                  ),
                ],
              ),
              pw.SizedBox(width: 30),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Total Credit',
                      style: pw.TextStyle(
                          font: ttf,
                          fontSize: 8,
                          color: PdfColors.grey600)),
                  pw.Text(
                    currencyFormat.format(totalCredit),
                    style: pw.TextStyle(
                        font: ttfBold, fontSize: 11, color: PdfColors.green),
                  ),
                ],
              ),
              pw.SizedBox(width: 30),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 15, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: closingBalance > 0 ? PdfColors.red : PdfColors.green,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      closingBalance > 0 ? 'Receivable' : 'Payable',
                      style: pw.TextStyle(
                          font: ttf, fontSize: 8, color: PdfColors.white),
                    ),
                    pw.Text(
                      currencyFormat.format(closingBalance.abs()),
                      style: pw.TextStyle(
                          font: ttfBold, fontSize: 12, color: PdfColors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportToPDF() async {
    setState(() => isExporting = true);

    try {
      final pdfData = await _generatePDFDocument();

      final directory = await getApplicationDocumentsDirectory();
      final fileName = showAllCustomers
          ? 'All_Customers_Ledger_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf'
          : '${selectedCustomer!.name.replaceAll(' ', '_')}_Ledger_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfData);

      setState(() => isExporting = false);

      _showExportSuccessDialog(file.path, 'PDF');
    } catch (e) {
      setState(() => isExporting = false);
      _showErrorSnackBar('Error exporting PDF: $e');
    }
  }

  Future<void> _printLedger() async {
    setState(() => isExporting = true);

    try {
      final pdfData = await _generatePDFDocument();

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfData,
        name: showAllCustomers
            ? 'All_Customers_Ledger'
            : '${selectedCustomer!.name}_Ledger',
      );

      setState(() => isExporting = false);
    } catch (e) {
      setState(() => isExporting = false);
      _showErrorSnackBar('Error printing: $e');
    }
  }

  Future<void> _sharePDF() async {
    setState(() => isExporting = true);

    try {
      final pdfData = await _generatePDFDocument();

      final directory = await getTemporaryDirectory();
      final fileName = showAllCustomers
          ? 'All_Customers_Ledger.pdf'
          : '${selectedCustomer!.name.replaceAll(' ', '_')}_Ledger.pdf';

      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfData);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Customer Ledger Report',
        text: 'Please find attached the customer ledger report.',
      );

      setState(() => isExporting = false);
    } catch (e) {
      setState(() => isExporting = false);
      _showErrorSnackBar('Error sharing: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXCEL EXPORT
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _exportToExcel() async {
    setState(() => isExporting = true);

    try {
      final excel = xl.Excel.createExcel();
      final dateFormat = DateFormat('dd MMM yyyy');

      excel.delete('Sheet1');

      final summarySheet = excel['Summary'];
      _buildExcelSummarySheet(summarySheet, dateFormat);

      final ledgerSheet = excel['Ledger'];
      _buildExcelLedgerSheet(ledgerSheet, dateFormat);

      if (showAllCustomers && allCustomersSummary.isNotEmpty) {
        final customerSheet = excel['Customer Summary'];
        _buildExcelCustomerSummarySheet(customerSheet);
      }

      final directory = await getApplicationDocumentsDirectory();
      final fileName = showAllCustomers
          ? 'All_Customers_Ledger_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx'
          : '${selectedCustomer!.name.replaceAll(' ', '_')}_Ledger_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

      final file = File('${directory.path}/$fileName');
      final excelBytes = excel.save();
      await file.writeAsBytes(excelBytes!);

      setState(() => isExporting = false);

      _showExportSuccessDialog(file.path, 'Excel');
    } catch (e) {
      setState(() => isExporting = false);
      _showErrorSnackBar('Error exporting Excel: $e');
    }
  }

  void _buildExcelSummarySheet(xl.Sheet sheet, DateFormat dateFormat) {
    sheet.cell(xl.CellIndex.indexByString('A1')).value =
        xl.TextCellValue('CUSTOMER LEDGER REPORT');
    sheet.merge(xl.CellIndex.indexByString('A1'),
        xl.CellIndex.indexByString('D1'));
    sheet.cell(xl.CellIndex.indexByString('A1')).cellStyle = xl.CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: xl.ExcelColor.fromHexString('#1E40AF'),
    );

    sheet.cell(xl.CellIndex.indexByString('A3')).value =
        xl.TextCellValue('Customer:');
    sheet.cell(xl.CellIndex.indexByString('B3')).value = xl.TextCellValue(
        showAllCustomers ? 'All Customers' : selectedCustomer!.name);

    sheet.cell(xl.CellIndex.indexByString('A4')).value =
        xl.TextCellValue('Period:');
    sheet.cell(xl.CellIndex.indexByString('B4')).value = xl.TextCellValue(
        '${dateFormat.format(fromDate)} to ${dateFormat.format(toDate)}');

    sheet.cell(xl.CellIndex.indexByString('A5')).value =
        xl.TextCellValue('Generated:');
    sheet.cell(xl.CellIndex.indexByString('B5')).value = xl.TextCellValue(
        DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()));

    sheet.cell(xl.CellIndex.indexByString('A7')).value =
        xl.TextCellValue('SUMMARY');
    sheet.cell(xl.CellIndex.indexByString('A7')).cellStyle =
        xl.CellStyle(bold: true, fontSize: 12);

    final summaryHeaderStyle = xl.CellStyle(
      bold: true,
      backgroundColorHex: xl.ExcelColor.fromHexString('#E2E8F0'),
    );

    sheet.cell(xl.CellIndex.indexByString('A8')).value =
        xl.TextCellValue('Description');
    sheet.cell(xl.CellIndex.indexByString('B8')).value =
        xl.TextCellValue('Amount');
    sheet.cell(xl.CellIndex.indexByString('A8')).cellStyle = summaryHeaderStyle;
    sheet.cell(xl.CellIndex.indexByString('B8')).cellStyle = summaryHeaderStyle;

    sheet.cell(xl.CellIndex.indexByString('A9')).value =
        xl.TextCellValue('Opening Balance');
    sheet.cell(xl.CellIndex.indexByString('B9')).value =
        xl.DoubleCellValue(openingBalance);

    sheet.cell(xl.CellIndex.indexByString('A10')).value =
        xl.TextCellValue('Total Debit');
    sheet.cell(xl.CellIndex.indexByString('B10')).value =
        xl.DoubleCellValue(totalDebit);
    sheet.cell(xl.CellIndex.indexByString('B10')).cellStyle = xl.CellStyle(
      fontColorHex: xl.ExcelColor.fromHexString('#DC2626'),
    );

    sheet.cell(xl.CellIndex.indexByString('A11')).value =
        xl.TextCellValue('Total Credit');
    sheet.cell(xl.CellIndex.indexByString('B11')).value =
        xl.DoubleCellValue(totalCredit);
    sheet.cell(xl.CellIndex.indexByString('B11')).cellStyle = xl.CellStyle(
      fontColorHex: xl.ExcelColor.fromHexString('#16A34A'),
    );

    sheet.cell(xl.CellIndex.indexByString('A12')).value =
        xl.TextCellValue('Closing Balance');
    sheet.cell(xl.CellIndex.indexByString('B12')).value =
        xl.DoubleCellValue(closingBalance);
    sheet.cell(xl.CellIndex.indexByString('A12')).cellStyle =
        xl.CellStyle(bold: true);
    sheet.cell(xl.CellIndex.indexByString('B12')).cellStyle = xl.CellStyle(
      bold: true,
      fontColorHex: closingBalance > 0
          ? xl.ExcelColor.fromHexString('#DC2626')
          : xl.ExcelColor.fromHexString('#16A34A'),
    );

    sheet.cell(xl.CellIndex.indexByString('A13')).value =
        xl.TextCellValue('Total Transactions');
    sheet.cell(xl.CellIndex.indexByString('B13')).value =
        xl.IntCellValue(filteredEntries.length);

    sheet.setColumnWidth(0, 25);
    sheet.setColumnWidth(1, 20);
  }

  void _buildExcelLedgerSheet(xl.Sheet sheet, DateFormat dateFormat) {
    final headerStyle = xl.CellStyle(
      bold: true,
      backgroundColorHex: xl.ExcelColor.fromHexString('#1E293B'),
      fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
    );

    int col = 0;
    final headers = showAllCustomers
        ? [
            'Date',
            'Customer',
            'Phone',
            'Type',
            'Reference',
            'Description',
            'Debit',
            'Credit',
            'Balance'
          ]
        : ['Date', 'Type', 'Reference', 'Description', 'Debit', 'Credit', 'Balance'];

    for (var header in headers) {
      sheet
          .cell(xl.CellIndex.indexByColumnRow(
              columnIndex: col, rowIndex: 0))
          .value = xl.TextCellValue(header);
      sheet
          .cell(xl.CellIndex.indexByColumnRow(
              columnIndex: col, rowIndex: 0))
          .cellStyle = headerStyle;
      col++;
    }

    int row = 1;
    for (var entry in filteredEntries) {
      col = 0;

      sheet
          .cell(xl.CellIndex.indexByColumnRow(
              columnIndex: col++, rowIndex: row))
          .value = xl.TextCellValue(dateFormat.format(entry['date']));

      if (showAllCustomers) {
        sheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: col++, rowIndex: row))
            .value = xl.TextCellValue(entry['customerName'] ?? '');
        sheet
            .cell(xl.CellIndex.indexByColumnRow(
                columnIndex: col++, rowIndex: row))
            .value = xl.TextCellValue(entry['customerPhone'] ?? '');
      }

      sheet
          .cell(xl.CellIndex.indexByColumnRow(
              columnIndex: col++, rowIndex: row))
          .value = xl.TextCellValue(entry['type']);

      sheet
          .cell(xl.CellIndex.indexByColumnRow(
              columnIndex: col++, rowIndex: row))
          .value = xl.TextCellValue(entry['reference']);

      sheet
          .cell(xl.CellIndex.indexByColumnRow(
              columnIndex: col++, rowIndex: row))
          .value = xl.TextCellValue(entry['description']);

      final debitCell = sheet.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row));
      debitCell.value = xl.DoubleCellValue(entry['debit']);
      if (entry['debit'] > 0) {
        debitCell.cellStyle = xl.CellStyle(
            fontColorHex: xl.ExcelColor.fromHexString('#DC2626'));
      }

      final creditCell = sheet.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row));
      creditCell.value = xl.DoubleCellValue(entry['credit']);
      if (entry['credit'] > 0) {
        creditCell.cellStyle = xl.CellStyle(
            fontColorHex: xl.ExcelColor.fromHexString('#16A34A'));
      }

      final balanceCell = sheet.cell(
          xl.CellIndex.indexByColumnRow(columnIndex: col++, rowIndex: row));
      balanceCell.value = xl.DoubleCellValue(entry['balance']);
      balanceCell.cellStyle = xl.CellStyle(
        bold: true,
        fontColorHex: entry['balance'] > 0
            ? xl.ExcelColor.fromHexString('#DC2626')
            : xl.ExcelColor.fromHexString('#16A34A'),
      );

      row++;
    }

    row++;

    final totalLabelCol = showAllCustomers ? 5 : 3;
    sheet
        .cell(xl.CellIndex.indexByColumnRow(
            columnIndex: totalLabelCol, rowIndex: row))
        .value = xl.TextCellValue('TOTAL');
    sheet
        .cell(xl.CellIndex.indexByColumnRow(
            columnIndex: totalLabelCol, rowIndex: row))
        .cellStyle = xl.CellStyle(bold: true);

    final debitTotalCol = showAllCustomers ? 6 : 4;
    sheet
        .cell(xl.CellIndex.indexByColumnRow(
            columnIndex: debitTotalCol, rowIndex: row))
        .value = xl.DoubleCellValue(totalDebit);
    sheet
        .cell(xl.CellIndex.indexByColumnRow(
            columnIndex: debitTotalCol, rowIndex: row))
        .cellStyle = xl.CellStyle(
            bold: true,
            fontColorHex: xl.ExcelColor.fromHexString('#DC2626'));

    final creditTotalCol = showAllCustomers ? 7 : 5;
    sheet
        .cell(xl.CellIndex.indexByColumnRow(
            columnIndex: creditTotalCol, rowIndex: row))
        .value = xl.DoubleCellValue(totalCredit);
    sheet
        .cell(xl.CellIndex.indexByColumnRow(
            columnIndex: creditTotalCol, rowIndex: row))
        .cellStyle = xl.CellStyle(
            bold: true,
            fontColorHex: xl.ExcelColor.fromHexString('#16A34A'));

    final balanceTotalCol = showAllCustomers ? 8 : 6;
    sheet
        .cell(xl.CellIndex.indexByColumnRow(
            columnIndex: balanceTotalCol, rowIndex: row))
        .value = xl.DoubleCellValue(closingBalance);
    sheet
        .cell(xl.CellIndex.indexByColumnRow(
            columnIndex: balanceTotalCol, rowIndex: row))
        .cellStyle = xl.CellStyle(
      bold: true,
      fontColorHex: closingBalance > 0
          ? xl.ExcelColor.fromHexString('#DC2626')
          : xl.ExcelColor.fromHexString('#16A34A'),
    );

    if (showAllCustomers) {
      sheet.setColumnWidth(0, 15);
      sheet.setColumnWidth(1, 25);
      sheet.setColumnWidth(2, 15);
      sheet.setColumnWidth(3, 12);
      sheet.setColumnWidth(4, 15);
      sheet.setColumnWidth(5, 20);
      sheet.setColumnWidth(6, 15);
      sheet.setColumnWidth(7, 15);
      sheet.setColumnWidth(8, 15);
    } else {
      sheet.setColumnWidth(0, 15);
      sheet.setColumnWidth(1, 12);
      sheet.setColumnWidth(2, 15);
      sheet.setColumnWidth(3, 25);
      sheet.setColumnWidth(4, 15);
      sheet.setColumnWidth(5, 15);
      sheet.setColumnWidth(6, 15);
    }
  }

  void _buildExcelCustomerSummarySheet(xl.Sheet sheet) {
    final headerStyle = xl.CellStyle(
      bold: true,
      backgroundColorHex: xl.ExcelColor.fromHexString('#1E293B'),
      fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
    );

    final headers = [
      'Customer',
      'Phone',
      'Opening',
      'Debit',
      'Credit',
      'Closing',
      'Transactions'
    ];

    for (int i = 0; i < headers.length; i++) {
      sheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = xl.TextCellValue(headers[i]);
      sheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .cellStyle = headerStyle;
    }

    int row = 1;
    for (var summary in allCustomersSummary) {
      sheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = xl.TextCellValue(summary.customer.name);
      sheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = xl.TextCellValue(summary.customer.phone);
      sheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = xl.DoubleCellValue(summary.openingBalance);

      final debitCell = sheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
      debitCell.value = xl.DoubleCellValue(summary.totalDebit);
      debitCell.cellStyle = xl.CellStyle(
          fontColorHex: xl.ExcelColor.fromHexString('#DC2626'));

      final creditCell = sheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row));
      creditCell.value = xl.DoubleCellValue(summary.totalCredit);
      creditCell.cellStyle = xl.CellStyle(
          fontColorHex: xl.ExcelColor.fromHexString('#16A34A'));

      final closingCell = sheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row));
      closingCell.value = xl.DoubleCellValue(summary.closingBalance);
      closingCell.cellStyle = xl.CellStyle(
        bold: true,
        fontColorHex: summary.closingBalance > 0
            ? xl.ExcelColor.fromHexString('#DC2626')
            : xl.ExcelColor.fromHexString('#16A34A'),
      );

      sheet
          .cell(xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
          .value = xl.IntCellValue(summary.transactionCount);

      row++;
    }

    row++;
    sheet
        .cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = xl.TextCellValue('TOTAL');
    sheet
        .cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .cellStyle = xl.CellStyle(bold: true);

    sheet
        .cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        .value = xl.DoubleCellValue(openingBalance);
    sheet
        .cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
        .cellStyle = xl.CellStyle(bold: true);

    sheet
        .cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .value = xl.DoubleCellValue(totalDebit);
    sheet
        .cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
        .cellStyle = xl.CellStyle(
            bold: true,
            fontColorHex: xl.ExcelColor.fromHexString('#DC2626'));

    sheet
        .cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        .value = xl.DoubleCellValue(totalCredit);
    sheet
        .cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
        .cellStyle = xl.CellStyle(
            bold: true,
            fontColorHex: xl.ExcelColor.fromHexString('#16A34A'));

    sheet
        .cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
        .value = xl.DoubleCellValue(closingBalance);
    sheet
        .cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
        .cellStyle = xl.CellStyle(
      bold: true,
      fontColorHex: closingBalance > 0
          ? xl.ExcelColor.fromHexString('#DC2626')
          : xl.ExcelColor.fromHexString('#16A34A'),
    );

    sheet.setColumnWidth(0, 25);
    sheet.setColumnWidth(1, 15);
    sheet.setColumnWidth(2, 15);
    sheet.setColumnWidth(3, 15);
    sheet.setColumnWidth(4, 15);
    sheet.setColumnWidth(5, 15);
    sheet.setColumnWidth(6, 15);
  }

  void _showExportSuccessDialog(String filePath, String type) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF10B981),
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Export Successful!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$type file has been saved successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  filePath.split('/').last,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        OpenFile.open(filePath);
                      },
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomerDropdown() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CustomerSelectionSheet(
        customers: customers,
        selectedCustomer: selectedCustomer,
        currencyFormat: currencyFormat,
        onSelectAll: () {
          setState(() {
            selectedCustomer = null;
          });
          Navigator.pop(context);
        },
        onSelectCustomer: (customer) {
          setState(() {
            selectedCustomer = customer;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          SafeArea(
            child: _buildBody(),
          ),
          // Loading Overlay
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Generating Ledger...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          // Exporting Overlay
          if (isExporting)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Exporting...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Selection card is always shown as the main body
  // Ledger is shown in a full-screen dialog on top
  Widget _buildBody() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenType = _getScreenType(screenWidth);

    return Padding(
      padding: EdgeInsets.all(screenType == ScreenType.mobile ? 12 : 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSelectionCard(screenType),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCard(ScreenType screenType) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long_outlined,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Ledger Report',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      'Generate detailed transaction history',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          const Text(
            'Select Customer',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          _buildCustomerDropdownButton(),
          const SizedBox(height: 20),
          const Text(
            'Date Range',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  'From',
                  fromDate,
                  (d) => setState(() => fromDate = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateField(
                  'To',
                  toDate,
                  (d) => setState(() => toDate = d),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickDateChip('7 Days', () {
                setState(() {
                  fromDate =
                      DateTime.now().subtract(const Duration(days: 7));
                  toDate = DateTime.now();
                });
              }),
              _buildQuickDateChip('30 Days', () {
                setState(() {
                  fromDate =
                      DateTime.now().subtract(const Duration(days: 30));
                  toDate = DateTime.now();
                });
              }),
              _buildQuickDateChip('This Month', () {
                final now = DateTime.now();
                setState(() {
                  fromDate = DateTime(now.year, now.month, 1);
                  toDate = now;
                });
              }),
              _buildQuickDateChip('This Year', () {
                final now = DateTime.now();
                setState(() {
                  fromDate = DateTime(now.year, 1, 1);
                  toDate = now;
                });
              }),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : _generateLedger,
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      selectedCustomer == null
                          ? Icons.groups
                          : Icons.play_arrow,
                      size: 20,
                    ),
              label: Text(
                isLoading
                    ? 'Generating...'
                    : selectedCustomer == null
                        ? 'Generate All Customers Ledger'
                        : 'Generate Ledger',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedCustomer == null
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedCustomer == null
                        ? 'This will generate a combined ledger for all ${customers.length} customers'
                        : 'Ledger will be generated for ${selectedCustomer!.name}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0369A1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerDropdownButton() {
    final bool isAllSelected = selectedCustomer == null;

    return InkWell(
      onTap: _showCustomerDropdown,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isAllSelected
                ? const Color(0xFF8B5CF6)
                : const Color(0xFF3B82F6),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: isAllSelected
                    ? const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      )
                    : null,
                color: isAllSelected ? null : const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: isAllSelected
                    ? const Icon(Icons.groups, color: Colors.white, size: 20)
                    : Text(
                        selectedCustomer!.name.isNotEmpty
                            ? selectedCustomer!.name[0].toUpperCase()
                            : 'C',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAllSelected ? 'All Customers' : selectedCustomer!.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isAllSelected
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAllSelected
                        ? '${customers.length} customers total'
                        : selectedCustomer!.phone,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (!isAllSelected && selectedCustomer!.openingBalance > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  currencyFormat.format(selectedCustomer!.openingBalance),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField(
      String label, DateTime date, Function(DateTime) onChanged) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 1)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                    primary: Color(0xFF3B82F6)),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    DateFormat('dd MMM yyyy').format(date),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
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

  Widget _buildQuickDateChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LEDGER DIALOG CONTENT BUILDERS (called from _LedgerDialogContent)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget buildDialogHeader(ScreenType screenType) {
    final isMobile = screenType == ScreenType.mobile;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Color(0xFF3B82F6)),
                      onPressed: _goBackToSelection,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: showAllCustomers
                            ? const Color(0xFF8B5CF6).withOpacity(0.1)
                            : const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        showAllCustomers
                            ? Icons.groups
                            : Icons.receipt_long_outlined,
                        color: showAllCustomers
                            ? const Color(0xFF8B5CF6)
                            : const Color(0xFF6366F1),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            showAllCustomers
                                ? 'All Customers Ledger'
                                : 'Customer Ledger',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B)),
                          ),
                          Text(
                            showAllCustomers
                                ? '${allCustomersSummary.length} customers'
                                : selectedCustomer?.name ?? '',
                            style: TextStyle(
                                fontSize: 11,
                                color: showAllCustomers
                                    ? const Color(0xFF8B5CF6)
                                    : const Color(0xFF3B82F6),
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildHeaderAction(
                        Icons.download_outlined,
                        'Export',
                        _showExportOptions,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Color(0xFF3B82F6), size: 20),
                  ),
                  onPressed: _goBackToSelection,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: showAllCustomers
                        ? const Color(0xFF8B5CF6).withOpacity(0.1)
                        : const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    showAllCustomers
                        ? Icons.groups
                        : Icons.receipt_long_outlined,
                    color: showAllCustomers
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFF6366F1),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showAllCustomers
                            ? 'All Customers Ledger'
                            : 'Customer Ledger',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B)),
                      ),
                      Row(
                        children: [
                          if (showAllCustomers)
                            Text(
                              '${allCustomersSummary.length} customers',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF8B5CF6),
                                  fontWeight: FontWeight.w500),
                            )
                          else if (selectedCustomer != null)
                            Text(
                              selectedCustomer!.name,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF3B82F6),
                                  fontWeight: FontWeight.w500),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${DateFormat('dd MMM').format(fromDate)} - ${DateFormat('dd MMM yyyy').format(toDate)}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showExportOptions,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Export'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderAction(
      IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget buildDialogSummaryCards(ScreenType screenType) {
    final cards = [
      _buildSummaryCard(
        'Opening',
        openingBalance,
        Icons.account_balance_wallet_outlined,
        const Color(0xFF6366F1),
        subtitle: showAllCustomers
            ? '${allCustomersSummary.length} customers'
            : null,
        screenType: screenType,
      ),
      _buildSummaryCard(
        'Total Debit',
        totalDebit,
        Icons.arrow_upward,
        const Color(0xFFEF4444),
        screenType: screenType,
      ),
      _buildSummaryCard(
        'Total Credit',
        totalCredit,
        Icons.arrow_downward,
        const Color(0xFF10B981),
        screenType: screenType,
      ),
      _buildSummaryCard(
        'Closing',
        closingBalance,
        Icons.account_balance,
        closingBalance > 0
            ? const Color(0xFFEF4444)
            : const Color(0xFF10B981),
        isHighlighted: true,
        subtitle: closingBalance > 0 ? 'Receivable' : 'Payable',
        screenType: screenType,
      ),
    ];

    if (screenType == ScreenType.mobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 8),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 8),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      );
    }

    return Row(
      children: cards
          .map((card) => Expanded(child: card))
          .toList()
          .expand((widget) => [widget, const SizedBox(width: 12)])
          .toList()
        ..removeLast(),
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    IconData icon,
    Color color, {
    bool isHighlighted = false,
    String? subtitle,
    required ScreenType screenType,
  }) {
    final isMobile = screenType == ScreenType.mobile;

    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 16),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isHighlighted
                ? color.withOpacity(0.3)
                : const Color(0xFFE2E8F0)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(icon, color: color, size: 14),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    currencyFormat.format(amount),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color:
                          isHighlighted ? color : const Color(0xFF1E293B),
                    ),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 9,
                        color: color,
                        fontWeight: FontWeight.w500),
                  ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          currencyFormat.format(amount),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isHighlighted
                                ? color
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget buildDialogToolbar(ScreenType screenType, StateSetter setDialogState) {
    final isMobile = screenType == ScreenType.mobile;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: isMobile
          ? Column(
              children: [
                TextField(
                  controller: searchController,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: showAllCustomers
                        ? 'Search by customer, reference...'
                        : 'Search transactions...',
                    hintStyle: TextStyle(
                        color: Colors.grey.shade400, fontSize: 12),
                    prefixIcon: Icon(Icons.search,
                        size: 18, color: Colors.grey.shade400),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    searchQuery = value;
                    _filterEntries();
                    setDialogState(() {});
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: transactionFilters.map((filter) {
                      final isActive = selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            selectedFilter = filter;
                            _filterEntries();
                            setDialogState(() {});
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isActive
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              filter,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isActive
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                SizedBox(
                  width: screenType == ScreenType.tablet ? 200 : 250,
                  child: TextField(
                    controller: searchController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: showAllCustomers
                          ? 'Search by customer, reference...'
                          : 'Search transactions...',
                      hintStyle: TextStyle(
                          color: Colors.grey.shade400, fontSize: 12),
                      prefixIcon: Icon(Icons.search,
                          size: 18, color: Colors.grey.shade400),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      searchQuery = value;
                      _filterEntries();
                      setDialogState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ...transactionFilters.map((filter) {
                  final isActive = selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        selectedFilter = filter;
                        _filterEntries();
                        setDialogState(() {});
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFF3B82F6)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isActive
                                ? Colors.white
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const Spacer(),
                Text(
                  '${filteredEntries.length} transactions',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
    );
  }

  Widget buildDialogTable(ScreenType screenType) {
    if (screenType == ScreenType.mobile) {
      return _buildMobileLedgerList();
    }
    return _buildDesktopLedgerTable(screenType);
  }

  Widget _buildMobileLedgerList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Expanded(
            child: filteredEntries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No transactions found',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: filteredEntries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];
                      return _buildMobileLedgerCard(entry);
                    },
                  ),
          ),
          _buildMobileFooter(),
        ],
      ),
    );
  }

  Widget _buildMobileLedgerCard(Map<String, dynamic> entry) {
    return InkWell(
      onTap: entry['details'] != null
          ? () => _showTransactionDetails(entry)
          : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (entry['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    entry['icon'] as IconData,
                    size: 14,
                    color: entry['color'] as Color,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry['type'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: entry['color'] as Color,
                        ),
                      ),
                      if (showAllCustomers &&
                          entry['customerName'] != null)
                        Text(
                          entry['customerName'],
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF64748B)),
                        ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('dd MMM').format(entry['date']),
                  style:
                      TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text('Ref: ${entry['reference']}',
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFF3B82F6))),
                ),
                if (entry['debit'] > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Dr: ${currencyFormat.format(entry['debit'])}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEF4444)),
                    ),
                  ),
                if (entry['credit'] > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Cr: ${currencyFormat.format(entry['credit'])}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981)),
                    ),
                  ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: entry['balance'] > 0
                        ? const Color(0xFFEF4444).withOpacity(0.1)
                        : const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    currencyFormat.format(entry['balance']),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: entry['balance'] > 0
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat('Debit', totalDebit, const Color(0xFFEF4444)),
              _buildMiniStat(
                  'Credit', totalCredit, const Color(0xFF10B981)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: closingBalance > 0
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  showAllCustomers
                      ? 'Total Receivable'
                      : 'Closing Balance',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.white70),
                ),
                Text(
                  currencyFormat.format(closingBalance),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        Text(
          currencyFormat.format(value),
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _buildDesktopLedgerTable(ScreenType screenType) {
    final isTablet = screenType == ScreenType.tablet;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                _buildTableHeader('Date', flex: 2),
                if (showAllCustomers)
                  _buildTableHeader('Customer',
                      flex: isTablet ? 2 : 3),
                _buildTableHeader('Type', flex: 2),
                if (!isTablet) _buildTableHeader('Reference', flex: 2),
                _buildTableHeader('Description',
                    flex: isTablet ? 2 : 3),
                _buildTableHeader('Debit',
                    flex: 2, align: TextAlign.right),
                _buildTableHeader('Credit',
                    flex: 2, align: TextAlign.right),
                _buildTableHeader('Balance',
                    flex: 2, align: TextAlign.right),
              ],
            ),
          ),
          Expanded(
            child: filteredEntries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No transactions found',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredEntries.length,
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];
                      final isEven = index % 2 == 0;

                      return InkWell(
                        onTap: entry['details'] != null
                            ? () => _showTransactionDetails(entry)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isEven
                                ? Colors.white
                                : const Color(0xFFFAFAFA),
                            border: Border(
                              bottom: BorderSide(
                                  color: Colors.grey.shade100),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  DateFormat('dd MMM yyyy')
                                      .format(entry['date']),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF475569)),
                                ),
                              ),
                              if (showAllCustomers)
                                Expanded(
                                  flex: isTablet ? 2 : 3,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3B82F6)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Center(
                                          child: Text(
                                            (entry['customerName']
                                                    as String)[0]
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF3B82F6),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          entry['customerName'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF1E293B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Expanded(
                                flex: 2,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: (entry['color'] as Color)
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Icon(
                                        entry['icon'] as IconData,
                                        size: 12,
                                        color: entry['color'] as Color,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        entry['type'],
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: entry['color'] as Color,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isTablet)
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    entry['reference'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ),
                                ),
                              Expanded(
                                flex: isTablet ? 2 : 3,
                                child: Text(
                                  entry['description'],
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF1E293B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  entry['debit'] > 0
                                      ? currencyFormat
                                          .format(entry['debit'])
                                      : '-',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: entry['debit'] > 0
                                        ? const Color(0xFFEF4444)
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  entry['credit'] > 0
                                      ? currencyFormat
                                          .format(entry['credit'])
                                      : '-',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: entry['credit'] > 0
                                        ? const Color(0xFF10B981)
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: entry['balance'] > 0
                                        ? const Color(0xFFEF4444)
                                            .withOpacity(0.1)
                                        : const Color(0xFF10B981)
                                            .withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    currencyFormat
                                        .format(entry['balance']),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: entry['balance'] > 0
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border:
                  Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Text(
                  showAllCustomers ? 'All Customers Total' : 'Total',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B)),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Debit',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500)),
                    Text(
                      currencyFormat.format(totalDebit),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEF4444)),
                    ),
                  ],
                ),
                const SizedBox(width: 32),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Credit',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500)),
                    Text(
                      currencyFormat.format(totalCredit),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981)),
                    ),
                  ],
                ),
                const SizedBox(width: 32),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: closingBalance > 0
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        showAllCustomers
                            ? 'Total Receivable'
                            : 'Closing Balance',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white70),
                      ),
                      Text(
                        currencyFormat.format(closingBalance),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text,
      {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> entry) {
    final details = entry['details'] as Map<String, dynamic>?;
    if (details == null) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth < 600 ? screenWidth * 0.95 : 500.0;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: dialogWidth,
          padding: EdgeInsets.all(screenWidth < 600 ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (entry['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(entry['icon'] as IconData,
                        color: entry['color'] as Color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invoice #${details['invoiceId']}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B)),
                        ),
                        Text(
                          DateFormat('dd MMMM yyyy, hh:mm a').format(
                              DateTime.parse(details['dateTime'])),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (showAllCustomers &&
                  entry['customerName'] != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry['customerName'],
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        entry['customerPhone'] ?? '',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Divider(),
              const SizedBox(height: 16),
              _buildDetailRow('Subtotal',
                  currencyFormat.format(details['subtotal'] ?? 0)),
              _buildDetailRow('Discount',
                  currencyFormat.format(details['discount'] ?? 0)),
              _buildDetailRow(
                  'Tax', currencyFormat.format(details['tax'] ?? 0)),
              const Divider(height: 24),
              _buildDetailRow(
                  'Total', currencyFormat.format(details['total'] ?? 0),
                  isBold: true),
              _buildDetailRow(
                  'Amount Paid',
                  currencyFormat.format(details['amountPaid'] ?? 0),
                  color: const Color(0xFF10B981)),
              _buildDetailRow('Balance',
                  currencyFormat.format(details['balance'] ?? 0),
                  color: const Color(0xFFEF4444), isBold: true),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.print_outlined, size: 12),
                    label: const Text('Print'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Close'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: color ?? const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEDGER DIALOG CONTENT WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

class _LedgerDialogContent extends StatefulWidget {
  final _CustomerLedgerReportState parent;

  const _LedgerDialogContent({required this.parent});

  @override
  State<_LedgerDialogContent> createState() => _LedgerDialogContentState();
}

class _LedgerDialogContentState extends State<_LedgerDialogContent> {
  ScreenType _getScreenType(double width) {
    if (width < 600) return ScreenType.mobile;
    if (width < 1024) return ScreenType.tablet;
    return ScreenType.desktop;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenType = _getScreenType(screenWidth);
    final isMobile = screenType == ScreenType.mobile;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.all(isMobile ? 8 : 16),
              child: Column(
                children: [
                  // Header with back button + export button
                  widget.parent.buildDialogHeader(screenType),
                  const SizedBox(height: 12),
                  // Summary cards
                  widget.parent.buildDialogSummaryCards(screenType),
                  const SizedBox(height: 12),
                  // Search + filter toolbar
                  widget.parent
                      .buildDialogToolbar(screenType, setState),
                  const SizedBox(height: 8),
                  // Ledger table / list
                  Expanded(
                    child: widget.parent.buildDialogTable(screenType),
                  ),
                ],
              ),
            ),
            // Exporting overlay inside dialog
            if (widget.parent.isExporting)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Exporting...',
                        style:
                            TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CUSTOMER SELECTION BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _CustomerSelectionSheet extends StatefulWidget {
  final List<Customer> customers;
  final Customer? selectedCustomer;
  final NumberFormat currencyFormat;
  final VoidCallback onSelectAll;
  final Function(Customer) onSelectCustomer;

  const _CustomerSelectionSheet({
    required this.customers,
    required this.selectedCustomer,
    required this.currencyFormat,
    required this.onSelectAll,
    required this.onSelectCustomer,
  });

  @override
  State<_CustomerSelectionSheet> createState() =>
      _CustomerSelectionSheetState();
}

class _CustomerSelectionSheetState
    extends State<_CustomerSelectionSheet> {
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();

  List<Customer> get filteredCustomers {
    if (searchQuery.isEmpty) return widget.customers;
    return widget.customers
        .where((c) =>
            c.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
            c.phone.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.people_outline,
                      color: Color(0xFF3B82F6), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Customer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Choose a customer or generate for all',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: searchController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                hintStyle:
                    TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: Icon(Icons.search,
                    size: 20, color: Colors.grey.shade400),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InkWell(
              onTap: widget.onSelectAll,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: widget.selectedCustomer == null
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF8B5CF6),
                            Color(0xFF6366F1)
                          ],
                        )
                      : null,
                  color: widget.selectedCustomer == null
                      ? null
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.selectedCustomer == null
                        ? Colors.transparent
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: widget.selectedCustomer == null
                            ? Colors.white.withOpacity(0.2)
                            : const Color(0xFF8B5CF6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.groups,
                        color: widget.selectedCustomer == null
                            ? Colors.white
                            : const Color(0xFF8B5CF6),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All Customers',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: widget.selectedCustomer == null
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'Generate combined ledger for ${widget.customers.length} customers',
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.selectedCustomer == null
                                  ? Colors.white70
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.selectedCustomer == null)
                      const Icon(Icons.check_circle,
                          color: Colors.white, size: 22),
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR SELECT A CUSTOMER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),
          ),
          Expanded(
            child: filteredCustomers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          'No customers found',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = filteredCustomers[index];
                      final isSelected =
                          widget.selectedCustomer?.id == customer.id;
                      final hasBalance = customer.openingBalance > 0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () =>
                              widget.onSelectCustomer(customer),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF3B82F6)
                                      .withOpacity(0.05)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF3B82F6)
                                    : const Color(0xFFE2E8F0),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF3B82F6)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      customer.name.isNotEmpty
                                          ? customer.name[0]
                                              .toUpperCase()
                                          : 'C',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customer.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? const Color(0xFF3B82F6)
                                              : const Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        customer.phone,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                ),
                                if (hasBalance)
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444)
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      widget.currencyFormat.format(
                                          customer.openingBalance),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFEF4444),
                                      ),
                                    ),
                                  ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.check_circle,
                                      color: Color(0xFF3B82F6), size: 22),
                                ],
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
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ENUMS & HELPER CLASSES
// ═══════════════════════════════════════════════════════════════════════════════

enum ScreenType { mobile, tablet, desktop }

class CustomerLedgerSummary {
  final Customer customer;
  final double openingBalance;
  final double totalDebit;
  final double totalCredit;
  final double closingBalance;
  final int transactionCount;

  CustomerLedgerSummary({
    required this.customer,
    required this.openingBalance,
    required this.totalDebit,
    required this.totalCredit,
    required this.closingBalance,
    required this.transactionCount,
  });
}