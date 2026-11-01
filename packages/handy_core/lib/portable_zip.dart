import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Validates the ZIP directory, paths, ranges and declared expansion before
/// bounded inflation. Never writes a path or follows a symlink. Callers supply
/// a strict format-specific path allowlist, not a generic path sanitizer.
Map<String, Uint8List> decodePortableZip(
  Uint8List bytes, {
  required bool Function(String) isAllowedPath,
  int maxEntries = 256,
  int maxEntryBytes = 12000000,
  int maxTotalBytes = 30000000,
}) {
  if (maxEntries < 1 ||
      maxEntries > 1000 ||
      maxEntryBytes < 1 ||
      maxTotalBytes < 22 ||
      maxTotalBytes > 30000000) {
    throw ArgumentError('Invalid portable ZIP limits');
  }
  try {
    return _decode(
      bytes,
      isAllowedPath,
      maxEntries,
      maxEntryBytes,
      maxTotalBytes,
    );
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Malformed portable ZIP');
  }
}

Map<String, Uint8List> _decode(
  Uint8List bytes,
  bool Function(String) isAllowedPath,
  int maxEntries,
  int maxEntryBytes,
  int maxTotalBytes,
) {
  final headers = _preflight(
        bytes,
        isAllowedPath,
        maxEntries,
        maxEntryBytes,
        maxTotalBytes,
      ),
      files = <String, Uint8List>{};
  for (final h in headers) {
    final compressed = Uint8List.sublistView(
      bytes,
      h.start,
      h.start + h.compressed,
    );
    final data = h.method == 0
        ? Uint8List.fromList(compressed)
        : const ZLibDecoder().decodeBytes(
            compressed,
            raw: true,
            maxOutputSize: h.size,
          );
    if (data.length != h.size || getCrc32(data) != h.crc)
      throw const FormatException('ZIP asset length/checksum mismatch');
    files[h.name] = data;
  }
  return files;
}

class _ZipHeader {
  final String name;
  final int size, crc, start, compressed, method;
  const _ZipHeader(
    this.name,
    this.size,
    this.crc,
    this.start,
    this.compressed,
    this.method,
  );
}

List<_ZipHeader> _preflight(
  Uint8List bytes,
  bool Function(String) isAllowedPath,
  int maxEntries,
  int maxEntryBytes,
  int maxTotalBytes,
) {
  if (bytes.length < 22 || bytes.length > maxTotalBytes)
    throw const FormatException('Invalid ZIP size');
  final d = ByteData.sublistView(bytes);
  int u16(int at) => d.getUint16(at, Endian.little);
  int u32(int at) => d.getUint32(at, Endian.little);
  var end = -1;
  for (
    var at = bytes.length - 22;
    at >= 0 && at >= bytes.length - 65557;
    at--
  ) {
    if (u32(at) == 0x06054b50 && at + 22 + u16(at + 20) == bytes.length) {
      end = at;
      break;
    }
  }
  if (end < 0 ||
      u16(end + 4) != 0 ||
      u16(end + 6) != 0 ||
      u16(end + 8) != u16(end + 10))
    throw const FormatException('Invalid ZIP directory');
  final count = u16(end + 10), size = u32(end + 12), start = u32(end + 16);
  if (count < 1 ||
      count > maxEntries ||
      start + size != end ||
      size == 0xffffffff ||
      start == 0xffffffff)
    throw const FormatException('Unsupported ZIP count or ZIP64');
  var at = start, total = 0;
  final result = <_ZipHeader>[], names = <String>{}, ranges = <(int, int)>[];
  for (var i = 0; i < count; i++) {
    if (at + 46 > end || u32(at) != 0x02014b50)
      throw const FormatException('Invalid ZIP entry header');
    final flags = u16(at + 8),
        method = u16(at + 10),
        crc = u32(at + 16),
        compressed = u32(at + 20),
        expanded = u32(at + 24),
        nameLength = u16(at + 28),
        extra = u16(at + 30),
        comment = u16(at + 32),
        attributes = u32(at + 38),
        local = u32(at + 42);
    if (u16(at + 34) != 0)
      throw const FormatException('Multi-disk ZIP entries unsupported');
    if (flags & 0x41 != 0 ||
        ![0, 8].contains(method) ||
        expanded == 0xffffffff ||
        compressed == 0xffffffff ||
        local == 0xffffffff ||
        expanded > maxEntryBytes ||
        compressed == 0 && expanded > 0 ||
        expanded > compressed * 200 + 1000 ||
        (attributes >> 16) & 0xf000 == 0xa000 ||
        at + 46 + nameLength + extra + comment > end)
      throw const FormatException('Unsafe, encrypted or oversized ZIP entry');
    final name = utf8.decode(
      bytes.sublist(at + 46, at + 46 + nameLength),
      allowMalformed: false,
    );
    if (!isAllowedPath(name) || !names.add(name))
      throw const FormatException('Unsafe or duplicate ZIP path');
    total += expanded;
    if (total > maxTotalBytes)
      throw const FormatException('ZIP expansion exceeds budget');
    if (local + 30 > start ||
        u32(local) != 0x04034b50 ||
        u16(local + 6) != flags ||
        u16(local + 8) != method)
      throw const FormatException('ZIP local header mismatch');
    final localName = u16(local + 26),
        localExtra = u16(local + 28),
        dataStart = local + 30 + localName + localExtra;
    if (dataStart + compressed > start ||
        utf8.decode(
              bytes.sublist(local + 30, local + 30 + localName),
              allowMalformed: false,
            ) !=
            name)
      throw const FormatException('ZIP local path or range mismatch');
    if (ranges.any((r) => local < r.$2 && dataStart + compressed > r.$1))
      throw const FormatException('Overlapping ZIP entries');
    ranges.add((local, dataStart + compressed));
    result.add(_ZipHeader(name, expanded, crc, dataStart, compressed, method));
    at += 46 + nameLength + extra + comment;
  }
  if (at != end) throw const FormatException('ZIP directory length mismatch');
  return result;
}
