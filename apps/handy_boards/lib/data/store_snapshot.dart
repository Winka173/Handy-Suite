part of 'store_native.dart';

final _readConnections = <String, Database>{};
Database _readConnection(String path) =>
    _readConnections.putIfAbsent(path, () => openBoardsDatabase(path));

class _SqlRecords extends BoardsSnapshotMap<BoardRecord> {
  final Database db;
  final String path, kind;
  @override
  final int snapshotRevision;
  final List<String> _keys;
  final Set<String> _keySet;
  final _cache = LinkedHashMap<String, BoardRecord>();
  _SqlRecords(
    this.db,
    this.path,
    this.kind,
    this.snapshotRevision,
    List<String> keys,
  ) : _keys = List.unmodifiable(keys),
      _keySet = Set.of(keys);
  @override
  String get storageIdentity => '$path/$kind';
  @override
  Iterable<String> get keys => _keys;
  @override
  int get length => _keys.length;
  @override
  bool containsKey(Object? key) => _keySet.contains(key);
  @override
  BoardRecord? operator [](Object? key) {
    if (!_keySet.contains(key)) return null;
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key as String] = cached;
      return cached;
    }
    final row = db.select(
      'SELECT payload,deleted FROM record_versions WHERE kind=? AND id=? AND revision<=? ORDER BY revision DESC LIMIT 1',
      [kind, key, snapshotRevision],
    ).single;
    if (row['deleted'] == 1) return null;
    final value = BoardRecord(object(jsonDecode(row['payload'] as String)));
    _cache[key as String] = value;
    if (_cache.length > 128) _cache.remove(_cache.keys.first);
    return value;
  }

  @override
  Iterable<MapEntry<String, BoardRecord>> get entries sync* {
    // A sync* consumer may stop without closing an SQLite cursor. Materialize
    // bounded pages so early firstWhere/take never pins a database transaction.
    int? afterOrder;
    String? afterId;
    while (true) {
      final rows = db.select(
        'SELECT v.id,v.payload,v.ordinal FROM record_versions v WHERE v.kind=? ${afterOrder == null ? '' : 'AND (v.ordinal,v.id) > (?,?)'} AND v.revision=(SELECT MAX(w.revision) FROM record_versions w WHERE w.kind=v.kind AND w.id=v.id AND w.revision<=?) AND v.deleted=0 ORDER BY v.ordinal,v.id LIMIT 256',
        [
          kind,
          if (afterOrder != null) ...[afterOrder, afterId],
          snapshotRevision,
        ],
      );
      for (final row in rows)
        yield MapEntry(
          row['id'] as String,
          BoardRecord(object(jsonDecode(row['payload'] as String))),
        );
      if (rows.length < 256) break;
      afterOrder = rows.last['ordinal'] as int;
      afterId = rows.last['id'] as String;
    }
  }

  @override
  Iterable<BoardRecord> get values => entries.map((e) => e.value);
  @override
  Set<String> changedKeysCompared(BoardsSnapshotMap<BoardRecord> other) => db
      .select(
        'SELECT DISTINCT id FROM record_versions WHERE kind=? AND revision>? AND revision<=?',
        [
          kind,
          min(snapshotRevision, other.snapshotRevision),
          max(snapshotRevision, other.snapshotRevision),
        ],
      )
      .map((r) => r['id'] as String)
      .toSet();
  @override
  void operator []=(String key, BoardRecord value) =>
      throw UnsupportedError('Immutable SQL snapshot');
  @override
  BoardRecord? remove(Object? key) =>
      throw UnsupportedError('Immutable SQL snapshot');
  @override
  void clear() => throw UnsupportedError('Immutable SQL snapshot');
}

class _SqlAssets extends BoardsAssetMap {
  final Database db;
  final String path;
  @override
  final int snapshotRevision;
  final Map<String, String> _hashes;
  _SqlAssets(this.db, this.path, this.snapshotRevision, this._hashes);
  late final Map<String, Json> _descriptors = {
    for (final e in _hashes.entries)
      e.key: {
        'sha256': e.value,
        'bytes': db.select(
          'SELECT length(body) n FROM asset_blobs WHERE hash=?',
          [e.value],
        ).single['n'],
      },
  };
  @override
  Map<String, Json> get descriptors => _descriptors;
  @override
  Future<Uint8List> readAsset(String key) async =>
      this[key] ?? (throw const FormatException('Missing asset'));
  @override
  String get storageIdentity => '$path/assets';
  @override
  Iterable<String> get keys => _hashes.keys;
  @override
  bool containsKey(Object? key) => _hashes.containsKey(key);
  @override
  int get length => _hashes.length;
  @override
  Uint8List? operator [](Object? key) {
    final hash = _hashes[key];
    if (hash == null) return null;
    final bytes = Uint8List.fromList(
      db.select('SELECT body FROM asset_blobs WHERE hash=?', [
            hash,
          ]).single['body']
          as Uint8List,
    );
    if (sha256.convert(bytes).toString() != hash)
      throw const FormatException('Stored file checksum mismatch');
    return bytes;
  }

