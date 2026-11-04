import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:handy_core/handy_core.dart';
import 'package:image/image.dart' as image;
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

class ScanLimits {
  static const pixels = 4194304,
      edge = 2048,
      bytes = 12000000,
      pages = 20,
      sessionBytes = 30000000,
      sessionPixels = 16777216;
}

class ScanPoint {
  final double x, y;
  const ScanPoint(this.x, this.y);
  Map<String, double> toJson() => {'x': x, 'y': y};
}

List<ScanPoint> fullScanCorners() => const [
  ScanPoint(0, 0),
  ScanPoint(1, 0),
  ScanPoint(1, 1),
  ScanPoint(0, 1),
];
void validateScanCorners(List<ScanPoint> corners) {
  if (corners.length != 4 ||
      corners.any(
        (p) =>
            !p.x.isFinite ||
            !p.y.isFinite ||
            p.x < 0 ||
            p.x > 1 ||
            p.y < 0 ||
            p.y > 1,
      ))
    throw const FormatException('Four corners must be inside image');
  var area = 0.0;
  for (var i = 0; i < 4; i++) {
    final a = corners[i], b = corners[(i + 1) % 4], c = corners[(i + 2) % 4];
    if ((b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x) <= 0.00001 ||
        math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2)) < 0.02)
      throw const FormatException(
        'Corners must form clockwise convex document without crossing',
      );
    area += a.x * b.y - b.x * a.y;
  }
  if (area / 2 < 0.01) throw const FormatException('Document area too small');
}

void _size(
  int width,
  int height, {
  int minDimension = 2,
  int maxEdge = ScanLimits.edge,
  int maxPixels = ScanLimits.pixels,
}) {
  if (width < minDimension ||
      height < minDimension ||
      width > maxEdge ||
      height > maxEdge ||
      width * height > maxPixels)
    throw const FormatException(
      'Normalize image to 2–2048 pixels per edge before scanning',
    );
}

class ScanRaster {
  final int width, height;
  final Uint8List rgba;
  factory ScanRaster({
    required int width,
    required int height,
    required Uint8List rgba,
  }) {
    _size(width, height);
    if (rgba.length != width * height * 4)
      throw const FormatException('Invalid RGBA raster length');
    return ScanRaster._(
      width,
      height,
      Uint8List.fromList(rgba).asUnmodifiableView(),
    );
  }
  ScanRaster._(this.width, this.height, this.rgba);
}

({int width, int height}) scanOutputSize(
  int width,
  int height,
  List<ScanPoint> corners,
) {
  _size(width, height);
  validateScanCorners(corners);
  double edge(ScanPoint a, ScanPoint b) => math.sqrt(
    math.pow((a.x - b.x) * (width - 1), 2) +
        math.pow((a.y - b.y) * (height - 1), 2),
  );
  final w = math.max(
        edge(corners[0], corners[1]),
        edge(corners[3], corners[2]),
      ),
      h = math.max(edge(corners[0], corners[3]), edge(corners[1], corners[2]));
  final scale = math.min(1, ScanLimits.edge / math.max(w, h));
  return (
    width: math.min(ScanLimits.edge, math.max(2, (w * scale).round() + 1)),
    height: math.min(ScanLimits.edge, math.max(2, (h * scale).round() + 1)),
  );
}

