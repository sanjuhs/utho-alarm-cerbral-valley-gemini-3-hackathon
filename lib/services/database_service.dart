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
      version: 1,
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
      },
    );
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