  @override
  Set<String> changedKeysCompared(BoardsSnapshotMap<Uint8List> other) => db
      .select(
        'SELECT DISTINCT path FROM file_versions WHERE revision>? AND revision<=?',
        [
          min(snapshotRevision, other.snapshotRevision),
          max(snapshotRevision, other.snapshotRevision),
        ],
      )
      .map((r) => r['path'] as String)
      .toSet();
  @override
  void operator []=(String key, Uint8List value) =>
      throw UnsupportedError('Immutable SQL snapshot');
  @override
  Uint8List? remove(Object? key) =>
      throw UnsupportedError('Immutable SQL snapshot');
  @override
  void clear() => throw UnsupportedError('Immutable SQL snapshot');
}

BoardsState readBoardsRevision(Database db, String path, int revision) =>
    _sqlSnapshot(db, path, atRevision: revision);

BoardsState _sqlSnapshot(Database db, String path, {int? atRevision}) {
  final metadata = db
          .select(
            atRevision == null
                ? 'SELECT revision,payload FROM metadata WHERE id=1'
                : 'SELECT revision,payload FROM header_versions WHERE revision=?',
            atRevision == null ? [] : [atRevision],
          )
          .single,
      revision = metadata['revision'] as int,
      header = object(jsonDecode(metadata['payload'] as String));
  if (![1, 2, 3].contains(header['schema']))
    throw const FormatException('Unsupported Boards schema');
  return BoardsState.fromSnapshot(
    revision: revision,
    preferences: object(header['preferences'] ?? {}),
    data: {
      for (final k in kinds)
        k: _SqlRecords(
          db,
          path,
          k,
          revision,
          db
              .select(
                'SELECT v.id FROM record_versions v WHERE v.kind=? AND v.revision=(SELECT MAX(w.revision) FROM record_versions w WHERE w.kind=v.kind AND w.id=v.id AND w.revision<=?) AND v.deleted=0 ORDER BY v.ordinal,v.id',
                [k, revision],
              )
              .map((r) => r['id'] as String)
              .toList(),
        ),
    },
    files: _SqlAssets(db, path, revision, {
      for (final row in db.select(
        'SELECT v.path,v.hash FROM file_versions v WHERE v.revision=(SELECT MAX(w.revision) FROM file_versions w WHERE w.path=v.path AND w.revision<=?) AND v.hash IS NOT NULL',
        [revision],
      ))
        row['path'] as String: row['hash'] as String,
    }),
  );
}

