import 'database_helper.dart';

/// Repository for daily closing-related database operations
class DailyClosingRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Save or update daily closing record
  Future<int> saveDailyClosing(Map<String, dynamic> closingMap) async {
    final db = await _dbHelper.database;

    final existing = await db.query(
      'daily_closing',
      where: 'date = ?',
      whereArgs: [closingMap['date']],
    );

    if (existing.isNotEmpty) {
      return await db.update(
        'daily_closing',
        closingMap,
        where: 'date = ?',
        whereArgs: [closingMap['date']],
      );
    }

    return await db.insert('daily_closing', closingMap);
  }

  /// Get daily closing record for a specific date
  Future<Map<String, dynamic>?> getDailyClosing(String date) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'daily_closing',
      where: 'date = ?',
      whereArgs: [date],
    );
    return result.isNotEmpty ? result.first : null;
  }
}