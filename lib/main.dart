import 'dart:io';

import 'package:flutter/material.dart';
import 'package:medical_app/Screens/dashboardScreen.dart';
import 'package:medical_app/Screens/sales_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 REQUIRED FOR WINDOWS / DESKTOP
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    debugPrint('✅ sqflite_common_ffi initialized for Desktop');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medical App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: PremiumDashboardScreen(),
    );
  }
}
