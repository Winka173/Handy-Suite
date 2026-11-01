import 'dart:convert';
import 'dart:typed_data';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'exif.dart';

class ImageMetadata {
  final String format;
  final int width, height;
  final List<String> sections;
  final bool hasExif, gpsPossible;
  final Map<String, String> tags;
  final double? latitude, longitude;
  final List<String> warnings;
  const ImageMetadata(
    this.format,
    this.width,
    this.height,
    this.sections,
    this.hasExif,
    this.gpsPossible, {
    this.tags = const {},
    this.latitude,
    this.longitude,
    this.warnings = const [],
  });
}

class _Part {
  final int start, end;
  final String kind;
  final int? payload;
  const _Part(this.start, this.end, this.kind, [this.payload]);
}

List<_Part> _pngParts(Uint8List bytes) {
  final parts = <_Part>[];
  for (var offset = 8; offset < bytes.length;) {
    if (offset + 12 > bytes.length)
      throw const FormatException('Truncated PNG chunk');
    final length = ByteData.sublistView(bytes).getUint32(offset),
        end = offset + 12 + length;
    if (end > bytes.length)
      throw const FormatException('Truncated PNG payload');
    final type = ascii.decode(bytes.sublist(offset + 4, offset + 8));
    parts.add(_Part(offset, end, type));
    offset = end;
  }
  return parts;
}

List<_Part> _jpegParts(Uint8List bytes) {
  final parts = <_Part>[];
  var offset = 2;
  while (offset < bytes.length - 2) {
    final start = offset;
    if (bytes[offset++] != 255)
      throw const FormatException('Malformed JPEG marker');
    while (offset < bytes.length && bytes[offset] == 255) {
      offset++;
    }
    if (offset >= bytes.length)
      throw const FormatException('Truncated JPEG marker');
    final marker = bytes[offset++];
    if (marker == 0 ||
        marker == 216 ||
        marker == 217 ||
        marker >= 208 && marker <= 215)
      throw const FormatException('Unexpected JPEG marker');
    if (offset + 2 > bytes.length)
      throw const FormatException('Truncated JPEG length');
    final length = (bytes[offset] << 8) | bytes[offset + 1],
        end = offset + length;
    if (length < 2 || end > bytes.length)
      throw const FormatException('Invalid JPEG segment');
    if (marker == 218) {
      parts.add(_Part(start, bytes.length, 'scan'));
      return parts;
    }
    parts.add(
      _Part(
        start,
        end,
        marker == 225
            ? 'APP1'
            : marker == 237
            ? 'APP13'
            : marker == 254
            ? 'COM'
            : 'marker-$marker',
        offset + 2,
      ),
    );
    offset = end;
  }
  throw const FormatException('JPEG scan missing');
}

ImageMetadata inspectImageMetadata(Uint8List bytes) {
  final decoded = decodeBoundedImage(bytes), png = bytes.first == 137;
  final parts = png ? _pngParts(bytes) : _jpegParts(bytes);
  final sections = parts
      .where(
        (p) => png
            ? ['eXIf', 'tEXt', 'zTXt', 'iTXt', 'tIME'].contains(p.kind)
            : ['APP1', 'APP13', 'COM'].contains(p.kind),
      )
      .map((p) => p.kind)
      .toList();
  var exif = false, gps = false;
  double? latitude, longitude;
  final tags = <String, String>{}, warnings = <String>[];
  var exifCount = 0;
  for (final part in parts) {
    Uint8List? tiff;
    if (png && part.kind == 'eXIf')
      tiff = Uint8List.sublistView(bytes, part.start + 8, part.end - 4);
    if (!png && part.kind == 'APP1') {
      final at = part.payload!;
      if (at + 6 <= part.end &&
          bytes.sublist(at, at + 6).join(',') == '69,120,105,102,0,0')
        tiff = Uint8List.sublistView(bytes, at + 6, part.end);
    }
    if (tiff == null) continue;
    exif = true;
    exifCount++;
    try {
      final parsed = inspectExifTiff(tiff);
      gps |= parsed.hasGps;
      latitude ??= parsed.latitude;
      longitude ??= parsed.longitude;
      for (final e in parsed.tags.entries) {
        tags['${exifCount > 1 ? 'EXIF$exifCount.' : ''}${e.key}'] = e.value;
      }
    } on FormatException catch (e) {
      gps = true;
      warnings.add(e.message);
    }
  }
  return ImageMetadata(
    png ? 'PNG' : 'JPEG',
    decoded.width,
    decoded.height,
    List.unmodifiable(sections),
    exif,
    gps,
    tags: Map.unmodifiable(tags),
    latitude: latitude,
    longitude: longitude,
    warnings: List.unmodifiable(warnings),
  );
}

/// PNG removes EXIF/text/time; JPEG removes APP1 (EXIF/XMP), APP13 and comments.
/// JPEG pixels are preserved. EXIF orientation is removed too; callers must preview
/// the result, because presentation may rotate. No promise about steganography.
Uint8List stripImageMetadata(Uint8List bytes) {
  inspectImageMetadata(bytes);
  final png = bytes.first == 137,
      parts = png ? _pngParts(bytes) : _jpegParts(bytes),
      output = BytesBuilder(copy: false);
  output.add(bytes.sublist(0, png ? 8 : 2));
  for (final part in parts) {
    final remove = png
        ? ['eXIf', 'tEXt', 'zTXt', 'iTXt', 'tIME'].contains(part.kind)
        : ['APP1', 'APP13', 'COM'].contains(part.kind);
    if (!remove) output.add(bytes.sublist(part.start, part.end));
  }
  final result = output.takeBytes();
  inspectImageMetadata(result);
  return result;
}
