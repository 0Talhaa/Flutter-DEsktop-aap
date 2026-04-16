// lib/services/printer_service.dart

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_usb_printer/flutter_usb_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class UsbPrinterInfo {
  final String name;
  final int vendorId;
  final int productId;
  final Map<String, dynamic> rawDevice;

  UsbPrinterInfo({
    required this.name,
    required this.vendorId,
    required this.productId,
    required this.rawDevice,
  });

  String get identifier => 'VID:$vendorId PID:$productId';

  @override
  String toString() => '🔌 $name ($identifier)';
}

class PrinterService {
  // ── Singleton ─────────────────────────────────────────
  static final PrinterService _instance = PrinterService._();
  factory PrinterService() => _instance;
  PrinterService._();

  // ── Internal ──────────────────────────────────────────
  final FlutterUsbPrinter _usbPrinter = FlutterUsbPrinter();
  UsbPrinterInfo? _connectedPrinter;
  bool _isConnected = false;

  // ── Getters ───────────────────────────────────────────
  bool get isConnected => _isConnected;
  UsbPrinterInfo? get connectedPrinter => _connectedPrinter;
  String get connectedPrinterName =>
      _connectedPrinter?.name ?? 'No printer connected';

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  DISCOVER USB PRINTERS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<List<UsbPrinterInfo>> discoverPrinters() async {
    try {
      final List<Map<String, dynamic>> devices =
          await FlutterUsbPrinter.getUSBDeviceList();

      debugPrint('[Printer] Found ${devices.length} USB device(s)');

      final List<UsbPrinterInfo> result = [];

      for (final device in devices) {
        final printer = UsbPrinterInfo(
          name: '${device['productName'] ?? 'USB Printer'}',
          vendorId: int.parse('${device['vendorId']}'),
          productId: int.parse('${device['productId']}'),
          rawDevice: device,
        );

        result.add(printer);
        debugPrint('[Printer]   → ${printer.name} (${printer.identifier})');
      }

      return result;
    } catch (e) {
      debugPrint('[Printer] ❌ USB scan error: $e');
      return [];
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  CONNECT
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<bool> connect(UsbPrinterInfo printer) async {
    try {
      // Disconnect existing first
      await disconnect();

      debugPrint('[Printer] Connecting to ${printer.name} '
          '(VID:${printer.vendorId} PID:${printer.productId})…');

      final bool? connected = await _usbPrinter.connect(
        printer.vendorId,
        printer.productId,
      );

      if (connected == true) {
        _isConnected = true;
        _connectedPrinter = printer;
        debugPrint('[Printer] ✅ Connected: ${printer.name}');
        return true;
      }

      debugPrint('[Printer] ❌ Connection returned false');
      return false;
    } catch (e) {
      debugPrint('[Printer] ❌ Connect error: $e');
      _isConnected = false;
      _connectedPrinter = null;
      return false;
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  PRINT BYTES
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<bool> printBytes(Uint8List bytes) async {
    if (!_isConnected || _connectedPrinter == null) {
      debugPrint('[Printer] ❌ No printer connected');
      return false;
    }

    try {
      debugPrint('[Printer] 📡 Sending ${bytes.length} bytes via USB…');
      await _usbPrinter.write(bytes);
      debugPrint('[Printer] ✅ Print complete');
      return true;
    } catch (e) {
      debugPrint('[Printer] ❌ Print error: $e');
      return false;
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  DISCONNECT
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<void> disconnect() async {
    _isConnected = false;
    _connectedPrinter = null;
    debugPrint('[Printer] Disconnected');
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  //  TEST PRINT
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Future<bool> testPrint() async {
    if (!_isConnected) return false;

    try {
      final profile = await CapabilityProfile.load();
      final gen = Generator(PaperSize.mm58, profile);

      List<int> bytes = [];
      bytes += gen.reset();
      bytes += gen.text(
        'PRINTER TEST',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += gen.hr(ch: '-');
      bytes += gen.text(
        'If you can read this,',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += gen.text(
        'your printer is working!',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += gen.hr(ch: '-');
      bytes += gen.text(
        'Printer: ${_connectedPrinter?.name}',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += gen.text(
        'Time: ${DateTime.now()}',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += gen.feed(3);
      bytes += gen.cut();

      return await printBytes(Uint8List.fromList(bytes));
    } catch (e) {
      debugPrint('[Printer] Test print error: $e');
      return false;
    }
  }
}