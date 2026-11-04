import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/documents.dart';

const readerExtensions = [
  'txt', 'md', 'markdown', 'html', 'htm', 'json', 'yaml', 'yml', 'xml', //
  'csv', 'js', 'ts', 'dart', 'py', 'kt', 'swift', 'css', 'sql', 'toml',
  'ini', 'log', 'sh',
];

/// The reading library: local copies of text files, and the one document
/// open now. An opened file is only read until the person saves a copy;
/// every change is written first and shown after.
class ReaderStore extends ChangeNotifier {
  /// As many as the 8 MB library holds, up to this many.
  static const maxDocuments = readerDocumentLimit;
  final DocumentRepository documents;
  ReaderStore(this.documents);

  ReaderLibrary? library;
  Object? error;

  /// The document being read, and whether the library holds it.
  ReaderDocument? current;
  bool saved = false;

  List<ReaderDocument> get recent =>
      [...?library?.documents]
        ..sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));

  List<String> get folders => {
    for (final d in library?.documents ?? const <ReaderDocument>[])
      if (d.folder.isNotEmpty) d.folder,
  }.toList()..sort();

  Future<void> load() async {
    error = null;
    try {
      final raw = await documents.load();
      library = raw == null ? ReaderLibrary([]) : ReaderLibrary.parse(raw);
      current = null;
      saved = false;
    } catch (e) {
      error = e;
    }
    notifyListeners();
  }

  Future<void> commit(ReaderLibrary next) async {
    await documents.save(next.serialize());
    library = next;
    if (saved && current != null) {
      final match = next.documents.where((d) => d.id == current!.id);
      if (match.isNotEmpty) {
        current = match.single;
      } else {
        current = null;
        saved = false;
      }
    }
    notifyListeners();
  }

  /// Reads a picked file as UTF-8; a file that is not text is refused.
  static ReaderDocument read(ImportedBytes file) {
    final now = DateTime.now().toUtc().toIso8601String();
    return ReaderDocument.parse(
      ReaderDocument(
        id: 'doc-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}',
        name: safeFilename(file.name),
        kind: readerKind(file.name),
        source: readerUtf8(file.bytes),
        createdAt: now,
        lastOpenedAt: now,
      ).toJson(),
    );
  }

  void show(ReaderDocument document) {
    current = document;
    saved = false;
    notifyListeners();
  }

  void close() {
    current = null;
    saved = false;
    notifyListeners();
  }

  /// Every file is read and the whole library checked before anything is
  /// written; one bad file leaves the library as it was.
  ReaderLibrary withAll(List<ImportedBytes> files) {
    if (files.length + library!.documents.length > maxDocuments) {
      throw const FormatException(
        'Document limit: 500; remove local copies or split the batch / Tối đa 500 tài liệu; hãy xoá bớt bản đã lưu hoặc chia nhỏ lô',
      );
    }
    return ReaderLibrary([...library!.documents, ...files.map(read)]);
  }

  Future<void> open(ReaderDocument entry) async {
    final next = entry.copyWith(
      opened: DateTime.now().toUtc().toIso8601String(),
    );
    await commit(library!.save(next));
    current = next;
    saved = true;
    notifyListeners();
  }

  Future<void> keep() async {
    await commit(library!.save(current!));
    saved = true;
    notifyListeners();
  }

  Future<void> change(ReaderDocument next) async {
    if (library!.documents.any((d) => d.id == next.id)) {
      await commit(library!.save(next));
    }
    if (current?.id == next.id) {
      current = next;
      notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    await commit(library!.remove(id));
    if (current?.id == id) close();
  }

  Uint8List backup() => readerZip(library!);

  Uint8List source(ReaderDocument d) =>
      Uint8List.fromList(utf8.encode(d.source));
}
