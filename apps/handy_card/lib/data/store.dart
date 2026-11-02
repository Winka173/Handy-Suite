import 'dart:typed_data';
import 'store_stub.dart'
    if (dart.library.io) 'store_native.dart'
    if (dart.library.js_interop) 'store_web.dart'
    as platform;

/// Everything saved, as JSON text per record, and the ids of the stored
/// pictures (their bytes load on demand).
class CardStoreData {
  final Map<String, Map<String, String>> records;
  final Set<String> assets;
  const CardStoreData(this.records, this.assets);
}

/// Record kinds the app keeps.
const cardRecordKinds = ['design', 'profile', 'template', 'settings'];

/// Each design, profile and template is its own record, written in one
/// transaction when it changes, so a crash loses at most the last few
/// hundred milliseconds of one design. Pictures live apart, by the hash of
/// their bytes, never inside the JSON.
abstract interface class CardStore {
  Future<CardStoreData> read();
  Future<void> put(String kind, String id, String json);
  Future<void> delete(String kind, String id);
  Future<void> putAsset(String id, Uint8List bytes);
  Future<Uint8List?> asset(String id);
  Future<void> deleteAssets(Set<String> ids);
}

Future<CardStore> openCardStore() => platform.openStore();

/// A store in memory, for tests and when the device's storage fails.
class MemoryCardStore implements CardStore {
  final records = <String, Map<String, String>>{};
  final assets = <String, Uint8List>{};
  @override
  Future<CardStoreData> read() async => CardStoreData({
    for (final e in records.entries) e.key: Map.of(e.value),
  }, assets.keys.toSet());
  @override
  Future<void> put(String kind, String id, String json) async =>
      (records[kind] ??= {})[id] = json;
  @override
  Future<void> delete(String kind, String id) async =>
      records[kind]?.remove(id);
  @override
  Future<void> putAsset(String id, Uint8List bytes) async => assets[id] = bytes;
  @override
  Future<Uint8List?> asset(String id) async => assets[id];
  @override
  Future<void> deleteAssets(Set<String> ids) async =>
      assets.removeWhere((k, _) => ids.contains(k));
}
