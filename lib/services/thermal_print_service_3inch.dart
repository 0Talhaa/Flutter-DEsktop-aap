import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';

class ReceiptItem {
  final int qty;
  final String productName;
  final double tradePrice;
  final double retailPrice;
  final double discountPercent;
  final double lineTotal;

  const ReceiptItem({
    required this.qty,
    required this.productName,
    required this.tradePrice,
    required this.retailPrice,
    required this.discountPercent,
    required this.lineTotal,
  });
}

class ThermalPrintService80mm {
  static final _fmt = NumberFormat('#,##0.00');
  static final _fmtInt = NumberFormat('#,##0');

  // 80mm thermal printer = 48 chars per line at normal font size
  static const int _W = 48;

  static Future<Uint8List> buildReceipt({
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    String? shopTagline,
    required String invoiceNumber,
    required String date,
    required String customerName,
    required List<ReceiptItem> items,
    required double subtotal,
    required double totalDiscount,
    required double tax,
    required double saleAmount,
    required double previousBalance,
    required double totalDue,
    required double amountPaid,
    required double remainingBalance,
    String paymentMethod = 'Cash',
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile); // ← mm80
    List<int> bytes = [];

    bytes += generator.reset();

    // ══════════════════════════════════════════════════
    //  HEADER
    // ══════════════════════════════════════════════════
    bytes += generator.text(
      shopName.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    bytes += generator.feed(1);

    bytes += generator.text(
      shopAddress,
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.text(
      'Tel: $shopPhone',
      styles: const PosStyles(align: PosAlign.center),
    );

    if (shopTagline != null && shopTagline.isNotEmpty) {
      bytes += generator.text(
        shopTagline,
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    bytes += generator.text(_line('='));

    // ══════════════════════════════════════════════════
    //  INVOICE INFO
    // ══════════════════════════════════════════════════
    bytes += generator.text(_labelValue('Invoice#:', invoiceNumber));
    bytes += generator.text(_labelValue('Date:', date));
    bytes += generator.text(_labelValue('Customer:', customerName));
    bytes += generator.text(_labelValue('Payment:', paymentMethod));

    bytes += generator.text(_line('='));

    // ══════════════════════════════════════════════════
    //  TABLE HEADER
    //
    //  Column layout (total = 48):
    //  QTY(4) | PRODUCT(20) | PRICE(8) | DISC(6) | TOTAL(10)
    //   4     +     20      +    8     +    6    +    10   = 48
    // ══════════════════════════════════════════════════
    bytes += generator.text(
      _tableHeader(),
      styles: const PosStyles(bold: true),
    );
    bytes += generator.text(_line('-'));

    // ══════════════════════════════════════════════════
    //  TABLE ROWS
    // ══════════════════════════════════════════════════
    for (final item in items) {
      final lines = _tableRow(item);
      for (final line in lines) {
        bytes += generator.text(line);
      }
    }

    bytes += generator.text(_line('='));

    // ══════════════════════════════════════════════════
    //  TOTALS SECTION
    // ══════════════════════════════════════════════════
    bytes += generator.text(
      _labelValue('Subtotal:', _fmt.format(subtotal)),
    );

    if (totalDiscount > 0) {
      bytes += generator.text(
        _labelValue('Discount:', '-${_fmt.format(totalDiscount)}'),
      );
    }

    if (tax > 0) {
      bytes += generator.text(
        _labelValue('Tax (${tax.toStringAsFixed(0)}%):', '+${_fmt.format(tax)}'),
      );
    }

    bytes += generator.text(_line('='));

    bytes += generator.text(
      _labelValue('SALE TOTAL:', _fmt.format(saleAmount)),
      styles: const PosStyles(bold: true),
    );

    bytes += generator.text(_line('='));

    // ══════════════════════════════════════════════════
    //  PREVIOUS BALANCE
    // ══════════════════════════════════════════════════
    if (previousBalance > 0) {
      bytes += generator.text(
        _labelValue('Previous Balance:', _fmt.format(previousBalance)),
      );
      bytes += generator.text(
        _labelValue('Total Due:', _fmt.format(totalDue)),
        styles: const PosStyles(bold: true),
      );
      bytes += generator.text(_line('-'));
    }

    // ══════════════════════════════════════════════════
    //  PAYMENT
    // ══════════════════════════════════════════════════
    bytes += generator.text(
      _labelValue('Amount Paid ($paymentMethod):', _fmt.format(amountPaid)),
    );

    bytes += generator.text(_line('='));

    // ══════════════════════════════════════════════════
    //  BALANCE STATUS
    // ══════════════════════════════════════════════════
    if (remainingBalance > 0) {
      bytes += generator.text(
        _center('*** BALANCE DUE: ${_fmt.format(remainingBalance)} ***'),
        styles: const PosStyles(bold: true, reverse: true),
      );
    } else if (remainingBalance < 0) {
      bytes += generator.text(
        _labelValue('Change:', _fmt.format(remainingBalance.abs())),
        styles: const PosStyles(bold: true),
      );
    } else {
      bytes += generator.text(
        _center('*** FULLY PAID ***'),
        styles: const PosStyles(bold: true, reverse: true),
      );
    }

    bytes += generator.text(_line('='));

    // ══════════════════════════════════════════════════
    //  FOOTER
    // ══════════════════════════════════════════════════
    final totalQty = items.fold<int>(0, (s, i) => s + i.qty);

    bytes += generator.text(
      _center('Total Items: ${items.length}   Total Qty: $totalQty'),
    );

    bytes += generator.text(_line('-'));

    bytes += generator.text(
      _center('Thank you for your purchase!'),
      styles: const PosStyles(bold: true),
    );

    bytes += generator.text(
      _center('Please visit us again!'),
    );

    bytes += generator.feed(4);
    bytes += generator.cut();

    return Uint8List.fromList(bytes);
  }

  // ────────────────────────────────────────────────────────────
  //  HELPERS — every method produces exactly _W (48) characters
  // ────────────────────────────────────────────────────────────

  /// Full separator line
  /// "================================================"
  static String _line([String ch = '-']) => ch * _W;

  /// Center a string within 48 chars
  static String _center(String text) {
    if (text.length >= _W) return text.substring(0, _W);
    final pad = (_W - text.length) ~/ 2;
    return text.padLeft(text.length + pad).padRight(_W);
  }

  /// Left label + right value = exactly 48 chars
  /// "Customer:                            John Doe"
  static String _labelValue(String label, String value) {
    if (label.length + value.length >= _W) {
      final maxLabel = _W - value.length - 1;
      label = label.substring(0, maxLabel.clamp(0, label.length));
    }
    final spaces = _W - label.length - value.length;
    return '$label${' ' * spaces}$value';
  }

  /// Table header — must match _tableRow() column widths exactly
  ///
  ///  QTY(4) PRODUCT(20) PRICE(8) DISC(6) TOTAL(10) = 48
  static String _tableHeader() {
    const int qtyW = 4;
    const int prodW = 20;
    const int priceW = 8;
    const int discW = 6;
    const int totalW = 10;
    // 4 + 20 + 8 + 6 + 10 = 48 ✓

    final qty = 'QTY'.padRight(qtyW);
    final product = 'PRODUCT'.padRight(prodW);
    final price = 'PRICE'.padLeft(priceW);
    final disc = 'DISC'.padLeft(discW);
    final total = 'TOTAL'.padLeft(totalW);

    return '$qty$product$price$disc$total';
  }

  /// Table row — wraps product name if longer than prodW
  ///
  ///  QTY(4) PRODUCT(20) PRICE(8) DISC(6) TOTAL(10) = 48
  static List<String> _tableRow(ReceiptItem item) {
    const int qtyW = 4;
    const int prodW = 20;
    const int priceW = 8;
    const int discW = 6;
    const int totalW = 10;

    final String qtyStr = item.qty.toString().padRight(qtyW);
    final String priceStr = _fmtInt.format(item.retailPrice).padLeft(priceW);
    final String discStr = item.discountPercent > 0
        ? '${item.discountPercent.toStringAsFixed(0)}%'.padLeft(discW)
        : '-'.padLeft(discW);
    final String totalStr = _fmtInt.format(item.lineTotal).padLeft(totalW);

    final List<String> rows = [];
    final String fullName = item.productName;

    // First line with price, disc, total
    final String firstName = fullName.length > prodW
        ? fullName.substring(0, prodW)
        : fullName.padRight(prodW);

    rows.add('$qtyStr$firstName$priceStr$discStr$totalStr');

    // Overflow lines for long product names
    if (fullName.length > prodW) {
      String remaining = fullName.substring(prodW);
      while (remaining.isNotEmpty) {
        final chunk = remaining.length > prodW
            ? remaining.substring(0, prodW)
            : remaining.padRight(prodW);
        rows.add(' ' * qtyW + chunk);
        remaining = remaining.length > prodW
            ? remaining.substring(prodW)
            : '';
      }
    }

    return rows;
  }
}