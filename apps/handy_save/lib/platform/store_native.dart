import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:crypto/crypto.dart';
import 'store.dart';

Future<void> preserveAndResetStore() async {
  final directory = await getApplicationSupportDirectory();
  await preserveDatabaseFiles(
    '${directory.path}${Platform.pathSeparator}handy-save.sqlite',
  );
}

/// Caller closes connections and confirms preservation/reset. No original is deleted.
Future<Directory> preserveDatabaseFiles(String path) async {
  final source = File(path).absolute;
  if (await FileSystemEntity.type(source.path, followLinks: false) !=
      FileSystemEntityType.file)
    throw StateError('Database file unavailable; no reset performed');
  final recovery = Directory(
    '${source.parent.path}${Platform.pathSeparator}save-recovery-${DateTime.now().microsecondsSinceEpoch}',
  );
  await recovery.create();
  final originals = <File>[], copies = <File>[];
  for (final suffix in ['', '-wal', '-shm']) {
    final file = File('$path$suffix');
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) continue;
    if (type != FileSystemEntityType.file)
      throw StateError('Unexpected database file; no reset performed');
    final copy = await file.copy(
      '${recovery.path}${Platform.pathSeparator}snapshot.sqlite$suffix',
    );
    if (await copy.length() != await file.length() ||
        await sha256.bind(copy.openRead()).first !=
            await sha256.bind(file.openRead()).first)
      throw StateError('Recovery copy incomplete; no reset performed');
    originals.add(file);
    copies.add(copy);
  }
  // Keep verified copies and move the closed originals inside the same directory.
  // A partial filesystem failure still leaves every byte in an owned location.
  for (var i = originals.length - 1; i >= 0; i--) {
    await originals[i].rename('${copies[i].path}.original');
  }
  return recovery;
}

Future<BookmarkStore> openStore() async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  return NativeBookmarkStore.open(
    '${directory.path}${Platform.pathSeparator}handy-save.sqlite',
  );
}

class NativeBookmarkStore implements BookmarkStore {
  final SendPort port;
  final Isolate worker;
  final ReceivePort _lifecycle;
  final Completer<Object> _termination;
  final Duration operationTimeout;
  final _pending = <Completer<dynamic>>{};
  bool closed = false;

  NativeBookmarkStore._(
    this.port,
    this.worker,
    this._lifecycle,
    this._termination,
    this.operationTimeout,
  ) {
    _termination.future.then((_) {
      closed = true;
      worker.kill(priority: Isolate.immediate);
      _lifecycle.close();
      _failPending();
    });
  }

  static StateError _lostConnection() => StateError(
    'Database connection was lost. The last operation may have committed; '
    'reopen the database to reload saved data before retrying.',
  );

  static Future<NativeBookmarkStore> open(
    String path, {
    Duration startupTimeout = const Duration(seconds: 30),
    Duration operationTimeout = const Duration(seconds: 30),
  }) async {
    final ready = ReceivePort();
    final lifecycle = ReceivePort();
    final termination = Completer<Object>();
    lifecycle.listen((event) {
      if (!termination.isCompleted) termination.complete(_lostConnection());
    });
    Isolate? worker;
    try {
      worker = await Isolate.spawn(
        _databaseWorker,
        [path, ready.sendPort],
        onError: lifecycle.sendPort,
        onExit: lifecycle.sendPort,
        errorsAreFatal: true,
      );
      final result = await Future.any<Object?>([
        ready.first,
        termination.future.then((_) => throw _lostConnection()),
      ]).timeout(startupTimeout);
      if (result is! SendPort || termination.isCompleted) {
        throw StateError(
          'Database could not open; existing file was preserved: ${result is Map ? result["diagnostic"] : "worker stopped"}',
        );
      }
      return NativeBookmarkStore._(
        result,
        worker,
        lifecycle,
        termination,
        operationTimeout,
      );
    } catch (_) {
      worker?.kill(priority: Isolate.immediate);
      lifecycle.close();
      rethrow;
    } finally {
      ready.close();
    }
  }

  void _invalidate() {
    closed = true;
    worker.kill(priority: Isolate.immediate);
    if (!_termination.isCompleted) _termination.complete(_lostConnection());
    _lifecycle.close();
    _failPending();
  }

  void _failPending() {
    for (final pending in _pending) {
      if (!pending.isCompleted) pending.completeError(_lostConnection());
    }
  }

