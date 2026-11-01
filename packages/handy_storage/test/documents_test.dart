import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_storage/src/documents_io.dart';

void main() {
  late Directory temp;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('handy-documents-');
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });
  test(
    'reset preserves corrupt bytes, ZIP exports exactly, undo restores them',
    () async {
      final store = FileDocuments('handy-test', 10000, directory: temp);
      await store.save('{"n":1}');
      final folder = Directory('${temp.path}/handy-test');
      final original = <String, List<int>>{
        'a.json': [0, 255, 13, 10, 42],
        'b.json': utf8.encode('broken'),
        'b.json.pending': utf8.encode('interrupted write'),
      };
      for (final entry in original.entries) {
        await File('${folder.path}/${entry.key}').writeAsBytes(entry.value);
      }
      await expectLater(store.load(), throwsFormatException);
      final copy = await store.preserveAndReset();
      expect(await store.load(), isNull);
      expect((await store.preserved()).single.id, copy.id);
      final zip = ZipDecoder().decodeBytes(
        await store.exportPreserved(copy.id),
        verify: true,
      );
      for (final entry in original.entries) {
        expect(zip.findFile(entry.key)!.content, entry.value);
      }
      final manifest = jsonDecode(
        utf8.decode(zip.findFile('manifest.json')!.content),
      );
      expect(manifest['namespace'], 'handy-test');
      expect(
        (manifest['checksums'] as Map).keys.toSet(),
        original.keys.toSet(),
      );
      await store.undoReset(copy.id);
      await expectLater(store.load(), throwsFormatException);
      for (final entry in original.entries) {
        expect(
          await File('${folder.path}/${entry.key}').readAsBytes(),
          entry.value,
        );
      }
      expect(await store.preserved(), isEmpty);
    },
  );
  test(
    'undo never overwrites new data; later reset preserves both libraries',
    () async {
      final store = FileDocuments('handy-test', 10000, directory: temp);
      await store.save('{"old":1}');
      final first = await store.preserveAndReset();
      await store.save('{"new":2}');
      await expectLater(store.undoReset(first.id), throwsFormatException);
      expect(await store.load(), '{"new":2}');
      final second = await store.preserveAndReset();
      await store.undoReset(first.id);
      expect(await store.load(), '{"old":1}');
      expect((await store.preserved()).single.id, second.id);
      expect(await store.exportPreserved(second.id), isNotEmpty);
    },
  );
  test(
    'recovery validates IDs, serializes saves, refuses empty reset',
    () async {
      final store = FileDocuments('handy-test', 10000, directory: temp);
      await expectLater(store.preserveAndReset(), throwsFormatException);
      await store.save('{"n":1}');
      final reset = store.preserveAndReset();
      final save = store.save('{"n":2}');
      final copy = await reset;
      await save;
      expect(await store.load(), '{"n":2}');
      await expectLater(store.exportPreserved('../a'), throwsFormatException);
      await expectLater(store.undoReset('../a'), throwsFormatException);
      expect(await store.exportPreserved(copy.id), isNotEmpty);
      expect(
        () => FileDocuments('../escape', 10, directory: temp),
        throwsArgumentError,
      );
    },
  );
  test(
    'unknown files are preserved and diagnostic export refuses unsafe content',
    () async {
      final store = FileDocuments('handy-test', 10000, directory: temp);
      await store.save('{"n":1}');
      await File('${temp.path}/handy-test/extra.bin').writeAsBytes([1, 2, 3]);
      final copy = await store.preserveAndReset();
      await expectLater(store.exportPreserved(copy.id), throwsFormatException);
      await store.undoReset(copy.id);
      expect(await File('${temp.path}/handy-test/extra.bin').readAsBytes(), [
        1,
        2,
        3,
      ]);
    },
  );
  test(
    'oversized corrupt snapshot stays preserved when diagnostic ZIP is refused',
    () async {
      final store = FileDocuments('handy-test', 10000, directory: temp);
      await store.save('{"n":1}');
      final source = File('${temp.path}/handy-test/a.json');
      final handle = await source.open(mode: FileMode.write);
      await handle.truncate(29000001);
      await handle.close();
      final copy = await store.preserveAndReset();
      await expectLater(store.exportPreserved(copy.id), throwsFormatException);
      await store.undoReset(copy.id);
      expect(await source.length(), 29000001);
      await expectLater(store.load(), throwsFormatException);
    },
  );
  test(
    'real verified local document survives reopening with Unicode',
    () async {
      final s = FileDocuments('handy-test', 10000, directory: temp);
      await s.save('{"name":"Đặng 😀"}');
      expect(
        await FileDocuments('handy-test', 10000, directory: temp).load(),
        '{"name":"Đặng 😀"}',
      );
    },
  );
  test('corrupt latest slot recovers previous committed snapshot', () async {
    final s = FileDocuments('handy-test', 10000, directory: temp);
    await s.save('{"n":1}');
    await s.save('{"n":2}');
    await File('${temp.path}/handy-test/b.json').writeAsString('corrupt');
    expect(await s.load(), '{"n":1}');
    expect(
      await File('${temp.path}/handy-test/b.json').readAsString(),
      'corrupt',
    );
  });
  test('all corrupt slots refuse overwrite and preserve evidence', () async {
    final s = FileDocuments('handy-test', 10000, directory: temp);
    await s.save('{"n":1}');
    final f = File('${temp.path}/handy-test/a.json');
    await f.writeAsString('bad');
    await expectLater(s.load(), throwsFormatException);
    await expectLater(s.save('{"n":3}'), throwsFormatException);
    expect(await f.readAsString(), 'bad');
  });
  test('oversized or malformed writes do not replace current data', () async {
    final s = FileDocuments('handy-test', 12, directory: temp);
    await s.save('{"n":1}');
    await expectLater(s.save('not-json'), throwsFormatException);
    await expectLater(s.save('{"x":"😀😀😀"}'), throwsFormatException);
    expect(await s.load(), '{"n":1}');
  });
  test('pending crash file never becomes committed data', () async {
    final s = FileDocuments('handy-test', 10000, directory: temp);
    await s.save('{"n":1}');
    await File(
      '${temp.path}/handy-test/b.json.pending',
    ).writeAsString('{broken');
    expect(await s.load(), '{"n":1}');
  });
  test(
    'concurrent calls on one repository serialize and retain recovery slot',
    () async {
      final s = FileDocuments('handy-test', 10000, directory: temp);
      await Future.wait([
        s.save('{"n":1}'),
        s.save('{"n":2}'),
        s.save('{"n":3}'),
      ]);
      expect(await s.load(), '{"n":3}');
      expect(await File('${temp.path}/handy-test/b.json').exists(), true);
    },
  );
}
