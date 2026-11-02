import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/data/store_native.dart';
import 'package:handy_boards/controller.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

void main() {
  late Directory dir;
  late NativeBoardsStore store;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('boards-store-');
    store = NativeBoardsStore('${dir.path}/boards.sqlite');
  });
  tearDown(() async {
    store.close();
    await dir.delete(recursive: true);
  });
  test(
    'SQLite atomic commit, exact reopen, CAS refusal preserves previous state',
    () async {
      expect((await store.read()).rows('tasks'), isEmpty);
      var s = createBoard(
        BoardsState(),
        'Semester',
        boardId: 'b',
        template: 'study',
      );
      s = saveTask(s, newTask(s, 'b', 'Bài tập'));
      s = s.copy(revision: 1);
      await store.commit(s, expectedRevision: 0);
      expect((await NativeBoardsStore(store.path).read()).toJson(), s.toJson());
      await expectLater(store.commit(s, expectedRevision: 0), throwsStateError);
      expect((await store.read()).toJson(), s.toJson());
    },
  );
  test(
    'SQLite managed asset bytes survive reopen, removal and persisted Undo',
    () async {
      var s = createBoard(BoardsState(), 'Files', boardId: 'b');
      final task = newTask(s, 'b', 'Original asset');
      s = saveTask(s, task);
      final bytes = Uint8List.fromList(List.generate(1000000, (i) => i % 256));
      s = s
          .copy(files: {'assets/original.bin': bytes})
          .put(
            'attachments',
            BoardRecord({
              'id': 'asset',
              'task': task.id,
              'board': 'b',
              'name': 'Original.bin',
              'path': 'assets/original.bin',
              'sha256': sha256.convert(bytes).toString(),
            }),
          )
          .copy(revision: 1);
      await store.commit(s, expectedRevision: 0);
      final reopened = await NativeBoardsStore(store.path).read();
      expect(reopened.files['assets/original.bin'], bytes);
      final c = BoardsController(open: () async => store);
      await c.load();
      await c.change((s) {
        final e = BoardsEdit(s);
        e.remove('attachments', 'asset');
        e.files.remove('assets/original.bin');
        return e.finish();
      });
      expect((await store.read()).files, isEmpty);
      await c.undo();
      final restored = await NativeBoardsStore(store.path).read();
      expect(restored.files['assets/original.bin'], bytes);
      expect(restored.get('attachments', 'asset').str('task'), task.id);
      c.dispose();
    },
  );
  test('future/corrupt schema is refused without reset', () async {
    final db = openBoardsDatabase(store.path);
    db.execute('PRAGMA user_version=99');
    db.close();
    await expectLater(store.read(), throwsFormatException);
    final raw = File(store.path).readAsBytesSync();
    expect(raw, isNotEmpty);
  });
  test(
    'controller serializes edits, Undo/Redo persists and restart reads final state',
    () async {
      final c = BoardsController(open: () async => store);
      await c.load();
      await c.change((s) => createBoard(s, 'Life', boardId: 'b'));
      await Future.wait([
        c.change((s) => saveTask(s, newTask(s, 'b', 'A'))),
        c.change((s) => saveTask(s, newTask(s, 'b', 'B'))),
      ]);
      expect(c.state!.rows('tasks').length, 2);
      await c.undo();
      expect(c.state!.rows('tasks').length, 1);
      await c.redo();
      expect(c.state!.rows('tasks').length, 2);
      expect((await store.read()).toJson(), c.state!.toJson());
      c.dispose();
    },
  );
}
