import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'engine_test.dart' show fixture, withTask;

void main() {
  test(
    'managed original attachment JSON ZIP roundtrip, merge remaps only references',
    () {
      var s = withTask(fixture());
      final bytes = Uint8List.fromList(utf8.encode('original bytes')),
          path = 'assets/attachment.txt';
      s = s
          .copy(files: {path: bytes})
          .put(
            'attachments',
            BoardRecord({
              'id': 'a',
              'task': 't',
              'path': path,
              'name': 't',
              'sha256': sha256.convert(bytes).toString(),
            }),
          );
      s = s.put(
        'tasks',
        s.get('tasks', 't').copy({'title': 't', 'notes': 't'}),
      );
      for (final zip in [true, false]) {
        final back = readBackup(exportBackup(s, zip: zip));
        expect(back.toJson(), s.toJson());
      }
      final merged = restoreBackup(
        BoardsState(),
        s,
        replace: false,
        confirmed: true,
      );
      expect(merged.rows('tasks').single.str('title'), 't');
      expect(merged.rows('tasks').single.str('notes'), 't');
      expect(merged.rows('attachments').single.str('name'), 't');
      expect(merged.file(merged.rows('attachments').single.str('path')), bytes);
      bytes[0] = 0;
      expect(s.file(path)[0], isNot(0));
    },
  );
  test('ZIP traversal and mismatched checksums are rejected', () {
    final a = Archive()..addFile(ArchiveFile('../escape', 1, [1]));
    expect(
      () => readBackup(Uint8List.fromList(ZipEncoder().encode(a))),
      throwsFormatException,
    );
    final j = fixture().toJson();
    j['schema'] = 99;
    expect(
      () => readBackup(Uint8List.fromList(utf8.encode(jsonEncode(j)))),
      throwsFormatException,
    );
  });
  test(
    'canonical CSV preserves task UUID, tags, Unicode, time and ordering',
    () {
      var s = withTask(fixture());
      s = s
          .put(
            'tags',
            BoardRecord({'id': 'math', 'board': 'b', 'title': 'Toán'}),
          )
          .put(
            'tags',
            BoardRecord({'id': 'school', 'board': 'b', 'title': 'school'}),
          );
      s = s.put(
        'tasks',
        s.get('tasks', 't').copy({
          'tags': ['math', 'school'],
        }),
      );
      s = s.put(
        'tasks',
        s.get('tasks', 't').copy({
          'title': '=2+3',
          'notes': 'first, line\nTiếng Việt',
          'due': {
            'kind': 'time',
            'at': '2026-11-02T03:30:00Z',
            'zone': 'Asia/Ho_Chi_Minh',
          },
          'order': 17,
        }),
      );
      final csv = exportTaskCsv(s, 'b'),
          base = s
              .remove('tasks', {'t'})
              .remove('events', s.rows('events').map((r) => r.id).toSet());
      final restored = importOwnTaskCsv(base, 'b', parseCsv(csv));
      expect(restored.get('tasks', 't').toJson(), s.get('tasks', 't').toJson());
      final rows = parseCsv(csv);
      rows[1][1] = 'changed';
      expect(() => importOwnTaskCsv(base, 'b', rows), throwsFormatException);
    },
  );

  test('timed range includes the end day', () {
    var s = withTask(fixture());
    s = s.put(
      'tasks',
      s.get('tasks', 't').copy({
        'due': {
          'kind': 'time',
          'at': '2026-11-03T02:00:00Z',
          'zone': 'Asia/Ho_Chi_Minh',
        },
      }),
    );
    expect(
      queryTasks(
        s,
        filter: {'dueFrom': '2026-11-03', 'dueTo': '2026-11-03'},
      ).length,
      1,
    );
  });
}
