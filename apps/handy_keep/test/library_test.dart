import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_keep/library.dart';

const now = '2026-10-31T08:00:00.000Z',
    photo = 'file:///handy-assets/photo.png',
    receipt = 'file:///handy-assets/receipt.pdf';
final photoBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
  ),
);
final receiptBytes = Uint8List.fromList(
  utf8.encode('%PDF-1.4\nreceipt fixture\n%%EOF'),
);
KeepState fixtureState() => saveAsset(
  emptyKeepState(),
  createAsset(
    id: 'camera',
    name: 'Máy ảnh 😀',
    now: now,
    fields: {
      'location': 'Phòng làm việc',
      'photoUri': photo,
      'receipts': [
        {
          'id': 'receipt',
          'name': 'Hóa đơn.pdf',
          'mime': 'application/pdf',
          'uri': receipt,
        },
      ],
    },
  ),
);
InventoryLibrary fixture() => InventoryLibrary(fixtureState(), {
  photo: photoBytes,
  receipt: receiptBytes,
});
Uint8List rewriteZip(
  Uint8List zip,
  void Function(Map<String, dynamic>) update,
) {
  final archive = ZipDecoder().decodeBytes(zip),
      file = archive.find('manifest.json')!,
      manifest =
          jsonDecode(utf8.decode(file.readBytes()!)) as Map<String, dynamic>;
  update(manifest);
  archive.removeFile(file);
  archive.add(
    ArchiveFile.bytes('manifest.json', utf8.encode(jsonEncode(manifest))),
  );
  return Uint8List.fromList(ZipEncoder().encode(archive, level: 0));
}

