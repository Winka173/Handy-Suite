part of '../handy_boards_engine.dart';

/// Combines immutable sources without decoding or copying original file bodies.
class _RelocatedAssets extends BoardsAssetMap {
  final BoardsState current, incoming;
  final Map<String, String> paths;
  _RelocatedAssets(this.current, this.incoming, this.paths);
  @override
  String get storageIdentity => 'merge/${identityHashCode(this)}';
  @override
  int get snapshotRevision => current.revision;
  @override
  late final Map<String, Json> descriptors = {
    for (final path in current.filePaths) path: current.assetInfo(path),
    for (final path in paths.entries) path.value: incoming.assetInfo(path.key),
  };
  late final reversed = paths.map((key, value) => MapEntry(value, key));
  @override
  Iterable<String> get keys => descriptors.keys;
  @override
  Uint8List? operator [](Object? key) => key is! String
      ? null
      : reversed.containsKey(key)
      ? incoming.file(reversed[key]!)
      : current.hasFile(key)
      ? current.file(key)
      : null;
  @override
  Future<Uint8List> readAsset(String key) => reversed.containsKey(key)
      ? incoming.readFile(reversed[key]!)
      : current.readFile(key);
  @override
  Set<String> changedKeysCompared(BoardsSnapshotMap<Uint8List> other) => {
    ...keys,
    ...other.keys,
  };
  @override
  void operator []=(String key, Uint8List value) =>
      throw UnsupportedError('Immutable assets');
  @override
  Uint8List? remove(Object? key) => throw UnsupportedError('Immutable assets');
  @override
  void clear() => throw UnsupportedError('Immutable assets');
}

/// Storage-owned immutable, revision-addressable map. Values may be loaded lazily.
abstract class BoardsSnapshotMap<V> extends MapBase<String, V> {
  String get storageIdentity;
  int get snapshotRevision;
  Set<String> changedKeysCompared(BoardsSnapshotMap<V> other);
}

abstract class BoardsAssetMap extends BoardsSnapshotMap<Uint8List> {
  Map<String, Json> get descriptors;
  Future<Uint8List> readAsset(String path);
}

Json? _assetDescriptor(Map<String, Uint8List> files, String path) {
  if (files is _OverlayMap<Uint8List>) {
    if (files.removed.contains(path)) return null;
    final value = files.updates[path];
    if (value != null)
      return {
        'bytes': value.length,
        'sha256': sha256.convert(value).toString(),
      };
    return _assetDescriptor(files.base, path);
  }
  if (files is BoardsAssetMap) return files.descriptors[path];
  final bytes = files[path];
  return bytes == null
      ? null
      : {'bytes': bytes.length, 'sha256': sha256.convert(bytes).toString()};
}

Future<Uint8List> _readAsset(Map<String, Uint8List> files, String path) async {
  if (files is _OverlayMap<Uint8List>) {
    if (files.removed.contains(path))
      throw const FormatException('Missing asset');
    final value = files.updates[path];
    if (value != null) return Uint8List.fromList(value);
    return _readAsset(files.base, path);
  }
  if (files is BoardsAssetMap) return files.readAsset(path);
  final bytes = files[path];
  if (bytes == null) throw const FormatException('Missing asset');
  return Uint8List.fromList(bytes);
}

class _OverlayMap<V> extends MapBase<String, V> {
  final Map<String, V> base;
  final Map<String, V> updates;
  final Set<String> removed;
  final bool frozen;
  _OverlayMap(this.base) : updates = {}, removed = {}, frozen = false;
  _OverlayMap._(this.base, this.updates, this.removed) : frozen = true;
  Map<String, V> freeze() => updates.isEmpty && removed.isEmpty
      ? base
      : _OverlayMap<V>._(
          base,
          Map.unmodifiable({
            for (final e in updates.entries)
              e.key: e.value is Uint8List
                  ? Uint8List.fromList(e.value as Uint8List) as V
                  : e.value,
          }),
          Set.unmodifiable(removed),
        );
  @override
  V? operator [](Object? key) =>
      removed.contains(key) ? null : updates[key] ?? base[key];
  @override
  void operator []=(String key, V value) {
    if (frozen) throw UnsupportedError('Immutable snapshot');
    removed.remove(key);
    updates[key] = value;
  }

