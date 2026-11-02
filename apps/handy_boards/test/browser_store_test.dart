@TestOn('browser')
library;

import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:test/test.dart';
import 'package:crypto/crypto.dart';
import 'package:handy_boards/data/store_web.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

Future<void> createLegacy({bool corrupt = false}) async {
  final deleted = Completer<void>(),
      remove = web.window.indexedDB.deleteDatabase('handy-boards');
  remove.onsuccess = ((web.Event _) => deleted.complete()).toJS;
  remove.onerror = ((web.Event _) => deleted.completeError(
    StateError('delete failed'),
  )).toJS;
  await deleted.future;
  final opened = Completer<web.IDBDatabase>(),
      request = web.window.indexedDB.open('handy-boards', 1);
  request.onupgradeneeded = ((web.Event _) {
    final db = request.result as web.IDBDatabase;
    for (final kind in [...kinds, 'files', 'state']) db.createObjectStore(kind);
  }).toJS;
  request.onsuccess = ((web.Event _) => opened.complete(
    request.result as web.IDBDatabase,
  )).toJS;
  request.onerror = ((web.Event _) => opened.completeError(
    StateError('open legacy failed'),
  )).toJS;
  final db = await opened.future;
  try {
    final s = createBoard(BoardsState(), 'Dữ liệu cũ', boardId: 'legacy');
    final transaction = db.transaction(
          [...kinds, 'files', 'state'].map((k) => k.toJS).toList().toJS,
          'readwrite',
        ),
        done = Completer<void>();
    transaction.oncomplete = ((web.Event _) => done.complete()).toJS;
    transaction.onabort = ((web.Event _) => done.completeError(
      StateError('legacy write failed'),
    )).toJS;
    for (final kind in kinds)
      for (final record in s.rows(kind))
        transaction
            .objectStore(kind)
            .put(jsonEncode(record.data).toJS, record.id.toJS);
    transaction
        .objectStore('state')
        .put(
          jsonEncode({
            'app': 'handy-boards',
            'schema': 1,
            'revision': 7,
            'preferences': {'locale': 'vi'},
          }).toJS,
          'snapshot'.toJS,
        );
    transaction
        .objectStore('files')
        .put(
          jsonEncode({
            'path': 'assets/legacy.bin',
            'body': corrupt ? '!!!' : base64Encode([0, 1, 255]),
          }).toJS,
          'assets/legacy.bin'.toJS,
        );
    await done.future;
  } finally {
    db.close();
  }
}

void main() {
  test(
    'real IndexedDB v1 migration preserves data and aborts corrupt files',
    () async {
      await createLegacy(corrupt: true);
      await expectLater(openStore(), throwsStateError);
      final request = web.window.indexedDB.open('handy-boards'),
          opened = Completer<web.IDBDatabase>();
      request.onsuccess = ((web.Event _) => opened.complete(
        request.result as web.IDBDatabase,
      )).toJS;
      final legacy = await opened.future;
      expect(legacy.version, 1);
      legacy.close();
      await createLegacy();
      final store = await openStore() as BrowserBoardsStore;
      final state = await store.read();
      expect(state.revision, 7);
      expect(state.get('boards', 'legacy').str('title'), 'Dữ liệu cũ');
      expect(await state.readFile('assets/legacy.bin'), [0, 1, 255]);
      expect(state.preferences['locale'], 'vi');
      expect(store.db.version, 4);
      store.close();
    },
  );
  test(
    'real IndexedDB indexed paging, lazy bytes, Undo and competing writers',
    () async {
      final first = await openStore() as BrowserBoardsStore;
      final initial = await first.read();
      await first.commit(
        BoardsState().copy(revision: initial.revision + 1),
        expectedRevision: initial.revision,
      );
      var s = createBoard(first.currentSnapshot!, 'Browser QA', boardId: 'b');
      final edit = BoardsEdit(s), status = s.rows('statuses').first.id;
      for (var i = 0; i < 320; i++)
        edit.put(
          'tasks',
          BoardRecord({
            'id': 't$i',
            'board': 'b',
            'title': 'Bài tập $i',
            'notes': i % 2 == 0 ? 'Ôn vật lý' : 'Java',
            'status': status,
            'priority': i % 4,
            'estimate': i,
            'order': i,
          }),
        );
      final bytes = Uint8List.fromList(List.generate(1000000, (i) => i % 256));
      s = edit
          .finish()
          .putFile('assets/test.bin', bytes)
          .put(
            'attachments',
            BoardRecord({
              'id': 'file',
              'task': 't0',
              'path': 'assets/test.bin',
              'sha256': sha256.convert(bytes).toString(),
              'name': 'Original',
            }),
          )
          .copy(revision: first.currentSnapshot!.revision + 1);
      await first.commit(s, expectedRevision: first.currentSnapshot!.revision);
      var state = await first.read();
      Future<void> change(BoardsState Function(BoardsState) action) async {
        await first.commit(
          action(state).copy(revision: state.revision + 1),
          expectedRevision: state.revision,
        );
        state = first.currentSnapshot!;
      }

      expect(await state.readFile('assets/test.bin'), bytes);
      final backup = await exportBackupAsync(state);
      expect(readBackup(backup).file('assets/test.bin'), bytes);
      expect(
        readBackup(
          await exportBackupAsync(state, zip: false),
        ).file('assets/test.bin'),
        bytes,
      );
      var checks = 0;
      await expectLater(
        exportBackupAsync(
          state,
          check: () {
            if (++checks > 1) throw StateError('cancel');
          },
        ),
        throwsStateError,
      );
      final page = await first.taskPage(
        board: 'b',
        search: 'on vat',
        sort: 'priority',
        offset: 10,
        limit: 19,
        expectedRevision: state.revision,
      );
      expect(page.total, 160);
      expect(page.tasks.length, 19);
      expect(
        page.tasks.map((t) => t.id),
        queryTasks(
          state,
          board: 'b',
          search: 'on vat',
          sort: 'priority',
        ).skip(10).take(19).map((t) => t.id),
      );
      final beforeDelete = state;
      await change((s) {
        final e = BoardsEdit(s);
        e.remove('attachments', 'file');
        e.removeFile('assets/test.bin');
        return e.finish();
      });
      expect(state.hasFile('assets/test.bin'), false);
      await change((_) => beforeDelete);
      expect(await state.readFile('assets/test.bin'), bytes);
      final second = await openStore() as BrowserBoardsStore;
      final stale = await second.read();
      await change(
        (s) => s.put('tasks', s.get('tasks', 't0').copy({'title': 'New name'})),
      );
      await expectLater(
        second.commit(
          stale.copy(revision: stale.revision + 1),
          expectedRevision: stale.revision,
        ),
        throwsStateError,
      );
      expect((await first.taskPage(search: 'new name')).tasks.single.id, 't0');
      second.close();
      first.close();
    },
  );
}
