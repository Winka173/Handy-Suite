import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import '../blobs.dart';

BlobRepository createBlobs(String namespace) => FileBlobs(namespace);

/// One file per entry in `<support>/<namespace>-blobs/`, named by the
/// SHA-256 of its id, with a small header holding the id and the bytes'
/// SHA-256. Writes go to a pending file that is verified, then renamed.
class FileBlobs implements BlobRepository {
  final String namespace;
  final Directory? directory;
  FileBlobs(this.namespace, {this.directory});

  Future<Directory> _folder() async {
    final support = directory ?? await getApplicationSupportDirectory();
    final d = Directory('${support.path}/$namespace-blobs');
    await d.create(recursive: true);
    return d;
  }

  String _name(String id) => sha256.convert(utf8.encode(id)).toString();

  // Header: 4-byte length, then JSON {id, sha256}; then the bytes.
  Uint8List _encode(String id, Uint8List bytes) {
    final header = utf8.encode(
      jsonEncode({'id': id, 'sha256': sha256.convert(bytes).toString()}),
    );
    return (BytesBuilder(copy: false)
          ..add([
            header.length >> 24 & 255,
            header.length >> 16 & 255,
            header.length >> 8 & 255,
            header.length & 255,
          ])
          ..add(header)
          ..add(bytes))
        .takeBytes();
  }

  (String, Uint8List) _decode(Uint8List data) {
    if (data.length < 4) throw const FormatException('Damaged blob');
    final n = data[0] << 24 | data[1] << 16 | data[2] << 8 | data[3];
    if (n < 2 || n > 2000 || 4 + n > data.length)
      throw const FormatException('Damaged blob');
    final header = jsonDecode(utf8.decode(data.sublist(4, 4 + n)));
    final bytes = Uint8List.sublistView(data, 4 + n);
    if (header is! Map ||
        header['id'] is! String ||
        header['sha256'] != sha256.convert(bytes).toString())
      throw const FormatException('Blob checksum mismatch');
    return (header['id'] as String, bytes);
  }

  @override
  Future<Uint8List?> read(String id) async {
    checkBlobId(id);
    final f = File('${(await _folder()).path}/${_name(id)}');
    if (!await f.exists()) return null;
    final (stored, bytes) = _decode(await f.readAsBytes());
    if (stored != id) throw const FormatException('Blob id mismatch');
    return bytes;
  }

  @override
  Future<void> write(String id, Uint8List bytes) async {
    checkBlobId(id);
    if (bytes.length > blobMaxBytes)
      throw const FormatException('File too large to keep');
    final folder = await _folder(),
        target = File('${folder.path}/${_name(id)}'),
        pending = File('${target.path}.pending'),
        data = _encode(id, bytes);
    try {
      await pending.writeAsBytes(data, flush: true);
      final (_, check) = _decode(await pending.readAsBytes());
      if (check.length != bytes.length)
        throw const FileSystemException('Blob write verification failed');
      if (await target.exists()) await target.delete();
      await pending.rename(target.path);
    } finally {
      if (await pending.exists()) await pending.delete();
    }
  }

  @override
  Future<void> delete(String id) async {
    checkBlobId(id);
    final f = File('${(await _folder()).path}/${_name(id)}');
    if (await f.exists()) await f.delete();
  }

  @override
  Future<Set<String>> ids() async {
    final result = <String>{};
    await for (final e in (await _folder()).list()) {
      if (e is! File || e.path.endsWith('.pending')) continue;
      try {
        result.add(_decode(await e.readAsBytes()).$1);
      } on FormatException {
        // A damaged entry is left in place and not listed.
      }
    }
    return result;
  }
}
