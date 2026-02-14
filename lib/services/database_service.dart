import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/alarm.dart';
import '../models/task.dart';
import '../models/session.dart';
import '../models/preferences.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = p.join(await getDatabasesPath(), 'utho.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE alarms (
            id TEXT PRIMARY KEY,
            time INTEGER NOT NULL,
            label TEXT DEFAULT '',
            enabled INTEGER DEFAULT 1,
            repeat_days TEXT DEFAULT '',
            ringtone TEXT DEFAULT 'default',
            vibrate INTEGER DEFAULT 1,
            focus_label TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            due_time INTEGER,
            priority INTEGER DEFAULT 2,
            status TEXT DEFAULT 'pending',
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sessions (
            id TEXT PRIMARY KEY,
            date INTEGER NOT NULL,
            summary TEXT DEFAULT '',
            mode TEXT DEFAULT 'best_friend',
            alarms_created INTEGER DEFAULT 0,
            tasks_created INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE preferences (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await _createHistoryTable(db);
        await _createWalletTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createHistoryTable(db);
        }
        if (oldVersion < 3) {
          await _createWalletTable(db);
          // Add new columns to alarm_history if they're missing
          try { await db.execute('ALTER TABLE alarm_history ADD COLUMN session_id TEXT'); } catch (_) {}
          try { await db.execute('ALTER TABLE alarm_history ADD COLUMN persona TEXT'); } catch (_) {}
        }
      },
    );
  }

  static Future<void> _createHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS alarm_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        label TEXT NOT NULL,
        alarm_time INTEGER,
        session_id TEXT,
        persona TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  // ── Alarms ──
  static Future<List<Alarm>> getAlarms() async {
    final rows = await (await db).query('alarms', orderBy: 'time ASC');
    return rows.map(Alarm.fromMap).toList();
  }

  static Future<void> upsertAlarm(Alarm alarm) async {
    await (await db).insert('alarms', alarm.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteAlarm(String id) async {
    await (await db).delete('alarms', where: 'id = ?', whereArgs: [id]);
  }

  // ── Tasks ──
  static Future<List<Task>> getTasks({bool todayOnly = false}) async {
    final database = await db;
    if (todayOnly) {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      final endOfDay = startOfDay + 86400000;
      return (await database.query('tasks',
              where: '(due_time IS NULL OR (due_time >= ? AND due_time < ?)) AND status = ?',
              whereArgs: [startOfDay, endOfDay, 'pending'],
              orderBy: 'priority ASC, due_time ASC'))
          .map(Task.fromMap)
          .toList();
    }
    return (await database.query('tasks', orderBy: 'priority ASC, due_time ASC'))
        .map(Task.fromMap)
        .toList();
  }

  static Future<void> upsertTask(Task task) async {
    await (await db).insert('tasks', task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteTask(String id) async {
    await (await db).delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // ── Sessions ──
  static Future<void> saveSession(Session session) async {
    await (await db).insert('sessions', session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Session>> getRecentSessions({int limit = 7}) async {
    return (await (await db).query('sessions', orderBy: 'date DESC', limit: limit))
        .map(Session.fromMap)
        .toList();
  }

  // ── Wallet / Gamification ──
  static Future<void> _createWalletTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wallet (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        reason TEXT NOT NULL,
        persona TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  static Future<int> getWalletBalance() async {
    final rows = await (await db)
        .rawQuery('SELECT COALESCE(SUM(amount), 0) as total FROM wallet');
    return (rows.first['total'] as int?) ?? 0;
  }

  static Future<void> addWalletTransaction(
      int amount, String reason, String persona) async {
    await (await db).insert('wallet', {
      'amount': amount,
      'reason': reason,
      'persona': persona,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<List<Map<String, dynamic>>> getWalletHistory(
      {int limit = 50}) async {
    return (await db)
        .query('wallet', orderBy: 'created_at DESC', limit: limit);
  }

  // ── Alarm History ──
  static Future<void> logAlarmAction(
      String action, String label, DateTime alarmTime,
      {String? sessionId, String? persona}) async {
    await (await db).insert('alarm_history', {
      'action': action,
      'label': label,
      'alarm_time': alarmTime.millisecondsSinceEpoch,
      'session_id': sessionId,
      'persona': persona,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<List<Map<String, dynamic>>> getAlarmHistory(
      {int limit = 50}) async {
    return (await db).query('alarm_history',
        orderBy: 'created_at DESC', limit: limit);
  }

  // ── Preferences ──
  static Future<UserPreferences> getPreferences() async {
    final rows = await (await db).query('preferences');
    if (rows.isEmpty) return const UserPreferences();
    final map = <String, dynamic>{};
    for (final row in rows) {
      final key = row['key'] as String;
      final value = row['value'] as String;
      // Parse ints back
      if (key == 'default_reminder_cadence_minutes' || key == 'use_byok') {
        map[key] = int.tryParse(value) ?? value;
      } else {
        map[key] = value;
      }
    }
    return UserPreferences.fromMap(map);
  }

  static Future<void> savePreferences(UserPreferences prefs) async {
    final database = await db;
    final batch = database.batch();
    prefs.toMap().forEach((key, value) {
      batch.insert('preferences', {'key': key, 'value': value.toString()},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
    await batch.commit(noResult: true);
  }
}
