import 'dart:convert';
import 'dart:collection';
import 'dart:math';
import 'dart:isolate';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:crypto/crypto.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'store.dart';
part 'store_snapshot.dart';

Future<BoardsStore> openStore() async {
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return NativeBoardsStore('${dir.path}/handy-boards.sqlite');
}

Database openBoardsDatabase(String path) {
  final db = sqlite3.open(path);
  try {
    if (db.userVersion > 4)
      throw const FormatException('Newer Boards schema; database preserved');
    db.execute(
      'PRAGMA busy_timeout=10000; PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL;',
    );
    if (db.userVersion == 0) {
      db.execute('BEGIN IMMEDIATE');
      try {
        for (final kind in kinds)
          db.execute(
            'CREATE TABLE $kind(id TEXT PRIMARY KEY,payload TEXT NOT NULL,board_id TEXT,category_id TEXT,status_id TEXT,parent_id TEXT,due TEXT,position INTEGER); CREATE INDEX ${kind}_scope ON $kind(board_id,category_id,status_id); CREATE INDEX ${kind}_due ON $kind(due); CREATE INDEX ${kind}_parent ON $kind(parent_id);',
          );
        db.execute(
          'CREATE TABLE files(path TEXT PRIMARY KEY,checksum TEXT NOT NULL,body BLOB NOT NULL); CREATE TABLE metadata(id INTEGER PRIMARY KEY CHECK(id=1),revision INTEGER NOT NULL,payload TEXT NOT NULL)',
        );
        final header = BoardsState().toJson(includeFiles: false);
        for (final k in kinds) header.remove(k);
        db.execute('INSERT INTO metadata VALUES(1,0,?)', [jsonEncode(header)]);
        db.execute('PRAGMA user_version=1; COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    }
    _upgradeSnapshotSchema(db);
    if (db.userVersion < 3) {
      db.execute('BEGIN IMMEDIATE');
      try {
        db.execute(
          'CREATE TABLE header_versions(revision INTEGER PRIMARY KEY,payload TEXT NOT NULL); INSERT INTO header_versions SELECT revision,payload FROM metadata;',
        );
        db.execute(
          "CREATE INDEX IF NOT EXISTS attachments_task_json ON attachments(json_extract(payload,'\$.task')); CREATE INDEX IF NOT EXISTS dependencies_after_json ON dependencies(json_extract(payload,'\$.after')); CREATE INDEX IF NOT EXISTS dependencies_before_json ON dependencies(json_extract(payload,'\$.before'));",
        );
        db.execute('PRAGMA user_version=3; COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    }
    if (db.userVersion < 4) {
      db.execute('BEGIN IMMEDIATE');
      try {
        db.execute(
          'CREATE TABLE IF NOT EXISTS task_fts_lookup(id TEXT PRIMARY KEY,docid INTEGER NOT NULL)',
        );
        db.execute(
          'CREATE INDEX IF NOT EXISTS record_scan ON record_versions(kind,ordinal,id,revision)',
        );
        if (_ftsAvailable(db))
          db.execute(
            'INSERT OR REPLACE INTO task_fts_lookup SELECT id,rowid FROM task_fts',
          );
        db.execute('PRAGMA user_version=4; COMMIT');
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

class NativeBoardsStore
    implements BoardsStore, BoardsSnapshotStore, BoardsPagedStore {
  final String path;
  final void Function(String phase)? diagnostics;
  BoardsState? _last;
  @override
  BoardsState? get currentSnapshot => _last;
  NativeBoardsStore(this.path, {this.diagnostics});
  @override
  Future<BoardsState> read() async {
    final file = path;
    await Isolate.run(() {
      final db = openBoardsDatabase(file);
      try {
        db.execute('BEGIN');
        _sqlSnapshot(db, file).validate();
        db.execute('COMMIT');
      } finally {
        db.close();
      }
    });
    return _last = _sqlSnapshot(_readConnection(path), path);
  }

  @override
  Future<void> commit(BoardsState next, {required int expectedRevision}) async {
    diagnostics?.call('delta-start');
    final previous = _last ?? await read();
    final file = path,
        revision = next.revision,
        header = jsonEncode({
          'app': 'handy-boards',
          'schema': 3,
          'revision': revision,
          'preferences': next.preferences,
        });
    final records = {
      for (final kind in kinds)
        kind: {
          for (final e in next.recordChanges(previous, kind).entries)
            e.key: e.value == null ? null : jsonEncode(e.value!.data),
        },
    };
    final changes = next.assetChanges(previous);
    diagnostics?.call('delta-ready');
    final staged = await Directory.systemTemp.createTemp('boards-commit-');
    try {
      final assetPaths = <String, String?>{};
      var index = 0;
      for (final entry in changes.entries) {
        if (entry.value == null) {
          assetPaths[entry.key] = null;
          continue;
        }
        final asset = File('${staged.path}/${index++}');
        await asset.writeAsBytes(await next.readFile(entry.key), flush: true);
        assetPaths[entry.key] = asset.path;
      }
      await Isolate.run(
        () => _commitSnapshotDelta(
          file,
          expectedRevision,
          revision,
          header,
          records,
          _DiskChanges(assetPaths),
        ),
      );
      diagnostics?.call('transaction-committed');
    } finally {
      await staged.delete(recursive: true);
    }
    _last = _sqlSnapshot(_readConnection(path), path);
  }

  @override
  Future<BoardsTaskPage> taskPage({
    String? board,
    String search = '',
    Json filter = const {},
    String sort = 'manual',
    int offset = 0,
    int limit = 100,
    int? expectedRevision,
  }) {
    final file = path;
    return Isolate.run(() {
      final db = openBoardsDatabase(file);
      try {
        db.execute('BEGIN');
        final page = _queryTaskPage(
          db,
          board: board,
          search: search,
          filter: filter,
          sort: sort,
          offset: offset,
          limit: limit,
          expectedRevision: expectedRevision,
        );
        db.execute('COMMIT');
        return page;
      } finally {
        db.close();
      }
    });
  }

  @override
  Future<String> integrity() {
    final file = path;
    return Isolate.run(() {
      final db = openBoardsDatabase(file);
      try {
        return db.select('PRAGMA quick_check').single.values.first.toString();
      } finally {
        db.close();
      }
    });
  }

  @override
  void close() {
    _last = null;
    _readConnections.remove(path)?.close();
  }
}

class _DiskChanges extends MapBase<String, Uint8List?> {
  final Map<String, String?> paths;
  _DiskChanges(this.paths);
  @override
  Iterable<String> get keys => paths.keys;
  @override
  Uint8List? operator [](Object? key) =>
      paths[key] == null ? null : File(paths[key]!).readAsBytesSync();
  @override
  void operator []=(String key, Uint8List? value) =>
      throw UnsupportedError('Immutable changes');
  @override
  Uint8List? remove(Object? key) => throw UnsupportedError('Immutable changes');
  @override
  void clear() => throw UnsupportedError('Immutable changes');
}

void _commitSnapshotDelta(
  String file,
  int expectedRevision,
  int revision,
  String header,
  Map<String, Map<String, String?>> changes,
  Map<String, Uint8List?> assets,
) {
  final db = openBoardsDatabase(file);
  try {
    db.execute('BEGIN IMMEDIATE');
    try {
      if (db
                  .select('SELECT revision FROM metadata WHERE id=1')
                  .single['revision'] !=
              expectedRevision ||
          revision != expectedRevision + 1)
        throw StateError('Another writer changed Boards; reload');
      final affectedTasks = <String>{}, affectedBoards = <String>{};
      final nextOrdinal = {
        for (final kind in kinds)
          kind:
              db.select(
                    'SELECT COALESCE(MAX(ordinal),0) n FROM record_versions WHERE kind=?',
                    [kind],
                  ).single['n']
                  as int,
      };
      for (final kind in kinds) {
        for (final entry in changes[kind]!.entries) {
          final previous = db.select(
                'SELECT rowid,payload FROM $kind WHERE id=?',
                [entry.key],
              ),
              old = previous.isEmpty
                  ? null
                  : object(jsonDecode(previous.single['payload'] as String));
          final data = entry.value == null
              ? null
              : object(jsonDecode(entry.value!));
          if (kind == 'tasks') affectedTasks.add(entry.key);
          if ([
            'boards',
            'categories',
            'statuses',
            'tags',
            'fields',
          ].contains(kind)) {
            for (final r in [old, data])
              if (r != null)
                affectedBoards.add(
                  kind == 'boards' ? r['id'] as String : r['board'] as String,
                );
          }
          if (kind == 'attachments')
            for (final r in [old, data])
              if (r?['task'] != null) affectedTasks.add(r!['task']);
          if (kind == 'dependencies')
            for (final r in [old, data])
              if (r?['after'] != null) affectedTasks.add(r!['after']);
          final ordinal = previous.isEmpty
              ? (nextOrdinal[kind] = nextOrdinal[kind]! + 1)
              : db.select(
                      'SELECT ordinal FROM record_versions WHERE kind=? AND id=? ORDER BY revision DESC LIMIT 1',
                      [kind, entry.key],
                    ).single['ordinal']
                    as int;
          db.execute('INSERT INTO record_versions VALUES(?,?,?,?,?,?)', [
            kind,
            entry.key,
            revision,
            entry.value,
            entry.value == null ? 1 : 0,
            ordinal,
          ]);
          if (data == null) {
            db.execute('DELETE FROM $kind WHERE id=?', [entry.key]);
            continue;
          }
          final r = BoardRecord(data);
          db.execute(
            'INSERT INTO $kind VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,board_id=excluded.board_id,category_id=excluded.category_id,status_id=excluded.status_id,parent_id=excluded.parent_id,due=excluded.due,position=excluded.position',
            [
              r.id,
              entry.value,
              r.data['board'],
              r.data['category'],
              r.data['status'],
              r.data['parent'],
              r.data['due'] == null
                  ? null
                  : deadlineSort(object(r.data['due'])),
              r.number('order'),
            ],
          );
        }
      }
      for (final e in assets.entries) {
        final bytes = e.value,
            hash = bytes == null ? null : sha256.convert(bytes).toString();
        if (bytes != null)
          db.execute('INSERT OR IGNORE INTO asset_blobs VALUES(?,?)', [
            hash,
            bytes,
          ]);
        db.execute('INSERT INTO file_versions VALUES(?,?,?)', [
          e.key,
          revision,
          hash,
        ]);
      }
      for (final board in affectedBoards)
        affectedTasks.addAll(
          db
              .select('SELECT id FROM tasks WHERE board_id=?', [board])
              .map((r) => r['id'] as String),
        );
      final predecessors = Set.of(affectedTasks);
      if (predecessors.isNotEmpty)
        for (final row in db.select('SELECT payload FROM dependencies')) {
          final d = object(jsonDecode(row['payload'] as String));
          if (predecessors.contains(d['before'])) affectedTasks.add(d['after']);
        }
      _reindexTasks(db, affectedTasks);
      db.execute('UPDATE metadata SET revision=?,payload=? WHERE id=1', [
        revision,
        header,
      ]);
      db.execute('INSERT INTO header_versions VALUES(?,?)', [revision, header]);
      _sqlSnapshot(db, file).validate();
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  } finally {
    db.close();
  }
}
