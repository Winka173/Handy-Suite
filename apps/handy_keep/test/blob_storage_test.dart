import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_keep/inventory/keep_store.dart';
import 'package:handy_keep/library.dart';
import 'package:handy_storage/blobs.dart';
import 'package:handy_storage/documents.dart';

class Doc implements DocumentRepository {
  String? text;
  Doc([this.text]);
  @override
  Future<String?> load() async => text;
  @override
  Future<void> save(String next) async => text = next;
}

Uint8List jpeg(int size, int seed) => Uint8List.fromList([
  255,
  216,
  255,
  ...List.generate(size - 3, (i) => (i * seed) % 256),
]);

const photo = 'file:///handy-assets/p1.jpg';

void main() {
  test('a version 1 library moves its photos out on the next save', () async {
    final state = saveAsset(
      emptyKeepState(),
      createAsset(id: 'tv', name: 'TV', fields: {'photoUri': photo}),
    );
    final bytes = jpeg(2000, 7);
    final doc = Doc(InventoryLibrary(state, {photo: bytes}).serialize());
    final blobs = MemoryBlobs();
    final store = KeepStore(doc, blobs: blobs);
    await store.load();
    expect(store.library!.blobs[photo], bytes);
    await store.commit(store.state!);
    expect(jsonDecode(doc.text!)['version'], 2);
    expect(doc.text, isNot(contains(base64Encode(bytes).substring(0, 40))));
    expect(blobs.entries[photo], bytes);
    final again = KeepStore(doc, blobs: blobs);
    await again.load();
    expect(again.library!.blobs[photo], bytes);
    expect(again.missing, 0);
  });

  test('photos well past 16 MB in all are kept', () async {
    final doc = Doc(), blobs = MemoryBlobs();
    final store = KeepStore(doc, blobs: blobs);
    await store.load();
    for (var i = 0; i < 3; i++) {
      final uri = 'file:///handy-assets/big$i.jpg';
      await store.saveItem(
        AssetEdit(
          createAsset(id: 'i$i', name: 'Item $i', fields: {'photoUri': uri}),
          {uri: jpeg(7000000, i + 3)},
        ),
      );
    }
    expect(blobs.entries, hasLength(3));
    expect(utf8.encode(doc.text!).length, lessThan(100000));
    // Removing an item lets its photo go.
    await store.removeItem('i1');
    expect(
      blobs.entries.keys,
      isNot(contains('file:///handy-assets/big1.jpg')),
    );
  });

  test('a photo the blob store lost is counted, not fatal', () async {
    final doc = Doc(), blobs = MemoryBlobs();
    final store = KeepStore(doc, blobs: blobs);
    await store.load();
    await store.saveItem(
      AssetEdit(
        createAsset(id: 'tv', name: 'TV', fields: {'photoUri': photo}),
        {photo: jpeg(100, 3)},
      ),
    );
    blobs.entries.clear();
    final again = KeepStore(doc, blobs: blobs);
    await again.load();
    expect(again.error, isNull);
    expect(again.state!.assets.single.photoUri, photo);
    expect(again.missing, 1);
  });

  test('a failed photo write leaves the saved library as it was', () async {
    final doc = Doc(), blobs = MemoryBlobs();
    final store = KeepStore(doc, blobs: blobs);
    await store.load();
    await store.saveItem(AssetEdit(createAsset(id: 'a', name: 'A'), {}));
    final before = doc.text;
    blobs.failWrites = true;
    await expectLater(
      store.saveItem(
        AssetEdit(
          createAsset(id: 'b', name: 'B', fields: {'photoUri': photo}),
          {photo: jpeg(100, 5)},
        ),
      ),
      throwsStateError,
    );
    expect(doc.text, before);
    expect(store.state!.assets, hasLength(1));
  });
}
