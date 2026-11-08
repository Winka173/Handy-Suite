import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

class _ImportRecords extends BoardsSnapshotMap<BoardRecord> {
  final Map<String, BoardRecord> valuesById;
  _ImportRecords(Iterable<BoardRecord> records)
    : valuesById = Map.unmodifiable({for (final r in records) r.id: r});
  @override
  String get storageIdentity => 'import/${identityHashCode(this)}';
  @override
  int get snapshotRevision => 0;
  @override
  Iterable<String> get keys => valuesById.keys;
  @override
  BoardRecord? operator [](Object? key) => valuesById[key];
  @override
  Set<String> changedKeysCompared(BoardsSnapshotMap<BoardRecord> other) => {
    ...keys,
    ...other.keys,
  };
  @override
  void operator []=(String key, BoardRecord value) =>
      throw UnsupportedError('Immutable import');
  @override
  BoardRecord? remove(Object? key) =>
      throw UnsupportedError('Immutable import');
  @override
  void clear() => throw UnsupportedError('Immutable import');
}

class _ImportAssets extends BoardsAssetMap {
  final String directory;
  @override
  final Map<String, Json> descriptors;
  _ImportAssets(this.directory, Map<String, Json> descriptors)
    : descriptors = Map.unmodifiable(descriptors);
  @override
  String get storageIdentity => directory;
  @override
  int get snapshotRevision => 0;
  @override
  Iterable<String> get keys => descriptors.keys;
  @override
  Uint8List? operator [](Object? key) => descriptors.containsKey(key)
      ? File('$directory/$key').readAsBytesSync()
      : null;
  @override
  Future<Uint8List> readAsset(String key) async {
    if (!descriptors.containsKey(key))
      throw const FormatException('Missing asset');
    final bytes = await File('$directory/$key').readAsBytes();
    if (bytes.length != descriptors[key]!['bytes'] ||
        sha256.convert(bytes).toString() != descriptors[key]!['sha256'])
      throw const FormatException('Attachment checksum mismatch');
    return bytes;
  }

  @override
  Set<String> changedKeysCompared(BoardsSnapshotMap<Uint8List> other) => {
    ...keys,
    ...other.keys,
  };
  @override
  void operator []=(String key, Uint8List value) =>
      throw UnsupportedError('Immutable import');
  @override
  Uint8List? remove(Object? key) => throw UnsupportedError('Immutable import');
  @override
  void clear() => throw UnsupportedError('Immutable import');
}

class _LimitedOutput extends OutputFileStream {
  final int maximum;
  _LimitedOutput(String path, this.maximum)
    : super.withFileHandle(FileHandle(path, mode: FileAccess.write));
  void bound(int n) {
    if (length + n > maximum)
      throw const FormatException('ZIP expansion exceeds declared limit');
  }

