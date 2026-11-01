import 'package:handy_core/portable_zip.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'project.dart';

String portableProjectChecksum(Uint8List bytes) =>
    getCrc32(bytes).toRadixString(16).padLeft(8, '0');

class PortableCapture {
  final CaptureProject project;
  final Map<String, Uint8List> assets;
  PortableCapture(this.project, Map<String, Uint8List> assets)
    : assets = Map.unmodifiable({
        for (final e in assets.entries)
          e.key: Uint8List.fromList(e.value).asUnmodifiableView(),
      });
}

void verifyProjectImage(Uint8List bytes, ProjectStep step) {
  final info = projectPngDimensions(bytes);
  if (info.width != step.imageWidth || info.height != step.imageHeight)
    throw const FormatException(
      'Image dimensions must match the original step',
    );
}

({int width, int height}) projectPngDimensions(Uint8List bytes) {
  if (bytes.length < 45 ||
      bytes.length > 8000000 ||
      bytes.take(8).join(',') != '137,80,78,71,13,10,26,10')
    throw const FormatException('Project assets require PNG up to 8 MB');
  final info = _projectPngEnvelope(bytes);
  // Keep full pixel verification for the strict decoder's supported subset.
  // Large legacy assets stay byte-exact and decode at display/output size in
  // Flutter, avoiding an extra 128 MB Dart RGBA allocation for each library read.
  if (info.width * info.height <= 16000000 &&
      info.depth == 8 &&
      !info.interlaced)
    decodeBoundedImage(bytes);
  return (width: info.width, height: info.height);
}

({int width, int height, int depth, bool interlaced}) _projectPngEnvelope(
  Uint8List bytes,
) {
  final view = ByteData.sublistView(bytes);
  var count = 0,
      width = 0,
      height = 0,
      color = -1,
      depth = 0,
      interlace = 0,
      dataBytes = 0;
  var idat = false, leftIdat = false, ended = false, palette = false;
  final zlib = <int>[];
  for (var at = 8; at < bytes.length;) {
    if (++count > 4096 || at + 12 > bytes.length)
      throw const FormatException('Invalid project PNG chunks');
    final length = view.getUint32(at), end = at + 12 + length;
    if (end > bytes.length)
      throw const FormatException('Truncated project PNG');
    final type = ascii.decode(bytes.sublist(at + 4, at + 8));
    if (!RegExp(r'^[A-Za-z]{4}$').hasMatch(type) ||
        getCrc32(Uint8List.sublistView(bytes, at + 4, end - 4)) !=
            view.getUint32(end - 4))
      throw const FormatException('Project PNG checksum mismatch');
    if (count == 1 && type != 'IHDR')
      throw const FormatException('Project PNG header missing');
    if (type == 'IHDR') {
      if (count != 1 || length != 13)
        throw const FormatException('Invalid project PNG header');
      width = view.getUint32(at + 8);
      height = view.getUint32(at + 12);
      depth = bytes[at + 16];
      color = bytes[at + 17];
      interlace = bytes[at + 20];
      final validDepths = {
        0: {1, 2, 4, 8, 16},
        2: {8, 16},
        3: {1, 2, 4, 8},
        4: {8, 16},
        6: {8, 16},
      };
      if (width < 1 ||
          height < 1 ||
          width > 16384 ||
          height > 16384 ||
          width * height > 32000000 ||
          !(validDepths[color]?.contains(depth) ?? false) ||
          bytes[at + 18] != 0 ||
          bytes[at + 19] != 0 ||
          interlace > 1)
        throw const FormatException(
          'Project PNG exceeds legacy dimensions or format bounds',
        );
    } else if (type == 'PLTE') {
      if (palette || idat || length < 3 || length > 768 || length % 3 != 0)
        throw const FormatException('Invalid project PNG palette');
      palette = true;
    } else if (type == 'IDAT') {
      if (leftIdat || color == 3 && !palette)
        throw const FormatException('Invalid project PNG image sequence');
      idat = true;
      dataBytes += length;
      for (var i = at + 8; i < end - 4 && zlib.length < 2; i++)
        zlib.add(bytes[i]);
    } else if (type == 'IEND') {
      if (length != 0 || !idat || end != bytes.length)
        throw const FormatException('Invalid project PNG end');
      ended = true;
    } else {
      if (idat) leftIdat = true;
      if (type.codeUnitAt(0) < 97)
        throw const FormatException('Unsupported critical project PNG chunk');
      if (type == 'acTL' || type == 'fcTL' || type == 'fdAT')
        throw const FormatException('Animated project PNG is unsupported');
    }
    at = end;
  }
  if (!ended ||
      dataBytes < 6 ||
      zlib.length != 2 ||
      (zlib[0] & 15) != 8 ||
      zlib[0] >> 4 > 7 ||
      ((zlib[0] << 8) | zlib[1]) % 31 != 0 ||
      (zlib[1] & 32) != 0)
    throw const FormatException('Incomplete project PNG image stream');
  return (
    width: width,
    height: height,
    depth: depth,
    interlaced: interlace == 1,
  );
}

