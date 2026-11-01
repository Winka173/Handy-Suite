import 'dart:convert';
import 'dart:typed_data';
import 'package:handy_media_engine/handy_media_engine.dart';

class CaptureLibrary {
  final List<PortableCapture> projects;
  CaptureLibrary(Iterable<PortableCapture> entries)
    : projects = List.unmodifiable(entries) {
    if (projects.length > 100 ||
        projects.map((e) => e.project.id).toSet().length != projects.length)
      throw const FormatException(
        'Duplicate project IDs or library limit exceeded',
      );
    for (final entry in projects) {
      CaptureProject.parse(entry.project.toJson());
      final referenced = entry.project.steps.map((s) => s.imageUri).toSet();
      if (entry.assets.keys.any((uri) => !referenced.contains(uri)))
        throw const FormatException('Unreferenced project assets');
      for (final step in entry.project.steps) {
        final bytes = entry.assets[step.imageUri];
        if (bytes != null) verifyProjectImage(bytes, step);
      }
    }
  }
  String serialize() {
    final text = jsonEncode({
      'format': 'handy-media-capture-library',
      'version': 1,
      'projects': [
        for (final entry in projects)
          {
            'project': entry.project.toJson(),
            'assets': {
              for (final asset in entry.assets.entries)
                asset.key: base64Encode(asset.value),
            },
          },
      ],
    });
    if (utf8.encode(text).length > 30000000)
      throw const FormatException(
        'Local project library exceeds 30 MB. Export older projects before adding more.',
      );
    return text;
  }

  factory CaptureLibrary.parse(String text) {
    if (utf8.encode(text).length > 30000000)
      throw const FormatException('Library exceeds 30 MB');
    final raw = jsonDecode(text);
    if (raw is! Map ||
        raw['format'] != 'handy-media-capture-library' ||
        raw['version'] != 1 ||
        raw['projects'] is! List ||
        (raw['projects'] as List).length > 100)
      throw const FormatException('Unsupported capture library');
    return CaptureLibrary([for (final entry in raw['projects']) _entry(entry)]);
  }
  static PortableCapture _entry(dynamic raw) {
    if (raw is! Map ||
        raw['assets'] is! Map ||
        (raw['assets'] as Map).length > 100)
      throw const FormatException('Invalid project assets');
    final assets = <String, Uint8List>{};
    for (final entry in (raw['assets'] as Map).entries) {
      if (entry.key is! String ||
          entry.value is! String ||
          (entry.value as String).length > 10666668)
        throw const FormatException('Invalid asset encoding');
      final bytes = base64Decode(entry.value);
      if (base64Encode(bytes) != entry.value)
        throw const FormatException('Noncanonical asset encoding');
      assets[entry.key] = bytes;
    }
    return PortableCapture(CaptureProject.parse(raw['project']), assets);
  }

  CaptureLibrary save(PortableCapture bundle, {bool importing = false}) {
    if (importing && projects.any((p) => p.project.id == bundle.project.id))
      throw const FormatException(
        'This project ID already exists. Existing project was preserved.',
      );
    final next = CaptureLibrary([
      for (final p in projects)
        if (p.project.id != bundle.project.id) p,
      bundle,
    ]);
    next.serialize();
    return next;
  }

  CaptureLibrary remove(String id) =>
      CaptureLibrary(projects.where((p) => p.project.id != id));
}
