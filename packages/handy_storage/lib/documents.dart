import 'dart:typed_data';
import 'src/documents_stub.dart'
    if (dart.library.io) 'src/documents_io.dart'
    if (dart.library.js_interop) 'src/documents_web.dart'
    as implementation;

abstract interface class DocumentRepository {
  Future<String?> load();
  Future<void> save(String text);
}

class PreservedDocuments {
  final String id;
  final DateTime createdAt;
  const PreservedDocuments(this.id, this.createdAt);
}

/// Optional recovery capability. Reset always preserves old bytes first.
abstract interface class RecoverableDocuments implements DocumentRepository {
  Future<List<PreservedDocuments>> preserved();
  Future<PreservedDocuments> preserveAndReset();
  Future<Uint8List> exportPreserved(String id);
  Future<void> undoReset(String id);
}

DocumentRepository localDocuments(String namespace, {int maxBytes = 16000000}) {
  if (!RegExp(r'^handy-[a-z-]{1,40}$').hasMatch(namespace) ||
      maxBytes < 1 ||
      maxBytes > 30000000)
    throw ArgumentError('Invalid document store configuration');
  return implementation.createDocuments(namespace, maxBytes);
}
