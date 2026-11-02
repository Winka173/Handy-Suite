import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:handy_trip_engine/handy_trip_engine.dart';
import 'store.dart';

Future<TripStore> openStore() async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return NativeTripStore('${dir.path}/handy-trip.sqlite');
}

Database openTripDatabase(String path) {
  final db = sqlite3.open(path);
  try {
    if (db.userVersion > 1)
      throw const FormatException('Newer Trip schema; preserved');
    db.execute(
      'PRAGMA foreign_keys=ON; PRAGMA busy_timeout=10000; PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL;',
    );
    if (db.userVersion == 0) {
      db.execute('BEGIN IMMEDIATE');
      try {
        for (final k in collections) {
          db.execute(
            'CREATE TABLE $k(id TEXT PRIMARY KEY,payload TEXT NOT NULL,trip_id TEXT REFERENCES trips(id) DEFERRABLE INITIALLY DEFERRED,place_id TEXT REFERENCES places(id) DEFERRABLE INITIALLY DEFERRED,stop_id TEXT REFERENCES stops(id) DEFERRABLE INITIALLY DEFERRED,visit_id TEXT REFERENCES visits(id) DEFERRABLE INITIALLY DEFERRED,local_day TEXT,event_at TEXT,status TEXT)',
          );
          db.execute(
            'CREATE INDEX ${k}_trip_day ON $k(trip_id,local_day); CREATE INDEX ${k}_place_time ON $k(place_id,event_at); CREATE INDEX ${k}_status ON $k(status)',
          );
        }
        db.execute(
          'CREATE TABLE files(path TEXT PRIMARY KEY,checksum TEXT NOT NULL,body BLOB NOT NULL); CREATE TABLE metadata(id INTEGER PRIMARY KEY CHECK(id=1),revision INTEGER NOT NULL,payload TEXT NOT NULL);',
        );
        final header = TripState().toJson(includeData: false);
        for (final k in collections) header.remove(k);
        db.execute('INSERT INTO metadata VALUES(1,0,?)', [jsonEncode(header)]);
        db.execute('PRAGMA user_version=1; COMMIT');
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

class NativeTripStore implements TripStore {
  final String path;
  NativeTripStore(this.path);
  @override
  Future<TripState> read() {
    final file = path;
    return Isolate.run(() {
      final db = openTripDatabase(file);
      try {
        db.execute('BEGIN');
        final data = object(
          jsonDecode(
            db
                    .select('SELECT payload FROM metadata WHERE id=1')
                    .single['payload']
                as String,
          ),
        );
        for (final k in collections)
          data[k] = db
              .select('SELECT payload FROM $k ORDER BY rowid')
              .map((r) => jsonDecode(r['payload'] as String))
              .toList();
        final files = {
          for (final row in db.select('SELECT path,body FROM files'))
            row['path'] as String: Uint8List.fromList(row['body'] as Uint8List),
        };
        final state = TripState.fromJson(data, files: files);
        db.execute('COMMIT');
        return state;
      } finally {
        db.close();
      }
    });
  }

  @override
  Future<void> commit(TripState next, {required int expectedRevision}) {
    next.validate();
    final file = path;
    return Isolate.run(() {
      final db = openTripDatabase(file);
      try {
        db.execute('BEGIN IMMEDIATE');
        try {
          final previous = db
              .select('SELECT revision FROM metadata WHERE id=1')
              .single['revision'];
          if (previous != expectedRevision ||
              next.revision != expectedRevision + 1)
            throw StateError('Stale Trip revision; reload');
          for (final kind in collections) {
            final old = {
                  for (final row in db.select('SELECT id,payload FROM $kind'))
                    row['id'] as String: row['payload'] as String,
                },
                keys = next.entities(kind).map((v) => v.key).toSet();
            for (final key in old.keys.where((k) => !keys.contains(k)))
              db.execute('DELETE FROM $kind WHERE id=?', [key]);
            for (final entity in next.entities(kind)) {
              final j = entity.toJson(), body = jsonEncode(j);
              if (old[entity.key] == body) continue;
              String? local = j['day'] as String?;
              if (local == null && j['at'] != null)
                local = localDay(
                  DateTime.parse(j['at']),
                  j['zone'] ??
                      (j['trip'] == null ? 'UTC' : next.trip(j['trip']).zone),
                );
              db.execute(
                'INSERT INTO $kind VALUES(?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,trip_id=excluded.trip_id,place_id=excluded.place_id,stop_id=excluded.stop_id,visit_id=excluded.visit_id,local_day=excluded.local_day,event_at=excluded.event_at,status=excluded.status',
                [
                  entity.key,
                  body,
                  j['trip'],
                  j['place'],
                  j['stop'],
                  j['visit'],
                  local,
                  j['at'] ?? j['start'],
                  j['status'],
                ],
              );
            }
          }
          final oldFiles = {
            for (final row in db.select('SELECT path,checksum FROM files'))
              row['path'] as String: row['checksum'] as String,
          };
          for (final key in oldFiles.keys.where(
            (k) => !next.files.containsKey(k),
          ))
            db.execute('DELETE FROM files WHERE path=?', [key]);
          for (final entry in next.files.entries) {
            final hash = sha256.convert(entry.value).toString();
            if (oldFiles[entry.key] != hash)
              db.execute(
                'INSERT INTO files VALUES(?,?,?) ON CONFLICT(path) DO UPDATE SET checksum=excluded.checksum,body=excluded.body',
                [entry.key, hash, entry.value],
              );
          }
          final header = next.toJson(includeData: false);
          for (final k in collections) header.remove(k);
          db.execute('UPDATE metadata SET revision=?,payload=? WHERE id=1', [
            next.revision,
            jsonEncode(header),
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
      final db = openTripDatabase(file);
      try {
        return db.select('PRAGMA quick_check').single.values.first.toString();
      } finally {
        db.close();
      }
    });
  }
}
