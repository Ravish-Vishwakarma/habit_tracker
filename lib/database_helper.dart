
import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'habit_tracker.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit TEXT NOT NULL UNIQUE
      )
    ''');
  }

  Future<void> createHabitTable(int month, int year) async {
    final db = await database;
    final m = _getMonthName(month);
    final tableName = '$m$year';
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        day INTEGER UNIQUE
      )
    ''');
    final daysInMonth = DateTime(year, month + 1, 0).day;
    for (int i = 1; i <= daysInMonth; i++) {
      await db.rawInsert('INSERT OR IGNORE INTO $tableName (day) VALUES (?)', [i]);
    }
  }

  Future<List<Map<String, dynamic>>> getHabitTypes() async {
    final db = await database;
    return await db.query('habits');
  }

  Future<int> addHabitType(String habitName) async {
    final db = await database;
    return await db.insert('habits', {'habit': habitName}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<int> deleteHabitType(int id) async {
    final db = await database;
    return await db.delete('habits', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>> getHabitData(int month, int year) async {
    final db = await database;
    final m = _getMonthName(month);
    final tableName = '$m$year';

    try {
      final columns = await db.rawQuery('PRAGMA table_info($tableName)');
      final rows = await db.query(tableName);
      return {'columns': columns, 'rows': rows};
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return {'columns': [], 'rows': []};
    }
  }

  Future<void> updateHabitScore(int day, int month, int year, String habit, int score) async {
    final db = await database;
    final m = _getMonthName(month);
    final tableName = '$m$year';
    await db.update(
      tableName,
      {'"$habit"': score},
      where: 'day = ?',
      whereArgs: [day],
    );
  }

  Future<void> addHabitTypeToTable(int month, int year, String habit) async {
    final db = await database;
    final m = _getMonthName(month);
    final tableName = '$m$year';
    await db.execute('ALTER TABLE $tableName ADD COLUMN "$habit" INTEGER DEFAULT 0');
  }

  Future<void> deleteHabitTypeFromTable(int month, int year, String habit) async {
    final db = await database;
    final m = _getMonthName(month);
    final tableName = '$m$year';
    
    // SQLite doesn't support DROP COLUMN directly in all versions.
    // The recommended way is to create a new table and copy the data.
    
    // 1. Get the list of columns to keep
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    final columnsToKeep = columns.where((col) => col['name'] != habit).toList();
    final columnNames = columnsToKeep.map((col) => col['name'] as String).join(', ');

    // 2. Create a new table
    final newTableName = '${tableName}_new';
    final columnDefs = columnsToKeep.map((col) {
      return '${col['name']} ${col['type']}';
    }).join(', ');

    await db.execute('CREATE TABLE $newTableName ($columnDefs)');

    // 3. Copy the data
    await db.execute('INSERT INTO $newTableName ($columnNames) SELECT $columnNames FROM $tableName');

    // 4. Drop the old table
    await db.execute('DROP TABLE $tableName');

    // 5. Rename the new table
    await db.execute('ALTER TABLE $newTableName RENAME TO $tableName');
  }

  Future<void> createCompleteHabitTable(int month, int year) async {
    await createHabitTable(month, year);
    final habitTypes = await getHabitTypes();
    for (var habitType in habitTypes) {
      await addHabitTypeToTable(month, year, habitType['habit'] as String);
    }
  }

  String _getMonthName(int month) {
    const months = [
      'january', 'february', 'march', 'april', 'may', 'june',
      'july', 'august', 'september', 'october', 'november', 'december'
    ];
    return months[month - 1];
  }
}