List<double> scanHomography(List<ScanPoint> corners) {
  validateScanCorners(corners);
  final rows = <List<double>>[];
  for (var i = 0; i < 4; i++) {
    final u = [0.0, 1.0, 1.0, 0.0][i],
        v = [0.0, 0.0, 1.0, 1.0][i],
        x = corners[i].x,
        y = corners[i].y;
    rows.add([u, v, 1, 0, 0, 0, -u * x, -v * x, x]);
    rows.add([0, 0, 0, u, v, 1, -u * y, -v * y, y]);
  }
  for (var col = 0; col < 8; col++) {
    var pivot = col;
    for (var r = col + 1; r < 8; r++) {
      if (rows[r][col].abs() > rows[pivot][col].abs()) pivot = r;
    }
    final temp = rows[col];
    rows[col] = rows[pivot];
    rows[pivot] = temp;
    final d = rows[col][col];
    if (d.abs() < 1e-10) throw const FormatException('Degenerate perspective');
    for (var c = col; c < 9; c++) {
      rows[col][c] /= d;
    }
    for (var r = 0; r < 8; r++) {
      if (r == col) continue;
      final f = rows[r][col];
      for (var c = col; c < 9; c++) {
        rows[r][c] -= f * rows[col][c];
      }
    }
  }
  return List.unmodifiable(rows.map((r) => r[8]));
}

/// How a straightened page is toned: kept in colour, turned grey, or kept
/// in colour with the light ground pushed to white (a whiteboard).
const scanTones = ['color', 'gray', 'whiten'];

/// A kind of paper and the tone and contrast that usually suit it. The
/// person can still move the contrast after choosing.
class ScanPreset {
  final String id, en, vi, tone;
  final double contrast;
  const ScanPreset(this.id, this.en, this.vi, this.tone, this.contrast);
}

const scanPresets = [
  ScanPreset('original', 'As shot', 'Giữ màu gốc', 'color', 1),
  ScanPreset('document', 'Document', 'Giấy tờ', 'gray', 1.4),
  ScanPreset('receipt', 'Receipt', 'Hóa đơn', 'gray', 2),
  ScanPreset('board', 'Whiteboard', 'Bảng trắng', 'whiten', 1.3),
];

Future<ScanRaster> rectifyScan(
  ScanRaster source,
  List<ScanPoint> corners, {
  double contrast = 1,
  String tone = 'color',
  CancellationToken? cancellation,
  void Function(double)? onProgress,
}) async {
  cancellation?.check();
  _size(source.width, source.height);
  validateScanCorners(corners);
  if (!contrast.isFinite || contrast < 1 || contrast > 3)
    throw const FormatException('Contrast range: 1–3');
  if (!scanTones.contains(tone))
    throw const FormatException('Unknown scan tone');
  final size = scanOutputSize(source.width, source.height, corners),
      h = scanHomography(corners),
      rgba = Uint8List(size.width * size.height * 4);
  for (var y = 0; y < size.height; y++) {
    if (y % 32 == 0) {
      cancellation?.check();
      onProgress?.call(y / size.height);
      await Future<void>.delayed(Duration.zero);
      cancellation?.check();
    }
    final v = y / (size.height - 1);
    for (var x = 0; x < size.width; x++) {
      final u = x / (size.width - 1), d = h[6] * u + h[7] * v + 1;
      if (!d.isFinite || d.abs() < 1e-8)
        throw const FormatException('Invalid perspective mapping');
      final sx = (((h[0] * u + h[1] * v + h[2]) / d) * (source.width - 1))
              .clamp(0.0, source.width - 1.0),
          sy = (((h[3] * u + h[4] * v + h[5]) / d) * (source.height - 1)).clamp(
            0.0,
            source.height - 1.0,
          );
      final x0 = sx.floor(),
          y0 = sy.floor(),
          x1 = math.min(x0 + 1, source.width - 1),
          y1 = math.min(y0 + 1, source.height - 1),
          fx = sx - x0,
          fy = sy - y0;
      final samples = [
        (x0, y0, (1 - fx) * (1 - fy)),
        (x1, y0, fx * (1 - fy)),
        (x0, y1, (1 - fx) * fy),
        (x1, y1, fx * fy),
      ];
      final target = (y * size.width + x) * 4;
      final rgb = [0.0, 0.0, 0.0];
      for (var c = 0; c < 3; c++) {
        for (final p in samples) {
          final at = (p.$2 * source.width + p.$1) * 4,
              alpha = source.rgba[at + 3] / 255;
          rgb[c] += (source.rgba[at + c] * alpha + 255 * (1 - alpha)) * p.$3;
        }
      }
      if (tone == 'gray') {
        final l = 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2];
        rgb[0] = rgb[1] = rgb[2] = l;
      } else if (tone == 'whiten') {
        // A lit board is a little grey or blue; lift it to white and leave
        // the marker strokes, which are far darker, as they are.
        final l = 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2];
        if (l > 150) {
          final lift = ((l - 150) / 60).clamp(0.0, 1.0);
          for (var c = 0; c < 3; c++) {
            rgb[c] += (255 - rgb[c]) * lift;
          }
        }
      }
      for (var c = 0; c < 3; c++) {
        rgba[target + c] = ((rgb[c] - 128) * contrast + 128)
            .clamp(0, 255)
            .round();
      }
      rgba[target + 3] = 255;
    }
  }
  cancellation?.check();
  onProgress?.call(1);
  cancellation?.check();
  return ScanRaster(width: size.width, height: size.height, rgba: rgba);
}