  @override
  V? remove(Object? key) {
    if (frozen) throw UnsupportedError('Immutable snapshot');
    final old = this[key];
    updates.remove(key);
    if (key is String) removed.add(key);
    return old;
  }

  void discard(String key) {
    if (frozen) throw UnsupportedError('Immutable snapshot');
    updates.remove(key);
    removed.add(key);
  }

  @override
  void clear() {
    if (frozen) throw UnsupportedError('Immutable snapshot');
    updates.clear();
    removed.addAll(base.keys);
  }

  @override
  Iterable<String> get keys sync* {
    for (final key in base.keys) if (!removed.contains(key)) yield key;
    for (final key in updates.keys)
      if (!base.containsKey(key) && !removed.contains(key)) yield key;
  }

  @override
  bool containsKey(Object? key) =>
      !removed.contains(key) &&
      (updates.containsKey(key) || base.containsKey(key));
  @override
  Iterable<V> get values sync* {
    for (final e in base.entries)
      if (!removed.contains(e.key)) yield updates[e.key] ?? e.value;
    for (final e in updates.entries)
      if (!base.containsKey(e.key) && !removed.contains(e.key)) yield e.value;
  }

  @override
  Iterable<MapEntry<String, V>> get entries sync* {
    for (final e in base.entries)
      if (!removed.contains(e.key))
        yield MapEntry(e.key, updates[e.key] ?? e.value);
    for (final e in updates.entries)
      if (!base.containsKey(e.key) && !removed.contains(e.key)) yield e;
  }
}

Set<String> _changedCandidates<V>(Map<String, V> a, Map<String, V> b) {
  if (identical(a, b)) return {};
  if (a is _OverlayMap<V>)
    return {...a.updates.keys, ...a.removed, ..._changedCandidates(a.base, b)};
  if (b is _OverlayMap<V>)
    return {...b.updates.keys, ...b.removed, ..._changedCandidates(a, b.base)};
  if (a is BoardsSnapshotMap<V> &&
      b is BoardsSnapshotMap<V> &&
      a.storageIdentity == b.storageIdentity)
    return a.changedKeysCompared(b);
  return {...a.keys, ...b.keys};
}

extension BoardsSnapshots on BoardsState {
  Map<String, Json?> assetChanges(BoardsState previous) => {
    for (final key in _changedCandidates(_files, previous._files))
      if (_assetDescriptor(_files, key)?['sha256'] !=
          _assetDescriptor(previous._files, key)?['sha256'])
        key: _assetDescriptor(_files, key),
  };
  Map<String, BoardRecord?> recordChanges(BoardsState previous, String kind) {
    final a = records[kind]!, b = previous.records[kind]!;
    return {
      for (final id in _changedCandidates(a, b))
        if (jsonEncode(a[id]?.data) != jsonEncode(b[id]?.data)) id: a[id],
    };
  }

  Map<String, Uint8List?> fileChanges(BoardsState previous) {
    return {
      for (final id in _changedCandidates(_files, previous._files))
        if (_assetDescriptor(_files, id)?['sha256'] !=
            _assetDescriptor(previous._files, id)?['sha256'])
          id: _assetDescriptor(_files, id) == null
              ? null
              : Uint8List.fromList(_files[id]!),
    };
  }

  Iterable<String> get filePaths => _files.keys;
  Json assetInfo(String path) => Map.unmodifiable(
    _assetDescriptor(_files, path) ??
        (throw const FormatException('Missing asset')),
  );
  Future<Uint8List> readFile(String path) => _readAsset(_files, path);
  BoardsState putFile(String path, Uint8List bytes) {
    final files = _OverlayMap(_files)..[path] = Uint8List.fromList(bytes);
    return BoardsState._(revision, records, preferences, files.freeze());
  }
}
