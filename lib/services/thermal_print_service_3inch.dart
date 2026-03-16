import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';

/// ============================================================
/// MODEL: One line item on the receipt
/// ============================================================
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

/// ============================================================
/// SERVICE: 3-inch (58mm) Thermal Printer
/// Paper width  : 58 mm
/// Char columns : 32 (normal font)
/// ============================================================
class ThermalPrintService3Inch {
  // ── Paper constants ───────────────────────────────────────
  static const int _cols = 32;

  // ── Currency formatters ───────────────────────────────────
  static final _fmt    = NumberFormat('#,##0.00');
  static final _fmtInt = NumberFormat('#,##0');

  // ── DEBUG FLAG ────────────────────────────────────────────
  static bool enableDebugLogging = true;

  static void _log(String message) {
    if (enableDebugLogging) {
      print('[ThermalPrint] $message');
    }
  }

  // ─────────────────────────────────────────────────────────
  /// Generate ESC/POS bytes for a 3-inch thermal slip.
  // ─────────────────────────────────────────────────────────
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
    try {
      _log('Starting receipt generation...');
      _log('Shop: $shopName');
      _log('Invoice: $invoiceNumber');
      _log('Items count: ${items.length}');

      final profile   = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      // ── INIT ──────────────────────────────────────────────
      bytes += generator.reset();

      // ── SHOP HEADER ───────────────────────────────────────
      bytes += generator.text(
        shopName,
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );

      if (shopAddress.isNotEmpty) {
        bytes += generator.text(
          shopAddress,
          styles: const PosStyles(align: PosAlign.center),
        );
      }

      if (shopPhone.isNotEmpty) {
        bytes += generator.text(
          'Tel: $shopPhone',
          styles: const PosStyles(align: PosAlign.center),
        );
      }

      bytes += generator.hr(ch: '-', len: _cols);

      // ── INVOICE META ──────────────────────────────────────
      bytes += generator.row([
        PosColumn(
          text: 'Invoice#',
          width: 7,
          styles: const PosStyles(),
        ),
        PosColumn(
          text: _truncate(invoiceNumber, 12),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.row([
        PosColumn(
          text: 'Customer',
          width: 5,
          styles: const PosStyles(),
        ),
        PosColumn(
          text: _truncate(customerName, 18),
          width: 7,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.row([
        PosColumn(
          text: 'Date',
          width: 5,
          styles: const PosStyles(),
        ),
        PosColumn(
          text: date,
          width: 7,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.hr(ch: '-', len: _cols);

      // ── COLUMN HEADER ─────────────────────────────────────
      bytes += generator.text(
        '${_padL('Q',  3)}'
        '${_padL('PRODUCT', 11)}'
        '${_padR('TP',  5)}'
        '${_padR('RP',  5)}'
        '${_padR('DIS', 4)}'
        '${_padR('TOT', 4)}',
        styles: const PosStyles(bold: true),
      );

      bytes += generator.hr(ch: '-', len: _cols);

      // ── ITEMS ─────────────────────────────────────────────
      for (final item in items) {
        final nameLines = _wrapText(item.productName, 11);

        // First line — all columns
        bytes += generator.text(
          '${_padL('${item.qty}',           3)}'
          '${_padL(nameLines[0],           11)}'
          '${_padR('${item.tradePrice.toInt()}',  5)}'
          '${_padR('${item.retailPrice.toInt()}', 5)}'
          '${_padR('${item.discountPercent.toInt()}%', 4)}'
          '${_padR(_fmtInt.format(item.lineTotal), 4)}',
        );

        // Overflow product-name lines
        for (int i = 1; i < nameLines.length; i++) {
          bytes += generator.text(
            '   ${_padL(nameLines[i], 11)}',
          );
        }
      }

      bytes += generator.hr(ch: '-', len: _cols);

      // ── TOTALS ────────────────────────────────────────────
      bytes += _totalRow(generator, 'Subtotal', _fmt.format(subtotal));

      if (totalDiscount > 0) {
        bytes += _totalRow(generator, 'Discount', '-${_fmt.format(totalDiscount)}');
      }
      if (tax > 0) {
        bytes += _totalRow(generator, 'Tax', '+${_fmt.format(tax)}');
      }

      bytes += generator.hr(ch: '=', len: _cols);

      bytes += _totalRow(generator, 'SALE TOTAL', _fmt.format(saleAmount), bold: true);

      bytes += generator.hr(ch: '-', len: _cols);

      if (previousBalance > 0) {
        bytes += _totalRow(generator, 'Prev Bal.', _fmt.format(previousBalance));
        bytes += _totalRow(generator, 'Total Due', _fmt.format(totalDue), bold: true);
        bytes += generator.hr(ch: '-', len: _cols);
      }

      bytes += _totalRow(
        generator,
        'Paid ($paymentMethod)',
        _fmt.format(amountPaid),
        bold: true,
      );

      bytes += generator.hr(ch: '=', len: _cols);

      if (remainingBalance > 0) {
        bytes += _totalRow(
          generator,
          'BALANCE DUE',
          _fmt.format(remainingBalance),
          bold: true,
          invert: true,
        );
      } else if (remainingBalance < 0) {
        bytes += _totalRow(
          generator,
          'Change',
          _fmt.format(remainingBalance.abs()),
          bold: true,
        );
      } else {
        bytes += generator.text(
          '*** FULLY PAID ***',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        );
      }

      bytes += generator.hr(ch: '=', len: _cols);

      // ── ITEMS COUNT ───────────────────────────────────────
      final totalQty = items.fold<int>(0, (s, i) => s + i.qty);
      bytes += generator.text(
        'Items: ${items.length}  |  Qty: $totalQty',
        styles: const PosStyles(align: PosAlign.center),
      );

      bytes += generator.emptyLines(1);

      // ── TAGLINE / FOOTER ──────────────────────────────────
      if (shopTagline != null && shopTagline.isNotEmpty) {
        bytes += generator.text(
          shopTagline,
          styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB),
        );
      }

      bytes += generator.text(
        'Thank you for your purchase!',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );

      bytes += generator.feed(4);
      bytes += generator.cut();

      _log('Receipt generation complete! Total bytes: ${bytes.length}');

      return Uint8List.fromList(bytes);

    } catch (e, stackTrace) {
      _log('ERROR during receipt generation: $e');
      _log('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // ── Private helpers ───────────────────────────────────────

  static String _padL(String s, int width) {
    if (s.length >= width) return s.substring(0, width);
    return s.padRight(width);
  }

  static String _padR(String s, int width) {
    if (s.length >= width) return s.substring(0, width);
    return s.padLeft(width);
  }

  static List<int> _totalRow(
    Generator gen,
    String label,
    String value, {
    bool bold   = false,
    bool invert = false,
  }) {
    final safeLabel = _truncate(label, 17);
    final safeValue = _truncate(value, 13);

    return gen.row([
      PosColumn(
        text: safeLabel,
        width: 7,
        styles: PosStyles(bold: bold, reverse: invert),
      ),
      PosColumn(
        text: safeValue,
        width: 5,
        styles: PosStyles(bold: bold, align: PosAlign.right, reverse: invert),
      ),
    ]);
  }

  static List<String> _wrapText(String text, int maxWidth) {
    if (text.length <= maxWidth) return [text];
    final lines  = <String>[];
    final words  = text.split(' ');
    var   current = '';
    for (final word in words) {
      final candidate = current.isEmpty ? word : '$current $word';
      if (candidate.length <= maxWidth) {
        current = candidate;
      } else {
        if (current.isNotEmpty) lines.add(current);
        current = word.length > maxWidth ? word.substring(0, maxWidth) : word;
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines.isEmpty ? [''] : lines;
  }

  static String _truncate(String s, int max) =>
      s.length > max ? '${s.substring(0, max - 1)}…' : s;
}