  @override
  void writeByte(int b) {
    bound(1);
    super.writeByte(b);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    bound(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    while (!stream.isEOS) {
      writeBytes(stream.readBytes(min(65536, stream.length)).toUint8List());
    }
  }
}

/// Reads/extracts only into a caller-owned fresh private directory. Nothing is
/// applied to the library until the existing review/CAS transaction succeeds.
Future<BoardsState> readStagedBoardsZip(
  String source,
  String directory, {
  void Function(double)? onProgress,
}) async {
  final file = File(source), length = await file.length();
  if (length < 22 || length > 512000000)
    throw const FormatException('ZIP source must be 22 bytes..512 MB');
  final handle = await file.open();
  late Uint8List tail;
  try {
    await handle.setPosition(max(0, length - 65557));
    tail = await handle.read(min(length, 65557));
  } finally {
    await handle.close();
  }
  final data = ByteData.sublistView(tail);
  int? end;
  for (var i = tail.length - 22; i >= 0; i--) {
    if (data.getUint32(i, Endian.little) == 0x06054b50 &&
        i + 22 + data.getUint16(i + 20, Endian.little) == tail.length) {
      end = i;
      break;
    }
  }
  if (end == null ||
      data.getUint16(end + 4, Endian.little) != 0 ||
      data.getUint16(end + 6, Endian.little) != 0 ||
      data.getUint16(end + 8, Endian.little) !=
          data.getUint16(end + 10, Endian.little) ||
      data.getUint16(end + 10, Endian.little) > 10000 ||
      data.getUint32(end + 12, Endian.little) > 8000000)
    throw const FormatException('Unsupported or oversized ZIP directory');
  final stream = InputFileStream(source);
  try {
    final decoder = ZipDecoder(), archive = decoder.decodeStream(stream);
    final centralNames = decoder.directory.fileHeaders
        .map((h) => h.filename)
        .toSet();
    if (centralNames.length != decoder.directory.fileHeaders.length ||
        archive.length != decoder.directory.fileHeaders.length ||
        archive.length != data.getUint16(end + 10, Endian.little))
      throw const FormatException('Unsafe or duplicate ZIP path');
    if (archive.length > 10000)
      throw const FormatException('Backup exceeds 10000 entries');
    final names = <String>{};
    var total = 0;
    for (final entry in archive) {
      final path = entry.name,
          maxBytes = path == 'boards.json'
              ? 100000000
              : path == 'manifest.json'
              ? 2000000
              : 12000000;
      if (!entry.isFile ||
          entry.isSymbolicLink ||
          !names.add(path) ||
          !(path == 'boards.json' ||
              path == 'manifest.json' ||
              RegExp(
                r'^assets/[a-zA-Z0-9_-]{1,120}\.[a-z0-9]{1,8}$',
              ).hasMatch(path)))
        throw const FormatException('Unsafe or duplicate ZIP path');
      total += entry.size;
      if (entry.size < 0 || entry.size > maxBytes || total > 402000000)
        throw const FormatException('ZIP expanded size exceeds bounds');
    }
    for (final header in decoder.directory.fileHeaders) {
      if (header.uncompressedSize > max(1000000, header.compressedSize * 200))
        throw const FormatException('ZIP compression ratio exceeds bounds');
    }
    if (!names.containsAll(['boards.json', 'manifest.json']))
      throw const FormatException('Incomplete backup');
    var index = 0;
    final actual = <String, Json>{};
    for (final entry in archive) {
      final output = File('$directory/${entry.name}');
      await output.parent.create(recursive: true);
      final sink = _LimitedOutput(output.path, entry.size);
      try {
        entry.writeContent(sink);
      } finally {
        sink.closeSync();
      }
      if (await output.length() != entry.size)
        throw const FormatException('ZIP entry size mismatch');
      var crc = 0;
      await for (final bytes in output.openRead()) {
        crc = getCrc32(bytes, crc);
      }
      if (crc != entry.crc32) throw const FormatException('ZIP CRC mismatch');
      actual[entry.name] = {
        'bytes': entry.size,
        'sha256': (await sha256.bind(output.openRead()).first).toString(),
      };
      onProgress?.call(++index / (archive.length + 1));
    }
    final manifest = object(
      jsonDecode(await File('$directory/manifest.json').readAsString()),
    );
    if (manifest['app'] != 'handy-boards' ||
        ![1, 2, 3, 4].contains(manifest['schema']))
      throw const FormatException('Unsupported manifest');
    final checks = object(manifest['files']);
    actual.remove('manifest.json');
    if (checks.length != actual.length ||
        actual.entries.any(
          (e) => jsonEncode(object(checks[e.key])) != jsonEncode(e.value),
        )) {
      // Field order is not significant in a JSON checksum manifest.
      for (final e in actual.entries) {
        final c = object(checks[e.key]);
        if (c['bytes'] != e.value['bytes'] || c['sha256'] != e.value['sha256'])
          throw const FormatException('Backup checksum mismatch');
      }
      if (checks.length != actual.length)
        throw const FormatException('Manifest entry mismatch');
    }
    final j = object(
      jsonDecode(await File('$directory/boards.json').readAsString()),
    );
    if (j['app'] != 'handy-boards' || ![1, 2, 3, 4].contains(j['schema']))
      throw const FormatException('Unsupported Boards schema');
    final records = <String, BoardsSnapshotMap<BoardRecord>>{};
    for (final kind in kinds) {
      final rows = (j[kind] as List? ?? [])
          .map((r) => BoardRecord(object(r)))
          .toList();
      final map = _ImportRecords(rows);
      if (map.length != rows.length)
        throw const FormatException('Duplicate record ID');
      records[kind] = map;
    }
    actual.remove('boards.json');
    final s = BoardsState.fromSnapshot(
      revision: j['revision'] as int? ?? 0,
      data: records,
      files: _ImportAssets(directory, actual),
      preferences: object(j['preferences'] ?? {}),
    );
    s.validate();
    onProgress?.call(1);
    return s;
  } finally {
    await stream.close();
  }
}
