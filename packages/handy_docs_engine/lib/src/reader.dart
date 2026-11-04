import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:handy_core/portable_zip.dart';
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;

const readerKinds = {'text', 'markdown', 'html', 'code'};
String readerUtf8(Uint8List bytes) {
  if (bytes.length > 1000000)
    throw const FormatException('Reader source limit: 1 MB');
  final source = utf8.decode([32, ...bytes]).substring(1);
  if (RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]').hasMatch(source))
    throw const FormatException(
      'Text document contains unsupported control bytes',
    );
  return source;
}

String readerKind(String name) {
  final extension = name.split('.').last.toLowerCase();
  return {'md', 'markdown'}.contains(extension)
      ? 'markdown'
      : {'html', 'htm'}.contains(extension)
      ? 'html'
      : {
          'json',
          'yaml',
          'yml',
          'xml',
          'csv',
          'js',
          'ts',
          'dart',
          'py',
          'kt',
          'swift',
          'css',
          'sql',
          'toml',
          'ini',
          'log',
          'sh',
        }.contains(extension)
      ? 'code'
      : 'text';
}

class ReaderDocument {
  final String id, name, kind, source, folder, createdAt, lastOpenedAt;
  final bool favorite;
  const ReaderDocument({
    required this.id,
    required this.name,
    required this.kind,
    required this.source,
    required this.createdAt,
    required this.lastOpenedAt,
    this.folder = '',
    this.favorite = false,
  });
  factory ReaderDocument.parse(dynamic raw) {
    if (raw is! Map ||
        raw.keys.any(
          (k) => !{
            'id',
            'name',
            'kind',
            'source',
            'folder',
            'favorite',
            'createdAt',
            'lastOpenedAt',
          }.contains(k),
        ))
      throw const FormatException('Invalid reader document');
    String text(String key, int limit, {bool empty = false}) {
      final value = raw[key];
      if (value is! String ||
          value.length > limit ||
          !empty && value.isEmpty ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(value))
        throw const FormatException('Invalid reader metadata');
      return value;
    }

    final id = text('id', 100),
        name = text('name', 200),
        kind = text('kind', 20),
        folder = text('folder', 100, empty: true);
    final created = text('createdAt', 40), opened = text('lastOpenedAt', 40);
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id) ||
        !readerKinds.contains(kind) ||
        raw['favorite'] is! bool ||
        [
          created,
          opened,
        ].any((s) => !s.endsWith('Z') || DateTime.tryParse(s) == null) ||
        raw['source'] is! String)
      throw const FormatException('Invalid reader identity/date/kind');
    final source = raw['source'] as String;
    if (readerUtf8(Uint8List.fromList(utf8.encode(source))) != source)
      throw const FormatException('Reader source must be valid Unicode');
    return ReaderDocument(
      id: id,
      name: name,
      kind: kind,
      source: source,
      folder: folder,
      favorite: raw['favorite'],
      createdAt: created,
      lastOpenedAt: opened,
    );
  }
  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'kind': kind,
    'source': source,
    'folder': folder,
    'favorite': favorite,
    'createdAt': createdAt,
    'lastOpenedAt': lastOpenedAt,
  };
  ReaderDocument copyWith({
    String? name,
    String? folder,
    bool? favorite,
    String? opened,
  }) => ReaderDocument.parse({
    ...toJson(),
    if (name != null) 'name': name,
    if (folder != null) 'folder': folder,
    if (favorite != null) 'favorite': favorite,
    if (opened != null) 'lastOpenedAt': opened,
  });
}

/// Kept documents: as many as fit in 8 MB, at most [readerDocumentLimit].
/// Version 1 allowed 50; a library with more is written as version 2, so
/// an older app refuses it plainly instead of reading part of it.
const readerDocumentLimit = 500;

class ReaderLibrary {
  final List<ReaderDocument> documents;
  ReaderLibrary(Iterable<ReaderDocument> input)
    : documents = List.unmodifiable(input) {
    if (documents.length > readerDocumentLimit ||
        documents.map((d) => d.id).toSet().length != documents.length)
      throw const FormatException('Reader limit: 500 unique documents');
    for (final document in documents) ReaderDocument.parse(document.toJson());
    if (utf8.encode(jsonEncode(toJson())).length > 8000000)
      throw const FormatException('Reader library limit: 8 MB');
  }
  Map<String, Object> toJson() => {
    'format': 'handy-reader-library',
    'version': documents.length > 50 ? 2 : 1,
    'documents': documents.map((d) => d.toJson()).toList(),
  };
  String serialize() => jsonEncode(toJson());
  factory ReaderLibrary.parse(String text) {
    if (utf8.encode(text).length > 8000000)
      throw const FormatException('Reader library limit: 8 MB');
    final raw = jsonDecode(text);
    if (raw is! Map ||
        raw['format'] != 'handy-reader-library' ||
        (raw['version'] != 1 && raw['version'] != 2) ||
        raw['documents'] is! List)
      throw const FormatException('Unsupported reader library');
    return ReaderLibrary((raw['documents'] as List).map(ReaderDocument.parse));
  }
  ReaderLibrary save(ReaderDocument document) =>
      ReaderLibrary([document, ...documents.where((d) => d.id != document.id)]);
  ReaderLibrary remove(String id) =>
      ReaderLibrary(documents.where((d) => d.id != id));
}