const _pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];
int _crc(Uint8List bytes) {
  var c = 0xffffffff;
  for (final b in bytes) {
    c ^= b;
    for (var i = 0; i < 8; i++) {
      c = (c >>> 1) ^ ((c & 1) != 0 ? 0xedb88320 : 0);
    }
  }
  return (c ^ 0xffffffff) & 0xffffffff;
}

int _adler(Uint8List bytes) {
  var a = 1, b = 0;
  for (final value in bytes) {
    a = (a + value) % 65521;
    b = (b + a) % 65521;
  }
  return ((b << 16) | a) & 0xffffffff;
}

Uint8List _concat(List<Uint8List> parts) {
  final out = BytesBuilder(copy: false);
  for (final p in parts) {
    out.add(p);
  }
  return out.takeBytes();
}

class _PngData {
  final int width, height, type;
  final Uint8List pixels;
  final Uint8List? palette, alpha;
  _PngData(
    this.width,
    this.height,
    this.type,
    this.pixels,
    this.palette,
    this.alpha,
  );
}

_PngData _readPng(
  Uint8List bytes, {
  int minDimension = 2,
  int maxEdge = ScanLimits.edge,
  int maxPixels = ScanLimits.pixels,
  int maxBytes = ScanLimits.bytes,
}) {
  if (bytes.length < 45 ||
      bytes.length > maxBytes ||
      !Iterable<int>.generate(8).every((i) => bytes[i] == _pngSignature[i]))
    throw const FormatException('Invalid or oversized PNG');
  final view = ByteData.sublistView(bytes), parts = <Uint8List>[];
  var offset = 8,
      width = 0,
      height = 0,
      type = -1,
      count = 0,
      idat = false,
      leftIdat = false,
      ended = false;
  Uint8List? palette, alpha;
  while (offset < bytes.length) {
    if (++count > 4096 || offset + 12 > bytes.length)
      throw const FormatException('Invalid PNG chunks');
    final length = view.getUint32(offset), end = offset + length + 12;
    if (end > bytes.length) throw const FormatException('Truncated PNG');
    final name = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8)),
        data = Uint8List.sublistView(bytes, offset + 8, end - 4);
    if (!RegExp(r'^[A-Za-z]{4}$').hasMatch(name) ||
        _crc(Uint8List.sublistView(bytes, offset + 4, end - 4)) !=
            view.getUint32(end - 4))
      throw const FormatException('PNG checksum mismatch');
    if (count == 1 && name != 'IHDR')
      throw const FormatException('Missing PNG header');
    if (name == 'IHDR') {
      if (count != 1 || length != 13)
        throw const FormatException('Invalid PNG header');
      width = view.getUint32(offset + 8);
      height = view.getUint32(offset + 12);
      _size(
        width,
        height,
        minDimension: minDimension,
        maxEdge: maxEdge,
        maxPixels: maxPixels,
      );
      type = data[9];
      if (data[8] != 8 ||
          ![0, 2, 3, 4, 6].contains(type) ||
          data[10] != 0 ||
          data[11] != 0 ||
          data[12] != 0)
        throw const FormatException('Non-interlaced 8-bit PNG required');
    } else if (name == 'PLTE') {
      if (idat ||
          palette != null ||
          length == 0 ||
          length % 3 != 0 ||
          length > 768)
        throw const FormatException('Invalid PNG palette');
      palette = data;
    } else if (name == 'tRNS') {
      if (idat || alpha != null)
        throw const FormatException('Invalid PNG transparency');
      alpha = data;
    } else if (name == 'IDAT') {
      if (leftIdat) throw const FormatException('Nonconsecutive PNG data');
      idat = true;
      parts.add(data);
    } else {
      if (idat) leftIdat = true;
      if (name == 'IEND') {
        if (length != 0 || end != bytes.length || !idat)
          throw const FormatException('Invalid PNG end');
        ended = true;
      } else if (name[0] == name[0].toUpperCase() ||
          ['acTL', 'fcTL', 'fdAT'].contains(name))
        throw const FormatException('Unsupported PNG chunk');
      // Ancillary metadata is validated then discarded, never inflated.
    }
    offset = end;
  }
  if (!ended || width == 0 || (type == 3 && palette == null))
    throw const FormatException('Incomplete PNG');
  if (alpha != null &&
      ((type == 0 && alpha.length != 2) ||
          (type == 2 && alpha.length != 6) ||
          (type == 3 &&
              (alpha.isEmpty || alpha.length > palette!.length ~/ 3)) ||
          type == 4 ||
          type == 6))
    throw const FormatException('Invalid PNG transparency length');
  final channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[type]!,
      expected = (width * channels + 1) * height,
      compressed = _concat(parts);
  if (compressed.length < 6)
    throw const FormatException('Incomplete PNG compression');
  Uint8List decoded;
  try {
    decoded = const ZLibDecoder().decodeBytes(
      compressed,
      verify: true,
      maxOutputSize: expected,
    );
  } catch (_) {
    throw const FormatException('Invalid or oversized PNG compressed pixels');
  }
  if (decoded.length != expected ||
      _adler(decoded) !=
          ByteData.sublistView(compressed).getUint32(compressed.length - 4))
    throw const FormatException('Incomplete PNG pixels or checksum mismatch');
  return _PngData(width, height, type, decoded, palette, alpha);
}

