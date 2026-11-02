import 'dart:isolate';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'store.dart';

Future<CardStore> openStore() async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  final store = NativeCardStore('${dir.path}/handy-card.sqlite');
  final path = store.path;
  await Isolate.run(() => _open(path).close());
  return store;
}

Database _open(String path) {
  final db = sqlite3.open(path);
  try {
    if (db.userVersion > 1) {
      throw const FormatException(
        'This data was written by a newer Handy Card; it is kept untouched',
      );
    }
    db.execute(
      'PRAGMA busy_timeout=10000; PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL;',
    );
    if (db.userVersion == 0) {
      db.execute(
        'BEGIN IMMEDIATE; '
        'CREATE TABLE records(kind TEXT NOT NULL, id TEXT NOT NULL, json TEXT NOT NULL, PRIMARY KEY(kind, id)); '
        'CREATE TABLE assets(id TEXT PRIMARY KEY, bytes BLOB NOT NULL); '
        'PRAGMA user_version=1; COMMIT;',
      );
    }
    return db;
  } catch (_) {
    db.close();
    rethrow;
  }
}

/// SQLite in the app's support folder; each call runs in its own isolate
/// so the editor never waits on the disk.
class NativeCardStore implements CardStore {
  final String path;
  NativeCardStore(this.path);

  Future<T> _run<T>(T Function(Database db) task) {
    final file = path;
    return Isolate.run(() {
      final db = _open(file);
      try {
        return task(db);
      } finally {
        db.close();
      }
    });
  }

  @override
  Future<CardStoreData> read() => _run((db) {
    final records = <String, Map<String, String>>{};
    for (final row in db.select('SELECT kind, id, json FROM records')) {
      (records[row['kind'] as String] ??= {})[row['id'] as String] =
          row['json'] as String;
    }
    return CardStoreData(records, {
      for (final row in db.select('SELECT id FROM assets')) row['id'] as String,
    });
  });

  @override
  Future<void> put(String kind, String id, String json) => _run(
    (db) => db.execute(
      'INSERT INTO records(kind, id, json) VALUES(?, ?, ?) '
      'ON CONFLICT(kind, id) DO UPDATE SET json = excluded.json',
      [kind, id, json],
    ),
  );

  @override
  Future<void> delete(String kind, String id) => _run(
    (db) =>
        db.execute('DELETE FROM records WHERE kind = ? AND id = ?', [kind, id]),
  );

  @override
  Future<void> putAsset(String id, Uint8List bytes) => _run(
    (db) => db.execute('INSERT OR IGNORE INTO assets(id, bytes) VALUES(?, ?)', [
      id,
      bytes,
    ]),
  );

  @override
  Future<Uint8List?> asset(String id) => _run((db) {
    final rows = db.select('SELECT bytes FROM assets WHERE id = ?', [id]);
    return rows.isEmpty
        ? null
        : Uint8List.fromList(rows.single['bytes'] as Uint8List);
  });

  @override
  Future<void> deleteAssets(Set<String> ids) => _run((db) {
    db.execute('BEGIN');
    for (final id in ids) {
      db.execute('DELETE FROM assets WHERE id = ?', [id]);
    }
    db.execute('COMMIT');
  });
}
