part of '../handy_card_engine.dart';

const cardProjectFormat = 'handy-card-project', cardProjectVersion = 1;

/// The id of a picture: the SHA-256 of its bytes, so the same picture is
/// stored once however many designs use it.
String assetId(Uint8List bytes) => sha256.convert(bytes).toString();

/// What sniffing the bytes says the picture is, or null if not one we keep.
String? imageMime(Uint8List b) {
  if (b.length > 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47)
    return 'image/png';
  if (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF)
    return 'image/jpeg';
  if (b.length > 12 &&
      String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(b.sublist(8, 12)) == 'WEBP')
    return 'image/webp';
  return null;
}

/// A portable copy of designs, user templates, profiles and the pictures
/// they use. Each file is listed in the manifest with its SHA-256; fonts
/// are referenced by family, never bundled.
Uint8List encodeCardProject({
  List<CardDocument> designs = const [],
  List<CardDocument> templates = const [],
  List<CardProfile> profiles = const [],
  Map<String, Uint8List> assets = const {},
  required DateTime at,
}) {
  final files = <String, List<int>>{};
  final mimes = <String, String>{};
  for (final d in [...designs, ...templates]) {
    for (final a in d.assets) mimes[a.id] = a.mime;
  }
  for (final d in designs)
    files['designs/${d.id}.json'] = utf8.encode(d.encode());
  for (final t in templates)
    files['templates/${t.id}.json'] = utf8.encode(t.encode());
  for (final p in profiles)
    files['profiles/${p.id}.json'] = utf8.encode(jsonEncode(p.toJson()));
  final used = {
    for (final d in [...designs, ...templates]) ...d.assets.map((a) => a.id),
    for (final p in profiles) ...[?p.photo, ?p.logo],
  };
  for (final id in used) {
    final bytes = assets[id];
    if (bytes == null) continue;
    final mime = mimes[id] ?? imageMime(bytes);
    if (mime == null) continue;
    final ext = switch (mime) {
      'image/png' => 'png',
      'image/jpeg' => 'jpg',
      _ => 'webp',
    };
    files['assets/$id.$ext'] = bytes;
  }
  final manifest = {
    'format': cardProjectFormat,
    'version': cardProjectVersion,
    'schema': cardSchemaVersion,
    'createdAt': at.toUtc().toIso8601String(),
    'files': {
      for (final e in files.entries) e.key: sha256.convert(e.value).toString(),
    },
  };
  final archive = Archive();
  void add(String path, List<int> bytes) =>
      archive.addFile(ArchiveFile.bytes(path, Uint8List.fromList(bytes)));
  add(
    'manifest.json',
    utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest)),
  );
  for (final e in files.entries) add(e.key, e.value);
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// What a project file holds, read and checked before anything is saved.
class CardProjectContents {
  final List<CardDocument> designs, templates;
  final List<CardProfile> profiles;
  final Map<String, Uint8List> assets;

  /// Pictures a design or profile refers to that the file does not carry.
  final Set<String> missingAssets;
  const CardProjectContents(
    this.designs,
    this.templates,
    this.profiles,
    this.assets,
    this.missingAssets,
  );
}

final _projectPath = RegExp(
  r'^(manifest\.json|(designs|templates|profiles)/[A-Za-z0-9_-]{1,64}\.json|assets/[a-f0-9]{64}\.(png|jpg|webp))$',
);

/// Reads a project ZIP: paths from a fixed list only (no traversal), sizes
/// bounded before inflating, every file's hash checked against the
/// manifest, every picture's bytes checked against its name, every design
/// migrated and validated. Throws on the first problem; nothing is kept.
CardProjectContents decodeCardProject(
  Uint8List bytes,
  ElementRegistry registry,
) {
  final files = decodePortableZip(
    bytes,
    isAllowedPath: _projectPath.hasMatch,
    maxEntries: 1000,
    maxEntryBytes: 12000000,
    maxTotalBytes: 30000000,
  );
  final rawManifest = files['manifest.json'];
  if (rawManifest == null)
    throw const FormatException('Not a Handy Card project');
  final manifest = _map(jsonDecode(utf8.decode(rawManifest)), 'manifest');
  if (manifest['format'] != cardProjectFormat)
    throw const FormatException('Not a Handy Card project');
  final version = manifest['version'];
  if (version is! int || version > cardProjectVersion)
    throw const FormatException('This project was made by a newer Handy Card');
  final listed = _map(manifest['files'] ?? const {}, 'manifest files');
  for (final path in files.keys.where((p) => p != 'manifest.json')) {
    if (listed[path] != sha256.convert(files[path]!).toString())
      throw FormatException('$path is damaged or not listed');
  }
  for (final path in listed.keys) {
    if (!files.containsKey(path)) throw FormatException('$path is missing');
  }
  final assets = <String, Uint8List>{};
  final designs = <CardDocument>[], templates = <CardDocument>[];
  final profiles = <CardProfile>[];
  for (final e in files.entries) {
    final path = e.key;
    if (path.startsWith('assets/')) {
      final id = path.substring(7, 71);
      if (assetId(e.value) != id || imageMime(e.value) == null)
        throw FormatException('$path is not the picture it names');
      assets[id] = e.value;
    } else if (path.startsWith('designs/')) {
      designs.add(CardDocument.decode(utf8.decode(e.value), registry));
    } else if (path.startsWith('templates/')) {
      templates.add(CardDocument.decode(utf8.decode(e.value), registry));
    } else if (path.startsWith('profiles/')) {
      profiles.add(CardProfile.fromJson(jsonDecode(utf8.decode(e.value))));
    }
  }
  final missing = {
    for (final d in [...designs, ...templates])
      for (final a in d.assets)
        if (!assets.containsKey(a.id)) a.id,
    for (final p in profiles)
      for (final id in [?p.photo, ?p.logo])
        if (!assets.containsKey(id)) id,
  };
  return CardProjectContents(designs, templates, profiles, assets, missing);
}