DecodedImage _decodePngPixels(
  Uint8List bytes, {
  int minDimension = 2,
  int maxEdge = ScanLimits.edge,
  int maxPixels = ScanLimits.pixels,
  int maxBytes = ScanLimits.bytes,
}) {
  final p = _readPng(
        bytes,
        minDimension: minDimension,
        maxEdge: maxEdge,
        maxPixels: maxPixels,
        maxBytes: maxBytes,
      ),
      channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[p.type]!,
      stride = p.width * channels,
      raw = Uint8List(stride * p.height),
      rgba = Uint8List(p.width * p.height * 4);
  int paeth(int a, int b, int c) {
    final x = a + b - c,
        pa = (x - a).abs(),
        pb = (x - b).abs(),
        pc = (x - c).abs();
    return pa <= pb && pa <= pc
        ? a
        : pb <= pc
        ? b
        : c;
  }

  for (var y = 0; y < p.height; y++) {
    final filter = p.pixels[y * (stride + 1)];
    if (filter > 4) throw const FormatException('Invalid PNG filter');
    for (var x = 0; x < stride; x++) {
      final a = x >= channels ? raw[y * stride + x - channels] : 0,
          b = y > 0 ? raw[(y - 1) * stride + x] : 0,
          c = y > 0 && x >= channels ? raw[(y - 1) * stride + x - channels] : 0;
      raw[y * stride + x] =
          (p.pixels[y * (stride + 1) + x + 1] +
              switch (filter) {
                0 => 0,
                1 => a,
                2 => b,
                3 => (a + b) ~/ 2,
                _ => paeth(a, b, c),
              }) &
          255;
    }
  }
  for (var i = 0; i < p.width * p.height; i++) {
    final s = i * channels, t = i * 4;
    if (p.type == 6) {
      rgba.setRange(t, t + 4, raw, s);
    } else if (p.type == 2) {
      rgba.setRange(t, t + 3, raw, s);
      rgba[t + 3] =
          p.alpha != null &&
              raw[s] == ByteData.sublistView(p.alpha!).getUint16(0) &&
              raw[s + 1] == ByteData.sublistView(p.alpha!).getUint16(2) &&
              raw[s + 2] == ByteData.sublistView(p.alpha!).getUint16(4)
          ? 0
          : 255;
    } else if (p.type == 3) {
      final index = raw[s];
      if (index * 3 + 2 >= p.palette!.length)
        throw const FormatException('Invalid PNG palette index');
      rgba.setRange(t, t + 3, p.palette!, index * 3);
      rgba[t + 3] = p.alpha != null && index < p.alpha!.length
          ? p.alpha![index]
          : 255;
    } else {
      rgba[t] = rgba[t + 1] = rgba[t + 2] = raw[s];
      rgba[t + 3] = p.type == 4
          ? raw[s + 1]
          : p.alpha != null &&
                raw[s] == ByteData.sublistView(p.alpha!).getUint16(0)
          ? 0
          : 255;
    }
  }
  return DecodedImage._(p.width, p.height, rgba.asUnmodifiableView());
}

