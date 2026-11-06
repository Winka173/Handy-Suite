import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

const t0 = '2026-11-01T00:00:00.000Z';

(MediaRef, PortablePicture) picture(int seed, {int size = 3000}) {
  final bytes = Uint8List.fromList(
    List.generate(size, (i) => (i * seed + 7) % 251),
  );
  final ref = MediaRef(
    id: sha256.convert(bytes).toString(),
    mime: 'image/png',
    width: 640,
    height: 480,
    bytes: bytes.length,
    name: 'pic-$seed.png',
  );
  return (
    ref,
    PortablePicture(bytes, Uint8List.fromList(List.filled(120, seed))),
  );
}

Bookmark image(String id, MediaRef media, {String saved = t0}) => Bookmark(
  id: id,
  kind: 'image',
  originalUrl: '',
  normalizedUrl: '',
  media: media,
  savedAt: saved,
  updatedAt: saved,
);

Bookmark link(String id) => Bookmark(
  id: id,
  originalUrl: 'https://example.org/$id',
  normalizedUrl: 'https://example.org/$id',
  savedAt: t0,
  updatedAt: t0,
);

void main() {
  final (refA, picA) = picture(3);
  final (refB, picB) = picture(5);
  SaveLibrary library() => moveToTrash(
    SaveLibrary(bookmarks: [link('l1'), image('i1', refA), image('i2', refB)]),
    ['i2'],
    '2026-11-02T00:00:00.000Z',
  );

  test(
    'a ZIP backup carries pictures, Trash and tombstones, and restores them exactly',
    () {
      final lib = purgeTrash(moveToTrash(library(), ['l1'], t0), [
        'l1',
      ], '2026-11-03T00:00:00.000Z');
      final out = SavePortable.exportWithReport(
        lib,
        SaveFormat.zip,
        pictures: {refA.id: picA, refB.id: picB},
      );
      expect(
        (out.picturesIncluded, out.picturesOmitted, out.picturesMissing),
        (2, 0, 0),
      );
      expect(out.complete, isTrue);
      final preview = SavePortable.preview(out.bytes, SaveFormat.zip);
      expect(preview.pictures.keys, unorderedEquals([refA.id, refB.id]));
      expect(preview.pictures[refA.id]!.original, picA.original);
      expect(preview.pictures[refB.id]!.preview, picB.preview);
      expect((preview.invalidPictures, preview.missingPictures), (0, 0));
      final restored = preview.apply(
        SaveLibrary(),
        strategy: ImportStrategy.replace,
      );
      expect(restored.library.trash.single.id, 'i2');
      expect(restored.library.tombstones.single.id, 'l1');
      expect(restored.pictures.length, 2);
      expect(jsonEncode(restored.library.toJson()), jsonEncode(lib.toJson()));
    },
  );

  test(
    'a picture that is not what its id says is refused, the rest still restore',
    () {
      final out = SavePortable.export(
        library(),
        SaveFormat.zip,
        pictures: {refA.id: picA, refB.id: picB},
      );
      final archive = ZipDecoder().decodeBytes(out);
      final tampered = Archive();
      for (final f in archive.files) {
        var content = f.content as List<int>;
        if (f.name == 'media/${refA.id}.png') {
          content = List.of(content)..[10] ^= 0xFF;
        }
        tampered.addFile(ArchiveFile(f.name, content.length, content));
      }
      final bytes = Uint8List.fromList(ZipEncoder().encode(tampered, level: 0));
      final preview = SavePortable.preview(bytes, SaveFormat.zip);
      expect(preview.invalidPictures, 1);
      expect(preview.pictures.keys, [refB.id]);
      expect(preview.missingPictures, 1);
    },
  );

  test(
    'what does not fit or is missing is counted, never dropped silently',
    () {
      final out = SavePortable.exportWithReport(
        library(),
        SaveFormat.zip,
        pictures: {refA.id: picA},
      );
      expect(out.picturesIncluded, 1);
      expect(out.picturesMissing, 1);
      expect(out.complete, isFalse);
      // A JSON file carries no picture bytes; reading it says so.
      final json = SavePortable.export(library(), SaveFormat.json);
      final preview = SavePortable.preview(json, SaveFormat.json);
      expect(preview.missingPictures, 2);
      expect(preview.pictures, isEmpty);
    },
  );

  test(
    'a merge keeps the current Trash and brings only the pictures new items use',
    () {
      final current = moveToTrash(
        SaveLibrary(bookmarks: [image('mine', refA), link('x')]),
        ['x'],
        t0,
      );
      final file = SavePortable.export(
        SaveLibrary(
          bookmarks: [image('theirs-a', refA), image('theirs-b', refB)],
        ),
        SaveFormat.zip,
        pictures: {refA.id: picA, refB.id: picB},
      );
      final preview = SavePortable.preview(
        file,
        SaveFormat.zip,
        current: current,
      );
      expect(
        preview.duplicateCount,
        1,
        reason: 'the same picture is already saved',
      );
      final merged = preview.apply(current);
      expect(merged.library.trash.single.id, 'x');
      expect(
        merged.library.bookmarks.map((b) => b.id),
        unorderedEquals(['mine', 'theirs-b']),
      );
      expect(merged.pictures.keys, [refB.id]);
    },
  );

  test('older ZIP and pictures beside a version 2 manifest are told apart', () {
    final out = SavePortable.export(
      SaveLibrary(bookmarks: [link('a')]),
      SaveFormat.zip,
    );
    final manifest =
        jsonDecode(
              utf8.decode(
                ZipDecoder().decodeBytes(out).findFile('manifest.json')!.content
                    as List<int>,
              ),
            )
            as Map;
    expect(manifest['version'], 2, reason: 'no pictures: the old format');
    expect(
      SavePortable.preview(out, SaveFormat.zip).library.bookmarks.single.id,
      'a',
    );
  });
}
