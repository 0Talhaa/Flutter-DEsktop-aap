// import 'package:sqflite/sqflite.dart';
// import 'database_helper.dart';

// /// Repository for app settings-related database operations
// class SettingsRepository {
//   final DatabaseHelper _dbHelper = DatabaseHelper.instance;

//   /// Save a setting key-value pair
//   Future<void> saveSetting(String key, String value) async {
//     final db = await _dbHelper.database;
//     await db.insert(
//       'settings',
//       {'key': key, 'value': value},
//       conflictAlgorithm: ConflictAlgorithm.replace,
//     );
//   }

//   /// Get a setting value by key
//   Future<String?> getSetting(String key) async {
//     final db = await _dbHelper.database;
//     final result = await db.query('settings', where: 'key = ?', whereArgs: [key]);
//     return result.isNotEmpty ? result.first['value'] as String? : null;
//   }
// }