  Future<dynamic> call(
    String action, [
    Map<String, dynamic> args = const {},
  ]) async {
    if (closed) throw _lostConnection();
    final response = ReceivePort();
    final pending = Completer<dynamic>();
    _pending.add(pending);
    response.listen((result) {
      if (!pending.isCompleted) pending.complete(result);
    });
    try {
      port.send([action, args, response.sendPort]);
      final result = await pending.future.timeout(
        operationTimeout,
        onTimeout: () {
          _invalidate();
          throw _lostConnection();
        },
      );
      if (result is Map && result['error'] == true) {
        throw StateError(
          'Local database operation failed. '
          'Reload saved data before retrying.',
        );
      }
      return result;
    } finally {
      _pending.remove(pending);
      response.close();
    }
  }

  @override
  Future<Map<String, dynamic>> read() async =>
      Map<String, dynamic>.from(await call('read') as Map);
  @override
  Future<void> write({
    List<Map<String, dynamic>> upserts = const [],
    List<String> deletes = const [],
    Map<String, dynamic>? settings,
    bool replace = false,
  }) async {
    await call('write', {
      'upserts': upserts,
      'deletes': deletes,
      'settings': settings,
      'replace': replace,
    });
  }

  @override
  Future<Map<String, dynamic>> search(
    Map<String, dynamic> query, {
    int offset = 0,
    int limit = 100,
  }) async => Map<String, dynamic>.from(
    await call('search', {'query': query, 'offset': offset, 'limit': limit})
        as Map,
  );
  @override
  Future<Uint8List?> thumbnail(String id) async =>
      await call('thumbnail', {'id': id}) as Uint8List?;
  @override
  Future<void> putThumbnail(String id, Uint8List bytes) async {
    if (bytes.length > 1000000)
      throw const FormatException('Thumbnail exceeds 1 MB');
    await call('putThumbnail', {'id': id, 'bytes': bytes});
  }

  @override
  Future<void> clearThumbnails() async {
    await call('clearThumbnails');
  }

  @override
  Future<String> integrity() async => await call('integrity') as String;
  @override
  Future<void> close() async {
    if (closed) return;
    try {
      await call('close');
    } finally {
      _invalidate();
    }
  }
}

