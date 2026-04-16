import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:medical_app/models/sale_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medical_app/services/thermal_print_service_3inch.dart';
import 'package:medical_app/services/thermal_print_service_6inch.dart';

// ═════════════════════════════════════════════════════════════════
// PRINTER COMMUNICATOR - USB ONLY (Desktop + Android)
// ═════════════════════════════════════════════════════════════════
class PrinterCommunicator {
  static bool debugMode = true;

  static dynamic _usbPrinter;
  static bool _usbConnected = false;
  static Map<String, dynamic>? _connectedUsbDevice;

  static void _log(String msg) {
    if (debugMode) debugPrint('[Printer] $msg');
  }

  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static bool get isAndroid => Platform.isAndroid;

  // ─────────────────────────────────────────────────────────
  // GET AVAILABLE USB PRINTERS
  // ─────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getUsbPrinters() async {
    try {
      if (isDesktop) {
        return await _getDesktopPrinters();
      } else if (isAndroid) {
        return await _getAndroidUsbPrinters();
      }
      return [];
    } catch (e) {
      _log('❌ USB scan error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────
  // DESKTOP: Find system printers
  // ─────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> _getDesktopPrinters() async {
    final printers = <Map<String, dynamic>>[];

    try {
      if (Platform.isWindows) {
        // Primary method: PowerShell Get-Printer
        final psResult = await Process.run(
          'powershell.exe',
          [
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy',
            'Bypass',
            '-Command',
            'Get-Printer | Select-Object Name,PortName,PrinterStatus | ConvertTo-Csv -NoTypeInformation',
          ],
          runInShell: false,
        );

        if (psResult.exitCode == 0) {
          final lines = (psResult.stdout as String)
              .split('\n')
              .where((l) => l.trim().isNotEmpty)
              .toList();

          for (int i = 1; i < lines.length; i++) {
            final line = lines[i].replaceAll('"', '').trim();
            final parts = line.split(',');
            if (parts.isNotEmpty && parts[0].trim().isNotEmpty) {
              printers.add({
                'productName': parts[0].trim(),
                'portName': parts.length > 1 ? parts[1].trim() : 'Unknown',
                'status': parts.length > 2 ? parts[2].trim() : 'Unknown',
                'type': 'desktop',
              });
            }
          }
        }

        // Fallback: wmic
        if (printers.isEmpty) {
          final result = await Process.run(
            'wmic',
            ['printer', 'get', 'Name,PortName,Status', '/format:csv'],
            runInShell: true,
          );

          if (result.exitCode == 0) {
            final lines = (result.stdout as String)
                .split('\n')
                .where((l) => l.trim().isNotEmpty)
                .toList();

            for (int i = 1; i < lines.length; i++) {
              final parts = lines[i].split(',');
              if (parts.length >= 2) {
                final name = parts[1].trim();
                if (name.isNotEmpty) {
                  printers.add({
                    'productName': name,
                    'portName':
                        parts.length > 2 ? parts[2].trim() : 'Unknown',
                    'status':
                        parts.length > 3 ? parts[3].trim() : 'Unknown',
                    'type': 'desktop',
                  });
                }
              }
            }
          }
        }
      } else if (Platform.isLinux || Platform.isMacOS) {
        final result = await Process.run('lpstat', ['-p'], runInShell: true);
        if (result.exitCode == 0) {
          final lines = (result.stdout as String).split('\n');
          for (final line in lines) {
            if (line.contains('printer')) {
              final match = RegExp(r'printer (\S+)').firstMatch(line);
              if (match != null) {
                printers.add({
                  'productName': match.group(1)!,
                  'portName': 'CUPS',
                  'status': line.contains('idle') ? 'Ready' : 'Busy',
                  'type': 'desktop',
                });
              }
            }
          }
        }
      }
    } catch (e) {
      _log('❌ Desktop printer scan error: $e');
    }

    _log('Found ${printers.length} desktop printer(s)');
    for (final p in printers) {
      _log('  → ${p['productName']} (Port: ${p['portName']})');
    }

    return printers;
  }

  // ─────────────────────────────────────────────────────────
  // ANDROID: Find USB OTG printers
  // ─────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> _getAndroidUsbPrinters() async {
    try {
      final devices = await _callAndroidUsbScan();
      _log('Found ${devices.length} Android USB device(s)');
      return devices;
    } catch (e) {
      _log('❌ Android USB scan error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _callAndroidUsbScan() async {
    try {
      final module = await _loadUsbModule();
      if (module != null) {
        final devices = await module.getUSBDeviceList();
        return List<Map<String, dynamic>>.from(devices);
      }
    } catch (e) {
      _log('USB module not available: $e');
    }
    return [];
  }

  static Future<dynamic> _loadUsbModule() async {
    if (!isAndroid) return null;
    return null;
  }

  // ─────────────────────────────────────────────────────────
  // TEST CONNECTION
  // ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> testConnection() async {
    _log('Testing USB printer connection...');

    if (isDesktop) {
      return _testDesktopPrinter();
    } else if (isAndroid) {
      return _testAndroidUsb();
    }

    return {'success': false, 'message': '❌ Unsupported platform'};
  }

  // ─────────────────────────────────────────────────────────
  // PRINT RECEIPT
  // ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> printReceipt({
    required Uint8List bytes,
    String? printerName,
  }) async {
    _log('Attempting to print ${bytes.length} bytes via USB...');

    if (isDesktop) {
      return _printDesktop(bytes, printerName);
    } else if (isAndroid) {
      return _printAndroidUsb(bytes);
    }

    return {'success': false, 'message': '❌ Unsupported platform'};
  }

  // ─────────────────────────────────────────────────────────
  // DESKTOP — TEST
  // ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> _testDesktopPrinter() async {
    try {
      final printers = await _getDesktopPrinters();

      if (printers.isEmpty) {
        return {
          'success': false,
          'message': '❌ No printers found.\n\n'
              'Make sure:\n'
              '• Printer is powered ON\n'
              '• USB cable is connected\n'
              '• Printer driver is installed\n'
              '• Printer appears in system settings',
        };
      }

      final thermalPrinters = printers.where((p) {
        final name = (p['productName'] ?? '').toString().toLowerCase();
        return name.contains('thermal') ||
            name.contains('pos') ||
            name.contains('receipt') ||
            name.contains('58mm') ||
            name.contains('80mm') ||
            name.contains('xp-') ||
            name.contains('rp') ||
            name.contains('epson') ||
            name.contains('star') ||
            name.contains('bixolon') ||
            name.contains('citizen') ||
            name.contains('copper') ||
            name.contains('bc-');
      }).toList();

      final printerList =
          printers.map((p) => '• ${p['productName']}').join('\n');

      if (thermalPrinters.isNotEmpty) {
        return {
          'success': true,
          'message': '✅ Thermal printer found!\n\n'
              'Detected:\n$printerList\n\n'
              'Recommended: ${thermalPrinters.first['productName']}',
          'printers': printers,
          'recommended': thermalPrinters.first['productName'],
        };
      }

      return {
        'success': true,
        'message':
            '✅ Printers found:\n\n$printerList\n\nSelect your thermal printer.',
        'printers': printers,
      };
    } catch (e) {
      return {'success': false, 'message': '❌ Error: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────
  // DESKTOP — PRINT
  // ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> _printDesktop(
    Uint8List bytes,
    String? printerName,
  ) async {
    try {
      if (Platform.isWindows) {
        return _printWindows(bytes, printerName);
      } else if (Platform.isLinux || Platform.isMacOS) {
        return _printUnix(bytes, printerName);
      }
      return {'success': false, 'message': '❌ Unsupported desktop OS'};
    } catch (e) {
      return {'success': false, 'message': '❌ Print error: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────
  // WINDOWS — Main print method
  // ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> _printWindows(
    Uint8List bytes,
    String? printerName,
  ) async {
    try {
      // Find printer if not specified
      if (printerName == null || printerName.isEmpty) {
        final printers = await _getDesktopPrinters();
        if (printers.isEmpty) {
          return {'success': false, 'message': '❌ No printers found'};
        }

        final thermal = printers.firstWhere(
          (p) {
            final name = (p['productName'] ?? '').toString().toLowerCase();
            return name.contains('thermal') ||
                name.contains('pos') ||
                name.contains('receipt') ||
                name.contains('58') ||
                name.contains('80') ||
                name.contains('xp-') ||
                name.contains('rp') ||
                name.contains('copper') ||
                name.contains('bc-');
          },
          orElse: () => printers.first,
        );
        printerName = thermal['productName'] as String;
      }

      _log('🖨️ Printing to: $printerName');

      // Write bytes to temp file
      final tempDir = Directory.systemTemp;
      final tempFile = File(
          '${tempDir.path}\\receipt_${DateTime.now().millisecondsSinceEpoch}.bin');
      await tempFile.writeAsBytes(bytes);

      _log('📄 Temp file: ${tempFile.path} (${bytes.length} bytes)');

      // Try RAW printing via PowerShell script file
      final result =
          await _printWindowsRawViaPsFile(tempFile.path, printerName!);

      // Clean up temp file
      try {
        await tempFile.delete();
      } catch (_) {}

      return result;
    } catch (e) {
      _log('❌ Windows print error: $e');
      return {'success': false, 'message': '❌ Print failed: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────
  // WINDOWS — RAW print via .ps1 script file
  // Avoids ALL PowerShell escaping issues
  // ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> _printWindowsRawViaPsFile(
    String tempFilePath,
    String printerName,
  ) async {
    File? scriptFile;
    try {
      // Use forward slashes in PS script to avoid escape issues
      final psFilePath = tempFilePath.replaceAll('\\', '/');
      final scriptContent = _buildPowerShellScript(psFilePath, printerName);

      final scriptPath =
          '${Directory.systemTemp.path}\\print_${DateTime.now().millisecondsSinceEpoch}.ps1';
      scriptFile = File(scriptPath);
      await scriptFile.writeAsString(scriptContent);

      _log('📜 PS1 script: $scriptPath');

      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          scriptPath,
        ],
        runInShell: false,
      );

      _log('PS stdout: ${result.stdout}');
      _log('PS stderr: ${result.stderr}');
      _log('PS exitCode: ${result.exitCode}');

      final stdout = result.stdout.toString().trim();

      if (stdout.contains('SUCCESS') || result.exitCode == 0) {
        return {
          'success': true,
          'message': '✅ Receipt printed to $printerName',
        };
      }

      // Fallback to CMD
      _log('PS method failed, trying CMD fallback...');
      return await _printWindowsCmdFallback(tempFilePath, printerName);
    } catch (e) {
      _log('❌ PS script error: $e');
      return await _printWindowsCmdFallback(tempFilePath, printerName);
    } finally {
      try {
        await scriptFile?.delete();
      } catch (_) {}
    }
  }

  // ─────────────────────────────────────────────────────────
  // BUILD PowerShell SCRIPT using winspool API
  // Written to a .ps1 FILE — no escaping issues
  // ─────────────────────────────────────────────────────────
  static String _buildPowerShellScript(
      String filePath, String printerName) {
    // Escape single quotes in printer name for PS string
    final safePrinterName = printerName.replaceAll("'", "''");
    final safeFilePath = filePath.replaceAll("'", "''");

    return r'''
Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Runtime.InteropServices;

public class RawPrint {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    public class DOCINFOA {
        [MarshalAs(UnmanagedType.LPStr)] public string pDocName;
        [MarshalAs(UnmanagedType.LPStr)] public string pOutputFile;
        [MarshalAs(UnmanagedType.LPStr)] public string pDataType;
    }

    [DllImport("winspool.Drv", EntryPoint = "OpenPrinterA",
        CharSet = CharSet.Ansi, SetLastError = true, ExactSpelling = true)]
    public static extern bool OpenPrinter(string szPrinter,
        out IntPtr hPrinter, IntPtr pd);

    [DllImport("winspool.Drv", EntryPoint = "ClosePrinter",
        SetLastError = true, ExactSpelling = true)]
    public static extern bool ClosePrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "StartDocPrinterA",
        CharSet = CharSet.Ansi, SetLastError = true, ExactSpelling = true)]
    public static extern bool StartDocPrinter(IntPtr hPrinter, Int32 level,
        [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOA di);

    [DllImport("winspool.Drv", EntryPoint = "EndDocPrinter",
        SetLastError = true, ExactSpelling = true)]
    public static extern bool EndDocPrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "StartPagePrinter",
        SetLastError = true, ExactSpelling = true)]
    public static extern bool StartPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "EndPagePrinter",
        SetLastError = true, ExactSpelling = true)]
    public static extern bool EndPagePrinter(IntPtr hPrinter);

    [DllImport("winspool.Drv", EntryPoint = "WritePrinter",
        SetLastError = true, ExactSpelling = true)]
    public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes,
        Int32 dwCount, out Int32 dwWritten);

    public static bool SendFile(string printerName, string fileName) {
        byte[] data = File.ReadAllBytes(fileName);
        IntPtr ptr = Marshal.AllocCoTaskMem(data.Length);
        Marshal.Copy(data, 0, ptr, data.Length);

        IntPtr hPrinter = IntPtr.Zero;
        DOCINFOA di = new DOCINFOA();
        di.pDocName   = "Receipt";
        di.pDataType  = "RAW";
        di.pOutputFile = null;

        bool ok = false;
        try {
            if (OpenPrinter(printerName, out hPrinter, IntPtr.Zero)) {
                if (StartDocPrinter(hPrinter, 1, di)) {
                    if (StartPagePrinter(hPrinter)) {
                        Int32 written;
                        ok = WritePrinter(hPrinter, ptr, data.Length,
                            out written);
                        EndPagePrinter(hPrinter);
                    }
                    EndDocPrinter(hPrinter);
                }
                ClosePrinter(hPrinter);
            }
        } finally {
            Marshal.FreeCoTaskMem(ptr);
        }
        return ok;
    }
}
"@

''' +
        '''
\$printerName = '$safePrinterName'
\$filePath    = '$safeFilePath'

Write-Host "Printer : \$printerName"
Write-Host "File    : \$filePath"

if (-not (Test-Path \$filePath)) {
    Write-Host "ERROR: File not found: \$filePath"
    exit 1
}

try {
    \$ok = [RawPrint]::SendFile(\$printerName, \$filePath)
    if (\$ok) {
        Write-Host "SUCCESS"
        exit 0
    } else {
        \$errCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        Write-Host "FAILED: Win32 error = \$errCode"
        exit 1
    }
} catch {
    Write-Host "EXCEPTION: \$_"
    exit 1
}
''';
  }

  // ─────────────────────────────────────────────────────────
  // FALLBACK — CMD COPY command
  // ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> _printWindowsCmdFallback(
    String filePath,
    String printerName,
  ) async {
    try {
      _log('Trying CMD copy fallback to: $printerName');

      // Try: copy /b file.bin "\\.\PrinterName"
      final result = await Process.run(
        'cmd.exe',
        ['/c', 'copy', '/b', filePath, '\\\\.\\$printerName'],
        runInShell: false,
      );

      _log('CMD stdout: ${result.stdout}');
      _log('CMD stderr: ${result.stderr}');
      _log('CMD exitCode: ${result.exitCode}');

      if (result.exitCode == 0) {
        return {
          'success': true,
          'message': '✅ Receipt printed (CMD fallback)',
        };
      }

      // Try: print /d command
      _log('Trying print /d command...');
      final printResult = await Process.run(
        'cmd.exe',
        ['/c', 'print', '/d:$printerName', filePath],
        runInShell: false,
      );

      _log('Print stdout: ${printResult.stdout}');
      _log('Print stderr: ${printResult.stderr}');

      if (printResult.exitCode == 0) {
        return {
          'success': true,
          'message': '✅ Receipt printed (print command)',
        };
      }

      return {
        'success': false,
        'message': '❌ All print methods failed.\n\n'
            'Printer: $printerName\n\n'
            'Try:\n'
            '• Check printer is online in Windows\n'
            '• Run app as Administrator\n'
            '• Reinstall printer driver\n'
            '• Set printer as Default Printer',
      };
    } catch (e) {
      return {'success': false, 'message': '❌ CMD fallback error: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────
  // LINUX/macOS — Print via lp
  // ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> _printUnix(
    Uint8List bytes,
    String? printerName,
  ) async {
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File(
          '${tempDir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.bin');
      await tempFile.writeAsBytes(bytes);

      final args = <String>['-o', 'raw'];
      if (printerName != null && printerName.isNotEmpty) {
        args.addAll(['-d', printerName]);
      }
      args.add(tempFile.path);

      final result = await Process.run('lp', args, runInShell: true);

      try {
        await tempFile.delete();
      } catch (_) {}

      if (result.exitCode == 0) {
        return {'success': true, 'message': '✅ Receipt sent to printer'};
      }

      return {
        'success': false,
        'message': '❌ Print failed: ${result.stderr}',
      };
    } catch (e) {
      return {'success': false, 'message': '❌ Print error: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────
  // ANDROID — TEST USB
  // ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> _testAndroidUsb() async {
    try {
      final devices = await _getAndroidUsbPrinters();
      if (devices.isEmpty) {
        return {
          'success': false,
          'message': '❌ No USB printers found.\n\n'
              'Make sure:\n'
              '• Printer is powered ON\n'
              '• Connected via USB OTG cable\n'
              '• USB OTG adapter is working',
        };
      }
      return {
        'success': true,
        'message':
            '✅ USB printer found!\nDevice: ${devices.first['productName']}',
      };
    } catch (e) {
      return {'success': false, 'message': '❌ USB error: $e'};
    }
  }

  // ─────────────────────────────────────────────────────────
  // ANDROID — PRINT USB
  // ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> _printAndroidUsb(
      Uint8List bytes) async {
    return {
      'success': false,
      'message': '❌ Android USB printing requires flutter_usb_printer.\n'
          'Add it to pubspec.yaml for Android builds.',
    };
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PRINTER STATUS ENUM
// ═════════════════════════════════════════════════════════════════════════════
enum PrinterStatus { unknown, checking, connected, disconnected, error }

// ═════════════════════════════════════════════════════════════════════════════
// SLIP PREVIEW SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class SlipPreviewScreen extends StatefulWidget {
  final String shopName;
  final String shopAddress;
  final String shopPhone;
  final String? shopTagline;
  final String invoiceNumber;
  final String date;
  final String customerName;
  final List<SaleItem> cartItems;
  final Map<String, double> balances;
  final String paymentMethod;
  final double Function(SaleItem) getLineTotal;
  final VoidCallback onPrint;

  const SlipPreviewScreen({
    super.key,
    required this.shopName,
    required this.shopAddress,
    required this.shopPhone,
    this.shopTagline,
    required this.invoiceNumber,
    required this.date,
    required this.customerName,
    required this.cartItems,
    required this.balances,
    required this.paymentMethod,
    required this.getLineTotal,
    required this.onPrint,
  });

  @override
  State<SlipPreviewScreen> createState() => _SlipPreviewScreenState();
}

class _SlipPreviewScreenState extends State<SlipPreviewScreen>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  bool _showPrinterSettings = false;
  PrinterStatus _printerStatus = PrinterStatus.unknown;
  bool _isChecking = false;
  String _statusMessage =
      'Press "Scan for USB Printers" to detect your printer.';
  String? _selectedPrinterName;
  List<Map<String, dynamic>> _availablePrinters = [];

  static const _kSelectedSize = 'slip_size';
  static const _kSelectedPrinter = 'selected_printer_name';

  static const Color _paperColor = Color(0xFFFFFDE7);
  static const Color _inkColor = Color(0xFF1A1A1A);
  static const Color _dividerColor = Color(0xFF9E9E9E);
  static const Color _accentColor = Color(0xFF1565C0);

  final _numFmt = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    _loadSettings();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedTab = prefs.getInt(_kSelectedSize) ?? 0;
      _selectedPrinterName = prefs.getString(_kSelectedPrinter);
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSelectedSize, _selectedTab);
    if (_selectedPrinterName != null) {
      await prefs.setString(_kSelectedPrinter, _selectedPrinterName!);
    }
  }

  // ═══════════════════════════════════════════════════════
  // CHECK USB PRINTER
  // ═══════════════════════════════════════════════════════
  Future<void> _checkPrinterConnection() async {
    setState(() {
      _isChecking = true;
      _printerStatus = PrinterStatus.checking;
      _statusMessage = 'Scanning for USB printers…';
    });

    final result = await PrinterCommunicator.testConnection();
    final printers = await PrinterCommunicator.getUsbPrinters();

    if (mounted) {
      setState(() {
        _isChecking = false;
        _availablePrinters = printers;
        _printerStatus = result['success']
            ? PrinterStatus.connected
            : PrinterStatus.error;
        _statusMessage = result['message'];

        if (result['recommended'] != null) {
          _selectedPrinterName = result['recommended'];
        } else if (printers.isNotEmpty && _selectedPrinterName == null) {
          _selectedPrinterName =
              printers.first['productName'] as String?;
        }
      });
      _saveSettings();
    }
  }

  // ═══════════════════════════════════════════════════════
  // PRINT RECEIPT
  // ═══════════════════════════════════════════════════════
  Future<void> _handleActualPrinting() async {
    try {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Printing receipt…'),
                ],
              ),
            ),
          ),
        ),
      );

      debugPrint('═══════════════════════════════════════');
      debugPrint('🖨️  STARTING USB PRINT JOB');
      debugPrint('Printer: $_selectedPrinterName');
      debugPrint('═══════════════════════════════════════');

      final Uint8List bytes;

      if (_selectedTab == 0) {
        bytes = await ThermalPrintService80mm.buildReceipt(
          shopName: widget.shopName,
          shopAddress: widget.shopAddress,
          shopPhone: widget.shopPhone,
          shopTagline: widget.shopTagline,
          invoiceNumber: widget.invoiceNumber,
          date: widget.date,
          customerName: widget.customerName,
          items: widget.cartItems
              .map((item) => ReceiptItem(
                    qty: item.quantity,
                    productName: item.productName,
                    tradePrice: item.tradePrice ?? 0,
                    retailPrice: item.price,
                    discountPercent: item.discount ?? 0,
                    lineTotal: widget.getLineTotal(item),
                  ))
              .toList(),
          subtotal: widget.balances['subtotal'] ?? 0,
          totalDiscount: widget.balances['discount'] ?? 0,
          tax: widget.balances['tax'] ?? 0,
          saleAmount: widget.balances['saleAmount'] ?? 0,
          previousBalance: widget.balances['previousBalance'] ?? 0,
          totalDue: widget.balances['totalDue'] ?? 0,
          amountPaid: widget.balances['amountPaid'] ?? 0,
          remainingBalance: widget.balances['remainingBalance'] ?? 0,
          paymentMethod: widget.paymentMethod,
        );
      } else {
        bytes = await ThermalPrintService6Inch.buildReceipt(
          shopName: widget.shopName,
          shopAddress: widget.shopAddress,
          shopPhone: widget.shopPhone,
          shopTagline: widget.shopTagline,
          invoiceNumber: widget.invoiceNumber,
          date: widget.date,
          customerName: widget.customerName,
          items: widget.cartItems
              .map((item) => ReceiptItem6(
                    qty: item.quantity,
                    productName: item.productName,
                    tradePrice: item.tradePrice ?? 0,
                    retailPrice: item.price,
                    discountPercent: item.discount ?? 0,
                    lineTotal: widget.getLineTotal(item),
                  ))
              .toList(),
          subtotal: widget.balances['subtotal'] ?? 0,
          totalDiscount: widget.balances['discount'] ?? 0,
          tax: widget.balances['tax'] ?? 0,
          saleAmount: widget.balances['saleAmount'] ?? 0,
          previousBalance: widget.balances['previousBalance'] ?? 0,
          totalDue: widget.balances['totalDue'] ?? 0,
          amountPaid: widget.balances['amountPaid'] ?? 0,
          remainingBalance: widget.balances['remainingBalance'] ?? 0,
          paymentMethod: widget.paymentMethod,
        );
      }

      debugPrint('✅ Generated ${bytes.length} bytes');

      final result = await PrinterCommunicator.printReceipt(
        bytes: bytes,
        printerName: _selectedPrinterName,
      );

      debugPrint(result['success'] ? '✅ SUCCESS!' : '❌ FAILED!');

      if (mounted) Navigator.of(context).pop();

      if (result['success'] && mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result['message']}'),
            backgroundColor:
                result['success'] ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ EXCEPTION: $e');
      debugPrint('$stackTrace');

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  double get _subtotal => widget.balances['subtotal'] ?? 0;
  double get _discount => widget.balances['discount'] ?? 0;
  double get _tax => widget.balances['tax'] ?? 0;
  double get _saleAmount => widget.balances['saleAmount'] ?? 0;
  double get _prevBalance => widget.balances['previousBalance'] ?? 0;
  double get _totalDue => widget.balances['totalDue'] ?? 0;
  double get _amountPaid => widget.balances['amountPaid'] ?? 0;
  double get _remaining => widget.balances['remainingBalance'] ?? 0;
  int get _totalQty =>
      widget.cartItems.fold(0, (s, i) => s + i.quantity);

  String _rs(double v) => 'Rs.${_numFmt.format(v)}';

  void _switchTab(int t) {
    if (t == _selectedTab) return;
    _fadeCtrl.reset();
    setState(() => _selectedTab = t);
    _fadeCtrl.forward();
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: 1050, maxHeight: size.height * 0.95),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        color: const Color(0xFF263238),
                        child: _buildPaperArea(),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _showPrinterSettings
                          ? _buildPrinterSettingsPanel()
                          : _buildActionPanel(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // TOP BAR
  // ═══════════════════════════════════════════════════════
  Widget _buildTopBar() {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0D47A1),
            Color(0xFF1565C0),
            Color(0xFF1976D2)
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          const Text('Slip Preview',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          const SizedBox(width: 16),
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tabButton('3-inch', 0),
                _tabButton('6-inch', 1),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildPrinterStatusChip(),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(widget.invoiceNumber,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
            splashRadius: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrinterStatusChip() {
    Color chipColor;
    Color dotColor;
    IconData chipIcon;
    String chipLabel;

    switch (_printerStatus) {
      case PrinterStatus.connected:
        chipColor = Colors.green.withOpacity(0.25);
        dotColor = const Color(0xFF66BB6A);
        chipIcon = Icons.usb;
        chipLabel = 'USB Ready';
        break;
      case PrinterStatus.error:
      case PrinterStatus.disconnected:
        chipColor = Colors.red.withOpacity(0.25);
        dotColor = const Color(0xFFEF5350);
        chipIcon = Icons.usb_off;
        chipLabel = 'No Printer';
        break;
      case PrinterStatus.checking:
        chipColor = Colors.orange.withOpacity(0.25);
        dotColor = Colors.orange;
        chipIcon = Icons.autorenew;
        chipLabel = 'Scanning…';
        break;
      default:
        chipColor = Colors.white.withOpacity(0.12);
        dotColor = Colors.white38;
        chipIcon = Icons.usb;
        chipLabel = 'USB Setup';
    }

    return GestureDetector(
      onTap: () =>
          setState(() => _showPrinterSettings = !_showPrinterSettings),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _showPrinterSettings
              ? Colors.white.withOpacity(0.25)
              : chipColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _showPrinterSettings
                ? Colors.white.withOpacity(0.6)
                : Colors.white.withOpacity(0.2),
          ),
        ),
        child:
            Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: dotColor.withOpacity(0.5), blurRadius: 4)
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(chipIcon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(chipLabel,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Icon(
            _showPrinterSettings
                ? Icons.keyboard_arrow_up
                : Icons.keyboard_arrow_down,
            color: Colors.white70,
            size: 13,
          ),
        ]),
      ),
    );
  }

  Widget _tabButton(String label, int idx) {
    final active = _selectedTab == idx;
    return GestureDetector(
      onTap: () => _switchTab(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? _accentColor : Colors.white70)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // PRINTER SETTINGS PANEL
  // ═══════════════════════════════════════════════════════
  Widget _buildPrinterSettingsPanel() {
    return Container(
      key: const ValueKey('printer_settings'),
      width: 280,
      color: const Color(0xFF1C2833),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF151E27),
              border:
                  Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(children: [
              const Icon(Icons.usb, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              const Text('USB Printer',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    setState(() => _showPrinterSettings = false),
                child: const Icon(Icons.chevron_right,
                    color: Colors.white38, size: 20),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 16),
                  _buildInfoBox(
                    icon: Icons.usb,
                    text:
                        'USB thermal printers are detected automatically.\n\n'
                        'Make sure:\n'
                        '• Printer is powered ON\n'
                        '• USB cable is connected\n'
                        '• Printer driver is installed',
                  ),
                  const SizedBox(height: 16),
                  if (_availablePrinters.isNotEmpty) ...[
                    _sectionLabel('DETECTED PRINTERS'),
                    const SizedBox(height: 8),
                    ..._availablePrinters
                        .map((p) => _printerListItem(p)),
                    const SizedBox(height: 16),
                  ],
                  _sectionLabel('PAPER SIZE'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: _paperSizeBtn('3-inch', 0,
                            subtitle: '58mm · Compact')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _paperSizeBtn('6-inch', 1,
                            subtitle: '152mm · Wide')),
                  ]),
                  const SizedBox(height: 20),
                  _buildCheckButton(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: [
              ElevatedButton.icon(
                onPressed: _handleActualPrinting,
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Print Now',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white60,
                  side: BorderSide(
                      color: Colors.white.withOpacity(0.2)),
                  minimumSize: const Size(double.infinity, 40),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel',
                    style: TextStyle(fontSize: 13)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _printerListItem(Map<String, dynamic> printer) {
    final name = printer['productName'] ?? 'Unknown';
    final port = printer['portName'] ?? '';
    final isSelected = _selectedPrinterName == name;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedPrinterName = name as String);
        _saveSettings();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1565C0).withOpacity(0.3)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF42A5F5)
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Icon(
            isSelected
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
            color: isSelected
                ? const Color(0xFF42A5F5)
                : Colors.white30,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.toString(),
                    style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.white70,
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500)),
                if (port.toString().isNotEmpty)
                  Text('Port: $port',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 9)),
              ],
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_circle,
                color: Color(0xFF66BB6A), size: 16),
        ]),
      ),
    );
  }

  Widget _buildStatusCard() {
    Color bg, border, iconColor, textColor;
    IconData statusIcon;
    String headline;

    switch (_printerStatus) {
      case PrinterStatus.connected:
        bg = const Color(0xFF1B5E20).withOpacity(0.4);
        border = const Color(0xFF43A047);
        iconColor = const Color(0xFF66BB6A);
        textColor = const Color(0xFFA5D6A7);
        statusIcon = Icons.check_circle_outline;
        headline = 'USB Printer Ready';
        break;
      case PrinterStatus.error:
        bg = const Color(0xFF7F0000).withOpacity(0.35);
        border = const Color(0xFFC62828);
        iconColor = const Color(0xFFEF5350);
        textColor = const Color(0xFFEF9A9A);
        statusIcon = Icons.error_outline;
        headline = 'No Printer Found';
        break;
      case PrinterStatus.checking:
        bg = const Color(0xFF212121).withOpacity(0.4);
        border = Colors.orange.shade700;
        iconColor = Colors.orange;
        textColor = Colors.orange.shade200;
        statusIcon = Icons.autorenew;
        headline = 'Scanning…';
        break;
      default:
        bg = const Color(0xFF212121).withOpacity(0.3);
        border = Colors.white12;
        iconColor = Colors.white38;
        textColor = Colors.white54;
        statusIcon = Icons.usb;
        headline = 'Not Checked';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        _printerStatus == PrinterStatus.checking
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: iconColor),
              )
            : Icon(statusIcon, color: iconColor, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(headline,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(_statusMessage,
                  style: TextStyle(
                      color: textColor.withOpacity(0.75),
                      fontSize: 10),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildCheckButton() {
    return ElevatedButton.icon(
      onPressed: _isChecking ? null : _checkPrinterConnection,
      icon: _isChecking
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.search, size: 16),
      label: Text(
          _isChecking ? 'Scanning…' : 'Scan for USB Printers',
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade700,
        minimumSize: const Size(double.infinity, 44),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    );
  }

  Widget _paperSizeBtn(String label, int idx,
      {String subtitle = ''}) {
    final active = _selectedTab == idx;
    return GestureDetector(
      onTap: () => _switchTab(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF0D47A1)
              : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? const Color(0xFF42A5F5)
                : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Column(children: [
          Icon(Icons.receipt_long,
              color: active ? Colors.white : Colors.white38,
              size: 18),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : Colors.white38)),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 8,
                  color:
                      active ? Colors.white60 : Colors.white24)),
        ]),
      ),
    );
  }

  Widget _buildInfoBox(
      {required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white38, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      height: 1.5)),
            ),
          ]),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(
            color: Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2));
  }

  // ═══════════════════════════════════════════════════════
  // ACTION PANEL
  // ═══════════════════════════════════════════════════════
  Widget _buildActionPanel() {
    return Container(
      key: const ValueKey('action_panel'),
      width: 200,
      color: const Color(0xFF1C2833),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('SUMMARY',
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                  const SizedBox(height: 10),
                  _summaryRow(
                      'Items', '${widget.cartItems.length}'),
                  _summaryRow('Qty', '$_totalQty'),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 8),
                  _summaryRow('Sale Amt',
                      'Rs.${_numFmt.format(_saleAmount)}',
                      highlight: true),
                  if (_prevBalance > 0)
                    _summaryRow('Prev Bal',
                        'Rs.${_numFmt.format(_prevBalance)}',
                        warn: true),
                  _summaryRow(
                      'Total Due',
                      'Rs.${_numFmt.format(_totalDue)}',
                      highlight: true),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 8),
                  _summaryRow(
                      'Paid', 'Rs.${_numFmt.format(_amountPaid)}'),
                  _summaryRow(
                    _remaining >= 0 ? 'Balance' : 'Change',
                    'Rs.${_numFmt.format(_remaining.abs())}',
                    warn: _remaining > 0,
                    good: _remaining <= 0,
                  ),
                ]),
          ),
          const SizedBox(height: 20),
          const Text('PAPER SIZE',
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          Row(children: [
            _sizeChip('3-inch', 0),
            const SizedBox(width: 8),
            _sizeChip('6-inch', 1),
          ]),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () =>
                setState(() => _showPrinterSettings = true),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(children: [
                _statusDot(),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                      const Text('USB PRINTER',
                          style: TextStyle(
                              color: Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8)),
                      Text(
                          _selectedPrinterName ??
                              _printerStatusLabel(),
                          style: TextStyle(
                              color: _printerStatusColor(),
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ])),
                const Icon(Icons.settings,
                    color: Colors.white24, size: 14),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _handleActualPrinting,
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print Now',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white60,
              side:
                  BorderSide(color: Colors.white.withOpacity(0.2)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child:
                const Text('Cancel', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _statusDot() {
    final color = _printerStatusColor();
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)
        ],
      ),
    );
  }

  String _printerStatusLabel() {
    switch (_printerStatus) {
      case PrinterStatus.connected:
        return 'USB Connected';
      case PrinterStatus.disconnected:
        return 'Disconnected';
      case PrinterStatus.error:
        return 'Error – Tap to fix';
      case PrinterStatus.checking:
        return 'Scanning…';
      default:
        return 'Tap to configure';
    }
  }

  Color _printerStatusColor() {
    switch (_printerStatus) {
      case PrinterStatus.connected:
        return const Color(0xFF66BB6A);
      case PrinterStatus.error:
      case PrinterStatus.disconnected:
        return const Color(0xFFEF5350);
      case PrinterStatus.checking:
        return Colors.orange;
      default:
        return Colors.white38;
    }
  }

  Widget _summaryRow(String label, String value,
      {bool highlight = false,
      bool warn = false,
      bool good = false}) {
    Color valueColor = Colors.white70;
    if (highlight) valueColor = Colors.white;
    if (warn) valueColor = const Color(0xFFEF5350);
    if (good) valueColor = const Color(0xFF66BB6A);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.5))),
            Text(value,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: highlight
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: valueColor)),
          ]),
    );
  }

  Widget _sizeChip(String label, int idx) {
    final active = _selectedTab == idx;
    return GestureDetector(
      onTap: () => _switchTab(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF1976D2)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: active
                  ? const Color(0xFF1976D2)
                  : Colors.white.withOpacity(0.15)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : Colors.white54)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // PAPER PREVIEW AREA
  // ═══════════════════════════════════════════════════════
  Widget _buildPaperArea() {
    return Stack(
      children: [
        Positioned.fill(child: _DotBackground()),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                vertical: 32, horizontal: 30),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: _selectedTab == 0
                  ? _build3InchSlip()
                  : _build6InchSlip(),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // 3-INCH SLIP
  // ═══════════════════════════════════════════════════════
  Widget _build3InchSlip() {
    return _SlipWrapper(
      width: 290,
      child: Column(children: [
        _s3Text(widget.shopName.toUpperCase(),
            bold: true, size: 15, center: true),
        const SizedBox(height: 3),
        _s3Text(widget.shopAddress, center: true, size: 10),
        _s3Text('Tel: ${widget.shopPhone}', center: true, size: 10),
        _sDash(dash: '-'),
        _s3Row('Invoice#', widget.invoiceNumber),
        _s3Row('Customer', widget.customerName),
        _s3Row('Date', widget.date),
        _sDash(dash: '-'),
        _s3Text('Item             Qty   Amount',
            mono: true, bold: true, size: 9),
        _s3Text('  TP / RP / DIS%', mono: true, size: 9),
        _sDash(dash: '-'),
        ...widget.cartItems.map((item) {
          final lineTotal = widget.getLineTotal(item);
          final name = item.productName.length > 14
              ? item.productName.substring(0, 14)
              : item.productName.padRight(14);
          final qty = '${item.quantity}x'.padLeft(4);
          final amt = _numFmt.format(lineTotal).padLeft(7);
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _s3Text('$name$qty$amt', mono: true, size: 9),
                _s3Text(
                  '  TP:${_numFmt.format(item.tradePrice ?? 0)} '
                  'RP:${_numFmt.format(item.price)} '
                  'DIS:${(item.discount ?? 0).toStringAsFixed(0)}%',
                  mono: true,
                  size: 8,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(height: 2),
              ]);
        }),
        _sDash(dash: '-'),
        _s3Row('Subtotal', _rs(_subtotal)),
        if (_discount > 0)
          _s3Row('Discount', '-${_rs(_discount)}',
              valueColor: Colors.red.shade700),
        _s3Row('Tax (5%)', '+${_rs(_tax)}'),
        _sDash(ch: '='),
        _s3Row('SALE TOTAL', _rs(_saleAmount), bold: true),
        _sDash(dash: '-'),
        if (_prevBalance > 0) ...[
          _s3Row('Prev. Balance', _rs(_prevBalance),
              valueColor: Colors.red.shade700),
          _s3Row('Total Due', _rs(_totalDue), bold: true),
          _sDash(dash: '-'),
        ],
        _s3Row('Paid (${widget.paymentMethod})', _rs(_amountPaid),
            bold: true),
        if (_remaining > 0)
          _s3Highlight('BALANCE DUE', _rs(_remaining))
        else if (_remaining < 0)
          _s3Row('Change', _rs(_remaining.abs()),
              bold: true, valueColor: Colors.green.shade700)
        else
          _s3Text('*** FULLY PAID — THANK YOU ***',
              bold: true, center: true, size: 10),
        _sDash(ch: '='),
        _s3Text(
            'Items: ${widget.cartItems.length}  |  Qty: $_totalQty',
            center: true,
            size: 9),
        _sDash(dash: '-'),
        if (widget.shopTagline != null)
          _s3Text(widget.shopTagline!,
              center: true,
              size: 9,
              color: Colors.grey.shade600),
        _s3Text('Thank you for shopping with us!',
            bold: true, center: true, size: 10),
        _s3Text(
            DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
            center: true,
            size: 9,
            color: Colors.grey.shade600),
        const SizedBox(height: 8),
        _TearEdge(),
      ]),
    );
  }

  Widget _s3Text(String text,
      {bool bold = false,
      bool center = false,
      bool mono = false,
      double size = 10,
      Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(text,
          textAlign:
              center ? TextAlign.center : TextAlign.left,
          style: TextStyle(
              fontFamily: mono ? 'Courier' : null,
              fontSize: size,
              fontWeight:
                  bold ? FontWeight.w700 : FontWeight.w400,
              color: color ?? _inkColor,
              height: 1.3)),
    );
  }

  Widget _s3Row(String label, String value,
      {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight:
                        bold ? FontWeight.w700 : FontWeight.w400,
                    color: _inkColor)),
            Text(value,
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight:
                        bold ? FontWeight.w700 : FontWeight.w400,
                    fontFamily: 'Courier',
                    color: valueColor ?? _inkColor)),
          ]),
    );
  }

  Widget _s3Highlight(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      color: _inkColor,
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            Text(value,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Courier',
                    color: Colors.white)),
          ]),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 6-INCH SLIP
  // ═══════════════════════════════════════════════════════
  Widget _build6InchSlip() {
    const double wQty = 28;
    const double wName = 150;
    const double wTp = 58;
    const double wRp = 58;
    const double wDis = 44;
    const double wTot = 66;

    return _SlipWrapper(
      width: 528,
      child: Column(children: [
        _s6Text(widget.shopName.toUpperCase(),
            bold: true, size: 17, center: true),
        const SizedBox(height: 3),
        _s6Text(widget.shopAddress, center: true, size: 10),
        _s6Text('Tel: ${widget.shopPhone}',
            center: true, size: 10),
        _sDash(ch: '=', wide: true),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            _metaLabel('INVOICE #'),
            Expanded(
                child:
                    _s6Text(widget.invoiceNumber, size: 10)),
            _metaLabel('DATE'),
            _s6Text(widget.date, size: 10),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            _metaLabel('CUSTOMER'),
            Expanded(
                child: _s6Text(widget.customerName,
                    size: 10, bold: true)),
          ]),
        ),
        _sDash(dash: '-', wide: true),
        _s6TableRow(
            qty: 'QTY',
            name: 'PRODUCT NAME',
            tp: 'TP',
            rp: 'RP',
            dis: 'DIS%',
            tot: 'TOTAL',
            wQty: wQty,
            wName: wName,
            wTp: wTp,
            wRp: wRp,
            wDis: wDis,
            wTot: wTot,
            bold: true),
        _sDash(dash: '-', wide: true),
        ...widget.cartItems.map((item) {
          final lineTotal = widget.getLineTotal(item);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: _s6TableRow(
              qty: '${item.quantity}',
              name: item.productName,
              tp: _numFmt.format(item.tradePrice ?? 0),
              rp: _numFmt.format(item.price),
              dis:
                  '${(item.discount ?? 0).toStringAsFixed(0)}%',
              tot: _numFmt.format(lineTotal),
              wQty: wQty,
              wName: wName,
              wTp: wTp,
              wRp: wRp,
              wDis: wDis,
              wTot: wTot,
            ),
          );
        }),
        _sDash(ch: '=', wide: true),
        _s6TotalRow('Subtotal:', _rs(_subtotal)),
        if (_discount > 0)
          _s6TotalRow('Total Discount:', '-${_rs(_discount)}',
              valueColor: Colors.red.shade700),
        if (_tax > 0)
          _s6TotalRow('Tax (5%):', '+${_rs(_tax)}',
              valueColor: Colors.teal.shade700),
        _sDash(dash: '-', wide: true),
        _s6TotalRow('SALE AMOUNT:', _rs(_saleAmount),
            bold: true),
        _sDash(dash: '-', wide: true),
        if (_prevBalance > 0) ...[
          _s6TotalRow(
              'Previous Balance:', _rs(_prevBalance),
              valueColor: Colors.red.shade700),
          _s6TotalRow('TOTAL DUE:', _rs(_totalDue),
              bold: true),
          _sDash(dash: '-', wide: true),
        ],
        _s6TotalRow(
            'Amount Paid (${widget.paymentMethod}):',
            _rs(_amountPaid),
            bold: true),
        _sDash(ch: '=', wide: true),
        if (_remaining > 0)
          _s6Highlight('BALANCE DUE:', _rs(_remaining))
        else if (_remaining < 0)
          _s6TotalRow('CHANGE:', _rs(_remaining.abs()),
              bold: true,
              valueColor: Colors.green.shade700)
        else
          _s6Text('*** FULLY PAID — THANK YOU ***',
              bold: true, center: true, size: 11),
        _sDash(dash: '-', wide: true),
        Row(children: [
          _s6Text(
              'Total Items: ${widget.cartItems.length}    Total Qty: $_totalQty',
              size: 9.5)
        ]),
        _sDash(ch: '=', wide: true),
        if (widget.shopTagline != null)
          _s6Text(widget.shopTagline!,
              center: true,
              size: 9.5,
              color: Colors.grey.shade600),
        _s6Text('Thank you for shopping with us!',
            bold: true, center: true, size: 10.5),
        _s6Text(
            DateFormat('dd/MM/yyyy HH:mm')
                .format(DateTime.now()),
            center: true,
            size: 9.5,
            color: Colors.grey.shade600),
        const SizedBox(height: 8),
        _TearEdge(),
      ]),
    );
  }

  Widget _s6Text(String text,
      {bool bold = false,
      bool center = false,
      double size = 10,
      Color? color}) {
    return Text(text,
        textAlign:
            center ? TextAlign.center : TextAlign.left,
        style: TextStyle(
            fontSize: size,
            fontWeight:
                bold ? FontWeight.w700 : FontWeight.w400,
            color: color ?? _inkColor,
            height: 1.35));
  }

  Widget _metaLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
              letterSpacing: 0.5)),
    );
  }

  Widget _s6TableRow({
    required String qty,
    required String name,
    required String tp,
    required String rp,
    required String dis,
    required String tot,
    required double wQty,
    required double wName,
    required double wTp,
    required double wRp,
    required double wDis,
    required double wTot,
    bool bold = false,
  }) {
    final style = TextStyle(
        fontFamily: 'Courier',
        fontSize: 9,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: _inkColor);
    String clip(String s, int max) =>
        s.length > max ? '${s.substring(0, max - 1)}…' : s;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          width: wQty,
          child: Text(qty, style: style, overflow: TextOverflow.clip)),
      SizedBox(
          width: wName,
          child: Text(clip(name, 22),
              style: style, overflow: TextOverflow.ellipsis)),
      SizedBox(
          width: wTp,
          child:
              Text(tp, style: style, textAlign: TextAlign.right)),
      SizedBox(
          width: wRp,
          child:
              Text(rp, style: style, textAlign: TextAlign.right)),
      SizedBox(
          width: wDis,
          child:
              Text(dis, style: style, textAlign: TextAlign.right)),
      SizedBox(
          width: wTot,
          child:
              Text(tot, style: style, textAlign: TextAlign.right)),
    ]);
  }

  Widget _s6TotalRow(String label, String value,
      {bool bold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(
            flex: 7,
            child: Text(label,
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight:
                        bold ? FontWeight.w700 : FontWeight.w400,
                    color: _inkColor))),
        Expanded(
            flex: 3,
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 9.5,
                    fontWeight:
                        bold ? FontWeight.w700 : FontWeight.w400,
                    color: valueColor ?? _inkColor))),
      ]),
    );
  }

  Widget _s6Highlight(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: _inkColor,
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white))),
        Text(value,
            style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      ]),
    );
  }

  Widget _sDash({String? dash, String? ch, bool wide = false}) {
    final char = ch ?? dash ?? '-';
    final count = wide ? 64 : 32;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        char * count,
        style: TextStyle(
            fontFamily: 'Courier',
            fontSize: 8,
            color: _dividerColor,
            letterSpacing: char == '=' ? 0.5 : 0),
        overflow: TextOverflow.clip,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════
class _SlipWrapper extends StatelessWidget {
  final double width;
  final Widget child;
  const _SlipWrapper({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDE7),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 28,
              offset: const Offset(0, 8)),
          BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Perforation(),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: child,
        ),
      ]),
    );
  }
}

class _TearEdge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => CustomPaint(
      size: const Size(double.infinity, 16),
      painter: _TearEdgePainter());
}

class _TearEdgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const r = 4.0, gap = 10.0;
    double x = r;
    while (x < size.width) {
      canvas.drawArc(
          Rect.fromCircle(
              center: Offset(x, size.height / 2), radius: r),
          0,
          3.14159,
          false,
          paint);
      x += r * 2 + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _Perforation extends StatelessWidget {
  @override
  Widget build(BuildContext context) => CustomPaint(
      size: const Size(double.infinity, 18),
      painter: _PerforationPainter());
}

class _PerforationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFEEEEEE));
    final hole = Paint()..color = const Color(0xFF263238);
    const r = 4.5, spacing = 16.0;
    double x = spacing;
    while (x < size.width) {
      canvas.drawCircle(Offset(x, size.height / 2), r, hole);
      x += spacing;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _DotBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DotPainter());
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.04);
    const gap = 22.0;
    for (double x = 0; x < size.width; x += gap) {
      for (double y = 0; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}