/// Shared strict codec boundary. Scanner APIs retain their original 2..2048 limits.
class DecodedImage {
  final int width, height;
  final Uint8List rgba;
  DecodedImage._(this.width, this.height, this.rgba);
}

ScanRaster decodeScanPng(Uint8List bytes) {
  final raster = _decodePngPixels(bytes);
  return ScanRaster(
    width: raster.width,
    height: raster.height,
    rgba: raster.rgba,
  );
}

Uint8List encodeScanPng(ScanRaster raster) {
  _size(raster.width, raster.height);
  final bitmap = image.Image.fromBytes(
    width: raster.width,
    height: raster.height,
    bytes: raster.rgba.buffer,
    numChannels: 4,
  );
  final bytes = image.encodePng(bitmap);
  if (bytes.length > ScanLimits.bytes)
    throw const FormatException('Encoded scan exceeds 12 MB');
  return bytes;
}

ScanRaster decodeScanImage(Uint8List bytes) {
  final raster = decodeBoundedImage(
    bytes,
    minDimension: 2,
    maxEdge: ScanLimits.edge,
    maxPixels: ScanLimits.pixels,
    maxBytes: ScanLimits.bytes,
  );
  return ScanRaster(
    width: raster.width,
    height: raster.height,
    rgba: raster.rgba,
  );
}

