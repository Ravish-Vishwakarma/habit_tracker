import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

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
    final documentsDirectory = await getApplicationSupportDirectory();
    final path = join(documentsDirectory.path, 'habit_tracker.db');
    return openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createHabitTables(db);
        await _createMonthHabitTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createMonthHabitTables(db);
        } else if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE habit_months ADD COLUMN is_customized '
            'INTEGER NOT NULL DEFAULT 0',
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE habits ADD COLUMN is_global '
            'INTEGER NOT NULL DEFAULT 1',
          );
        }
      },
    );
  }

  Future<void> _createHabitTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE habits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit TEXT NOT NULL UNIQUE,
        is_global INTEGER NOT NULL DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
      CREATE TABLE habits_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        status INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (habit_id) REFERENCES habits(id),
        UNIQUE (habit_id, date)
      )
    ''');
  }

  Future<void> _createMonthHabitTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS habit_months (
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        is_customized INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (month, year)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS month_habits (
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        habit_id INTEGER NOT NULL,
        PRIMARY KEY (month, year, habit_id)
      )
    ''');
  }

  Future<List<Map<String, dynamic>>> getHabitTypes() async {
    final db = await database;
    return db.query('habits', where: 'is_global = 1', orderBy: 'id');
  }

  Future<int> addHabitType(String habitName) async {
    final db = await database;
    return db.transaction((txn) async {
      final id = await txn.insert('habits', {
        'habit': habitName,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.update(
        'habits',
        {'is_global': 1},
        where: 'habit = ?',
        whereArgs: [habitName],
      );
      return id;
    });
  }

  Future<int> deleteHabitType(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      await txn.rawDelete(
        '''
        DELETE FROM month_habits
        WHERE habit_id = ?
          AND EXISTS (
            SELECT 1
            FROM habit_months
            WHERE habit_months.month = month_habits.month
              AND habit_months.year = month_habits.year
              AND habit_months.is_customized = 0
          )
        ''',
        [id],
      );
      return txn.update(
        'habits',
        {'is_global': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<List<Map<String, dynamic>>> getMonthHabits(int month, int year) async {
    final db = await database;
    await _ensureMonthHabits(db, month, year);
    return db.rawQuery(
      '''
      SELECT habits.id, habits.habit
      FROM month_habits
      INNER JOIN habits ON habits.id = month_habits.habit_id
      WHERE month_habits.month = ? AND month_habits.year = ?
      ORDER BY habits.id
      ''',
      [month, year],
    );
  }

  Future<Map<String, int>> getMonthHabitStatuses(int month, int year) async {
    final db = await database;
    final startDate = _formatDate(year, month, 1);
    final endDate = _formatDate(year, month, DateTime(year, month + 1, 0).day);
    final logs = await db.query(
      'habits_logs',
      columns: ['habit_id', 'date', 'status'],
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
    );

    return {
      for (final log in logs)
        '${log['habit_id']}:${int.parse((log['date'] as String).substring(8, 10))}':
            log['status'] as int,
    };
  }

  Future<Map<String, List<Map<String, dynamic>>>> getYearHabitActivity(
    int year,
  ) async {
    final db = await database;
    final startDate = _formatDate(year, 1, 1);
    final endDate = _formatDate(year, 12, 31);
    final habits = await db.rawQuery(
      '''
      SELECT id, habit
      FROM habits
      WHERE is_global = 1
         OR id IN (
           SELECT habit_id FROM month_habits WHERE year = ?
         )
         OR id IN (
           SELECT habit_id FROM habits_logs
           WHERE date >= ? AND date <= ? AND status > 0
         )
      ORDER BY id
      ''',
      [year, startDate, endDate],
    );
    final logs = await db.query(
      'habits_logs',
      columns: ['habit_id', 'date'],
      where: 'date >= ? AND date <= ? AND status > 0',
      whereArgs: [startDate, endDate],
    );
    return {'habits': habits, 'logs': logs};
  }

  Future<void> updateHabitScore(
    int day,
    int month,
    int year,
    int habitId,
    int score,
  ) async {
    final db = await database;
    final date = _formatDate(year, month, day);
    if (score == 0) {
      await db.delete(
        'habits_logs',
        where: 'habit_id = ? AND date = ?',
        whereArgs: [habitId, date],
      );
      return;
    }

    await db.insert('habits_logs', {
      'habit_id': habitId,
      'date': date,
      'status': score,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> addHabitToMonth(int month, int year, String habitName) async {
    final db = await database;
    await _ensureMonthHabits(db, month, year);
    await db.transaction((txn) async {
      await txn.insert('habits', {
        'habit': habitName,
        'is_global': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final habits = await txn.query(
        'habits',
        columns: ['id'],
        where: 'habit = ?',
        whereArgs: [habitName],
        limit: 1,
      );
      final habitId = habits.single['id'] as int;
      await txn.insert('month_habits', {
        'month': month,
        'year': year,
        'habit_id': habitId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.update(
        'habit_months',
        {'is_customized': 1},
        where: 'month = ? AND year = ?',
        whereArgs: [month, year],
      );
    });
  }

  Future<void> deleteHabitFromMonth(int month, int year, int habitId) async {
    final db = await database;
    await db.delete(
      'month_habits',
      where: 'month = ? AND year = ? AND habit_id = ?',
      whereArgs: [month, year, habitId],
    );
    await db.update(
      'habit_months',
      {'is_customized': 1},
      where: 'month = ? AND year = ?',
      whereArgs: [month, year],
    );
  }

  Future<void> _ensureMonthHabits(Database db, int month, int year) async {
    await db.transaction((txn) async {
      final configuredMonth = await txn.query(
        'habit_months',
        columns: ['is_customized'],
        where: 'month = ? AND year = ?',
        whereArgs: [month, year],
        limit: 1,
      );
      if (configuredMonth.isNotEmpty) {
        if (configuredMonth.single['is_customized'] == 0) {
          final habits = await txn.query(
            'habits',
            columns: ['id'],
            where: 'is_global = 1',
          );
          for (final habit in habits) {
            await txn.insert('month_habits', {
              'month': month,
              'year': year,
              'habit_id': habit['id'],
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
        return;
      }

      final legacyTable = '${_getMonthName(month)}$year';
      final legacyTables = await txn.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        [legacyTable],
      );
      var legacyHabits = <String>[];
      if (legacyTables.isNotEmpty) {
        final columns = await txn.rawQuery('PRAGMA table_info("$legacyTable")');
        legacyHabits = columns
            .map((column) => column['name'] as String)
            .where((name) => name != 'day')
            .toList();
      }

      await txn.insert('habit_months', {
        'month': month,
        'year': year,
        'is_customized': legacyHabits.isNotEmpty ? 1 : 0,
      });

      if (legacyHabits.isNotEmpty) {
        await _importLegacyMonth(txn, legacyTable, month, year, legacyHabits);
      } else {
        final habits = await txn.query(
          'habits',
          columns: ['id'],
          where: 'is_global = 1',
        );
        for (final habit in habits) {
          await txn.insert('month_habits', {
            'month': month,
            'year': year,
            'habit_id': habit['id'],
          });
        }
      }
    });
  }

  Future<void> _importLegacyMonth(
    Transaction txn,
    String tableName,
    int month,
    int year,
    List<String> habitNames,
  ) async {
    final habitIds = <String, int>{};
    for (final habitName in habitNames) {
      await txn.insert('habits', {
        'habit': habitName,
        'is_global': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final rows = await txn.query(
        'habits',
        columns: ['id'],
        where: 'habit = ?',
        whereArgs: [habitName],
        limit: 1,
      );
      final habitId = rows.single['id'] as int;
      habitIds[habitName] = habitId;
      await txn.insert('month_habits', {
        'month': month,
        'year': year,
        'habit_id': habitId,
      });
    }

    final rows = await txn.query(tableName);
    for (final row in rows) {
      final day = row['day'] as int;
      for (final habitName in habitNames) {
        final status = row[habitName];
        if (status is num && status != 0) {
          await txn.insert('habits_logs', {
            'habit_id': habitIds[habitName],
            'date': _formatDate(year, month, day),
            'status': status.toInt(),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    }
  }

  String _formatDate(int year, int month, int day) {
    return '${year.toString().padLeft(4, '0')}-'
        '${month.toString().padLeft(2, '0')}-'
        '${day.toString().padLeft(2, '0')}';
  }

  String _getMonthName(int month) {
    const months = [
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
    ];
    return months[month - 1];
  }
}
