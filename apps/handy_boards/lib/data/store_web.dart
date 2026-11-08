import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:crypto/crypto.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'store.dart';

final names = [
  ...kinds,
  'files',
  'file_meta',
  'state',
  'task_index',
  'asset_blobs',
];
Future<BoardsStore> openStore() async {
  final done = Completer<BoardsStore>(),
      request = web.window.indexedDB.open('handy-boards', 4);
  request.onupgradeneeded = ((web.Event _) {
    final db = request.result as web.IDBDatabase,
        transaction = request.transaction!;
    for (final k in names)
      if (!db.objectStoreNames.contains(k)) db.createObjectStore(k);
    final index = transaction.objectStore('task_index');
    for (final entry in {
      'board': 'board',
      'grams': 'grams',
      'partial': 'partial',
    }.entries)
      if (!index.indexNames.contains(entry.key))
        index.createIndex(
          entry.key,
          entry.value.toJS,
          web.IDBIndexParameters(multiEntry: entry.key == 'grams'),
        );
    for (final key in [
      'manual',
      'due',
      'priority',
      'title',
      'created',
      'updated',
    ]) {
      for (final grouped in [true, false]) {
        final name = '${grouped ? 'board' : 'global'}_$key';
        if (!index.indexNames.contains(name))
          index.createIndex(name, [if (grouped) 'board', key, 'id'].jsify()!);
      }
    }
    index.clear();
    final cursor = transaction.objectStore('files').openCursor();
    cursor.onsuccess = ((web.Event _) {
      try {
        final raw = cursor.result;
        if (raw == null) return;
        final row = raw as web.IDBCursorWithValue;
        final value = object(jsonDecode(row.value.dartify() as String));
        if (value['path'] != row.key.dartify() ||
            value['body'] is! String ||
            (value['body'] as String).length > 16000000)
          throw const FormatException('Invalid managed asset');
        final bytes = base64Decode(value['body']);
        if (bytes.length > 12000000)
          throw const FormatException('Image exceeds 12 MB');
        transaction
            .objectStore('file_meta')
            .put(
              jsonEncode({
                'path': value['path'],
                'bytes': bytes.length,
                'sha256': sha256.convert(bytes).toString(),
              }).toJS,
              row.key,
            );
        transaction
            .objectStore('asset_blobs')
            .put(
              (value['body'] as String).toJS,
              sha256.convert(bytes).toString().toJS,
            );
        row.continue_();
      } catch (_) {
        transaction.abort();
      }
    }).toJS;
  }).toJS;
  request.onsuccess = ((web.Event _) {
    final db = request.result as web.IDBDatabase;
    db.onversionchange = ((web.Event _) => db.close()).toJS;
    if (!done.isCompleted) done.complete(BrowserBoardsStore(db));
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!done.isCompleted)
      done.completeError(
        StateError('Browser storage unavailable; existing data preserved'),
      );
  }).toJS;
  request.onblocked = ((web.Event _) {
    if (!done.isCompleted)
      done.completeError(StateError('Close other Boards tabs and retry'));
  }).toJS;
  return done.future;
}

class _BrowserRecords extends BoardsSnapshotMap<BoardRecord> {
  final Map<String, BoardRecord> data;
  final String kind;
  @override
  final int snapshotRevision;
  _BrowserRecords(this.kind, this.snapshotRevision, Iterable<BoardRecord> rows)
    : data = Map.unmodifiable({for (final r in rows) r.id: r});
  @override
  String get storageIdentity => 'handy-boards/$kind';
  @override
  Iterable<String> get keys => data.keys;
  @override
  BoardRecord? operator [](Object? key) => data[key];
  @override
  Set<String> changedKeysCompared(BoardsSnapshotMap<BoardRecord> other) => {
    ...keys,
    ...other.keys,
  };
  @override
  void operator []=(String key, BoardRecord value) =>
      throw UnsupportedError('Immutable snapshot');
  @override
  BoardRecord? remove(Object? key) =>
      throw UnsupportedError('Immutable snapshot');
  @override
  void clear() => throw UnsupportedError('Immutable snapshot');
}

class _BrowserAssets extends BoardsAssetMap {
  final web.IDBDatabase db;
  @override
  final int snapshotRevision;
  @override
  final Map<String, Json> descriptors;
  _BrowserAssets(this.db, this.snapshotRevision, Map<String, Json> descriptors)
    : descriptors = Map.unmodifiable(descriptors);
  @override
  String get storageIdentity => 'handy-boards/assets';
  @override
  Iterable<String> get keys => descriptors.keys;
  @override
  bool containsKey(Object? key) => descriptors.containsKey(key);
  @override
  Uint8List? operator [](Object? key) {
    if (!containsKey(key)) return null;
    throw UnsupportedError('Use asynchronous readFile for browser assets');
  }

