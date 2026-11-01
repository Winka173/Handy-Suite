part of '../handy_inventory.dart';

const keepZipMaxBytes = 30000000,
    keepZipAssetBytes = 12000000,
    keepZipAssetTotalBytes = 28000000;

class PortableInventoryFile {
  final String assetId, path, role, mime;
  final InventoryReceipt? receipt;
  final Uint8List bytes;
  PortableInventoryFile({
    required this.assetId,
    required this.path,
    required this.role,
    required this.mime,
    required this.bytes,
    this.receipt,
  });
}

class PortableKeepBundle {
  final KeepState state;
  final List<PortableInventoryFile> files;
  PortableKeepBundle(this.state, Iterable<PortableInventoryFile> files)
    : files = List.unmodifiable(files);

  /// Call only after staging every file and verifying the written bytes. No device
  /// URI in the source archive is trusted and no filesystem write occurs here.
  KeepState materialize(Map<String, String> uris) {
    final assets = {for (final a in state.assets) a.id: a};
    for (final f in files) {
      final uri = uris[f.path];
      if (uri == null) throw const FormatException('Missing staged asset');
      _localUri(uri, required: true);
      final a = assets[f.assetId]!;
      assets[a.id] = f.role == 'photo'
          ? a.copyWith({'photoUri': uri})
          : a.copyWith({
              'receipts': [
                ...a.receipts.map((r) => r.toJson()),
                {...f.receipt!.toJson(), 'uri': uri},
              ],
            });
    }
    return validateKeepState(
      KeepState(
        assets: state.assets.map((a) => assets[a.id]!),
        boxes: state.boxes,
      ).toJson(),
    );
  }
}

bool _safePath(String value) => RegExp(
  r'^(manifest\.json|assets/[a-zA-Z0-9_-]+\.(png|jpg|pdf))$',
).hasMatch(value);

void _signature(Uint8List bytes, String mime) {
  final valid = mime == 'image/png'
      ? bytes.length >= 8 &&
            bytes.take(8).join(',') == '137,80,78,71,13,10,26,10'
      : mime == 'image/jpeg'
      ? bytes.length >= 3 &&
            bytes[0] == 255 &&
            bytes[1] == 216 &&
            bytes[2] == 255
      : mime == 'application/pdf'
      ? bytes.length >= 5 && ascii.decode(bytes.take(5).toList()) == '%PDF-'
      : false;
  if (!valid)
    throw const FormatException('Image/receipt signature does not match type');
}

