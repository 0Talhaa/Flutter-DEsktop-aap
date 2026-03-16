
import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// ============================================================
/// MODEL: One line item on the receipt
/// ============================================================
class ReceiptItem6 {
  final int qty;
  final String productName;
  final double tradePrice;
  final double retailPrice;
  final double discountPercent; // e.g. 2.0 for 2%
  final double lineTotal;

  const ReceiptItem6({
    required this.qty,
    required this.productName,
    required this.tradePrice,
    required this.retailPrice,
    required this.discountPercent,
    required this.lineTotal,
  });
}

/// ============================================================
/// SERVICE: 6-inch (~152mm) Thermal Printer
/// Paper width  : ~152 mm
/// Char columns : 64 (normal font)
///
/// Column layout (total 64 chars):
///   QTY(4) | PRODUCT NAME(22) | TP(8) | RP(8) | DIS(6) | TOT(9) | pad(7)
/// ============================================================
class ThermalPrintService6Inch {
  // ── Paper constants ───────────────────────────────────────
  static const int _cols = 64;

  // Column widths (in chars) for the items table
  static const int _wQty   = 4;
  static const int _wName  = 22;
  static const int _wTp    = 8;
  static const int _wRp    = 8;
  static const int _wDis   = 6;
  static const int _wTot   = 9;
  // _wQty + _wName + _wTp + _wRp + _wDis + _wTot = 57  (leaves 7 for padding/gaps)

  // ── Currency formatter ────────────────────────────────────
  static final _fmt    = NumberFormat('#,##0.00');
  static final _fmtInt = NumberFormat('#,##0');

  // ─────────────────────────────────────────────────────────
  /// Generate ESC/POS bytes for a 6-inch thermal slip.
  ///
  /// Returns [Uint8List] ready to send to your printer plugin.
  // ─────────────────────────────────────────────────────────
  static Future<Uint8List> buildReceipt({
    // Shop / company info
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    String? shopTagline,
    String? logoAssetPath,

    // Invoice info
    required String invoiceNumber,
    required String date,
    required String customerName,

    // Items
    required List<ReceiptItem6> items,

    // Totals
    required double subtotal,
    required double totalDiscount,
    required double tax,
    required double saleAmount,
    required double previousBalance,
    required double totalDue,
    required double amountPaid,
    required double remainingBalance,

    // Payment
    String paymentMethod = 'Cash',
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile); // closest to 6-inch
    List<int> bytes = [];

    // ── INIT ──────────────────────────────────────────────
    bytes += generator.reset();

    // ── LOGO (optional) ───────────────────────────────────
    if (logoAssetPath != null) {
      try {
        final ByteData data = await rootBundle.load(logoAssetPath);
        // Implement with esc_pos_utils image helper if needed
      } catch (_) {
        // Logo not found — skip
      }
    }

    // ── SHOP HEADER ───────────────────────────────────────
    bytes += generator.text(
      shopName.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2, // double-width for shop name
        fontType: PosFontType.fontA,
      ),
    );

