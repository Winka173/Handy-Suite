import 'dart:typed_data';
import 'src/blobs_stub.dart'
    if (dart.library.io) 'src/blobs_io.dart'
    if (dart.library.js_interop) 'src/blobs_web.dart'
    as implementation;

/// Bytes kept beside an app's document (photos, receipts), one entry per id,
/// so the document itself stays small. Each entry is checked by SHA-256 when
/// read back. Ids are the app's own virtual file ids, never OS paths.
abstract interface class BlobRepository {
  Future<Uint8List?> read(String id);

  /// Writes [bytes] and reads them back before returning.
  Future<void> write(String id, Uint8List bytes);
  Future<void> delete(String id);
  Future<Set<String>> ids();
}

const blobMaxBytes = 25000000;

void checkBlobId(String id) {
  if (id.isEmpty || id.length > 300 || RegExp(r'[\x00-\x1f]').hasMatch(id))
    throw ArgumentError('Invalid blob id');
}

BlobRepository localBlobs(String namespace) {
  if (!RegExp(r'^handy-[a-z-]{1,40}$').hasMatch(namespace))
    throw ArgumentError('Invalid blob store namespace');
  return implementation.createBlobs(namespace);
}

/// In memory, for tests and for platforms without local storage.
class MemoryBlobs implements BlobRepository {
  final entries = <String, Uint8List>{};
  bool failWrites = false;
  @override
  Future<Uint8List?> read(String id) async => entries[id];
  @override
  Future<void> write(String id, Uint8List bytes) async {
    checkBlobId(id);
    if (failWrites) throw StateError('Disk full');
    entries[id] = Uint8List.fromList(bytes);
  }

  @override
  Future<void> delete(String id) async => entries.remove(id);
  @override
  Future<Set<String>> ids() async => entries.keys.toSet();
}