void _databaseWorker(List<dynamic> start) async {
  final owner = start[1] as SendPort;
  Database? database;
  final commands = ReceivePort();
  try {
    database = sqlite3.open(start[0] as String);
    final db = database;
    db.execute('PRAGMA foreign_keys=ON');
    db.execute('PRAGMA busy_timeout=5000');
    final version = db.userVersion;
    if (version > 1) throw StateError('Unsupported newer database');
    if (version == 0) {
      db.execute('BEGIN IMMEDIATE');
      try {
        db.execute(
          'CREATE TABLE bookmarks(id TEXT PRIMARY KEY, normalized_url TEXT NOT NULL, canonical_url TEXT, domain TEXT, platform TEXT, content_type TEXT, collection_id TEXT, favorite INTEGER NOT NULL, archived INTEGER NOT NULL, read_state INTEGER NOT NULL, pinned INTEGER NOT NULL, saved_at TEXT, updated_at TEXT, last_opened_at TEXT, opened_count INTEGER, payload TEXT NOT NULL)',
        );
        db.execute(
          'CREATE TABLE settings(key TEXT PRIMARY KEY, payload TEXT NOT NULL)',
        );
        db.execute(
          'CREATE TABLE collections(id TEXT PRIMARY KEY, parent_id TEXT, position INTEGER, payload TEXT NOT NULL)',
        );
        db.execute('CREATE TABLE tags(name TEXT PRIMARY KEY)');
        db.execute(
          'CREATE TABLE bookmark_tags(bookmark_id TEXT NOT NULL REFERENCES bookmarks(id) ON DELETE CASCADE,tag TEXT NOT NULL REFERENCES tags(name),PRIMARY KEY(bookmark_id,tag))',
        );
        db.execute(
          'CREATE TABLE thumbnails(bookmark_id TEXT PRIMARY KEY REFERENCES bookmarks(id) ON DELETE CASCADE,data BLOB NOT NULL,accessed INTEGER NOT NULL)',
        );
        for (final column in [
          'normalized_url',
          'canonical_url',
          'domain',
          'platform',
          'collection_id',
          'favorite',
          'archived',
          'read_state',
          'saved_at',
          'updated_at',
          'last_opened_at',
        ]) {
          db.execute('CREATE INDEX idx_$column ON bookmarks($column)');
        }
        db.execute('CREATE INDEX idx_tags ON bookmark_tags(tag)');
        db.userVersion = 1;
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    }
    db.execute('PRAGMA journal_mode=WAL');
    db.execute('PRAGMA synchronous=FULL');
    // Derived index: canonical order remains in the versioned settings payload.
    db.execute(
      'CREATE TABLE IF NOT EXISTS bookmark_order(bookmark_id TEXT PRIMARY KEY REFERENCES bookmarks(id) ON DELETE CASCADE,position INTEGER NOT NULL)',
    );
    String? indexedOrder;
    bool fts = true;
    try {
      db.execute(
        'CREATE VIRTUAL TABLE IF NOT EXISTS bookmark_search USING fts5(id UNINDEXED,content,tokenize="unicode61")',
      );
    } catch (_) {
      fts = false;
    }
    if (fts &&
        (db.select('SELECT count(*) AS n FROM bookmark_search').first['n'] !=
                db.select('SELECT count(*) AS n FROM bookmarks').first['n'] ||
            db
                    .select(
                      'SELECT count(*) AS n FROM bookmark_search f JOIN bookmarks b '
                      'ON f.rowid=b.rowid AND f.id=b.id',
                    )
                    .first['n'] !=
                db.select('SELECT count(*) AS n FROM bookmarks').first['n'])) {
      db.execute('BEGIN');
      try {
        db.execute('DELETE FROM bookmark_search');
        for (final row in db.select('SELECT rowid,payload FROM bookmarks')) {
          final b = jsonDecode(row['payload'] as String) as Map;
          db.execute(
            'INSERT INTO bookmark_search(rowid,id,content) VALUES(?,?,?)',
            [row['rowid'], b['id'], _searchText(b)],
          );
        }
        db.execute('COMMIT');
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    }
    owner.send(commands.sendPort);
    await for (final message in commands) {
      final action = message[0] as String,
          args = message[1] as Map,
          reply = message[2] as SendPort;
      try {
        dynamic result;
        switch (action) {
          case 'read':
            final setting = db.select(
              "SELECT payload FROM settings WHERE key='state'",
            );
            result = {
              'bookmarks': [
                for (final row in db.select('SELECT payload FROM bookmarks'))
                  jsonDecode(row['payload'] as String),
              ],
              'state': setting.isEmpty
                  ? <String, dynamic>{}
                  : jsonDecode(setting.first['payload'] as String),
            };
          case 'write':
            if (args['replace'] == true || (args['deletes'] as List).isNotEmpty)
              indexedOrder = null;
            db.execute('BEGIN IMMEDIATE');
            try {
              if (args['replace'] == true) {
                db.execute('DELETE FROM bookmarks');
                db.execute('DELETE FROM collections');
                db.execute('DELETE FROM tags');
                if (fts) db.execute('DELETE FROM bookmark_search');
              }
              for (final id in args['deletes'] as List) {
                if (fts)
                  db.execute(
                    'DELETE FROM bookmark_search WHERE rowid='
                    '(SELECT rowid FROM bookmarks WHERE id=?)',
                    [id],
                  );
                db.execute('DELETE FROM bookmarks WHERE id=?', [id]);
              }
              final statement = db.prepare(
                'INSERT INTO bookmarks VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET normalized_url=excluded.normalized_url,canonical_url=excluded.canonical_url,domain=excluded.domain,platform=excluded.platform,content_type=excluded.content_type,collection_id=excluded.collection_id,favorite=excluded.favorite,archived=excluded.archived,read_state=excluded.read_state,pinned=excluded.pinned,saved_at=excluded.saved_at,updated_at=excluded.updated_at,last_opened_at=excluded.last_opened_at,opened_count=excluded.opened_count,payload=excluded.payload',
              );
              try {
                for (final value in args['upserts'] as List) {
                  final b = value as Map;
                  statement.execute([
                    b['id'],
                    b['normalizedUrl'],
                    b['canonicalUrl'],
                    b['sourceDomain'],
                    b['platform'],
                    b['contentType'],
                    b['collectionId'],
                    b['isFavorite'] == true ? 1 : 0,
                    b['isArchived'] == true ? 1 : 0,
                    b['isRead'] == true ? 1 : 0,
                    b['isPinned'] == true ? 1 : 0,
                    b['savedAt'],
                    b['updatedAt'],
                    b['lastOpenedAt'],
                    b['openedCount'],
                    jsonEncode(b),
                  ]);
                  db.execute('DELETE FROM bookmark_tags WHERE bookmark_id=?', [
                    b['id'],
                  ]);
                  for (final tag in (b['tags'] as List? ?? []).toSet()) {
                    db.execute('INSERT OR IGNORE INTO tags VALUES(?)', [tag]);
                    db.execute('INSERT INTO bookmark_tags VALUES(?,?)', [
                      b['id'],
                      tag,
                    ]);
                  }
                  if (fts) {
                    db.execute(
                      'DELETE FROM bookmark_search WHERE rowid='
                      '(SELECT rowid FROM bookmarks WHERE id=?)',
                      [b['id']],
                    );
                    db.execute(
                      'INSERT INTO bookmark_search(rowid,id,content) '
                      'VALUES((SELECT rowid FROM bookmarks WHERE id=?),?,?)',
                      [b['id'], b['id'], _searchText(b)],
                    );
                  }
                }
              } finally {
                statement.close();
              }
              if (args['settings'] != null) {
                final state = args['settings'] as Map;
                final order =
                    (state['preferences'] as Map?)?['bookmarkOrder'] as List? ??
                    [];
                final encodedOrder = jsonEncode(order);
                if (encodedOrder != indexedOrder) {
                  db.execute('DELETE FROM bookmark_order');
                  final ordering = db.prepare(
                    'INSERT OR IGNORE INTO bookmark_order SELECT id,? FROM bookmarks WHERE id=?',
                  );
                  try {
                    for (var i = 0; i < order.length; i++) {
                      ordering.execute([i, order[i]]);
                    }
                  } finally {
                    ordering.close();
                  }
                }
                db.execute(
                  "INSERT INTO settings VALUES('state',?) ON CONFLICT(key) DO UPDATE SET payload=excluded.payload",
                  [jsonEncode(state)],
                );
                db.execute('DELETE FROM collections');
                db.execute(
                  'INSERT OR IGNORE INTO tags SELECT value FROM json_each(?)',
                  [jsonEncode(state['tags'] ?? [])],
                );
                for (final c in state['collections'] as List? ?? []) {
                  db.execute('INSERT INTO collections VALUES(?,?,?,?)', [
                    c['id'],
                    c['parentId'],
                    c['position'],
                    jsonEncode(c),
                  ]);
                }
              }
              db.execute(
                "DELETE FROM tags WHERE NOT EXISTS(SELECT 1 FROM bookmark_tags WHERE tag=tags.name) AND name NOT IN(SELECT value FROM json_each(coalesce((SELECT json_extract(payload,'\$.tags') FROM settings WHERE key='state'),'[]')))",
              );
              db.execute('COMMIT');
              // Refresh after commit so a rollback never marks the index current.
              if (args['settings'] != null)
                indexedOrder = jsonEncode(
                  ((args['settings'] as Map)['preferences']
                          as Map?)?['bookmarkOrder'] ??
                      [],
                );
            } catch (_) {
              db.execute('ROLLBACK');
              rethrow;
            }
            result = true;
          case 'search':
            result = _query(
              db,
              args['query'] as Map,
              args['offset'] as int,
              args['limit'] as int,
              fts,
            );
          case 'thumbnail':
            final rows = db.select(
              'SELECT data FROM thumbnails WHERE bookmark_id=?',
              [args['id']],
            );
            result = rows.isEmpty ? null : rows.first['data'];
            if (rows.isNotEmpty)
              db.execute(
                'UPDATE thumbnails SET accessed=? WHERE bookmark_id=?',
                [DateTime.now().microsecondsSinceEpoch, args['id']],
              );
          case 'putThumbnail':
            db.execute(
              'INSERT INTO thumbnails VALUES(?,?,?) ON CONFLICT(bookmark_id) DO UPDATE SET data=excluded.data,accessed=excluded.accessed',
              [
                args['id'],
                args['bytes'],
                DateTime.now().microsecondsSinceEpoch,
              ],
            );
            while ((db
                        .select(
                          'SELECT coalesce(sum(length(data)),0) AS n FROM thumbnails',
                        )
                        .first['n']
                    as int) >
                20000000) {
              db.execute(
                'DELETE FROM thumbnails WHERE bookmark_id=(SELECT bookmark_id FROM thumbnails ORDER BY accessed LIMIT 1)',
              );
            }
            result = true;
          case 'clearThumbnails':
            db.execute('DELETE FROM thumbnails');
            result = true;
          case 'integrity':
            result =
                db.select('PRAGMA quick_check').first.values.first as String;
          case 'close':
            db.close();
            reply.send(true);
            commands.close();
            return;
          default:
            throw StateError('Unknown operation');
        }
        reply.send(result);
      } catch (_) {
        reply.send({'error': true});
      }
    }
  } catch (e) {
    database?.close();
    owner.send({
      'error': true,
      'diagnostic': e is SqliteException ? e.message : e.runtimeType.toString(),
    });
    commands.close();
  }
}

String _searchText(Map b) => [
  b['title'],
  b['originalUrl'],
  b['description'],
  b['note'],
  b['sourceDomain'],
  b['platform'],
  ...(b['tags'] as List? ?? []),
].whereType<String>().join(' ');
Map<String, dynamic> _query(
  Database db,
  Map q,
  int offset,
  int limit,
  bool fts,
) {
  if (offset < 0 || limit < 1 || limit > 500)
    throw const FormatException('Invalid page');
  final where = <String>[], values = <Object?>[];
  final text = (q['text'] as String? ?? '').trim();
  if (text.isNotEmpty) {
    where.add(
      'id IN (SELECT id FROM bookmark_search WHERE bookmark_search MATCH ?)',
    );
    values.add(
      text
          .split(RegExp(r'\s+'))
          .map((v) => '"${v.replaceAll('"', '""')}"*')
          .join(' AND '),
    );
    if (!fts) {
      where.removeLast();
      values.removeLast();
      where.add('payload LIKE ? ESCAPE \'\\\'');
      values.add(
        '%${text.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%',
      );
    }
    where[where.length - 1] =
        '(${where.last} OR collection_id IN(SELECT id FROM collections WHERE lower(json_extract(payload,\'\$.name\')) LIKE ? ESCAPE \'\\\'))';
    values.add(
      '%${text.toLowerCase().replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%',
    );
  }
  for (final entry in {
    'platform': 'platform',
    'contentType': 'content_type',
    'collectionId': 'collection_id',
    'isFavorite': 'favorite',
    'isArchived': 'archived',
    'isRead': 'read_state',
    'isPinned': 'pinned',
  }.entries) {
    if (q[entry.key] != null) {
      where.add('${entry.value}=?');
      final v = q[entry.key];
      values.add(v is bool ? (v ? 1 : 0) : v);
    }
  }
  if (q['inbox'] == true) where.add('collection_id IS NULL');
  for (final tag in q['tags'] as List? ?? []) {
    where.add(
      'id IN(SELECT bookmark_id FROM bookmark_tags WHERE tag=? COLLATE NOCASE)',
    );
    values.add(tag);
  }
  for (final entry in {'savedAfter': '>=', 'savedBefore': '<='}.entries) {
    if (q[entry.key] != null) {
      where.add('saved_at ${entry.value} ?');
      values.add(q[entry.key]);
    }
  }
  for (final entry in {'openedAfter': '>=', 'openedBefore': '<='}.entries) {
    if (q[entry.key] != null) {
      where.add('last_opened_at ${entry.value} ?');
      values.add(q[entry.key]);
    }
  }
  final sql = where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}';
  final order =
      {
        'oldest': 'saved_at ASC',
        'updated': 'updated_at DESC',
        'title': 'json_extract(payload,\'\$.title\') COLLATE NOCASE',
        'domain': 'domain COLLATE NOCASE',
        'mostOpened': 'opened_count DESC',
        'reminder': 'json_extract(payload,\'\$.reminderAt\') ASC',
        'opened': 'last_opened_at DESC',
        'recentlyOpened': 'last_opened_at DESC',
        'manual':
            'coalesce((SELECT position FROM bookmark_order WHERE bookmark_id=bookmarks.id),2147483647),rowid ASC',
      }[q['sort']] ??
      'saved_at DESC';
  return {
    'total': db
        .select('SELECT count(*) AS n FROM bookmarks$sql', values)
        .first['n'],
    'bookmarks': [
      for (final row in db.select(
        'SELECT payload FROM bookmarks$sql ORDER BY pinned DESC,$order,id ASC LIMIT ? OFFSET ?',
        [...values, limit, offset],
      ))
        jsonDecode(row['payload'] as String),
    ],
  };
}