/// Decode PNG/JPEG with immutable RGBA, explicit hard memory/byte ceilings and EXIF
/// orientation baked. Used by Media without duplicating the strict PNG decoder.
DecodedImage decodeBoundedImage(
  Uint8List bytes, {
  int minDimension = 1,
  int maxEdge = 16384,
  int maxPixels = 16000000,
  int maxBytes = 20000000,
  bool allowWebP = false,
}) {
  if (minDimension < 1 ||
      minDimension > 2 ||
      maxEdge < 1 ||
      maxEdge > 16384 ||
      maxPixels < 1 ||
      maxPixels > 16000000 ||
      maxBytes < 1 ||
      maxBytes > 20000000) {
    throw const FormatException('Codec limits exceed hard bounds');
  }
  if (bytes.length < 4 || bytes.length > maxBytes)
    throw const FormatException('Invalid or oversized image');
  if (allowWebP &&
      bytes[0] == 82 &&
      bytes[1] == 73 &&
      bytes[2] == 70 &&
      bytes[3] == 70) {
    return _decodeStaticWebP(
      bytes,
      minDimension: minDimension,
      maxEdge: maxEdge,
      maxPixels: maxPixels,
    );
  }
  if (bytes[0] == 137)
    return _decodePngPixels(
      bytes,
      minDimension: minDimension,
      maxEdge: maxEdge,
      maxPixels: maxPixels,
      maxBytes: maxBytes,
    );
  if (bytes[0] != 255 ||
      bytes[1] != 216 ||
      bytes[bytes.length - 2] != 255 ||
      bytes.last != 217)
    throw const FormatException('Complete PNG or JPEG required');
  final decoder = image.JpegDecoder(maxPixels: maxPixels);
  if (!decoder.isValidFile(bytes)) throw const FormatException('Invalid JPEG');
  final info = decoder.startDecode(bytes);
  if (info == null) throw const FormatException('Invalid JPEG dimensions');
  _size(
    info.width,
    info.height,
    minDimension: minDimension,
    maxEdge: maxEdge,
    maxPixels: maxPixels,
  );
  final decoded = decoder.decode(bytes);
  if (decoded == null) throw const FormatException('JPEG decode failed');
  final oriented = image.bakeOrientation(decoded);
  _size(
    oriented.width,
    oriented.height,
    minDimension: minDimension,
    maxEdge: maxEdge,
    maxPixels: maxPixels,
  );
  return DecodedImage._(
    oriented.width,
    oriented.height,
    oriented.getBytes(order: image.ChannelOrder.rgba).asUnmodifiableView(),
  );
}

DecodedImage _decodeStaticWebP(
  Uint8List bytes, {
  required int minDimension,
  required int maxEdge,
  required int maxPixels,
}) {
  if (bytes.length < 20 || ascii.decode(bytes.sublist(8, 12)) != 'WEBP')
    throw const FormatException('Complete static WebP required');
  final view = ByteData.sublistView(bytes);
  if (view.getUint32(4, Endian.little) != bytes.length - 8)
    throw const FormatException('WebP RIFF size mismatch');
  final seen = <String>{};
  (int, int)? canvas, bitmap;
  for (var at = 12; at < bytes.length;) {
    if (at + 8 > bytes.length || seen.length >= 16)
      throw const FormatException('Invalid WebP chunk table');
    final type = ascii.decode(bytes.sublist(at, at + 4)),
        length = view.getUint32(at + 4, Endian.little),
        start = at + 8;
    final end = start + length + (length & 1);
    if (end > bytes.length ||
        !{
          'VP8X',
          'VP8 ',
          'VP8L',
          'ALPH',
          'ICCP',
          'EXIF',
          'XMP ',
        }.contains(type) ||
        !seen.add(type))
      throw const FormatException(
        'Only bounded, single-frame WebP is supported',
      );
    if ({'EXIF', 'XMP ', 'ICCP'}.contains(type) && length > 1000000)
      throw const FormatException('WebP metadata exceeds 1 MB');
    int u24(int offset) =>
        bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);
    (int, int)? size;
    if (type == 'VP8X') {
      if (length != 10 ||
          (bytes[start] & 0xc3) != 0 ||
          bytes[start + 1] != 0 ||
          bytes[start + 2] != 0 ||
          bytes[start + 3] != 0)
        throw const FormatException(
          'Animated/reserved WebP flags are unsupported',
        );
      size = (u24(start + 4) + 1, u24(start + 7) + 1);
      canvas = size;
    } else if (type == 'VP8L') {
      if (length < 5 || bytes[start] != 0x2f)
        throw const FormatException('Invalid WebP lossless header');
      final bits = view.getUint32(start + 1, Endian.little);
      if (bits >> 29 != 0)
        throw const FormatException('Unsupported WebP lossless version');
      size = ((bits & 0x3fff) + 1, ((bits >> 14) & 0x3fff) + 1);
      bitmap = size;
    } else if (type == 'VP8 ') {
      if (length < 10 ||
          (bytes[start] & 1) != 0 ||
          bytes[start + 3] != 0x9d ||
          bytes[start + 4] != 1 ||
          bytes[start + 5] != 0x2a)
        throw const FormatException('Invalid WebP key frame');
      size = (
        view.getUint16(start + 6, Endian.little) & 0x3fff,
        view.getUint16(start + 8, Endian.little) & 0x3fff,
      );
      bitmap = size;
    }
    if (size != null)
      _size(
        size.$1,
        size.$2,
        minDimension: minDimension,
        maxEdge: maxEdge,
        maxPixels: maxPixels,
      );
    at = end;
  }
  if (bitmap == null ||
      (seen.contains('VP8 ') && seen.contains('VP8L')) ||
      (canvas != null && canvas != bitmap) ||
      (seen.contains('ALPH') && !seen.contains('VP8 ')))
    throw const FormatException('Inconsistent WebP image headers');
  try {
    final decoder = image.WebPDecoder()..maxPixels = maxPixels;
    final info = decoder.startDecode(bytes);
    if (info == null ||
        info.hasAnimation ||
        info.numFrames > 1 ||
        (info.width, info.height) != bitmap)
      throw const FormatException('Invalid static WebP image');
    final decoded = decoder.decodeFrame(0);
    if (decoded == null) throw const FormatException('WebP decode failed');
    final oriented = image.bakeOrientation(decoded);
    _size(
      oriented.width,
      oriented.height,
      minDimension: minDimension,
      maxEdge: maxEdge,
      maxPixels: maxPixels,
    );
    return DecodedImage._(
      oriented.width,
      oriented.height,
      oriented.getBytes(order: image.ChannelOrder.rgba).asUnmodifiableView(),
    );
  } catch (_) {
    throw const FormatException(
      'Could not decode this bounded static WebP image',
    );
  }
}

