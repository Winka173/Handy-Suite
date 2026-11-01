import 'dart:convert';
import 'dart:typed_data';

class ExifInspection {
  final Map<String, String> tags;
  final double? latitude, longitude;
  final bool hasGps;
  ExifInspection(
    Map<String, String> tags,
    this.latitude,
    this.longitude,
    this.hasGps,
  ) : tags = Map.unmodifiable(tags);
}

/// Bounded TIFF/EXIF reader; never follows external paths or executes metadata.
ExifInspection inspectExifTiff(Uint8List bytes) {
  if (bytes.length < 8 || bytes.length > 262144)
    throw const FormatException('EXIF size outside verified 256 KB budget');
  final data = ByteData.sublistView(bytes),
      order = bytes[0] == 73 && bytes[1] == 73
          ? Endian.little
          : bytes[0] == 77 && bytes[1] == 77
          ? Endian.big
          : null;
  if (order == null) throw const FormatException('Invalid EXIF byte order');
  void range(int at, int count) {
    if (at < 0 || count < 0 || at + count > bytes.length)
      throw const FormatException('EXIF offset outside payload');
  }

  int u16(int at) {
    range(at, 2);
    return data.getUint16(at, order);
  }

  int u32(int at) {
    range(at, 4);
    return data.getUint32(at, order);
  }

  if (u16(2) != 42) throw const FormatException('Unsupported TIFF version');
  final tags = <String, String>{}, gps = <int, Object>{}, visited = <int>{};
  var entries = 0, hasGps = false;
  const sizes = {
    1: 1,
    2: 1,
    3: 2,
    4: 4,
    5: 8,
    6: 1,
    7: 1,
    8: 2,
    9: 4,
    10: 8,
    11: 4,
    12: 8,
    13: 4,
  };
  Object value(int entry, int type, int count) {
    final size = sizes[type];
    if (size == null)
      throw const FormatException('Unsupported EXIF field type');
    if (count < 1 || count > 65536)
      throw const FormatException('EXIF value count outside budget');
    final length = size * count, at = length <= 4 ? entry + 8 : u32(entry + 8);
    range(at, length);
    if (type == 2)
      return latin1
          .decode(bytes.sublist(at, at + length))
          .replaceAll(RegExp(r'\x00+$'), '')
          .replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ');
    if (type == 7) {
      final shown = bytes
          .sublist(at, at + (length > 64 ? 64 : length))
          .map((n) => n.toRadixString(16).padLeft(2, '0'))
          .join();
      return '$shown${length > 64 ? '… ($length bytes)' : ''}';
    }
    final result = <num>[];
    if (count > 4096)
      throw const FormatException('EXIF numeric array outside budget');
    for (var i = 0; i < count; i++) {
      final pos = at + i * size;
      final num number;
      switch (type) {
        case 1:
          number = data.getUint8(pos);
        case 3:
          number = u16(pos);
        case 4 || 13:
          number = u32(pos);
        case 6:
          number = data.getInt8(pos);
        case 8:
          number = data.getInt16(pos, order);
        case 9:
          number = data.getInt32(pos, order);
        case 5 || 10:
          final a = type == 5 ? u32(pos) : data.getInt32(pos, order),
              b = type == 5 ? u32(pos + 4) : data.getInt32(pos + 4, order);
          if (b == 0)
            throw const FormatException('EXIF rational division by zero');
          number = a / b;
        case 11:
          number = data.getFloat32(pos, order);
        case 12:
          number = data.getFloat64(pos, order);
        default:
          throw const FormatException('Unsupported EXIF field');
      }
      if (!number.isFinite)
        throw const FormatException('EXIF nonfinite number');
      result.add(number);
    }
    return count == 1 ? result.single : List<num>.unmodifiable(result);
  }

  const names = {
    0x010e: 'Description',
    0x010f: 'Make',
    0x0110: 'Model',
    0x0112: 'Orientation',
    0x0131: 'Software',
    0x0132: 'DateTime',
    0x013b: 'Artist',
    0x8298: 'Copyright',
    0x829a: 'ExposureTime',
    0x829d: 'FNumber',
    0x8827: 'ISO',
    0x9003: 'DateTimeOriginal',
    0x9004: 'DateTimeDigitized',
    0x920a: 'FocalLength',
    0xa002: 'PixelXDimension',
    0xa003: 'PixelYDimension',
    0xa434: 'LensModel',
  };
  const gpsNames = {
    0: 'Version',
    1: 'LatitudeRef',
    2: 'Latitude',
    3: 'LongitudeRef',
    4: 'Longitude',
    5: 'AltitudeRef',
    6: 'Altitude',
    7: 'TimeStamp',
    29: 'DateStamp',
  };
  void directory(int offset, String name, int depth) {
    if (offset == 0) return;
    if (depth > 4 || !visited.add(offset))
      throw const FormatException('Cyclic or too-deep EXIF directories');
    final count = u16(offset);
    entries += count;
    if (count > 256 || entries > 512)
      throw const FormatException('EXIF directory entry limit');
    range(offset + 2, count * 12 + 4);
    final ids = <int>{};
    for (var i = 0; i < count; i++) {
      final entry = offset + 2 + i * 12,
          id = u16(entry),
          type = u16(entry + 2),
          amount = u32(entry + 4);
      if (!ids.add(id)) throw const FormatException('Duplicate EXIF tag');
      final decoded = value(entry, type, amount);
      if ([0x8769, 0x8825, 0xa005].contains(id)) {
        if (type != 4 || amount != 1 || decoded is! int)
          throw const FormatException('Invalid EXIF directory pointer');
        final child = id == 0x8825
            ? 'GPS'
            : id == 0x8769
            ? 'EXIF'
            : 'Interop';
        if (child == 'GPS') hasGps = true;
        directory(decoded, child, depth + 1);
        continue;
      }
      if (name == 'GPS') gps[id] = decoded;
      final tag = name == 'GPS' ? gpsNames[id] : names[id],
          key = '$name.${tag ?? '0x${id.toRadixString(16).padLeft(4, '0')}'}';
      final display = decoded is List ? decoded.join(', ') : decoded.toString();
      tags[key] = display.length > 1024
          ? '${display.substring(0, 1024)}…'
          : display;
    }
    final next = u32(offset + 2 + count * 12);
    if (next != 0) directory(next, '$name.next', depth + 1);
  }

  directory(u32(4), 'IFD0', 0);
  double? coordinate(
    int id,
    int ref,
    double limit,
    String positive,
    String negative,
  ) {
    final v = gps[id], r = gps[ref];
    if (v == null && r == null) return null;
    if (v is! List<num> ||
        v.length != 3 ||
        r is! String ||
        ![positive, negative].contains(r) ||
        v[0] < 0 ||
        v[1] < 0 ||
        v[1] >= 60 ||
        v[2] < 0 ||
        v[2] >= 60)
      throw const FormatException('Invalid EXIF GPS coordinates');
    final n = v[0] + v[1] / 60 + v[2] / 3600;
    if (!n.isFinite || n > limit)
      throw const FormatException('GPS coordinates outside range');
    return (r == negative ? -n : n).toDouble();
  }

  return ExifInspection(
    tags,
    coordinate(2, 1, 90, 'N', 'S'),
    coordinate(4, 3, 180, 'E', 'W'),
    hasGps,
  );
}
