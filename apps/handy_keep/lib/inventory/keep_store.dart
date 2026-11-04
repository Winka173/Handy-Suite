import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_storage/blobs.dart';
import 'package:handy_storage/documents.dart';
import '../library.dart';

String newId() =>
    '${DateTime.now().millisecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}';
String timestamp() => DateTime.fromMillisecondsSinceEpoch(
  DateTime.now().millisecondsSinceEpoch,
  isUtc: true,
).toIso8601String();
String today() => DateTime.now().toIso8601String().substring(0, 10);

/// An edited item with the photo and receipt bytes it references.
class AssetEdit {
  final InventoryAsset asset;
  final Map<String, Uint8List> blobs;
  const AssetEdit(this.asset, this.blobs);
}

/// Owns the inventory on this device. Every change is written first and only
/// then shown, so a failed write leaves the screen and the file as they were.
class KeepStore extends ChangeNotifier {
  final DocumentRepository documents;

  /// Where photo and receipt bytes go; without one they are embedded in the
  /// document as before (16 MB in all).
  final BlobRepository? blobs;
  KeepStore(this.documents, {this.blobs});

  /// Ids already written to [blobs], so a save only writes new bytes.
  final _stored = <String>{};

  /// Photos or receipts the data names but the blob store no longer has.
  int missing = 0;

  InventoryLibrary? library;
  Object? error;
  KeepState? get state => library?.state;
  bool get loaded => library != null;

  Future<void> load() async {
    error = null;
    notifyListeners();
    try {
      final raw = await documents.load();
      var next = raw == null
          ? InventoryLibrary(emptyKeepState(), {})
          : InventoryLibrary.parse(raw);
      _stored.clear();
      missing = 0;
      if (next.external) {
        final loaded = <String, Uint8List>{};
        for (final id in next.references) {
          final bytes = await blobs?.read(id);
          if (bytes == null) {
            missing++;
          } else {
            loaded[id] = bytes;
            _stored.add(id);
          }
        }
        next = InventoryLibrary(next.state, loaded);
      }
      library = next;
    } catch (e) {
      // A corrupt file is kept as it is; the recovery page handles it.
      error = e;
    }
    notifyListeners();
  }

  /// New bytes first, then the data that names them, then (best effort)
  /// the bytes it no longer names. A failure before the data is saved
  /// leaves the old library whole.
  Future<void> _write(InventoryLibrary next) async {
    final store = blobs;
    if (store == null) {
      await documents.save(next.serialize());
    } else {
      for (final e in next.blobs.entries) {
        if (_stored.contains(e.key)) continue;
        await store.write(e.key, e.value);
        _stored.add(e.key);
      }
      await documents.save(next.serializeData());
      // Only bytes this run wrote or read and the data has now dropped:
      // a library set aside by a reset keeps its photos for undo.
      final keep = next.references;
      for (final id in _stored.difference(keep).toList()) {
        try {
          await store.delete(id);
          _stored.remove(id);
        } catch (_) {
          // Left-over bytes are harmless; the next save tries again.
        }
      }
    }
    library = next;
    notifyListeners();
  }

  Future<void> commit(KeepState next) => _write(library!.withState(next));

  Future<void> saveItem(AssetEdit edit) {
    final next = saveAsset(state!, edit.asset);
    return _write(
      InventoryLibrary(next, {
        ...library!.blobs,
        ...edit.blobs,
      }).withState(next),
    );
  }

  /// Saves several new items in one write: all of them land, or none.
  Future<void> saveItems(List<AssetEdit> edits) {
    final next = saveAssets(state!, edits.map((e) => e.asset));
    return _write(
      InventoryLibrary(next, {
        ...library!.blobs,
        for (final e in edits) ...e.blobs,
      }).withState(next),
    );
  }

  Future<void> removeItem(String id) => commit(removeAsset(state!, id));
  Future<void> saveBoxRecord(InventoryBox box) => commit(saveBox(state!, box));
  Future<void> removeBoxRecord(String id) => commit(removeBox(state!, id));

  Future<void> lend(String id, String borrower, String on, String due) =>
      commit(lendAsset(state!, id, borrower, on, due, now: timestamp()));

  Future<void> giveBack(String id) =>
      commit(returnAsset(state!, id, now: timestamp()));

  Future<void> restock(String id) =>
      commit(restockAsset(state!, id, today(), now: timestamp()));

  /// Adds a backup's items, boxes and collections; any repeated ID rejects
  /// the whole merge.
  Future<void> merge(InventoryLibrary incoming) => _write(
    InventoryLibrary(
      validateKeepState({
        'version': keepStateVersion,
        'collections': [
          ...state!.collections.map((c) => c.toJson()),
          ...incoming.state.collections.map((c) => c.toJson()),
        ],
        'assets': [
          ...state!.assets.map((a) => a.toJson()),
          ...incoming.state.assets.map((a) => a.toJson()),
        ],
        'boxes': [
          ...state!.boxes.map((b) => b.toJson()),
          ...incoming.state.boxes.map((b) => b.toJson()),
        ],
      }),
      {...library!.blobs, ...incoming.blobs},
    ),
  );

  Future<void> replace(InventoryLibrary incoming) => _write(incoming);
}
