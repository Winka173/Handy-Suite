import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'store.dart';

Future<HabitStore> openStore() async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  return NativeHabitStore(
    '${directory.path}${Platform.pathSeparator}handy-habit.sqlite',
  );
}

const entities = ['habits', 'events', 'routines', 'sessions'];
Database database(String path) {
  final db = sqlite3.open(path);
  try {
    if (db.userVersion > 1)
      throw const FormatException('Newer database schema; preserved');
    db.execute(
      'PRAGMA foreign_keys=ON; PRAGMA busy_timeout=10000; PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL;',
    );
    if (db.userVersion == 0) {
      db.execute('BEGIN IMMEDIATE');
      try {
        db.execute(
          'CREATE TABLE habits(id TEXT PRIMARY KEY,payload TEXT NOT NULL); CREATE TABLE events(id TEXT PRIMARY KEY,habit TEXT NOT NULL REFERENCES habits(id),day TEXT NOT NULL,source TEXT NOT NULL,session TEXT,step TEXT,payload TEXT NOT NULL); CREATE INDEX habit_day ON events(habit,day); CREATE INDEX event_day ON events(day); CREATE UNIQUE INDEX linked_once ON events(session,step) WHERE source=\'routine\'; CREATE TABLE routines(id TEXT PRIMARY KEY,payload TEXT NOT NULL); CREATE TABLE sessions(id TEXT PRIMARY KEY,status TEXT NOT NULL,payload TEXT NOT NULL); CREATE INDEX session_status ON sessions(status); CREATE TABLE state(id INTEGER PRIMARY KEY CHECK(id=1),revision INTEGER NOT NULL,payload TEXT NOT NULL); PRAGMA user_version=1;',
        );
        final initial = HabitState().toJson();
        for (final key in entities) {
          initial.remove(key);
        }
        db.execute('INSERT INTO state VALUES(1,0,?)', [jsonEncode(initial)]);
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    }
    return db;
  } catch (_) {
    db.close();
    rethrow;
  }
}

class NativeHabitStore implements HabitStore {
  final String path;
  NativeHabitStore(this.path);
  @override
  Future<HabitState> read() {
    final file = path;
    return Isolate.run(() {
      final db = database(file);
      try {
        db.execute('BEGIN');
        final json = Map<String, dynamic>.from(
          jsonDecode(
                db
                        .select('SELECT payload FROM state WHERE id=1')
                        .single['payload']
                    as String,
              )
              as Map,
        );
        for (final kind in entities) {
          json[kind] = db
              .select('SELECT payload FROM $kind ORDER BY rowid')
              .map((row) => jsonDecode(row['payload'] as String))
              .toList();
        }
        db.execute('COMMIT');
        return HabitState.fromJson(json);
      } finally {
        db.close();
      }
    });
  }

  @override
  Future<void> commit(HabitState next, {required int expectedRevision}) {
    final file = path;
    return Isolate.run(() {
      next.validate();
      final db = database(file);
      try {
        db.execute('BEGIN IMMEDIATE');
        try {
          if (db
                      .select('SELECT revision FROM state WHERE id=1')
                      .single['revision'] !=
                  expectedRevision ||
              next.revision != expectedRevision + 1)
            throw StateError('Stale revision; reload');
          final json = next.toJson(), old = <String, Map<String, String>>{};
          for (final kind in entities) {
            old[kind] = {
              for (final row in db.select('SELECT id,payload FROM $kind'))
                row['id'] as String: row['payload'] as String,
            };
          }
          // Remove dependent events before habits; insertion order reverses that dependency.
          for (final kind in ['events', 'sessions', 'routines', 'habits']) {
            final ids = (json[kind] as List)
                .map((e) => (e as Map)['id'])
                .toSet();
            for (final id in old[kind]!.keys.where((id) => !ids.contains(id))) {
              db.execute('DELETE FROM $kind WHERE id=?', [id]);
            }
          }
          for (final kind in entities) {
            for (final record in json[kind] as List) {
              final row = record as Map,
                  id = row['id'] as String,
                  payload = jsonEncode(row);
              if (old[kind]![id] == payload) continue;
              if (kind == 'events') {
                db.execute(
                  'INSERT INTO events VALUES(?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET habit=excluded.habit,day=excluded.day,source=excluded.source,session=excluded.session,step=excluded.step,payload=excluded.payload',
                  [
                    id,
                    row['habit'],
                    row['day'],
                    row['source'],
                    row['session'],
                    row['step'],
                    payload,
                  ],
                );
              } else if (kind == 'sessions') {
                db.execute(
                  'INSERT INTO sessions VALUES(?,?,?) ON CONFLICT(id) DO UPDATE SET status=excluded.status,payload=excluded.payload',
                  [id, row['status'], payload],
                );
              } else {
                db.execute(
                  'INSERT INTO $kind VALUES(?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',
                  [id, payload],
                );
              }
            }
            json.remove(kind);
          }
          db.execute('UPDATE state SET revision=?,payload=? WHERE id=1', [
            next.revision,
            jsonEncode(json),
          ]);
          db.execute('COMMIT');
        } catch (_) {
          db.execute('ROLLBACK');
          rethrow;
        }
      } finally {
        db.close();
      }
    });
  }

  @override
  Future<String> integrity() {
    final file = path;
    return Isolate.run(() {
      final db = database(file);
      try {
        return db.select('PRAGMA quick_check').single.values.first.toString();
      } finally {
        db.close();
      }
    });
  }
}
