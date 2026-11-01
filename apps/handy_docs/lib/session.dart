import 'dart:convert';
import 'dart:typed_data';
import 'package:handy_docs_engine/handy_docs_engine.dart';

class ScanPage {
  final String id, name;
  final Uint8List _png;
  Uint8List get png => Uint8List.fromList(_png);
  ScanPage(this.id, this.name, Uint8List png) : _png = Uint8List.fromList(png);
}

class ScanSession {
  final List<ScanPage> pages;
  ScanSession(Iterable<ScanPage> pages) : pages = List.unmodifiable(pages) {
    if (this.pages.length > 20 ||
        this.pages.map((p) => p.id).toSet().length != this.pages.length) {
      throw const FormatException(
        'At most 20 pages with unique IDs are allowed',
      );
    }
    var size = 0, pixels = 0;
    for (final page in this.pages) {
      if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(page.id) ||
          page.name.isEmpty ||
          page.name.length > 200 ||
          page.name.contains('\x00')) {
        throw const FormatException('Invalid page identity');
      }
      size += page._png.length;
      if (size > 16000000) throw const FormatException('Session exceeds 16 MB');
      final image = decodeScanPng(page._png);
      pixels += image.width * image.height;
      if (pixels > 16777216)
        throw const FormatException(
          'Session exceeds 16 million pixels; export a smaller group',
        );
    }
  }
  String serialize() => jsonEncode({
    'format': 'handy-docs-scan',
    'version': 1,
    'pages': [
      for (final p in pages)
        {'id': p.id, 'name': p.name, 'png': base64Encode(p._png)},
    ],
  });
  factory ScanSession.parse(String text) {
    if (utf8.encode(text).length > 24000000)
      throw const FormatException('Session file exceeds 24 MB');
    final raw = jsonDecode(text);
    if (raw is! Map ||
        raw['format'] != 'handy-docs-scan' ||
        raw['version'] != 1 ||
        raw['pages'] is! List ||
        (raw['pages'] as List).length > 20) {
      throw const FormatException('Unsupported scanner session');
    }
    return ScanSession([for (final p in raw['pages']) _parsePage(p)]);
  }
  static ScanPage _parsePage(dynamic p) {
    if (p is! Map ||
        p['id'] is! String ||
        p['name'] is! String ||
        p['png'] is! String ||
        (p['png'] as String).length > 16000000) {
      throw const FormatException('Invalid scanner page');
    }
    final bytes = base64Decode(p['png']);
    if (base64Encode(bytes) != p['png'])
      throw const FormatException('Invalid page encoding');
    return ScanPage(p['id'], p['name'], bytes);
  }
}
