import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_inventory/handy_inventory.dart';

const now = '2026-10-31T08:00:00.000Z';
final png = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
  ),
);
void main() {
  KeepState fixture() => saveAsset(
    emptyKeepState(),
    createAsset(
      id: 'camera',
      name: 'Máy ảnh',
      now: now,
      fields: {
        'photoUri': 'file:///old/photo.png',
        'receipts': [
          {
            'id': 'invoice',
            'name': 'Hóa đơn.pdf',
            'mime': 'application/pdf',
            'uri': 'file:///old/invoice.pdf',
          },
        ],
      },
    ),
  );
  Map<String, Uint8List> files() => {
    'file:///old/photo.png': png,
    'file:///old/invoice.pdf': Uint8List.fromList(
      utf8.encode('%PDF-1.4\nfixture receipt\n%%EOF'),
    ),
  };
  Uint8List change(
    Uint8List zip,
    void Function(Map<String, dynamic>, Archive) task,
  ) {
    final archive = ZipDecoder().decodeBytes(zip),
        manifest =
            jsonDecode(utf8.decode(archive.find('manifest.json')!.readBytes()!))
                as Map<String, dynamic>;
    task(manifest, archive);
    archive.removeFile(archive.find('manifest.json')!);
    archive.add(
      ArchiveFile.bytes('manifest.json', utf8.encode(jsonEncode(manifest))),
    );
    return Uint8List.fromList(ZipEncoder().encode(archive, level: 0));
  }

  test(
    'portable ZIP includes data photos receipts and checksums across devices',
    () {
      final original = fixture(),
          zip = buildKeepZip(original, files()),
          parsed = parseKeepZip(Uint8List.fromList(zip));
      expect(parsed.files.length, 2);
      expect(parsed.state.assets.single.photoUri, '');
      expect(parsed.state.assets.single.receipts, isEmpty);
      expect(parsed.files.first.bytes, png);
      expect(parsed.files.last.receipt!.name, 'Hóa đơn.pdf');
      final restored = parsed.materialize({
        for (final f in parsed.files)
          f.path: 'file:///new/${f.path.split('/').last}',
      });
      expect(restored.assets.single.id, 'camera');
      expect(restored.assets.single.photoUri, startsWith('file:///new/'));
      expect(
        restored.assets.single.receipts.single.uri,
        startsWith('file:///new/'),
      );
      expect(original.assets.single.photoUri, 'file:///old/photo.png');
      final repacked = buildKeepZip(restored, {
        for (final f in parsed.files)
          'file:///new/${f.path.split('/').last}': f.bytes,
      });
      expect(parseKeepZip(repacked).state.toJson(), parsed.state.toJson());
    },
  );
  test('legacy TS ZIP without hashes still imports with CRC validation', () {
    final bytes = change(buildKeepZip(fixture(), files()), (m, a) {
      for (final ref in m['assets'] as List) (ref as Map).remove('sha256');
    });
    expect(parseKeepZip(bytes).files.length, 2);
  });
  test('empty inventory ZIP roundtrip', () {
    final bytes = buildKeepZip(emptyKeepState(), {});
    expect(parseKeepZip(bytes).state.assets, isEmpty);
    expect(parseKeepZip(bytes).files, isEmpty);
  });
  test(
    'incomplete staged file map never creates a partially restored state',
    () {
      final parsed = parseKeepZip(buildKeepZip(fixture(), files()));
      expect(
        () => parsed.materialize({
          parsed.files.first.path: 'file:///new/photo.png',
        }),
        throwsFormatException,
      );
      expect(parsed.state.assets.single.photoUri, '');
      expect(
        () => parsed.materialize({
          for (final f in parsed.files) f.path: 'https://bad/${f.path}',
        }),
        throwsFormatException,
      );
    },
  );
  test('missing file bad signature or oversized asset fails before output', () {
    expect(() => buildKeepZip(fixture(), {}), throwsFormatException);
    expect(
      () => buildKeepZip(fixture(), {
        ...files(),
        'file:///old/photo.png': Uint8List.fromList([1, 2, 3]),
      }),
      throwsFormatException,
    );
    expect(
      () => buildKeepZip(fixture(), {
        ...files(),
        'file:///old/photo.png': Uint8List(12000001),
      }),
      throwsFormatException,
    );
  });
  test('manifest checksum mismatch rejected', () {
    final changed = change(buildKeepZip(fixture(), files()), (m, a) {
      (m['assets'] as List).first['sha256'] = '0' * 64;
    });
    expect(() => parseKeepZip(changed), throwsFormatException);
  });
  test(
    'wrong app version references paths roles and receipt types rejected',
    () {
      for (final task in <void Function(Map<String, dynamic>, Archive)>[
        (m, a) {
          m['format'] = 'other-app';
        },
        (m, a) {
          m['version'] = 99;
        },
        (m, a) {
          (m['assets'] as List).first['assetId'] = 'missing';
        },
        (m, a) {
          (m['assets'] as List).first['path'] = '../private';
        },
        (m, a) {
          (m['assets'] as List).first['role'] = 'script';
        },
        (m, a) {
          ((m['assets'] as List).last['receipt'] as Map)['mime'] = 'text/html';
        },
        (m, a) {
          (m['assets'] as List).add((m['assets'] as List).first);
        },
      ]) {
        expect(
          () => parseKeepZip(change(buildKeepZip(fixture(), files()), task)),
          throwsFormatException,
        );
      }
    },
  );
  test('manifest must not smuggle absolute old device paths', () {
    final changed = change(buildKeepZip(fixture(), files()), (m, a) {
      (m['state']['assets'] as List).first['photoUri'] = 'file:///old/private';
    });
    expect(() => parseKeepZip(changed), throwsFormatException);
  });
  test('unreferenced asset entries rejected', () {
    final changed = change(buildKeepZip(fixture(), files()), (m, a) {
      a.add(ArchiveFile.bytes('assets/unused.png', png));
    });
    expect(() => parseKeepZip(changed), throwsFormatException);
  });
  test(
    'path traversal absolute symlink and compression bombs preflight before inflate',
    () {
      for (final path in [
        '../escape',
        '/absolute',
        'C:/escape',
        'assets/../escape.png',
        'assets\\escape.png',
      ]) {
        final a = Archive()..add(ArchiveFile.bytes(path, [1]));
        expect(
          () => parseKeepZip(
            Uint8List.fromList(ZipEncoder().encode(a, level: 0)),
          ),
          throwsFormatException,
        );
      }
      final a = Archive()
        ..add(ArchiveFile.bytes('assets/bomb.png', Uint8List(1000000)));
      expect(
        () =>
            parseKeepZip(Uint8List.fromList(ZipEncoder().encode(a, level: 9))),
        throwsFormatException,
      );
    },
  );
  test('truncated ZIP and invalid CRC rejected', () {
    final zip = buildKeepZip(fixture(), files());
    expect(
      () => parseKeepZip(Uint8List.fromList(zip.take(zip.length - 4).toList())),
      throwsFormatException,
    );
    final damaged = Uint8List.fromList(zip);
    final data = ByteData.sublistView(damaged);
    final end = damaged.length - 22,
        central = data.getUint32(end + 16, Endian.little);
    damaged[central + 16] ^= 1;
    expect(() => parseKeepZip(damaged), throwsFormatException);
  });
  test('default millisecond timestamp creation works without explicit now', () {
    final created = createAsset(id: 'n', name: 'n');
    expect(created.createdAt, contains('T'));
    expect(
      () => validateKeepState(saveAsset(emptyKeepState(), created).toJson()),
      returnsNormally,
    );
  });
}
