part of '../handy_recall.dart';

const recallImageMaxBytes = 500000;

class OcclusionMask {
  final double x, y, width, height;
  const OcclusionMask({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
  factory OcclusionMask.fromJson(Object? value) {
    final r = _record(value),
        x = _number(r['x'], 0, 1),
        y = _number(r['y'], 0, 1),
        w = _number(r['width'], 0, 1),
        h = _number(r['height'], 0, 1);
    if (w <= 0 || h <= 0 || x + w > 1 + 1e-10 || y + h > 1 + 1e-10)
      throw const FormatException('Occlusion region must fit inside image');
    return OcclusionMask(x: x, y: y, width: w, height: h);
  }
  Map<String, double> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
  OcclusionMask copyWith(Map<String, Object?> changes) =>
      OcclusionMask.fromJson({...toJson(), ...changes});
}

class RecallImage {
  final String dataUri;

  /// Parts covered until the answer shows; none for a plain picture.
  final List<OcclusionMask> masks;

  /// The note side the picture belongs to: 'front' (shown with the question)
  /// or 'back' (shown only with the answer). Covers need 'front'.
  final String side;
  RecallImage({
    required this.dataUri,
    required Iterable<OcclusionMask> masks,
    this.side = 'front',
  }) : masks = List.unmodifiable(masks);

  /// The first covered part; only for a picture that has covers.
  OcclusionMask get mask => masks.first;
  factory RecallImage.fromJson(Object? value) {
    final r = _record(value), uri = r['dataUri'];
    if (uri is! String || uri.length > 667000)
      throw const FormatException('Invalid card image');
    final match = RegExp(r'^data:image/(png|jpeg);base64,').firstMatch(uri);
    if (match == null)
      throw const FormatException('Only embedded PNG or JPEG images supported');
    final encoded = uri.substring(match.end);
    if (encoded.isEmpty ||
        encoded.length > 666668 ||
        encoded.length % 4 != 0 ||
        !RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(encoded))
      throw const FormatException('Invalid image base64');
    final bytes = base64Decode(encoded);
    if (bytes.length > recallImageMaxBytes || base64Encode(bytes) != encoded)
      throw const FormatException(
        'Image exceeds limit or base64 is noncanonical',
      );
    _validateImage(bytes, match[1]!);
    // Version 1 always had at least one region (and 'mask'); version 2 may
    // carry a plain picture with none.
    final Object? rawMasks = r['masks'] ?? [r['mask']];
    if (rawMasks is! List || rawMasks.length > 32)
      throw const FormatException('Image takes up to 32 occlusion regions');
    final side = r['side'] ?? 'front';
    if (side != 'front' && side != 'back')
      throw const FormatException('Invalid picture side');
    return RecallImage(
      dataUri: uri,
      masks: rawMasks.map(OcclusionMask.fromJson),
      side: side as String,
    );
  }
  Map<String, Object?> toJson() => {
    'dataUri': dataUri,
    // Kept for version 1 readers of covered pictures.
    if (masks.isNotEmpty) 'mask': masks.first.toJson(),
    'masks': masks.map((m) => m.toJson()).toList(),
    if (side != 'front') 'side': side,
  };
  RecallImage copyWith({
    String? dataUri,
    Iterable<OcclusionMask>? masks,
    String? side,
  }) => RecallImage.fromJson({
    'dataUri': dataUri ?? this.dataUri,
    'masks': (masks ?? this.masks).map((m) => m.toJson()).toList(),
    'side': side ?? this.side,
  });
}

void _dimensions(int width, int height) {
  if (width <= 0 ||
      height <= 0 ||
      width > 10000 ||
      height > 10000 ||
      width * height > 20000000)
    throw const FormatException('Image dimensions exceed supported limits');
}

void _validateImage(Uint8List bytes, String kind) {
  if (kind == 'png') {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < 45 ||
        List.generate(8, (i) => bytes[i]).join(',') != signature.join(','))
      throw const FormatException('Image signature is not PNG');
    final data = ByteData.sublistView(bytes);
    if (data.getUint32(8) != 13 ||
        ascii.decode(bytes.sublist(12, 16)) != 'IHDR')
      throw const FormatException('Invalid PNG header');
    _dimensions(data.getUint32(16), data.getUint32(20));
    var at = 8, hasData = false;
    while (at + 12 <= bytes.length) {
      final size = data.getUint32(at),
          type = ascii.decode(bytes.sublist(at + 4, at + 8));
      if (size > bytes.length - at - 12)
        throw const FormatException('Truncated PNG chunk');
      if (type == 'IDAT' && size > 0) hasData = true;
      at += size + 12;
      if (type == 'IEND') {
        if (size != 0 || at != bytes.length || !hasData)
          throw const FormatException('Invalid PNG ending');
        return;
      }
    }
    throw const FormatException('Truncated PNG');
  }
  if (bytes.length < 12 ||
      bytes[0] != 255 ||
      bytes[1] != 216 ||
      bytes[2] != 255 ||
      bytes[bytes.length - 2] != 255 ||
      bytes.last != 217)
    throw const FormatException('Image signature is not JPEG');
  var at = 2;
  while (at + 4 <= bytes.length) {
    if (bytes[at] != 255) throw const FormatException('Invalid JPEG marker');
    while (at < bytes.length && bytes[at] == 255) {
      at++;
    }
    if (at >= bytes.length) break;
    final marker = bytes[at++];
    if (marker == 218 || marker == 217) break;
    if (marker == 1 || (marker >= 208 && marker <= 215)) continue;
    if (at + 2 > bytes.length) break;
    final size = (bytes[at] << 8) | bytes[at + 1];
    if (size < 2 || at + size > bytes.length)
      throw const FormatException('Truncated JPEG segment');
    if ([
      192,
      193,
      194,
      195,
      197,
      198,
      199,
      201,
      202,
      203,
      205,
      206,
      207,
    ].contains(marker)) {
      if (size < 8) throw const FormatException('Invalid JPEG frame');
      _dimensions(
        (bytes[at + 5] << 8) | bytes[at + 6],
        (bytes[at + 3] << 8) | bytes[at + 4],
      );
      return;
    }
    at += size;
  }
  throw const FormatException('JPEG frame dimensions missing');
}

/// Optional real raster decode, suitable for validating user-picked images after
/// structural/dimension bounds. It never changes embedded bytes or mask positions.
RecallImage decodeRecallImage(Object? value) {
  final valid = RecallImage.fromJson(value),
      bytes = base64Decode(
        valid.dataUri.substring(valid.dataUri.indexOf(',') + 1),
      ),
      decoded = image.decodeImage(bytes, frame: 0);
  if (decoded == null)
    throw const FormatException('Image pixels could not be decoded');
  _dimensions(decoded.width, decoded.height);
  return valid;
}