  @override
  Future<Uint8List> readAsset(String path) {
    final done = Completer<Uint8List>(),
        transaction = db.transaction(['asset_blobs'.toJS].toJS, 'readonly'),
        request = transaction
            .objectStore('asset_blobs')
            .get((descriptors[path]?['sha256'] as String? ?? '').toJS);
    request.onsuccess = ((web.Event _) {
      try {
        final raw = request.result.dartify();
        if (raw == null) throw const FormatException('Missing asset');
        final bytes = base64Decode(raw as String);
        if (bytes.length != descriptors[path]?['bytes'] ||
            sha256.convert(bytes).toString() != descriptors[path]?['sha256'])
          throw const FormatException('Stored file checksum mismatch');
        done.complete(bytes);
      } catch (e) {
        done.completeError(e);
      }
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!done.isCompleted)
        done.completeError(StateError('Unable to read browser asset'));
    }).toJS;
    return done.future;
  }

  @override
  Set<String> changedKeysCompared(BoardsSnapshotMap<Uint8List> other) => {
    ...keys,
    ...other.keys,
  };
  @override
  void operator []=(String key, Uint8List value) =>
      throw UnsupportedError('Immutable snapshot');
  @override
  Uint8List? remove(Object? key) =>
      throw UnsupportedError('Immutable snapshot');
  @override
  void clear() => throw UnsupportedError('Immutable snapshot');
}