void _upgradeSnapshotSchema(Database db) {
  if (db.userVersion >= 2) return;
  db.execute('BEGIN IMMEDIATE');
  try {
    db.execute(
      'CREATE TABLE record_versions(kind TEXT NOT NULL,id TEXT NOT NULL,revision INTEGER NOT NULL,payload TEXT,deleted INTEGER NOT NULL DEFAULT 0,ordinal INTEGER NOT NULL,PRIMARY KEY(kind,id,revision));CREATE INDEX record_revisions ON record_versions(kind,revision);CREATE TABLE asset_blobs(hash TEXT PRIMARY KEY,body BLOB NOT NULL);CREATE TABLE file_versions(path TEXT NOT NULL,revision INTEGER NOT NULL,hash TEXT,PRIMARY KEY(path,revision));CREATE INDEX file_revisions ON file_versions(revision);',
    );
    final revision = db
        .select('SELECT revision FROM metadata WHERE id=1')
        .single['revision'];
    for (final kind in kinds)
      db.execute(
        'INSERT INTO record_versions(kind,id,revision,payload,ordinal) SELECT ?,id,?,payload,rowid FROM $kind',
        [kind, revision],
      );
    db.execute(
      'INSERT OR IGNORE INTO asset_blobs SELECT checksum,body FROM files',
    );
    db.execute('INSERT INTO file_versions SELECT path,?,checksum FROM files', [
      revision,
    ]);
    db.execute(
      'CREATE TABLE task_index(id TEXT PRIMARY KEY,board TEXT,category TEXT,status TEXT,parent TEXT,priority INTEGER,estimate INTEGER,assignee TEXT,archived INTEGER,trashed INTEGER,blocked INTEGER,due_day TEXT,due_instant TEXT,position INTEGER,folded_title TEXT,created TEXT,updated TEXT,search TEXT);CREATE INDEX task_page_scope ON task_index(board,archived,trashed,parent,position,id);CREATE INDEX task_page_due ON task_index(board,due_day,id);CREATE INDEX task_page_priority ON task_index(board,priority,id);',
    );
    try {
      db.execute(
        "CREATE VIRTUAL TABLE task_fts USING fts5(id UNINDEXED,search,tokenize='trigram')",
      );
    } on SqliteException {
      /* Older platforms retain bounded SQL LIKE fallback. */
    }
    db.execute(
      "CREATE INDEX attachments_task_json ON attachments(json_extract(payload,'\$.task')); CREATE INDEX dependencies_after_json ON dependencies(json_extract(payload,'\$.after')); CREATE INDEX dependencies_before_json ON dependencies(json_extract(payload,'\$.before'));",
    );
    db.execute(
      'CREATE TABLE IF NOT EXISTS task_fts_lookup(id TEXT PRIMARY KEY,docid INTEGER NOT NULL)',
    );
    _reindexTasks(
      db,
      db.select('SELECT id FROM tasks').map((r) => r['id'] as String).toSet(),
    );
    db.execute('PRAGMA user_version=2; COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

bool _ftsAvailable(Database db) =>
    db.select("SELECT 1 FROM sqlite_master WHERE name='task_fts'").isNotEmpty;
void _reindexTasks(Database db, Set<String> ids) {
  final fts = _ftsAvailable(db);
  for (final id in ids) {
    db.execute('DELETE FROM task_index WHERE id=?', [id]);
    if (fts) {
      final old = db.select('SELECT docid FROM task_fts_lookup WHERE id=?', [
        id,
      ]);
      if (old.isNotEmpty)
        db.execute('DELETE FROM task_fts WHERE rowid=?', [old.single['docid']]);
      db.execute('DELETE FROM task_fts_lookup WHERE id=?', [id]);
    }
    final found = db.select('SELECT payload FROM tasks WHERE id=?', [id]);
    if (found.isEmpty) continue;
    final t = BoardRecord(
      object(jsonDecode(found.single['payload'] as String)),
    );
    Json record(String kind, String? id) {
      if (id == null) return {};
      final r = db.select('SELECT payload FROM $kind WHERE id=?', [id]);
      return r.isEmpty ? {} : object(jsonDecode(r.single['payload'] as String));
    }

    final board = record('boards', t.str('board')),
        category = record('categories', t.data['category']),
        tagNames = t
            .strings('tags')
            .map((id) => record('tags', id)['title'] ?? '')
            .join(' '),
        links = db
            .select(
              'SELECT payload FROM attachments WHERE parent_id=? OR json_extract(payload,\'\$.task\')=?',
              [id, id],
            )
            .map((r) => object(jsonDecode(r['payload'] as String)))
            .map((r) => '${r['url'] ?? ''} ${r['name'] ?? ''}')
            .join(' ');
    var blocked = false;
    for (final r in db.select(
      'SELECT payload FROM dependencies WHERE json_extract(payload,\'\$.after\')=?',
      [id],
    )) {
      final predecessor = record(
        'tasks',
        object(jsonDecode(r['payload'] as String))['before'],
      );
      if (predecessor.isEmpty ||
          predecessor['trashed'] == true ||
          record('statuses', predecessor['status'])['done'] != true) {
        blocked = true;
        break;
      }
    }
    final search = foldSearch(
          '${t.str('title')} ${t.str('notes')} ${category['title'] ?? ''} $tagNames ${t.data['custom'] ?? {}} $links',
        ),
        due = t.data['due'] == null ? null : object(t.data['due']);
    db.execute(
      'INSERT INTO task_index VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      [
        id,
        t.str('board'),
        t.data['category'],
        t.str('status'),
        t.data['parent'],
        t.number('priority'),
        t.number('estimate'),
        t.str('assignee'),
        t.flag('archived') ? 1 : 0,
        t.flag('trashed') ? 1 : 0,
        blocked ? 1 : 0,
        due == null
            ? null
            : deadlineDay(due, board['zone'] as String? ?? 'Asia/Ho_Chi_Minh'),
        due == null ? null : deadlineSort(due),
        t.number('order'),
        foldSearch(t.str('title')),
        t.str('created'),
        t.str('updated'),
        search,
      ],
    );
    if (fts) {
      db.execute('INSERT INTO task_fts(id,search) VALUES(?,?)', [id, search]);
      db.execute('INSERT INTO task_fts_lookup VALUES(?,?)', [
        id,
        db.lastInsertRowId,
      ]);
    }
  }
}

BoardsTaskPage _queryTaskPage(
  Database db, {
  String? board,
  String search = '',
  Json filter = const {},
  String sort = 'manual',
  int offset = 0,
  int limit = 100,
  int? expectedRevision,
}) {
  validateTaskFilter(filter);
  if (offset < 0 || limit < 1 || limit > 500)
    throw const FormatException('Page size 1..500');
  final revision =
      db.select('SELECT revision FROM metadata WHERE id=1').single['revision']
          as int;
  if (expectedRevision != null && revision != expectedRevision)
    throw StateError('Page revision changed; reload');
  final where = <String>['i.trashed=0'], args = <Object?>[];
  void clause(String sql, Object? value) {
    where.add(sql);
    args.add(value);
  }

  if (board != null) clause('i.board=?', board);
  clause('i.archived=?', filter['archived'] == true ? 1 : 0);
  for (final k in ['category', 'status', 'priority', 'assignee'])
    if (filter.containsKey(k)) {
      if (filter[k] == null) {
        where.add('i.$k IS NULL');
      } else {
        clause('i.$k=?', filter[k]);
      }
    }
  if (filter.containsKey('priority'))
    where.add("json_type(t.payload,'\$.priority') = 'integer'");
  if (filter['parentOnly'] == true) where.add('i.parent IS NULL');
  if (filter['blocked'] is bool)
    clause('i.blocked=?', filter['blocked'] == true ? 1 : 0);
  if (filter['estimateMin'] != null)
    clause('i.estimate>=?', filter['estimateMin']);
  if (filter['estimateMax'] != null)
    clause('i.estimate<=?', filter['estimateMax']);
  if (filter['dueFrom'] != null) clause('i.due_day>=?', filter['dueFrom']);
  if (filter['dueTo'] != null) clause('i.due_day<=?', filter['dueTo']);
  if (filter['tag'] != null)
    clause(
      "EXISTS(SELECT 1 FROM json_each(t.payload,'\$.tags') jt WHERE jt.value=?)",
      filter['tag'],
    );
  if (filter['hasReminder'] is bool)
    where.add(
      '${filter['hasReminder'] == true ? '' : 'NOT '}EXISTS(SELECT 1 FROM reminders r WHERE json_extract(r.payload,\'\$.task\')=i.id AND json_extract(r.payload,\'\$.enabled\')=1)',
    );
  final needle = foldSearch(search);
  if (needle.length >= 3 && _ftsAvailable(db)) {
    clause(
      'i.id IN(SELECT id FROM task_fts WHERE task_fts MATCH ?)',
      '"${needle.replaceAll('"', '""')}"',
    );
  } else if (needle.isNotEmpty) {
    clause(
      "i.search LIKE ? ESCAPE '\\'",
      '%${needle.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_')}%',
    );
  }
  final order = switch (sort) {
    'title' => 'i.folded_title',
    'due' => "COALESCE(i.due_instant,'9999')",
    'priority' => 'i.priority DESC',
    'created' => 'i.created',
    'updated' => 'i.updated',
    _ => 'i.position',
  };
  final from =
          'task_index i JOIN tasks t ON t.id=i.id WHERE ${where.join(' AND ')}',
      count =
          db.select('SELECT COUNT(*) n FROM $from', args).single['n'] as int;
  final rows = db.select(
    'SELECT t.payload FROM $from ORDER BY $order,i.id LIMIT ? OFFSET ?',
    [...args, limit, offset],
  );
  return BoardsTaskPage(
    rows
        .map((r) => BoardRecord(object(jsonDecode(r['payload'] as String))))
        .toList(),
    count,
    revision,
  );
}