PortableCapture parsePortableProject(Uint8List bytes) {
  try {
    return _parsePortableProject(bytes);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Malformed project ZIP');
  }
}

PortableCapture _parsePortableProject(Uint8List bytes) {
  final files = decodePortableZip(
    bytes,
    isAllowedPath: (name) => RegExp(
      r'^(manifest\.json|assets/image-[0-9]{1,3}\.png)$',
    ).hasMatch(name),
    maxEntries: 101,
    maxEntryBytes: 8000000,
  );
  final manifest = files['manifest.json'];
  if (manifest == null || manifest.length > 3000000)
    throw const FormatException('Project manifest missing or too large');
  final raw = jsonDecode(utf8.decode(manifest));
  if (raw is! Map ||
      raw['format'] != 'handy-media-project' ||
      raw['version'] != 1 ||
      raw['assets'] is! List)
    throw const FormatException('Unsupported project manifest');
  final project = CaptureProject.parse(raw['project']),
      entries = raw['assets'] as List;
  if (entries.length != project.steps.length ||
      files.length != entries.length + 1)
    throw const FormatException('Manifest/assets count mismatch');
  final assets = <String, Uint8List>{};
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i],
        path = 'assets/image-$i.png',
        uri = 'file:///portable/$path',
        image = files[path],
        step = project.steps[i];
    if (entry is! Map ||
        entry['path'] != path ||
        image == null ||
        entry['bytes'] != image.length ||
        entry['crc32'] != portableProjectChecksum(image) ||
        step.imageUri != uri)
      throw const FormatException('Project manifest verification failed');
    verifyProjectImage(image, step);
    assets[uri] = image;
  }
  return PortableCapture(project, assets);
}

Uint8List buildPortableProject(
  CaptureProject input,
  Map<String, Uint8List> images,
) {
  final source = CaptureProject.parse(input.toJson()),
      archive = Archive(),
      assets = <Map<String, dynamic>>[],
      steps = <ProjectStep>[];
  var total = 0;
  for (var i = 0; i < source.steps.length; i++) {
    final step = source.steps[i], image = images[step.imageUri];
    if (image == null)
      throw const FormatException(
        'Source asset missing; relink every image before ZIP export',
      );
    verifyProjectImage(image, step);
    total += image.length;
    if (total > 28000000)
      throw const FormatException('Project assets exceed ZIP budget');
    final path = 'assets/image-$i.png';
    archive.addFile(ArchiveFile(path, image.length, image));
    assets.add({
      'path': path,
      'bytes': image.length,
      'crc32': portableProjectChecksum(image),
    });
    steps.add(step.copyWith(imageUri: 'file:///portable/$path'));
  }
  final portable = CaptureProject.parse({
        ...source.toJson(),
        'steps': [for (final s in steps) s.toJson()],
      }),
      manifest = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'format': 'handy-media-project',
            'version': 1,
            'project': portable.toJson(),
            'assets': assets,
          }),
        ),
      );
  if (total + manifest.length > 30000000)
    throw const FormatException('Project exceeds 30 MB');
  archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
  final result = ZipEncoder().encodeBytes(archive, level: 0);
  if (result.length > 30000000)
    throw const FormatException('Project ZIP exceeds 30 MB');
  parsePortableProject(result);
  return result;
}