void main() {
  test(
    'local library JSON roundtrip retains Unicode photos receipts and stable IDs',
    () {
      final original = fixture(),
          serialized = original.serialize(),
          restored = InventoryLibrary.parse(serialized);
      expect(restored.state.toJson(), original.state.toJson());
      expect(restored.blobs[photo], photoBytes);
      expect(restored.blobs[receipt], receiptBytes);
      expect(restored.state.assets.single.receipts.single.name, 'Hóa đơn.pdf');
    },
  );
  test(
    'portable ZIP recreates virtual URIs while preserving asset identity and content',
    () {
      final original = fixture(),
          zip = original.portable(),
          restored = InventoryLibrary.fromPortable(Uint8List.fromList(zip));
      final item = restored.state.assets.single;
      expect(item.id, 'camera');
      expect(item.name, 'Máy ảnh 😀');
      expect(item.location, 'Phòng làm việc');
      expect(item.photoUri, startsWith('file:///handy-assets/import-'));
      expect(item.photoUri, isNot(photo));
      expect(restored.blobs[item.photoUri], photoBytes);
      expect(
        item.receipts.single.uri,
        startsWith('file:///handy-assets/import-'),
      );
      expect(item.receipts.single.name, 'Hóa đơn.pdf');
      expect(restored.blobs[item.receipts.single.uri], receiptBytes);
      expect(restored.blobs.length, 2);
      final reopened = InventoryLibrary.parse(restored.serialize());
      expect(reopened.state.toJson(), restored.state.toJson());
      expect(reopened.blobs[item.photoUri], photoBytes);
      expect(original.state.assets.single.photoUri, photo);
    },
  );
  test(
    'legacy React Native ZIP without checksum imports and reexports with assets',
    () {
      final legacy = rewriteZip(fixture().portable(), (m) {
        for (final r in m['assets'] as List) (r as Map).remove('sha256');
      });
      final restored = InventoryLibrary.fromPortable(legacy),
          roundtrip = parseKeepZip(restored.portable());
      expect(roundtrip.files.length, 2);
      expect(roundtrip.files.first.bytes, photoBytes);
      expect(roundtrip.files.last.bytes, receiptBytes);
    },
  );
  test(
    'legacy JSON inventory keeps records and does not invent missing bytes',
    () {
      final legacy = fixtureState(),
          restored = InventoryLibrary.parse(serializeKeepState(legacy));
      expect(restored.state.assets.single.id, 'camera');
      expect(restored.state.assets.single.photoUri, photo);
      expect(restored.blobs, isEmpty);
      expect(() => restored.portable(), throwsFormatException);
    },
  );
  test(
    'missing and unreferenced virtual blob IDs rejected before state commit',
    () {
      final before = fixture(),
          snapshot = before.serialize(),
          raw = jsonDecode(snapshot) as Map<String, dynamic>;
      final assets = raw['assets'] as Map;
      assets.remove(photo);
      expect(
        () => InventoryLibrary.parse(jsonEncode(raw)),
        throwsFormatException,
      );
      expect(before.serialize(), snapshot);
      assets[photo] = base64Encode(photoBytes);
      assets['file:///handy-assets/unreferenced.png'] = base64Encode(
        photoBytes,
      );
      expect(
        () => InventoryLibrary.parse(jsonEncode(raw)),
        throwsFormatException,
      );
      expect(before.serialize(), snapshot);
    },
  );
  test(
    'malformed versions fields base64 and virtual paths rejected without replacing old state',
    () {
      final before = fixture(), snapshot = before.serialize();
      for (final value in [
        null,
        {
          'format': 'handy-keep-local',
          'version': 99,
          'state': before.state.toJson(),
          'assets': {},
        },
        {
          'format': 'handy-keep-local',
          'version': 1,
          'state': before.state.toJson(),
          'assets': {photo: '!!!!'},
        },
        {
          'format': 'handy-keep-local',
          'version': 1,
          'state': before.state.toJson(),
          'assets': {'file:///private/secret.png': base64Encode(photoBytes)},
        },
        {
          'format': 'handy-keep-local',
          'version': 1,
          'state': before.state.toJson(),
          'assets': {photo: 4},
        },
      ]) {
        expect(
          () => InventoryLibrary.parse(jsonEncode(value)),
          throwsA(anything),
        );
        expect(before.serialize(), snapshot);
      }
      expect(() => InventoryLibrary.parse('{broken'), throwsFormatException);
    },
  );
  test('UTF8 library byte cap rejects nonASCII data before decode', () {
    final before = fixture(), snapshot = before.serialize();
    final oversized = '"${'ệ' * 5333334}"';
    expect(oversized.length, lessThan(16000000));
    expect(utf8.encode(oversized).length, greaterThan(16000000));
    expect(() => InventoryLibrary.parse(oversized), throwsFormatException);
    expect(before.serialize(), snapshot);
  });
  test(
    'checksum corruption in restore leaves original library and blobs untouched',
    () {
      final before = fixture(),
          snapshot = before.serialize(),
          damaged = rewriteZip(before.portable(), (m) {
            (m['assets'] as List).first['sha256'] = '0' * 64;
          });
      expect(
        () => InventoryLibrary.fromPortable(damaged),
        throwsFormatException,
      );
      expect(before.serialize(), snapshot);
      expect(before.blobs[photo], photoBytes);
    },
  );
  test(
    'truncated archive and missing attachment restore retain previous state',
    () {
      final before = fixture(),
          snapshot = before.serialize(),
          zip = before.portable();
      expect(
        () => InventoryLibrary.fromPortable(
          Uint8List.fromList(zip.take(zip.length - 8).toList()),
        ),
        throwsFormatException,
      );
      final damaged = rewriteZip(zip, (m) {
        (m['assets'] as List).first['path'] = 'assets/missing.png';
      });
      expect(
        () => InventoryLibrary.fromPortable(damaged),
        throwsFormatException,
      );
      expect(before.serialize(), snapshot);
    },
  );
  test('withState drops orphaned blobs and leaves old library intact', () {
    final before = fixture(),
        next = before.withState(
          saveAsset(
            before.state,
            before.state.assets.single.copyWith({'photoUri': ''}),
          ),
        );
    expect(next.blobs.containsKey(photo), false);
    expect(next.blobs.containsKey(receipt), true);
    expect(before.blobs.containsKey(photo), true);
    final deleted = next.withState(removeAsset(next.state, 'camera'));
    expect(deleted.blobs, isEmpty);
    expect(deleted.state.assets, isEmpty);
  });
  test('blob maps and bytes are deeply immutable after construction', () {
    final bytes = Uint8List.fromList(photoBytes),
        library = InventoryLibrary(
          saveAsset(
            emptyKeepState(),
            createAsset(
              id: 'image',
              name: 'Image',
              now: now,
              fields: {'photoUri': photo},
            ),
          ),
          {photo: bytes},
        );
    bytes[0] = 0;
    expect(library.blobs[photo], photoBytes);
    expect(() => library.blobs.clear(), throwsUnsupportedError);
    expect(() => library.blobs[photo]![0] = 0, throwsUnsupportedError);
  });
  test('portable empty inventory survives local restart roundtrip', () {
    final restored = InventoryLibrary.fromPortable(
      InventoryLibrary(emptyKeepState(), {}).portable(),
    );
    expect(restored.state.assets, isEmpty);
    expect(InventoryLibrary.parse(restored.serialize()).blobs, isEmpty);
  });
}
