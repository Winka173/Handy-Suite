import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:handy_inventory/handy_inventory.dart';
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
  KeepStore(this.documents);

  InventoryLibrary? library;
  Object? error;
  KeepState? get state => library?.state;
  bool get loaded => library != null;

  Future<void> load() async {
    error = null;
    notifyListeners();
    try {
      final raw = await documents.load();
      library = raw == null
          ? InventoryLibrary(emptyKeepState(), {})
          : InventoryLibrary.parse(raw);
    } catch (e) {
      // A corrupt file is kept as it is; the recovery page handles it.
      error = e;
    }
    notifyListeners();
  }

  Future<void> _write(InventoryLibrary next) async {
    await documents.save(next.serialize());
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

  Future<void> removeItem(String id) => commit(removeAsset(state!, id));
  Future<void> saveBoxRecord(InventoryBox box) => commit(saveBox(state!, box));
  Future<void> removeBoxRecord(String id) => commit(removeBox(state!, id));

  Future<void> lend(String id, String borrower, String on, String due) =>
      commit(lendAsset(state!, id, borrower, on, due, now: timestamp()));

  Future<void> giveBack(String id) =>
      commit(returnAsset(state!, id, now: timestamp()));

  /// Adds a backup's items and boxes; any repeated ID rejects the whole merge.
  Future<void> merge(InventoryLibrary incoming) => _write(
    InventoryLibrary(
      validateKeepState({
        'version': 1,
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