Future<Uint8List> scanPng(
  Uint8List bytes,
  List<ScanPoint> corners, {
  double contrast = 1,
  String tone = 'color',
  CancellationToken? cancellation,
  void Function(double)? onProgress,
}) async {
  cancellation?.check();
  final raster = decodeScanImage(bytes);
  cancellation?.check();
  final result = await rectifyScan(
    raster,
    corners,
    contrast: contrast,
    tone: tone,
    cancellation: cancellation,
    onProgress: onProgress,
  );
  cancellation?.check();
  final encoded = encodeScanPng(result);
  cancellation?.check();
  return encoded;
}

Future<Uint8List> scannerPdf(
  List<Uint8List> pages, {
  CancellationToken? cancellation,
  void Function(double)? onProgress,
}) async {
  cancellation?.check();
  if (pages.isEmpty ||
      pages.length > ScanLimits.pages ||
      pages.fold<int>(0, (s, b) => s + b.length) > ScanLimits.sessionBytes)
    throw const FormatException('Scanner PDF: 1–20 pages, at most 30 MB');
  // Snapshot caller-owned bytes before the first await.
  final inputs = pages.map(Uint8List.fromList).toList();
  var pixels = 0;
  for (final page in inputs) {
    await Future<void>.delayed(Duration.zero);
    cancellation?.check();
    final p = _readPng(page);
    pixels += p.width * p.height;
    if (pixels > ScanLimits.sessionPixels)
      throw const FormatException(
        'Scanner PDF: aggregate pixel limit 16777216',
      );
  }
  final document = pw.Document(
    compress: false,
    version: pdf.PdfVersion.pdf_1_4,
  );
  for (var i = 0; i < inputs.length; i++) {
    cancellation?.check();
    onProgress?.call(i / inputs.length);
    await Future<void>.delayed(Duration.zero);
    cancellation?.check();
    final raster = decodeScanPng(inputs[i]),
        scale = math.min(
          1.0,
          math.min(595 / raster.width, 842 / raster.height),
        ),
        width = raster.width * scale,
        height = raster.height * scale;
    final bitmap = pw.MemoryImage(inputs[i]);
    document.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat(width, height),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(bitmap, fit: pw.BoxFit.fill),
      ),
    );
  }
  cancellation?.check();
  final bytes = await document.save();
  cancellation?.check();
  if (bytes.length > ScanLimits.sessionBytes)
    throw const FormatException('Scanner PDF output exceeds 30 MB');
  final actual = inspectScannerPdf(bytes);
  if (actual.pages != inputs.length)
    throw const FormatException('Generated PDF page verification failed');
  onProgress?.call(1);
  cancellation?.check();
  return bytes;
}

