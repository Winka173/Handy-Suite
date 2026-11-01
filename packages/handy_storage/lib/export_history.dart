import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'documents.dart';

class ExportHistoryEntry {
  final String id, tool, at, uri, mime;
  final String? checksum;
  final int? bytes;
  const ExportHistoryEntry({
    required this.id,
    required this.tool,
    required this.at,
    required this.uri,
    required this.mime,
    this.checksum,
    this.bytes,
  });
  factory ExportHistoryEntry.parse(dynamic raw) {
    if (raw is! Map ||
        raw.keys.any(
          (k) => !{
            'id',
            'tool',
            'at',
            'uri',
            'mime',
            'checksum',
            'bytes',
          }.contains(k),
        ))
      throw const FormatException('Invalid export history entry');
    String text(String key, int max) {
      final v = raw[key];
      if (v is! String ||
          v.isEmpty ||
          v.length > max ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(v))
        throw const FormatException('Invalid export history metadata');
      return v;
    }

    final id = text('id', 100),
        tool = text('tool', 100),
        at = text('at', 40),
        uri = text('uri', 2048),
        mime = text('mime', 100);
    final stamp = DateTime.tryParse(at);
    if (stamp == null ||
        !at.endsWith('Z') ||
        stamp.year < 1970 ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id) ||
        !RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(tool) ||
        !RegExp(r'^[a-z0-9!#$&^_.+-]+/[a-z0-9!#$&^_.+-]+$').hasMatch(mime))
      throw const FormatException('Invalid history date/tool/type');
    final parsed = Uri.tryParse(uri);
    if (parsed == null ||
        parsed.hasQuery ||
        parsed.hasFragment ||
        (parsed.hasScheme &&
            !{
              'file',
              'content',
              'blob',
              'download',
              'history',
            }.contains(parsed.scheme)))
      throw const FormatException(
        'History destination must be a local file reference',
      );
    final hash = raw['checksum'], length = raw['bytes'];
    if ((hash == null) != (length == null) ||
        hash != null &&
            (hash is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) ||
        length != null && (length is! int || length < 0 || length > 30000000))
      throw const FormatException('Invalid history file fingerprint');
    return ExportHistoryEntry(
      id: id,
      tool: tool,
      at: at,
      uri: uri,
      mime: mime,
      checksum: hash as String?,
      bytes: length as int?,
    );
  }
  Map<String, Object?> toJson() => {
    'id': id,
    'tool': tool,
    'at': at,
    'uri': uri,
    'mime': mime,
    if (checksum != null) 'checksum': checksum,
    if (bytes != null) 'bytes': bytes,
  };
  bool matches(Uint8List data) =>
      checksum == null ||
      data.length == bytes && sha256.convert(data).toString() == checksum;
}

List<ExportHistoryEntry> parseExportHistory(String text) {
  if (utf8.encode(text).length > 200000)
    throw const FormatException('History limit: 200 KB');
  final raw = jsonDecode(text);
  final dynamic values;
  if (raw is Map &&
      raw['version'] == 1 &&
      raw['format'] == 'handy-export-history') {
    values = raw['entries'];
  } else if (raw is Map && raw['version'] == 1 && raw['history'] is List) {
    values = raw['history'];
  } else {
    throw const FormatException('Unsupported export history backup');
  }
  if (values is! List || values.length > 50)
    throw const FormatException('History limit: 50 entries');
  final entries = values.map(ExportHistoryEntry.parse).toList();
  if (entries.map((e) => e.id).toSet().length != entries.length)
    throw const FormatException('Duplicate history IDs');
  return List.unmodifiable(entries);
}

String serializeExportHistory(List<ExportHistoryEntry> entries) {
  final text = jsonEncode({
    'format': 'handy-export-history',
    'version': 1,
    'entries': entries.map((e) => e.toJson()).toList(),
  });
  parseExportHistory(text);
  return text;
}

class ExportHistory {
  final DocumentRepository documents;
  ExportHistory(String app, {DocumentRepository? documents})
    : documents =
          documents ?? localDocuments('handy-$app-exports', maxBytes: 200000) {
    if (!RegExp(r'^[a-z]+$').hasMatch(app))
      throw ArgumentError('Invalid app history namespace');
  }
  Future<void> _pending = Future.value();
  Future<T> _serial<T>(Future<T> Function() work) {
    final next = _pending.catchError((_) {}).then((_) => work());
    _pending = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<List<ExportHistoryEntry>> load() async {
    final raw = await documents.load();
    return raw == null ? [] : parseExportHistory(raw);
  }

  Future<void> record({
    required String tool,
    required String uri,
    required String mime,
    required Uint8List data,
  }) => _serial(() async {
    final entry = ExportHistoryEntry.parse({
      'id':
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}',
      'tool': tool,
      'at': DateTime.now().toUtc().toIso8601String(),
      'uri': uri,
      'mime': mime,
      'checksum': sha256.convert(data).toString(),
      'bytes': data.length,
    });
    final old = await load();
    await documents.save(
      serializeExportHistory(
        [entry, ...old.where((e) => e.uri != uri)].take(50).toList(),
      ),
    );
  });
  Future<void> remove(String id) => _serial(() async {
    final old = await load();
    await documents.save(
      serializeExportHistory(old.where((e) => e.id != id).toList()),
    );
  });
  Future<void> restore(String text) => _serial(() async {
    await documents.save(serializeExportHistory(parseExportHistory(text)));
  });
  Future<void> clear() => restore(serializeExportHistory([]));
}