Uint8List readerZip(ReaderLibrary library) {
  final archive = Archive(), entries = <Map<String, Object>>[];
  var total = 0;
  for (var i = 0; i < library.documents.length; i++) {
    final document = library.documents[i],
        bytes = utf8.encode(document.source),
        path = 'documents/$i.txt';
    total += bytes.length;
    if (total > 8000000) throw const FormatException('Reader ZIP exceeds 8 MB');
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
    entries.add({
      ...document.toJson()..remove('source'),
      'path': path,
      'bytes': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
    });
  }
  final manifest = utf8.encode(
    jsonEncode({
      'format': 'handy-reader-pack',
      // Version 2 only when it holds more than version 1 allowed.
      'version': library.documents.length > 50 ? 2 : 1,
      'documents': entries,
    }),
  );
  archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
  final bytes = Uint8List.fromList(ZipEncoder().encodeBytes(archive, level: 0));
  if (bytes.length > 9000000)
    throw const FormatException('Reader ZIP exceeds 9 MB');
  if (readReaderZip(bytes).serialize() != library.serialize())
    throw const FormatException('Reader ZIP roundtrip failed');
  return bytes;
}

ReaderLibrary readReaderZip(Uint8List bytes) {
  final files = decodePortableZip(
    bytes,
    isAllowedPath: (s) =>
        s == 'manifest.json' ||
        RegExp(r'^documents/[0-9]{1,3}\.txt$').hasMatch(s),
    maxEntries: readerDocumentLimit + 1,
    maxEntryBytes: 1000000,
    maxTotalBytes: 9000000,
  );
  final manifest = files['manifest.json'];
  if (manifest == null || manifest.length > 1000000)
    throw const FormatException('Reader manifest missing/oversized');
  final raw = jsonDecode(utf8.decode(manifest));
  if (raw is! Map ||
      raw['format'] != 'handy-reader-pack' ||
      (raw['version'] != 1 && raw['version'] != 2) ||
      raw['documents'] is! List ||
      raw['documents'].length > readerDocumentLimit ||
      files.length != raw['documents'].length + 1)
    throw const FormatException('Invalid reader pack');
  final documents = <ReaderDocument>[];
  for (var i = 0; i < (raw['documents'] as List).length; i++) {
    final entry = raw['documents'][i],
        path = 'documents/$i.txt',
        content = files[path];
    if (entry is! Map ||
        entry['path'] != path ||
        content == null ||
        entry['bytes'] != content.length ||
        entry['sha256'] != sha256.convert(content).toString())
      throw const FormatException('Reader pack integrity failure');
    final metadata = Map<String, dynamic>.from(entry)
      ..remove('path')
      ..remove('bytes')
      ..remove('sha256');
    documents.add(
      ReaderDocument.parse({...metadata, 'source': readerUtf8(content)}),
    );
  }
  return ReaderLibrary(documents);
}

String readableHtml(String source) {
  if (utf8.encode(source).length > 100000)
    throw const FormatException(
      'HTML reading limit: 100 KB; use source view for larger files',
    );
  // Bound tokenizer/DOM work before parsing and traversal after parsing.
  if ('<'.allMatches(source).length > 10000)
    throw const FormatException('HTML markup limit exceeded');
  final document = html.parse(source), output = StringBuffer();
  var count = 0;
  void walk(dom.Node node, int depth) {
    if (++count > 20000 || depth > 60)
      throw const FormatException('HTML structure limit exceeded');
    if (node is dom.Text) {
      output.write(node.data);
      return;
    }
    if (node is! dom.Element && node is! dom.Document) return;
    final tag = node is dom.Element ? node.localName : '';
    if ({
      'script',
      'style',
      'noscript',
      'template',
      'iframe',
      'object',
      'embed',
      'svg',
      'math',
      'img',
      'audio',
      'video',
      'form',
      'input',
      'button',
    }.contains(tag))
      return;
    final block = {
      'p',
      'div',
      'section',
      'article',
      'header',
      'footer',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'pre',
      'li',
      'tr',
      'blockquote',
      'br',
      'hr',
    }.contains(tag);
    if (block) output.write('\n');
    for (final child in node.nodes) walk(child, depth + 1);
    if (block) output.write('\n');
    if (tag == 'td' || tag == 'th') output.write('\t');
  }

  walk(document.body ?? document, 0);
  return output.toString().trim();
}

/// True for names the Markdown writer opens (`.md`, `.markdown`).
bool isMarkdownName(String name) => readerKind(name) == 'markdown';

const _fenceLanguages = {
  'js': 'javascript',
  'ts': 'typescript',
  'py': 'python',
  'kt': 'kotlin',
  'sh': 'bash',
  'yml': 'yaml',
};

/// An editable Markdown copy of a document that opened read-only: text as
/// it is, a web page as its readable text, code in a fenced block that no
/// backtick run inside it can close. The source is never changed.
String markdownCopyOf(ReaderDocument document) {
  switch (document.kind) {
    case 'markdown':
    case 'text':
      return document.source;
    case 'html':
      try {
        return '# ${document.name}\n\n${readableHtml(document.source)}\n';
      } on FormatException {
        // Too large to read as a page: keep the markup, fenced.
        return _fenced(document, 'html');
      }
    default:
      final extension = document.name.split('.').last.toLowerCase();
      return _fenced(document, _fenceLanguages[extension] ?? extension);
  }
}

String _fenced(ReaderDocument document, String language) {
  final longest = RegExp('`+')
      .allMatches(document.source)
      .fold<int>(0, (n, m) => m.group(0)!.length > n ? m.group(0)!.length : n);
  final fence = '`' * (longest < 3 ? 3 : longest + 1);
  final body = document.source.endsWith('\n')
      ? document.source
      : '${document.source}\n';
  return '# ${document.name}\n\n$fence$language\n$body$fence\n';
}
