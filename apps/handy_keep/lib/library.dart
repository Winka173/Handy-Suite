import 'dart:convert';
import 'dart:typed_data';
import 'package:handy_inventory/handy_inventory.dart';

/// Embedded blobs use stable virtual file IDs. They are never dereferenced as OS paths.
class InventoryLibrary {
  final KeepState state;
  final Map<String, Uint8List> blobs;
  InventoryLibrary(this.state, Map<String, Uint8List> blobs)
    : blobs = Map.unmodifiable({
        for (final e in blobs.entries)
          e.key: Uint8List.fromList(e.value).asUnmodifiableView(),
      });
  factory InventoryLibrary.parse(String text) {
    if (utf8.encode(text).length > 16000000)
      throw const FormatException('Library exceeds 16 MB');
    final raw = jsonDecode(text);
    if (raw is Map && raw['format'] == 'handy-keep-local') {
      if (raw['version'] != 1 || raw['state'] is! Map || raw['assets'] is! Map)
        throw const FormatException('Invalid inventory library');
      final state = validateKeepState(raw['state']),
          blobs = <String, Uint8List>{};
      for (final e in (raw['assets'] as Map).entries) {
        if (e.key is! String ||
            !RegExp(
              r'^file:///handy-assets/[a-zA-Z0-9_-]+\.(png|jpg|pdf)$',
            ).hasMatch(e.key) ||
            e.value is! String)
          throw const FormatException('Invalid local asset ID');
        final bytes = base64Decode(e.value as String);
        if (bytes.length > 12000000 || base64Encode(bytes) != e.value)
          throw const FormatException('Invalid asset encoding');
        blobs[e.key] = bytes;
      }
      final refs = _references(state);
      if (blobs.keys.any((id) => !refs.contains(id)))
        throw const FormatException('Unreferenced library asset');
      if (refs.any(
        (id) =>
            id.startsWith('file:///handy-assets/') && !blobs.containsKey(id),
      ))
        throw const FormatException('Missing library asset');
      return InventoryLibrary(state, blobs);
    }
    return InventoryLibrary(parseKeepState(text), {});
  }
  InventoryLibrary withState(KeepState next) {
    final refs = _references(next);
    return InventoryLibrary(next, {
      for (final e in blobs.entries)
        if (refs.contains(e.key)) e.key: e.value,
    });
  }

  String serialize() {
    final text = jsonEncode({
      'format': 'handy-keep-local',
      'version': 1,
      'state': state.toJson(),
      'assets': {for (final e in blobs.entries) e.key: base64Encode(e.value)},
    });
    if (utf8.encode(text).length > 16000000)
      throw const FormatException(
        'Library exceeds 16 MB; export a backup and reduce attachments.',
      );
    InventoryLibrary.parse(text);
    return text;
  }

  Uint8List portable() => buildKeepZip(state, blobs);
  factory InventoryLibrary.fromPortable(Uint8List bytes) {
    final bundle = parseKeepZip(bytes),
        uris = <String, String>{},
        blobs = <String, Uint8List>{};
    var i = 0;
    for (final file in bundle.files) {
      final uri =
          'file:///handy-assets/import-${DateTime.now().millisecondsSinceEpoch}-${++i}.${file.path.split('.').last}';
      uris[file.path] = uri;
      blobs[uri] = file.bytes;
    }
    return InventoryLibrary(bundle.materialize(uris), blobs);
  }
  static Set<String> _references(KeepState state) => {
    for (final a in state.assets) ...[
      if (a.photoUri.isNotEmpty) a.photoUri,
      for (final r in a.receipts) r.uri,
    ],
  };
}