/// Reopens only this engine's classic-xref PDF output, not arbitrary imported PDF.
({int pages, int images}) inspectScannerPdf(Uint8List bytes) {
  if (bytes.length < 100 || bytes.length > ScanLimits.sessionBytes)
    throw const FormatException('Invalid scanner PDF size');
  final source = latin1.decode(bytes),
      trailer = RegExp(r'startxref\s+(\d+)\s+%%EOF\s*$').firstMatch(source);
  if (!source.startsWith('%PDF-1.4') || trailer == null)
    throw const FormatException('Invalid PDF header/trailer');
  final offset = int.parse(trailer[1]!);
  if (offset < 0 ||
      offset >= source.length ||
      !source.substring(offset).startsWith('xref'))
    throw const FormatException('Invalid PDF xref offset');
  final header = RegExp(
    r'^xref\s+0\s+(\d+)\s+',
  ).firstMatch(source.substring(offset));
  if (header == null) throw const FormatException('Invalid PDF xref table');
  final count = int.parse(header[1]!),
      entries = RegExp(
        r'(\d{10}) (\d{5}) ([nf])[ \t]*(?:\r?\n|\r)',
      ).allMatches(source.substring(offset + header.end)).take(count).toList();
  if (entries.length != count || count > 5000 || entries.first[3] != 'f')
    throw const FormatException('Invalid PDF xref entries');
  final objects = <int, String>{};
  for (var i = 1; i < count; i++) {
    final at = int.parse(entries[i][1]!);
    if (entries[i][3] != 'n' ||
        at <= 0 ||
        at >= offset ||
        !source.substring(at).startsWith('$i 0 obj'))
      throw const FormatException('Invalid PDF object reference');
    final end = source.indexOf('endobj', at);
    if (end < 0 || end > offset)
      throw const FormatException('Incomplete PDF object');
    final content = source.substring(at, end),
        stream = content.indexOf('stream');
    objects[i] = stream < 0 ? content : content.substring(0, stream);
  }
  final root = RegExp(
    r'/Root\s+(\d+)\s+0\s+R',
  ).firstMatch(source.substring(offset));
  if (root == null ||
      !RegExp(
        r'/Type\s*/Catalog\b',
      ).hasMatch(objects[int.parse(root[1]!)] ?? ''))
    throw const FormatException('Missing PDF catalog');
  final pages = objects.values
          .where((v) => RegExp(r'/Type\s*/Page\b').hasMatch(v))
          .length,
      images = objects.values
          .where((v) => RegExp(r'/Subtype\s*/Image\b').hasMatch(v))
          .length;
  final tree = objects.values.where(
    (v) => RegExp(r'/Type\s*/Pages\b').hasMatch(v),
  );
  if (pages < 1 ||
      pages > ScanLimits.pages ||
      tree.isEmpty ||
      tree.every((v) => !RegExp('/Count\\s+$pages\\b').hasMatch(v)) ||
      images < 1)
    throw const FormatException('Invalid PDF page tree/images');
  return (pages: pages, images: images);
}
