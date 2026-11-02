import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/data/store_native.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:crypto/crypto.dart';

void main() {
  late Directory dir;
  late NativeBoardsStore store;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('boards-index-');
    store = NativeBoardsStore('${dir.path}/data.sqlite');
  });
  tearDown(() async {
    store.close();
    await dir.delete(recursive: true);
  });
  test(
    'indexed pages match engine Unicode/substring/filter order without duplicate IDs',
    () async {
      var s = createBoard(
        BoardsState(),
        'Study',
        boardId: 'b',
        template: 'study',
      );
      final edit = BoardsEdit(s),
          status = s
              .rows('statuses')
              .firstWhere((r) => !r.flag('done') && r.number('order') == 1),
          category = s.rows('categories').first;
      for (var i = 0; i < 1205; i++)
        edit.put(
          'tasks',
          BoardRecord({
            'id': 't$i',
            'board': 'b',
            'title': 'Bài tập $i',
            'notes': i % 3 == 0 ? 'Ôn tập vật lý' : 'Java',
            'category': category.id,
            'status': status.id,
            'priority': i == 1204 ? null : i % 4,
            'estimate': i % 60,
            'order': i,
          }),
        );
      s = edit.finish().copy(revision: 1);
      await store.commit(s, expectedRevision: 0);
      final lazy = await store.read();
      expect(lazy.records['tasks'], isA<BoardsSnapshotMap<BoardRecord>>());
      for (final sort in ['manual', 'due', 'title', 'priority']) {
        final filter = <String, dynamic>{
              'estimateMin': 10,
              'estimateMax': 40,
              'priority': 2,
            },
            expected = queryTasks(
              lazy,
              board: 'b',
              search: 'tap vat',
              filter: filter,
              sort: sort,
            );
        final ids = <String>[];
        for (var offset = 0; offset < expected.length; offset += 17) {
          final page = await store.taskPage(
            board: 'b',
            search: 'tap vat',
            filter: filter,
            sort: sort,
            offset: offset,
            limit: 17,
            expectedRevision: 1,
          );
          expect(page.total, expected.length);
          ids.addAll(page.tasks.map((t) => t.id));
        }
        expect(ids, expected.map((t) => t.id).toList());
        expect(ids.toSet().length, ids.length);
      }
      expect((await store.taskPage(search: 'ập', limit: 2)).tasks.length, 2);
      expect(
        (await store.taskPage(filter: {'priority': 0}, limit: 500)).total,
        queryTasks(lazy, filter: {'priority': 0}).length,
      );
      await expectLater(store.taskPage(expectedRevision: 0), throwsStateError);
      await expectLater(store.taskPage(limit: 501), throwsFormatException);
      final next = lazy
          .put(
            'tasks',
            lazy.get('tasks', 't1').copy({'title': 'Đổi tên độc nhất'}),
          )
          .copy(revision: 2);
      await store.commit(next, expectedRevision: 1);
      expect((await store.taskPage(search: 'doc nhat')).tasks.single.id, 't1');
      expect(lazy.get('tasks', 't1').str('title'), 'Bài tập 1');
      expect(
        store.currentSnapshot!.get('tasks', 't1').str('title'),
        'Đổi tên độc nhất',
      );
    },
  );
  test(
    'native v1 migration retains task/assets and builds indexes transactionally',
    () async {
      final db = openBoardsDatabase(store.path);
      db.execute(
        'PRAGMA user_version=1; DROP TABLE record_versions; DROP TABLE file_versions; DROP TABLE asset_blobs; DROP TABLE task_index; DROP TABLE header_versions; DROP TABLE task_fts_lookup;',
      );
      if (db
          .select("SELECT name FROM sqlite_master WHERE name='task_fts'")
          .isNotEmpty)
        db.execute('DROP TABLE task_fts');
      for (final index in [
        'attachments_task_json',
        'dependencies_after_json',
        'dependencies_before_json',
      ])
        db.execute('DROP INDEX IF EXISTS $index');
      final bytes = Uint8List.fromList([0, 1, 2, 255]);
      db.execute('INSERT INTO files VALUES(?,?,?)', [
        'assets/original.bin',
        sha256.convert(bytes).toString(),
        bytes,
      ]);
      final header = BoardsState().toJson(includeFiles: false)..['schema'] = 1;
      for (final kind in kinds) header.remove(kind);
      db.execute('UPDATE metadata SET payload=?', [jsonEncode(header)]);
      db.close();
      final migrated = await store.read();
      expect(migrated.file('assets/original.bin'), bytes);
      expect(migrated.toJson()['schema'], 2);
      final again = openBoardsDatabase(store.path);
      expect(again.userVersion, 4);
      again.close();
    },
  );
}
