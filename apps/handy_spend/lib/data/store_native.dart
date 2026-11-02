import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'store.dart';

Future<SpendStore> openStore() async {
  final d = await getApplicationSupportDirectory();
  await d.create(recursive: true);
  return NativeSpendStore(
    '${d.path}${Platform.pathSeparator}handy-spend.sqlite',
  );
}

Database _database(String path) {
  final db = sqlite3.open(path);
  try {
    db.execute('PRAGMA foreign_keys=ON; PRAGMA busy_timeout=10000;');
    final version = db.userVersion;
    if (version > 2)
      throw StateError('Newer database version; no changes made');
    db.execute('PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL;');
    if (version == 1) {
      // Schema 2: receipt files in their own table. The ledger rows are
      // read as they are; SpendState upgrades their JSON on the next write.
      db.execute('BEGIN IMMEDIATE');
      try {
        db.execute(
          'CREATE TABLE receipts(id TEXT PRIMARY KEY,bytes BLOB NOT NULL); PRAGMA user_version=2;',
        );
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    }
    if (version == 0) {
      db.execute('BEGIN IMMEDIATE');
      try {
        db.execute(
          'CREATE TABLE accounts(id TEXT PRIMARY KEY,payload TEXT NOT NULL); CREATE TABLE entries(id TEXT PRIMARY KEY,account TEXT NOT NULL REFERENCES accounts(id),destination TEXT REFERENCES accounts(id),date TEXT NOT NULL,kind TEXT NOT NULL,status TEXT NOT NULL,amount TEXT NOT NULL,payload TEXT NOT NULL); CREATE INDEX entries_date ON entries(date); CREATE INDEX entries_account_date ON entries(account,date); CREATE INDEX entries_kind ON entries(kind,status); CREATE TABLE state(id INTEGER PRIMARY KEY CHECK(id=1),revision INTEGER NOT NULL,payload TEXT NOT NULL); CREATE TABLE receipts(id TEXT PRIMARY KEY,bytes BLOB NOT NULL); PRAGMA user_version=2;',
        );
        final initial = SpendState().toJson()
          ..remove('accounts')
          ..remove('entries');
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

class NativeSpendStore implements SpendStore {
  final String path;
  NativeSpendStore(this.path);
  @override
  Future<SpendState> read() async {
    final file = path;
    return Isolate.run(() {
      final db = _database(file);
      try {
        db.execute('BEGIN');
        final state = Map<String, dynamic>.from(
          jsonDecode(
                db
                        .select('SELECT payload FROM state WHERE id=1')
                        .single['payload']
                    as String,
              )
              as Map,
        );
        state['accounts'] = db
            .select('SELECT payload FROM accounts ORDER BY rowid')
            .map((r) => jsonDecode(r['payload'] as String))
            .toList();
        state['entries'] = db
            .select('SELECT payload FROM entries ORDER BY rowid')
            .map((r) => jsonDecode(r['payload'] as String))
            .toList();
        db.execute('COMMIT');
        return SpendState.fromJson(state);
      } finally {
        db.close();
      }
    });
  }

  @override
  Future<void> commit(SpendState state, {required int expectedRevision}) async {
    final file = path;
    await Isolate.run(() {
      final next = state, db = _database(file);
      next.validate();
      try {
        db.execute('BEGIN IMMEDIATE');
        try {
          if (db
                      .select('SELECT revision FROM state WHERE id=1')
                      .single['revision'] !=
                  expectedRevision ||
              next.revision != expectedRevision + 1)
            throw StateError('Stale data; reload before retry');
          final oldEntries = {
                for (final r in db.select('SELECT id,payload FROM entries'))
                  r['id'] as String: r['payload'] as String,
              },
              oldAccounts = {
                for (final r in db.select('SELECT id,payload FROM accounts'))
                  r['id'] as String: r['payload'] as String,
              };
          final ids = next.entries.map((e) => e.id).toSet();
          for (final id in oldEntries.keys.where((id) => !ids.contains(id))) {
            db.execute('DELETE FROM entries WHERE id=?', [id]);
          }
          for (final a in next.accounts) {
            final payload = jsonEncode(a.toJson());
            if (oldAccounts[a.id] != payload)
              db.execute(
                'INSERT INTO accounts VALUES(?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload',
                [a.id, payload],
              );
          }
          for (final e in next.entries) {
            final payload = jsonEncode(e.toJson());
            if (oldEntries[e.id] != payload)
              db.execute(
                'INSERT INTO entries VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET account=excluded.account,destination=excluded.destination,date=excluded.date,kind=excluded.kind,status=excluded.status,amount=excluded.amount,payload=excluded.payload',
                [
                  e.id,
                  e.account,
                  e.toAccount,
                  e.when,
                  e.kind,
                  e.status,
                  e.amount.toString(),
                  payload,
                ],
              );
          }
          final accountIds = next.accounts.map((a) => a.id).toSet();
          for (final id in oldAccounts.keys.where(
            (id) => !accountIds.contains(id),
          )) {
            db.execute('DELETE FROM accounts WHERE id=?', [id]);
          }
          final metadata = next.toJson()
            ..remove('accounts')
            ..remove('entries');
          db.execute('UPDATE state SET revision=?,payload=? WHERE id=1', [
            next.revision,
            jsonEncode(metadata),
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
  Future<void> putReceipt(String id, Uint8List bytes) async {
    final file = path;
    await Isolate.run(() {
      final db = _database(file);
      try {
        db.execute(
          'INSERT INTO receipts VALUES(?,?) ON CONFLICT(id) DO UPDATE SET bytes=excluded.bytes',
          [id, bytes],
        );
      } finally {
        db.close();
      }
    });
  }

  @override
  Future<Uint8List?> readReceipt(String id) async {
    final file = path;
    return Isolate.run(() {
      final db = _database(file);
      try {
        final rows = db.select('SELECT bytes FROM receipts WHERE id=?', [id]);
        return rows.isEmpty ? null : rows.single['bytes'] as Uint8List;
      } finally {
        db.close();
      }
    });
  }

  @override
  Future<int> sweepReceipts(Set<String> keep) async {
    final file = path, ids = Set<String>.of(keep);
    return Isolate.run(() {
      final db = _database(file);
      try {
        db.execute('BEGIN IMMEDIATE');
        try {
          var n = 0;
          for (final r in db.select('SELECT id FROM receipts')) {
            final id = r['id'] as String;
            if (ids.contains(id)) continue;
            db.execute('DELETE FROM receipts WHERE id=?', [id]);
            n++;
          }
          db.execute('COMMIT');
          return n;
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
  Future<String> integrity() async {
    final file = path;
    return Isolate.run(() {
      final db = _database(file);
      try {
        return db.select('PRAGMA quick_check').single.values.first.toString();
      } finally {
        db.close();
      }
    });
  }
}
