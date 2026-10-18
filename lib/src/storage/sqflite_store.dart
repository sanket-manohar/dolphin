import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/dolphin_progress.dart';
import 'dolphin_store.dart';

/// Keeps progress in a local SQLite database, one row per step, scope and
/// journey, so large apps with many pages stay fast.
///
/// Pass [databaseFactory] to use `sqflite_common_ffi` on desktop or in tests.
class SqfliteDolphinStore extends DolphinStore {
  SqfliteDolphinStore({
    this.databaseName = 'dolphin.db',
    DatabaseFactory? databaseFactory,
  }) : _factory = databaseFactory;

  final String databaseName;
  final DatabaseFactory? _factory;
  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final f = _factory ?? databaseFactory;
    final path = databaseName == inMemoryDatabasePath
        ? databaseName
        : '${await f.getDatabasesPath()}/$databaseName';
    return _db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('CREATE TABLE wk_steps (key TEXT PRIMARY KEY, '
              'scope TEXT NOT NULL, data TEXT NOT NULL)');
          await db.execute('CREATE INDEX wk_steps_scope ON wk_steps(scope)');
          await db.execute(
              'CREATE TABLE wk_scopes (scope TEXT PRIMARY KEY, data TEXT NOT NULL)');
          await db.execute(
              'CREATE TABLE wk_journeys (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
          await db.execute(
              'CREATE TABLE wk_meta (key TEXT PRIMARY KEY, value TEXT)');
        },
      ),
    );
  }

  @override
  Future<void> init() async => _database;

  @override
  Future<DolphinProgress> loadProgress() async {
    final db = await _database;
    Map<String, dynamic> dec(Object? s) =>
        Map<String, dynamic>.from(jsonDecode(s as String) as Map);
    final meta = {
      for (final r in await db.query('wk_meta')) r['key'] as String: r['value']
    };
    final steps = <String, StepRecord>{};
    for (final r in await db.query('wk_steps')) {
      final rec = StepRecord.fromJson(dec(r['data']));
      if (rec != null) steps[rec.key] = rec;
    }
    final scopes = <String, ScopeRecord>{};
    for (final r in await db.query('wk_scopes')) {
      final rec = ScopeRecord.fromJson(dec(r['data']));
      if (rec != null) scopes[rec.scope] = rec;
    }
    final journeys = <String, JourneyRecord>{};
    for (final r in await db.query('wk_journeys')) {
      final rec = JourneyRecord.fromJson(dec(r['data']));
      if (rec != null) journeys[rec.id] = rec;
    }
    return DolphinProgress(
      steps: steps,
      scopes: scopes,
      journeys: journeys,
      resetAt: DateTime.tryParse('${meta['resetAt']}'),
      updatedAt: DateTime.tryParse('${meta['updatedAt']}'),
    );
  }

  @override
  Future<void> saveProgress(DolphinProgress p, ProgressDelta delta) async {
    final db = await _database;
    await db.transaction((txn) async {
      if (delta.full) {
        await txn.delete('wk_steps');
        await txn.delete('wk_scopes');
        await txn.delete('wk_journeys');
      }
      final stepKeys = delta.full ? p.steps.keys : delta.steps;
      for (final k in stepKeys) {
        final r = p.steps[k];
        if (r == null) {
          await txn.delete('wk_steps', where: 'key = ?', whereArgs: [k]);
        } else {
          await txn.insert('wk_steps',
              {'key': k, 'scope': r.scope, 'data': jsonEncode(r.toJson())},
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      final scopeKeys = delta.full ? p.scopes.keys : delta.scopes;
      for (final k in scopeKeys) {
        final r = p.scopes[k];
        if (r == null) {
          await txn.delete('wk_scopes', where: 'scope = ?', whereArgs: [k]);
        } else {
          await txn.insert(
              'wk_scopes', {'scope': k, 'data': jsonEncode(r.toJson())},
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      final journeyKeys = delta.full ? p.journeys.keys : delta.journeys;
      for (final k in journeyKeys) {
        final r = p.journeys[k];
        if (r == null) {
          await txn.delete('wk_journeys', where: 'id = ?', whereArgs: [k]);
        } else {
          await txn.insert(
              'wk_journeys', {'id': k, 'data': jsonEncode(r.toJson())},
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      for (final e in {
        'resetAt': p.resetAt?.toUtc().toIso8601String(),
        'updatedAt': p.updatedAt?.toUtc().toIso8601String(),
      }.entries) {
        await txn.insert('wk_meta', {'key': e.key, 'value': e.value},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  @override
  Future<void> clearProgress() async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('wk_steps');
      await txn.delete('wk_scopes');
      await txn.delete('wk_journeys');
      await txn.delete('wk_meta');
    });
  }

  @override
  Future<Map<String, Object?>> loadFlags() async {
    final db = await _database;
    final rows = await db.query('wk_meta', where: "key LIKE 'flag.%'");
    return {
      for (final r in rows)
        (r['key'] as String).substring(5): _decodeFlag(r['value'] as String?)
    };
  }

  @override
  Future<void> setFlag(String key, Object? value) async {
    final db = await _database;
    if (value == null) {
      await db.delete('wk_meta', where: 'key = ?', whereArgs: ['flag.$key']);
    } else {
      await db.insert(
          'wk_meta', {'key': 'flag.$key', 'value': jsonEncode(value)},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Object? _decodeFlag(String? raw) {
    if (raw == null) return null;
    try {
      final v = jsonDecode(raw);
      if (v is List) return v.map((e) => e.toString()).toList();
      return v;
    } catch (_) {
      return raw;
    }
  }

  @override
  Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }
}
