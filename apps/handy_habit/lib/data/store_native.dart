import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'store.dart';
import 'delta.dart';

Future<HabitStore> openStore() async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  return NativeHabitStore(
    '${directory.path}${Platform.pathSeparator}handy-habit.sqlite',
  );
}

const entities = ['habits', 'events', 'routines', 'sessions', 'operations'];
Database database(String path) {
  final db = sqlite3.open(path);
  try {
    if (db.userVersion > 2)
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
    if (db.userVersion == 1) {
      // VACUUM includes committed WAL pages. Preserve the first pre-migration copy.
      final recoveryFile = File('$path.pre-v2.sqlite');
      if (!recoveryFile.existsSync()) {
        final temporary = '$path.pre-v2.tmp-${uid()}';
        try {
          db.execute('VACUUM INTO ?', [temporary]);
          final handle = File(temporary).openSync(mode: FileMode.append);
          try {
            handle.flushSync();
          } finally {
            handle.closeSync();
          }
          File(temporary).renameSync(recoveryFile.path);
        } finally {
          if (File(temporary).existsSync()) File(temporary).deleteSync();
        }
      }
      db.execute('BEGIN IMMEDIATE');
      try {
        // Recheck after obtaining the write lock (another opener may have migrated).
        if (db.userVersion == 1) {
          final raw = Map<String, dynamic>.from(
            jsonDecode(
                  db
                          .select('SELECT payload FROM state WHERE id=1')
                          .single['payload']
                      as String,
                )
                as Map,
          );
          for (final kind in ['habits', 'events', 'routines', 'sessions']) {
            raw[kind] = db
                .select('SELECT payload FROM $kind ORDER BY rowid')
                .map((r) => jsonDecode(r['payload'] as String))
                .toList();
          }
          final migrated = HabitState.fromJson(raw);
          db.execute(
            'CREATE TABLE operations(id TEXT PRIMARY KEY,actor TEXT NOT NULL,sequence INTEGER NOT NULL,kind TEXT NOT NULL,entity TEXT NOT NULL,payload TEXT NOT NULL,UNIQUE(actor,sequence)); CREATE INDEX operation_entity ON operations(kind,entity); CREATE TABLE recovery(id INTEGER PRIMARY KEY CHECK(id=1),payload TEXT NOT NULL);',
          );
          for (final op in migrated.operations) {
            db.execute('INSERT INTO operations VALUES(?,?,?,?,?,?)', [
              op.id,
              op.actor,
              op.sequence,
              op.kind,
              op.entity,
              jsonEncode(op.toJson()),
            ]);
          }
          final metadata = migrated.toJson();
          for (final kind in entities) {
            metadata.remove(kind);
          }
          db.execute('UPDATE state SET payload=? WHERE id=1', [
            jsonEncode(metadata),
          ]);
          db.execute('PRAGMA user_version=2');
        }
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

class NativeHabitStore implements RecoverableHabitStore, IncrementalHabitStore {
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
  Future<void> commit(HabitState next, {required int expectedRevision}) =>
      _commit(next, expectedRevision: expectedRevision);
  @override
  Future<void> commitDelta(
    HabitState previous,
    HabitState next, {
    required int expectedRevision,
  }) => _commit(next, expectedRevision: expectedRevision, previous: previous);
  Future<void> _commit(
    HabitState next, {
    required int expectedRevision,
    HabitState? previous,
  }) async {
    // Validate in the originating isolate, where an immutable controller snapshot
    // is already cached. Sending it to the writer cannot mutate its contents.
    validateStoredCounts(next);
    next.validate();
    final file = path;
    await Isolate.run(() {
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
          final delta = previous == null ? null : HabitDelta(previous, next);
          if (previous != null && previous.revision != expectedRevision)
            throw StateError('Invalid delta base');
          final json = delta == null
                  ? next.toJson()
                  : {...next.metadataJson(), ...delta.changed},
              old = <String, Map<String, String>>{};
          for (final kind in entities) {
            old[kind] = delta == null
                ? {
                    for (final row in db.select('SELECT id,payload FROM $kind'))
                      row['id'] as String: row['payload'] as String,
                  }
                : {
                    for (final id in delta.removed[kind]!) id: '',
                    for (final row in delta.changed[kind]!)
                      row['id'] as String: '',
                  };
          }
          // Remove dependent events before habits; insertion order reverses that dependency.
          for (final kind in [
            'operations',
            'events',
            'sessions',
            'routines',
            'habits',
          ]) {
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
              if (kind == 'operations') {
                db.execute(
                  'INSERT INTO operations VALUES(?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',
                  [
                    id,
                    row['actor'],
                    row['sequence'],
                    row['kind'],
                    row['entity'],
                    payload,
                  ],
                );
              } else if (kind == 'events') {
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
  Future<void> saveRecovery({required int expectedRevision}) {
    final file = path;
    return Isolate.run(() {
      final db = database(file);
      try {
        db.execute('BEGIN IMMEDIATE');
        try {
          final row = db
              .select('SELECT revision,payload FROM state WHERE id=1')
              .single;
          if (row['revision'] != expectedRevision)
            throw StateError('Data changed during preview');
          final raw = Map<String, dynamic>.from(
            jsonDecode(row['payload'] as String) as Map,
          );
          for (final kind in entities) {
            raw[kind] = db
                .select('SELECT payload FROM $kind ORDER BY rowid')
                .map((r) => jsonDecode(r['payload'] as String))
                .toList();
          }
          final snapshot = HabitState.fromJson(raw);
          db.execute(
            'INSERT INTO recovery VALUES(1,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',
            [jsonEncode(snapshot.toJson())],
          );
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
  Future<HabitState?> readRecovery() {
    final file = path;
    return Isolate.run(() {
      final db = database(file);
      try {
        final rows = db.select('SELECT payload FROM recovery WHERE id=1');
        return rows.isEmpty
            ? null
            : HabitState.fromJson(
                Map<String, dynamic>.from(
                  jsonDecode(rows.single['payload'] as String) as Map,
                ),
              );
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