PortableKeepBundle parseKeepZip(Uint8List bytes) {
  final entries = decodePortableZip(
    bytes,
    isAllowedPath: _safePath,
    maxEntryBytes: keepZipAssetBytes,
    maxTotalBytes: keepZipMaxBytes,
  );
  final manifest = entries['manifest.json'];
  if (manifest == null || manifest.length > keepBackupBytes)
    throw const FormatException('Missing or oversized Keep manifest');
  final m = _record(jsonDecode(utf8.decode(manifest, allowMalformed: false))),
      refs = m['assets'];
  if (m['format'] != 'handy-keep' ||
      m['version'] != 1 ||
      refs is! List ||
      refs.length > 255)
    throw const FormatException('Unsupported Keep archive');
  final state = validateKeepState(m['state']);
  if (state.assets.any((a) => a.photoUri.isNotEmpty || a.receipts.isNotEmpty))
    throw const FormatException('Archive manifest contains device paths');
  final used = <String>{'manifest.json'},
      identities = <String>{},
      assets = state.assets.map((a) => a.id).toSet(),
      files = <PortableInventoryFile>[];
  var total = 0;
  for (final value in refs) {
    final r = _record(value),
        assetId = _id(r['assetId']),
        path = _text(r['path'], 240, required: true),
        role = r['role'];
    if (!assets.contains(assetId) ||
        !path.startsWith('assets/') ||
        !_safePath(path) ||
        !used.add(path) ||
        !entries.containsKey(path) ||
        !['photo', 'receipt'].contains(role))
      throw const FormatException('Invalid archive asset reference');
    var mime = path.endsWith('.png')
        ? 'image/png'
        : path.endsWith('.pdf')
        ? 'application/pdf'
        : 'image/jpeg';
    InventoryReceipt? receipt;
    if (role == 'receipt') {
      final metadata = _record(r['receipt']);
      receipt = InventoryReceipt.fromJson({
        ...metadata,
        'uri': 'file:///staged-receipt',
      });
      mime = receipt.mime;
      if ((mime == 'application/pdf') != path.endsWith('.pdf') ||
          (mime == 'image/png') != path.endsWith('.png'))
        throw const FormatException('Receipt extension does not match type');
    } else if (mime == 'application/pdf') {
      throw const FormatException('Photo must be an image');
    }
    if (!identities.add('$assetId:$role:${receipt?.id ?? ''}'))
      throw const FormatException('Duplicate archive reference');
    final data = entries[path]!;
    _signature(data, mime);
    total += data.length;
    if (total > keepZipAssetTotalBytes)
      throw const FormatException('Assets exceed ZIP budget');
    if (r.containsKey('sha256') &&
        (r['sha256'] is! String ||
            r['sha256'] != sha256.convert(data).toString()))
      throw const FormatException('ZIP asset checksum mismatch');
    files.add(
      PortableInventoryFile(
        assetId: assetId,
        path: path,
        role: role as String,
        mime: mime,
        bytes: Uint8List.fromList(data),
        receipt: receipt,
      ),
    );
  }
  if (entries.keys.any((name) => !used.contains(name)))
    throw const FormatException('Unreferenced ZIP entries');
  return PortableKeepBundle(state, files);
}

Uint8List buildKeepZip(KeepState state, Map<String, Uint8List> filesByUri) {
  final valid = validateKeepState(state.toJson()),
      clean = _stripPaths(valid),
      refs = <Map<String, Object?>>[],
      archive = Archive();
  var count = 0, total = 0;
  void add(
    InventoryAsset a,
    String uri,
    String mime,
    String role, [
    InventoryReceipt? receipt,
  ]) {
    final input = filesByUri[uri];
    if (input == null || input.length > keepZipAssetBytes)
      throw const FormatException('Missing or oversized backup asset');
    final bytes = Uint8List.fromList(input);
    _signature(bytes, mime);
    total += bytes.length;
    if (total > keepZipAssetTotalBytes || ++count > 255)
      throw const FormatException('Backup asset budget exceeded');
    final path =
        'assets/file-$count.${mime == 'application/pdf'
            ? 'pdf'
            : mime == 'image/png'
            ? 'png'
            : 'jpg'}';
    archive.add(ArchiveFile.bytes(path, bytes));
    refs.add({
      'assetId': a.id,
      'path': path,
      'role': role,
      'sha256': sha256.convert(bytes).toString(),
      if (receipt != null)
        'receipt': {
          'id': receipt.id,
          'name': receipt.name,
          'mime': receipt.mime,
        },
    });
  }

  for (final a in valid.assets) {
    if (a.photoUri.isNotEmpty)
      add(
        a,
        a.photoUri,
        a.photoUri.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg',
        'photo',
      );
    for (final r in a.receipts) add(a, r.uri, r.mime, 'receipt', r);
  }
  final manifest = utf8.encode(
    jsonEncode({
      'format': 'handy-keep',
      'version': 1,
      'state': clean.toJson(),
      'assets': refs,
    }),
  );
  if (manifest.length > keepBackupBytes)
    throw const FormatException('Manifest exceeds budget');
  archive.add(ArchiveFile.bytes('manifest.json', manifest));
  final output = Uint8List.fromList(ZipEncoder().encode(archive, level: 0));
  if (output.length > keepZipMaxBytes)
    throw const FormatException('ZIP exceeds output budget');
  parseKeepZip(output);
  return output;
}
