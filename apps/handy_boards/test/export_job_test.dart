import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/data/store_native.dart';
import 'package:handy_boards/platform/export_job.dart';
import 'package:handy_boards/platform/export_job_native.dart';
import 'package:handy_boards/platform/staged_backup_native.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

void main() {
  late Directory dir;
  late NativeBoardsStore store;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('boards-stream-qa-');
    store = NativeBoardsStore('${dir.path}/boards.sqlite');
    await store.read();
  });
  tearDown(() async {
    store.close();
    await dir.delete(recursive: true);
  });
  BoardsState fixture() {
    var s = createBoard(
      BoardsState(),
      'Học kỳ / 東京',
      boardId: 'b',
      template: 'study',
    );
    s = saveTask(
      s,
      newTask(
        s,
        'b',
        'Toán học – kiểm tra',
        category: s.rows('categories').first.id,
      ),
    );
    return s.copy(revision: 1);
  }

  test(
    'stream ZIP preserves a captured revision and remains legacy-readable',
    () async {
      var s = fixture().putFile(
        'assets/a.bin',
        Uint8List.fromList([0, 255, 4]),
      );
      await store.commit(s, expectedRevision: 0);
      final original = store.currentSnapshot!;
      await store.commit(
        original.copy(revision: 2, preferences: {'locale': 'vi'}),
        expectedRevision: 1,
      );
      final job = BoardsJob();
      addTearDown(job.dispose);
      final output = '${dir.path}/backup.zip';
      await runBoardsExportWorker(store.path, 1, 'zip', output, job);
      final restored = readBackup(await File(output).readAsBytes());
      expect(restored.toJson(), original.toJson());
      expect(restored.preferences, isEmpty);
      final staging = await Directory('${dir.path}/verify').create();
      expect(
        (await readStagedBoardsZip(output, staging.path)).toJson(),
        original.toJson(),
      );
    },
  );
  test(
    '33 MB ZIP round trip stages originals and commits/restores exact IDs',
    () async {
      var s = fixture();
      final body = Uint8List.fromList(
        List.generate(11000000, (i) => (i * 17) % 256),
      );
      for (var i = 0; i < 3; i++) s = s.putFile('assets/large$i.bin', body);
      await store.commit(s, expectedRevision: 0);
      final lazy = store.currentSnapshot!, output = '${dir.path}/large.zip';
      await writeBoardsZip(lazy, output);
      expect(await File(output).length(), greaterThan(30000000));
      final stage = await Directory('${dir.path}/staged').create();
      final incoming = await readStagedBoardsZip(output, stage.path);
      expect(
        incoming.rows('tasks').map((t) => t.id),
        lazy.rows('tasks').map((t) => t.id),
      );
      expect(incoming.filePaths.length, 3);
      for (final path in incoming.filePaths)
        expect(
          sha256.convert(await incoming.readFile(path)).toString(),
          sha256.convert(body).toString(),
        );
      final replacement = restoreBackup(
        lazy,
        incoming,
        replace: true,
        confirmed: true,
      ).copy(revision: 2);
      await store.commit(replacement, expectedRevision: 1);
      expect(store.currentSnapshot!.filePaths.toSet(), lazy.filePaths.toSet());
      final merged = restoreBackup(
        store.currentSnapshot!,
        incoming,
        replace: false,
        confirmed: true,
      ).copy(revision: 3);
      await store.commit(merged, expectedRevision: 2);
      expect(store.currentSnapshot!.filePaths.length, 6);
      expect(store.currentSnapshot!.rows('tasks').length, 2);
      for (final path in store.currentSnapshot!.filePaths)
        expect(await store.currentSnapshot!.readFile(path), body);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
  test(
    'rejects traversal, duplicate, truncated and damaged manifest ZIPs',
    () async {
      final good = exportBackup(fixture());
      Future<void> rejects(Uint8List bytes, String name) async {
        final source = File('${dir.path}/$name.zip');
        await source.writeAsBytes(bytes);
        final stage = await Directory('${dir.path}/$name').create();
        await expectLater(
          readStagedBoardsZip(source.path, stage.path),
          throwsA(isA<FormatException>()),
        );
        expect((await store.read()).rows('boards'), isEmpty);
      }

      await rejects(good.sublist(0, good.length - 12), 'truncated');
      final a = Archive()..addFile(ArchiveFile('../outside.txt', 3, [1, 2, 3]));
      await rejects(Uint8List.fromList(ZipEncoder().encode(a)), 'traversal');
      final damaged = ZipDecoder().decodeBytes(good);
      final manifest = damaged.findFile('manifest.json')!;
      final j =
          jsonDecode(utf8.decode(manifest.content)) as Map<String, dynamic>;
      (j['files']['boards.json'] as Map)['sha256'] = '0' * 64;
      damaged.removeFile(manifest);
      final b = utf8.encode(jsonEncode(j));
      damaged.addFile(ArchiveFile('manifest.json', b.length, b));
      await rejects(
        Uint8List.fromList(ZipEncoder().encode(damaged)),
        'checksum',
      );
      expect(await File('${dir.path}/outside.txt').exists(), false);
    },
  );
  test(
    'cancel export worker preserves database; PDF is streamed as a valid file',
    () async {
      var s = fixture();
      final edit = BoardsEdit(s);
      for (var i = 0; i < 1000; i++)
        edit.put('tasks', newTask(s, 'b', 'Task $i'));
      s = edit.finish().copy(revision: 1);
      await store.commit(s, expectedRevision: 0);
      final job = BoardsJob();
      addTearDown(job.dispose);
      job.addListener(() {
        if ((job.value ?? 0) > 0) job.cancel();
      });
      final font = await File(
        '../../packages/handy_ui/assets/fonts/NotoSans-Regular.ttf',
      ).readAsBytes();
      await expectLater(
        runBoardsExportWorker(
          store.path,
          1,
          'pdf',
          '${dir.path}/cancel.pdf',
          job,
          board: 'b',
          font: font,
        ),
        throwsA(isA<BoardsJobCancelled>()),
      );
      expect((await store.read()).rows('tasks').length, 1001);
      final small = fixture().put(
            'boards',
            fixture().get('boards', 'b').copy({'title': 'Học kỳ'}),
          ),
          output = '${dir.path}/small.pdf';
      await writeBoardsPdf(small, 'b', font, output, vi: true);
      final bytes = await File(output).readAsBytes();
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(latin1.decode(bytes).contains('%%EOF'), true);
    },
  );
}