    bytes += generator.text(
      shopAddress,
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.text(
      'Tel: $shopPhone',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.hr(ch: '=');

    // ── INVOICE META (two-column layout) ──────────────────
    // On 64-col we can do a nice 2-column meta block
    bytes += generator.row([
      PosColumn(
        text: 'INVOICE #',
        width: 4,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: invoiceNumber,
        width: 4,
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        text: 'DATE',
        width: 2,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
      PosColumn(
        text: date,
        width: 2,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += generator.row([
      PosColumn(
        text: 'CUSTOMER',
        width: 3,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: _truncate(customerName, 45),
        width: 9,
        styles: const PosStyles(align: PosAlign.left),
      ),
    ]);

    bytes += generator.hr(ch: '-');

    // ── COLUMN HEADER ─────────────────────────────────────
    // QTY | PRODUCT NAME          |    TP  |    RP  |  DIS |    TOTAL
    bytes += generator.text(
      _buildHeaderLine(),
      styles: const PosStyles(bold: true, fontType: PosFontType.fontA),
    );

    bytes += generator.hr(ch: '-');

    // ── ITEMS ─────────────────────────────────────────────
    for (final item in items) {
      bytes += generator.text(
        _buildItemLine(item),
        styles: const PosStyles(fontType: PosFontType.fontA),
      );

      // If product name is too long, wrap it
      if (item.productName.length > _wName) {
        final overflow = item.productName.substring(_wName);
        bytes += generator.text(
          '${' ' * (_wQty + 1)}${_truncate(overflow, _wName)}',
          styles: const PosStyles(fontType: PosFontType.fontB),
        );
      }
    }

    bytes += generator.hr(ch: '=');

    // ── TOTALS SECTION ────────────────────────────────────
    // Right-align totals using 2-col row layout
    bytes += _row2(generator, 'Subtotal:', _fmt.format(subtotal));

    if (totalDiscount > 0) {
      bytes += _row2(generator, 'Total Discount:', '-${_fmt.format(totalDiscount)}');
    }

    if (tax > 0) {
      bytes += _row2(generator, 'Tax:', '+${_fmt.format(tax)}');
    }

    bytes += generator.hr(ch: '-');

    bytes += _row2Bold(generator, 'SALE AMOUNT:', _fmt.format(saleAmount));

    bytes += generator.hr(ch: '-');

    if (previousBalance > 0) {
      bytes += _row2(generator, 'Previous Balance:', _fmt.format(previousBalance));
      bytes += _row2Bold(generator, 'TOTAL DUE:', _fmt.format(totalDue));
      bytes += generator.hr(ch: '-');
    }

    bytes += _row2Bold(
      generator,
      'Amount Paid ($paymentMethod):',
      _fmt.format(amountPaid),
    );

    bytes += generator.hr(ch: '=');

    if (remainingBalance > 0) {
      // Customer still owes
      bytes += _row2Invert(
        generator,
        'BALANCE DUE:',
        _fmt.format(remainingBalance),
      );
    } else if (remainingBalance < 0) {
      // Overpaid — give change
      bytes += _row2Bold(
        generator,
        'CHANGE:',
        _fmt.format(remainingBalance.abs()),
      );
    } else {
      bytes += generator.text(
        '*** FULLY PAID — THANK YOU ***',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
    }

    bytes += generator.hr(ch: '-');

    // ── SUMMARY ───────────────────────────────────────────
    final totalQty = items.fold<int>(0, (s, i) => s + i.qty);
    bytes += generator.text(
      _padRight('Total Items: ${items.length}', 32) +
          _padLeft('Total Qty: $totalQty', 32),
      styles: const PosStyles(fontType: PosFontType.fontA),
    );

    bytes += generator.hr(ch: '=');

    // ── TAGLINE / FOOTER ──────────────────────────────────
    if (shopTagline != null && shopTagline.isNotEmpty) {
      bytes += generator.text(
        shopTagline,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: false,
          fontType: PosFontType.fontB,
        ),
      );
    }

    bytes += generator.text(
      'Thank you for shopping with us!',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    bytes += generator.text(
      DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
      styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB),
    );

    // ── FEED & CUT ────────────────────────────────────────
    bytes += generator.feed(4);
    bytes += generator.cut();

    return Uint8List.fromList(bytes);
  }

  // ── Layout Helpers ────────────────────────────────────────

  /// Build the column header line
  ///  QTY | PRODUCT NAME          |      TP |      RP |  DIS% |     TOTAL
  static String _buildHeaderLine() {
    return _col('QTY', _wQty, right: false) +
        ' ' +
        _col('PRODUCT NAME', _wName, right: false) +
        ' ' +
        _col('TP', _wTp) +
        ' ' +
        _col('RP', _wRp) +
        ' ' +
        _col('DIS%', _wDis) +
        ' ' +
        _col('TOTAL', _wTot);
  }

  /// Build one item data line
  static String _buildItemLine(ReceiptItem6 item) {
    return _col(item.qty.toString(), _wQty, right: false) +
        ' ' +
        _col(_truncate(item.productName, _wName), _wName, right: false) +
        ' ' +
        _col(_fmtInt.format(item.tradePrice), _wTp) +
        ' ' +
        _col(_fmtInt.format(item.retailPrice), _wRp) +
        ' ' +
        _col('${item.discountPercent.toStringAsFixed(0)}%', _wDis) +
        ' ' +
        _col(_fmtInt.format(item.lineTotal), _wTot);
  }

  /// 2-column row (label left, value right) — normal
  static List<int> _row2(Generator gen, String label, String value) {
    return gen.row([
      PosColumn(
        text: label,
        width: 8,
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        text: value,
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
  }

  /// 2-column row — bold
  static List<int> _row2Bold(Generator gen, String label, String value) {
    return gen.row([
      PosColumn(
        text: label,
        width: 8,
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        text: value,
        width: 4,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
  }

  /// 2-column row — inverted (white on black) for balance due
  static List<int> _row2Invert(Generator gen, String label, String value) {
    return gen.row([
      PosColumn(
        text: label,
        width: 8,
        styles: const PosStyles(
          align: PosAlign.left,
          bold: true,
          reverse: true,
        ),
      ),
      PosColumn(
        text: value,
        width: 4,
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          reverse: true,
        ),
      ),
    ]);
  }

  /// Fixed-width column — right-aligned by default
  static String _col(String s, int width, {bool right = true}) {
    if (s.length > width) s = s.substring(0, width);
    return right ? s.padLeft(width) : s.padRight(width);
  }

  static String _padRight(String s, int width) =>
      s.length >= width ? s.substring(0, width) : s.padRight(width);

  static String _padLeft(String s, int width) =>
      s.length >= width ? s.substring(0, width) : s.padLeft(width);

  static String _truncate(String s, int max) =>
      s.length > max ? '${s.substring(0, max - 1)}…' : s;
}