class BrowserBoardsStore
    implements BoardsStore, BoardsSnapshotStore, BoardsPagedStore {
  final web.IDBDatabase db;
  BoardsState? _last;
  BrowserBoardsStore(this.db);
  @override
  BoardsState? get currentSnapshot => _last;
  web.IDBTransaction tx(String mode) =>
      db.transaction(names.map((s) => s.toJS).toList().toJS, mode);
  @override
  Future<BoardsState> read() async {
    final done = Completer<BoardsState>(),
        transaction = tx('readonly'),
        values = <String, dynamic>{};
    for (final name in [...kinds, 'state', 'file_meta']) {
      final request = name == 'state'
          ? transaction.objectStore(name).get('snapshot'.toJS)
          : transaction.objectStore(name).getAll();
      request.onsuccess = ((web.Event _) {
        final raw = request.result.dartify();
        values[name] = name == 'state'
            ? (raw == null
                  ? BoardsState().toJson(includeFiles: false)
                  : jsonDecode(raw as String))
            : (raw as List).map((v) => jsonDecode(v as String)).toList();
      }).toJS;
    }
    transaction.oncomplete = ((web.Event _) {
      try {
        final header = object(values['state']);
        if (![1, 2, 3, 4].contains(header['schema']))
          throw const FormatException('Unsupported Boards schema');
        final revision = header['revision'] as int? ?? 0;
        final state = BoardsState.fromSnapshot(
          revision: revision,
          preferences: object(header['preferences'] ?? {}),
          data: {
            for (final k in kinds)
              k: _BrowserRecords(
                k,
                revision,
                (values[k] as List).map((v) => BoardRecord(object(v))),
              ),
          },
          files: _BrowserAssets(db, revision, {
            for (final raw in values['file_meta'] as List)
              object(raw)['path']: object(raw),
          }),
        );
        state.validate();
        done.complete(state);
      } catch (e) {
        done.completeError(e);
      }
    }).toJS;
    transaction.onabort = ((web.Event _) {
      if (!done.isCompleted)
        done.completeError(StateError('Browser read aborted'));
    }).toJS;
    final state = await done.future;
    _last = state;
    final check = Completer<int>(),
        countTx = tx('readonly'),
        count = countTx.objectStore('task_index').count();
    count.onsuccess = ((web.Event _) => check.complete(
      count.result.dartify() as int,
    )).toJS;
    if (await check.future != state.rows('tasks').length)
      await _repairIndex(state);
    return state;
  }

  Map<String, dynamic> projection(BoardsState s, BoardRecord task) {
    final category =
            s.maybe('categories', task.data['category'])?.str('title') ?? '',
        tags = task
            .strings('tags')
            .map((id) => s.get('tags', id).str('title'))
            .join(' '),
        links = s
            .related('attachments', task.id)
            .map((a) => '${a.str('url')} ${a.str('name')}')
            .join(' '),
        text = foldSearch(
          '${task.str('title')} ${task.str('notes')} $category $tags ${task.data['custom'] ?? {}} $links',
        );
    final grams = <String>{};
    for (var i = 0; i + 3 <= text.length && grams.length < 4096; i++)
      grams.add(text.substring(i, i + 3));
    return {
      'id': task.id,
      'board': task.str('board'),
      'payload': jsonEncode(task.data),
      'search': text,
      'grams': grams.toList(),
      'partial': grams.length >= 4096 ? 1 : 0,
      'manual': task.number('order'),
      'due': task.data['due'] == null
          ? '9999'
          : deadlineSort(object(task.data['due'])),
      'priority': -task.number('priority'),
      'title': foldSearch(task.str('title')),
      'created': task.str('created'),
      'updated': task.str('updated'),
    };
  }

  Future<void> _repairIndex(BoardsState state) async {
    final rows = <Map<String, dynamic>>[];
    var n = 0;
    for (final t in state.rows('tasks')) {
      rows.add(projection(state, t));
      if (++n % 100 == 0) await Future<void>.delayed(Duration.zero);
    }
    final done = Completer<void>(),
        transaction = tx('readwrite'),
        request = transaction.objectStore('state').get('snapshot'.toJS);
    Object? failure;
    transaction.oncomplete = ((web.Event _) => done.complete()).toJS;
    transaction.onabort = ((web.Event _) => done.completeError(
      failure ?? StateError('Index migration failed; library preserved'),
    )).toJS;
    request.onsuccess = ((web.Event _) {
      try {
        final raw = request.result.dartify(),
            revision = raw == null
                ? 0
                : object(jsonDecode(raw as String))['revision'];
        if (revision != state.revision)
          throw StateError('Another tab changed Boards data; reload');
        final index = transaction.objectStore('task_index');
        index.clear();
        for (final row in rows)
          index.put(row.jsify()!, (row['id'] as String).toJS);
      } catch (e) {
        failure = e;
        transaction.abort();
      }
    }).toJS;
    await done.future;
  }

  @override
  Future<void> commit(BoardsState next, {required int expectedRevision}) async {
    next.validate();
    final before = _last ?? await read(),
        changes = {for (final k in kinds) k: next.recordChanges(before, k)},
        assets = next.assetChanges(before);
    final affected = <String>{...changes['tasks']!.keys};
    for (final kind in ['categories', 'tags', 'boards', 'fields'])
      if (changes[kind]!.isNotEmpty)
        affected.addAll(next.rows('tasks').map((t) => t.id));
    for (final entry in changes['attachments']!.entries) {
      final old = before.maybe('attachments', entry.key);
      if (old != null) affected.add(old.str('task'));
      if (entry.value != null) affected.add(entry.value!.str('task'));
    }
    for (final e in assets.entries) {
      if (e.value == null) continue;
      final bytes = await next.readFile(e.key);
      final staged = Completer<void>(),
          transaction = db.transaction(['asset_blobs'.toJS].toJS, 'readwrite');
      transaction
          .objectStore('asset_blobs')
          .put(base64Encode(bytes).toJS, (e.value!['sha256'] as String).toJS);
      transaction.oncomplete = ((web.Event _) => staged.complete()).toJS;
      transaction.onabort = ((web.Event _) => staged.completeError(
        StateError('Browser asset quota exceeded; library preserved'),
      )).toJS;
      await staged.future;
    }
    final projections = <String, Map<String, dynamic>?>{};
    var n = 0;
    for (final id in affected) {
      final task = next.maybe('tasks', id);
      projections[id] = task == null ? null : projection(next, task);
      if (++n % 100 == 0) await Future<void>.delayed(Duration.zero);
    }
    final done = Completer<void>(),
        transaction = tx('readwrite'),
        request = transaction.objectStore('state').get('snapshot'.toJS);
    Object? failure;
    transaction.oncomplete = ((web.Event _) => done.complete()).toJS;
    transaction.onabort = ((web.Event _) => done.completeError(
      failure ??
          StateError(
            'Browser quota/transaction failure; previous data preserved',
          ),
    )).toJS;
    request.onsuccess = ((web.Event _) {
      try {
        final raw = request.result.dartify(),
            revision = raw == null
                ? 0
                : object(jsonDecode(raw as String))['revision'];
        if (revision != expectedRevision ||
            next.revision != expectedRevision + 1)
          throw StateError('Another tab changed Boards data; reload');
        for (final kind in kinds) {
          final store = transaction.objectStore(kind);
          for (final e in changes[kind]!.entries) {
            if (e.value == null) {
              store.delete(e.key.toJS);
            } else {
              store.put(jsonEncode(e.value!.data).toJS, e.key.toJS);
            }
          }
        }
        for (final e in assets.entries) {
          if (e.value == null) {
            transaction.objectStore('file_meta').delete(e.key.toJS);
            transaction.objectStore('files').delete(e.key.toJS);
          } else {
            transaction
                .objectStore('file_meta')
                .put(jsonEncode({'path': e.key, ...e.value!}).toJS, e.key.toJS);
          }
        }
        final index = transaction.objectStore('task_index');
        for (final e in projections.entries) {
          if (e.value == null) {
            index.delete(e.key.toJS);
          } else {
            index.put(e.value!.jsify()!, e.key.toJS);
          }
        }
        transaction
            .objectStore('state')
            .put(
              jsonEncode({
                'app': 'handy-boards',
                'schema': 3,
                'revision': next.revision,
                'preferences': next.preferences,
              }).toJS,
              'snapshot'.toJS,
            );
      } catch (e) {
        failure = e;
        transaction.abort();
      }
    }).toJS;
    await done.future;
    // Reuse immutable metadata after commit; only file descriptors need rebuilding.
    final descriptors = <String, Json>{
      for (final key in next.filePaths) key: next.assetInfo(key),
    };
    _last = BoardsState.fromSnapshot(
      revision: next.revision,
      preferences: next.preferences,
      data: {
        for (final k in kinds)
          k: _BrowserRecords(k, next.revision, next.rows(k)),
      },
      files: _BrowserAssets(db, next.revision, descriptors),
    );
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
  }) async {
    validateTaskFilter(filter);
    if (limit < 1 || limit > 500 || offset < 0)
      throw const FormatException('Page size 1..500');
    final state = _last ?? await read(), needle = foldSearch(search);
    if (expectedRevision != null && expectedRevision != state.revision)
      throw StateError('Page revision changed; reload');
    Set<String>? matchingIds;
    if (needle.length >= 3) {
      matchingIds = <String>{};
      final ids = matchingIds,
          done = Completer<void>(),
          transaction = tx('readonly'),
          index = transaction.objectStore('task_index');
      for (final request in [
        index
            .index('grams')
            .openCursor(web.IDBKeyRange.only(needle.substring(0, 3).toJS)),
        index.index('partial').openCursor(web.IDBKeyRange.only(1.toJS)),
      ]) {
        request.onsuccess = ((web.Event _) {
          final raw = request.result;
          if (raw == null) return;
          final cursor = raw as web.IDBCursorWithValue,
              row = object(cursor.value.dartify());
          if ((board == null || row['board'] == board) &&
              (row['search'] as String).contains(needle))
            ids.add(row['id']);
          cursor.continue_();
        }).toJS;
      }
      transaction.oncomplete = ((web.Event _) => done.complete()).toJS;
      transaction.onabort = ((web.Event _) => done.completeError(
        StateError('Browser search aborted'),
      )).toJS;
      await done.future;
    }
    final done = Completer<void>(),
        transaction = tx('readonly'),
        index = transaction.objectStore('task_index'),
        order =
            [
              'manual',
              'due',
              'priority',
              'title',
              'created',
              'updated',
            ].contains(sort)
            ? sort
            : 'manual';
    final cursorRequest = board == null
        ? index.index('global_$order').openCursor()
        : index
              .index('board_$order')
              .openCursor(
                web.IDBKeyRange.bound([board].jsify()!, [board, []].jsify()!),
              );
    final rows = <BoardRecord>[];
    var total = 0, revision = 0;
    cursorRequest.onsuccess = ((web.Event _) {
      final raw = cursorRequest.result;
      if (raw == null) return;
      final cursor = raw as web.IDBCursorWithValue,
          row = object(cursor.value.dartify());
      if ((matchingIds == null || matchingIds.contains(row['id'])) &&
          (needle.isEmpty || (row['search'] as String).contains(needle))) {
        final t = BoardRecord(object(jsonDecode(row['payload'] as String)));
        if (taskMatches(state, t, board: board, filter: filter)) {
          if (total >= offset && rows.length < limit) rows.add(t);
          total++;
        }
      }
      cursor.continue_();
    }).toJS;
    final rev = transaction.objectStore('state').get('snapshot'.toJS);
    rev.onsuccess = ((web.Event _) {
      final raw = rev.result.dartify();
      revision = raw == null
          ? 0
          : object(jsonDecode(raw as String))['revision'];
    }).toJS;
    transaction.oncomplete = ((web.Event _) => done.complete()).toJS;
    transaction.onabort = ((web.Event _) => done.completeError(
      StateError('Browser page read aborted'),
    )).toJS;
    await done.future;
    if (revision != state.revision)
      throw StateError('Page revision changed; reload');
    return BoardsTaskPage(rows, total, revision);
  }

  @override
  Future<String> integrity() async {
    (await read()).validate();
    return 'ok';
  }

  @override
  void close() {
    _last = null;
    db.close();
  }
}
