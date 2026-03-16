// lib/services/dot_matrix_print_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DotMatrixPrintService {
  // ESC/P Commands for Epson LQ-300+
  static const String ESC = '\x1B';
  static const String LF = '\x0A';
  static const String CR = '\x0D';
  static const String FF = '\x0C';  // Form Feed (page break)
  
  // Initialize printer
  static String get initialize => '$ESC@';
  
  // Text formatting
  static String get boldOn => '${ESC}E';
  static String get boldOff => '${ESC}F';
  static String get underlineOn => '${ESC}-\x01';
  static String get underlineOff => '${ESC}-\x00';
  static String get italicOn => '${ESC}4';
  static String get italicOff => '${ESC}5';
  
  // Double width/height
  static String get doubleWidthOn => '${ESC}W\x01';
  static String get doubleWidthOff => '${ESC}W\x00';
  static String get doubleHeightOn => '${ESC}w\x01';
  static String get doubleHeightOff => '${ESC}w\x00';
  
  // Font pitch (characters per inch)
  static String get pica => '${ESC}P';         // 10 CPI
  static String get elite => '${ESC}M';        // 12 CPI
  static String get condensed => '\x0F';       // 17 CPI
  static String get condensedOff => '\x12';
  
  // Line spacing
  static String get lineSpacing1_8 => '${ESC}0';     // 1/8 inch
  static String get lineSpacing1_6 => '${ESC}2';     // 1/6 inch (default)
  static String lineSpacingN(int n) => '${ESC}3${String.fromCharCode(n)}'; // n/180 inch
  
  // Text alignment (may not work on all models)
  static String get alignLeft => '${ESC}a\x00';
  static String get alignCenter => '${ESC}a\x01';
  static String get alignRight => '${ESC}a\x02';

  // Paper width for LQ-300+ (80 columns in 10 CPI)
  static const int paperWidth = 80;
  static const int paperWidthCondensed = 137; // In condensed mode
  
  /// Print invoice to Epson LQ-300+
  static Future<bool> printInvoice({
    required String invoiceNumber,
    required String date,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double tax,
    required double total,
    required double amountPaid,
    required double balance,
    String? printerName,
    String shopName = 'MEDICAL STORE',
    String shopAddress = '123 Main Street, City',
    String shopPhone = '0300-1234567',
  }) async {
    try {
      final content = _buildInvoiceContent(
        invoiceNumber: invoiceNumber,
        date: date,
        customerName: customerName,
        items: items,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        total: total,
        amountPaid: amountPaid,
        balance: balance,
        shopName: shopName,
        shopAddress: shopAddress,
        shopPhone: shopPhone,
      );
      
      return await _sendToPrinter(content, printerName: printerName);
    } catch (e) {
      debugPrint('Print Error: $e');
      return false;
    }
  }

  /// Build invoice content with ESC/P commands
  static String _buildInvoiceContent({
    required String invoiceNumber,
    required String date,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double tax,
    required double total,
    required double amountPaid,
    required double balance,
    required String shopName,
    required String shopAddress,
    required String shopPhone,
  }) {
    final buffer = StringBuffer();
    final currencyFormat = NumberFormat('#,###', 'en_PK');
    
    // Initialize printer
    buffer.write(initialize);
    buffer.write(lineSpacing1_6);
    buffer.write(pica); // 10 CPI - 80 chars per line
    
    // ═══════════════════════════════════════════
    // HEADER
    // ═══════════════════════════════════════════
    buffer.write(doubleWidthOn);
    buffer.write(boldOn);
    buffer.writeln(_centerText(shopName, paperWidth ~/ 2));
    buffer.write(doubleWidthOff);
    buffer.write(boldOff);
    
    buffer.writeln(_centerText(shopAddress, paperWidth));
    buffer.writeln(_centerText('Phone: $shopPhone', paperWidth));
    buffer.writeln(_repeatChar('=', paperWidth));
    
    // ═══════════════════════════════════════════
    // INVOICE INFO
    // ═══════════════════════════════════════════
    buffer.write(boldOn);
    buffer.writeln(_centerText('SALES INVOICE', paperWidth));
    buffer.write(boldOff);
    buffer.writeln(_repeatChar('-', paperWidth));
    
    buffer.writeln(_twoColumnText('Invoice No:', 'INV-$invoiceNumber', paperWidth));
    buffer.writeln(_twoColumnText('Date:', date, paperWidth));
    buffer.writeln(_twoColumnText('Customer:', customerName, paperWidth));
    buffer.writeln(_repeatChar('=', paperWidth));
    
    // ═══════════════════════════════════════════
    // ITEMS TABLE HEADER
    // ═══════════════════════════════════════════
    buffer.write(condensed); // Switch to condensed for more columns
    buffer.write(boldOn);
    buffer.writeln(_formatTableHeader());
    buffer.write(boldOff);
    buffer.writeln(_repeatChar('-', paperWidthCondensed));
    
    // ═══════════════════════════════════════════
    // ITEMS
    // ═══════════════════════════════════════════
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      buffer.writeln(_formatTableRow(
        sno: (i + 1).toString(),
        name: item['productName'] ?? '',
        qty: (item['quantity'] ?? 0).toString(),
        price: currencyFormat.format(item['price'] ?? 0),
        amount: currencyFormat.format(item['lineTotal'] ?? 0),
      ));
    }
    
    buffer.write(condensedOff); // Back to normal
    buffer.write(pica);
    buffer.writeln(_repeatChar('=', paperWidth));
    
    // ═══════════════════════════════════════════
    // TOTALS
    // ═══════════════════════════════════════════
    buffer.writeln(_twoColumnText('Subtotal:', 'Rs ${currencyFormat.format(subtotal)}', paperWidth));
    
    if (discount > 0) {
      buffer.writeln(_twoColumnText('Discount:', 'Rs ${currencyFormat.format(discount)}', paperWidth));
    }
    
    if (tax > 0) {
      buffer.writeln(_twoColumnText('Tax:', 'Rs ${currencyFormat.format(tax)}', paperWidth));
    }
    
    buffer.writeln(_repeatChar('-', paperWidth));
    
    buffer.write(boldOn);
    buffer.write(doubleWidthOn);
    buffer.writeln(_twoColumnText('TOTAL:', 'Rs ${currencyFormat.format(total)}', paperWidth ~/ 2));
    buffer.write(doubleWidthOff);
    buffer.write(boldOff);
    
    buffer.writeln(_repeatChar('-', paperWidth));
    buffer.writeln(_twoColumnText('Amount Paid:', 'Rs ${currencyFormat.format(amountPaid)}', paperWidth));
    
    if (balance > 0) {
      buffer.write(boldOn);
      buffer.writeln(_twoColumnText('Balance Due:', 'Rs ${currencyFormat.format(balance)}', paperWidth));
      buffer.write(boldOff);
    } else if (balance < 0) {
      buffer.writeln(_twoColumnText('Change:', 'Rs ${currencyFormat.format(balance.abs())}', paperWidth));
    }
    
    buffer.writeln(_repeatChar('=', paperWidth));
    
    // ═══════════════════════════════════════════
    // FOOTER
    // ═══════════════════════════════════════════
    buffer.writeln();
    buffer.writeln(_centerText('Thank you for your purchase!', paperWidth));
    buffer.writeln(_centerText('Please come again', paperWidth));
    buffer.writeln();
    buffer.writeln(_centerText('*** SOFTWARE BY YOUR COMPANY ***', paperWidth));
    buffer.writeln();
    
    // Form feed to eject paper
    buffer.write(FF);
    
    return buffer.toString();
  }

  /// Format table header for items
  static String _formatTableHeader() {
    // S# | Product Name | Qty | Price | Amount
    // 3  | 70          | 6   | 12    | 12
    return '${_padRight('S#', 3)}|${_padRight('Product Name', 70)}|${_padRight('Qty', 6)}|${_padRight('Price', 12)}|${_padRight('Amount', 12)}';
  }

  /// Format table row for items
  static String _formatTableRow({
    required String sno,
    required String name,
    required String qty,
    required String price,
    required String amount,
  }) {
    // Truncate name if too long
    String truncatedName = name.length > 68 ? '${name.substring(0, 65)}...' : name;
    
    return '${_padRight(sno, 3)}|${_padRight(truncatedName, 70)}|${_padLeft(qty, 6)}|${_padLeft(price, 12)}|${_padLeft(amount, 12)}';
  }

  /// Center text within given width
  static String _centerText(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    int padding = (width - text.length) ~/ 2;
    return '${' ' * padding}$text';
  }

  /// Two column text (left and right aligned)
  static String _twoColumnText(String left, String right, int width) {
    int spaces = width - left.length - right.length;
    if (spaces < 1) spaces = 1;
    return '$left${' ' * spaces}$right';
  }

  /// Repeat character n times
  static String _repeatChar(String char, int times) {
    return char * times;
  }

  /// Pad string to right
  static String _padRight(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    return text + (' ' * (width - text.length));
  }

  /// Pad string to left
  static String _padLeft(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    return (' ' * (width - text.length)) + text;
  }

  /// Send content to printer
  static Future<bool> _sendToPrinter(String content, {String? printerName}) async {
    if (Platform.isWindows) {
      return await _printWindows(content, printerName);
    } else if (Platform.isLinux) {
      return await _printLinux(content, printerName);
    } else if (Platform.isMacOS) {
      return await _printMacOS(content, printerName);
    }
    return false;
  }

  /// Print on Windows
  static Future<bool> _printWindows(String content, String? printerName) async {
    try {
      // Create temp file
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}\\invoice_${DateTime.now().millisecondsSinceEpoch}.txt');
      
      // Write content with proper encoding for dot matrix
      await tempFile.writeAsString(content, encoding: latin1);
      
      String printCommand;
      
      if (printerName != null && printerName.isNotEmpty) {
        // Print to specific printer
        printCommand = 'print /D:"$printerName" "${tempFile.path}"';
      } else {
        // Try direct LPT1 access for parallel port
        // Or use default printer
        printCommand = 'copy /b "${tempFile.path}" LPT1';
      }
      
      // Alternative: Use Windows print command
      final result = await Process.run(
        'cmd',
        ['/c', printCommand],
        runInShell: true,
      );
      
      // If LPT1 fails, try with default printer
      if (result.exitCode != 0) {
        final result2 = await Process.run(
          'notepad',
          ['/p', tempFile.path],
          runInShell: true,
        );
        
        // Clean up
        await Future.delayed(const Duration(seconds: 2));
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        
        return result2.exitCode == 0;
      }
      
      // Clean up temp file
      await Future.delayed(const Duration(seconds: 1));
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('Windows Print Error: $e');
      return false;
    }
  }

  /// Print on Windows using raw port access (better for dot matrix)
  static Future<bool> printRawWindows(String content, {String port = 'LPT1'}) async {
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}\\invoice_raw_${DateTime.now().millisecondsSinceEpoch}.prn');
      
      // Write raw ESC/P content
      await tempFile.writeAsBytes(latin1.encode(content));
      
      // Copy to port
      final result = await Process.run(
        'cmd',
        ['/c', 'copy', '/b', tempFile.path, port],
        runInShell: true,
      );
      
      // Clean up
      await Future.delayed(const Duration(milliseconds: 500));
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('Raw Print Error: $e');
      return false;
    }
  }

  /// Print using Windows Spooler (most reliable)
  static Future<bool> printViaSpooler(String content, String printerName) async {
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}\\invoice_${DateTime.now().millisecondsSinceEpoch}.txt');
      
      await tempFile.writeAsString(content, encoding: latin1);
      
      // Use PowerShell for better printer control
      final psCommand = '''
        \$content = Get-Content -Path "${tempFile.path}" -Raw -Encoding Default
        \$content | Out-Printer -Name "$printerName"
      ''';
      
      final result = await Process.run(
        'powershell',
        ['-Command', psCommand],
        runInShell: true,
      );
      
      // Clean up
      await Future.delayed(const Duration(seconds: 1));
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('Spooler Print Error: $e');
      return false;
    }
  }

  /// Print on Linux
  static Future<bool> _printLinux(String content, String? printerName) async {
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/invoice_${DateTime.now().millisecondsSinceEpoch}.txt');
      
      await tempFile.writeAsString(content, encoding: latin1);
      
      List<String> args = [tempFile.path];
      if (printerName != null) {
        args = ['-P', printerName, tempFile.path];
      }
      
      final result = await Process.run('lpr', args);
      
      // Clean up
      await Future.delayed(const Duration(seconds: 1));
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('Linux Print Error: $e');
      return false;
    }
  }

  /// Print on macOS
  static Future<bool> _printMacOS(String content, String? printerName) async {
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/invoice_${DateTime.now().millisecondsSinceEpoch}.txt');
      
      await tempFile.writeAsString(content, encoding: latin1);
      
      List<String> args = [tempFile.path];
      if (printerName != null) {
        args = ['-P', printerName, tempFile.path];
      }
      
      final result = await Process.run('lpr', args);
      
      // Clean up
      await Future.delayed(const Duration(seconds: 1));
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('macOS Print Error: $e');
      return false;
    }
  }

  /// Get list of available printers (Windows)
  static Future<List<String>> getAvailablePrinters() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run(
          'powershell',
          ['-Command', 'Get-Printer | Select-Object -ExpandProperty Name'],
          runInShell: true,
        );
        
        if (result.exitCode == 0) {
          return (result.stdout as String)
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Get Printers Error: $e');
      return [];
    }
  }
}