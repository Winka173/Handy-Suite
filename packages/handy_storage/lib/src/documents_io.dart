import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import '../documents.dart';

DocumentRepository createDocuments(String namespace, int maxBytes) =>
    FileDocuments(namespace, maxBytes);

class FileDocuments implements RecoverableDocuments {
  final String namespace;
  final int maxBytes;
  final Directory? directory;
  Future<void> _pending = Future.value();
  FileDocuments(this.namespace, this.maxBytes, {this.directory}) {
    if (!RegExp(r'^handy-[a-z-]{1,40}$').hasMatch(namespace) ||
        maxBytes < 1 ||
        maxBytes > 30000000)
      throw ArgumentError('Invalid document store configuration');
  }
  Future<Directory> _support() async =>
      directory ?? await getApplicationSupportDirectory();
  Future<Directory> _folder() async {
    final support = await _support();
    final d = Directory('${support.path}/$namespace');
    await d.create(recursive: true);
    return d;
  }

  Future<T> _serial<T>(Future<T> Function() work) {
    final result = _pending.catchError((_) {}).then((_) => work());
    _pending = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<List<(int, String, String)>> _valid(Directory folder) async {
    final result = <(int, String, String)>[];
    var existing = 0;
    for (final name in ['a.json', 'b.json']) {
      final f = File('${folder.path}/$name');
      if (!await f.exists()) continue;
      existing++;
      try {
        if (await f.length() > maxBytes * 2 + 4096)
          throw const FormatException('Stored document exceeds limits');
        final value = jsonDecode(await f.readAsString());
        if (value is! Map ||
            value['version'] != 1 ||
            value['revision'] is! int ||
            value['revision'] < 1 ||
            value['payload'] is! String ||
            value['checksum'] is! String)
          throw const FormatException('Invalid snapshot');
        final text = value['payload'] as String, bytes = utf8.encode(text);
        if (bytes.length > maxBytes ||
            sha256.convert(bytes).toString() != value['checksum'])
          throw const FormatException('Snapshot checksum mismatch');
        result.add((value['revision'], text, name));
      } catch (_) {
        /* Leave corrupt snapshot untouched. The other verified slot remains a recovery copy. */
      }
    }
    if (existing > 0 && result.isEmpty)
      throw const FormatException(
        'All local snapshots are corrupt. Restore an exported backup; existing files were preserved.',
      );
    result.sort((a, b) => b.$1.compareTo(a.$1));
    return result;
  }

  @override
  Future<String?> load() => _serial(() async {
    final values = await _valid(await _folder());
    return values.isEmpty ? null : values.first.$2;
  });
  @override
  Future<void> save(String text) => _serial(() async {
    final bytes = utf8.encode(text);
    if (bytes.length > maxBytes)
      throw const FormatException('Local document size limit exceeded');
    // Invalid JSON cannot replace a valid library.
    jsonDecode(text);
    final folder = await _folder(),
        previous = await _valid(folder),
        revision = previous.isEmpty ? 1 : previous.first.$1 + 1;
    final target = File(
      '${folder.path}/${previous.isEmpty || previous.first.$3 == 'b.json' ? 'a.json' : 'b.json'}',
    );
    final temporary = File('${target.path}.pending');
    final serialized = jsonEncode({
      'version': 1,
      'revision': revision,
      'payload': text,
      'checksum': sha256.convert(bytes).toString(),
    });
    try {
      await temporary.writeAsString(serialized, flush: true);
      if (await temporary.readAsString() != serialized)
        throw const FileSystemException('Document write verification failed');
      if (await target.exists()) await target.delete();
      await temporary.rename(target.path);
      if (await target.readAsString() != serialized)
        throw const FileSystemException('Document commit verification failed');
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  });

  Future<Directory> _preservedRoot() async =>
      Directory('${(await _support()).path}/.recovery-$namespace');

  Future<Directory> _preservedFolder(String id) async {
    if (!RegExp(r'^[0-9]{12,20}-[a-f0-9]{16}$').hasMatch(id))
      throw const FormatException('Invalid preserved library ID');
    final folder = Directory('${(await _preservedRoot()).path}/$id/snapshots');
    if (await FileSystemEntity.type(folder.path, followLinks: false) !=
        FileSystemEntityType.directory)
      throw const FormatException('Preserved library not found');
    return folder;
  }

  @override
  Future<List<PreservedDocuments>> preserved() => _serial(() async {
    final root = await _preservedRoot();
    if (!await root.exists()) return [];
    final result = <PreservedDocuments>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final id = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (!RegExp(r'^[0-9]{12,20}-[a-f0-9]{16}$').hasMatch(id)) continue;
      try {
        await _preservedFolder(id);
        result.add(
          PreservedDocuments(
            id,
            DateTime.fromMicrosecondsSinceEpoch(
              int.parse(id.split('-').first),
              isUtc: true,
            ),
          ),
        );
      } on FormatException {
        /* Incomplete reset folders are never treated as copies. */
      }
    }
    result.sort((a, b) => b.id.compareTo(a.id));
    return result;
  });

  @override
  Future<PreservedDocuments> preserveAndReset() => _serial(() async {
    final folder = await _folder();
    if (await folder.list(followLinks: false).isEmpty)
      throw const FormatException('The library is already empty');
    final now = DateTime.now().toUtc();
    final nonce = List.generate(
      8,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final id = '${now.microsecondsSinceEpoch}-$nonce';
    final wrapper = Directory('${(await _preservedRoot()).path}/$id');
    await wrapper.create(recursive: true);
    // A same-volume directory rename preserves all snapshots, pending writes and
    // unknown files, even if their contents cannot be decoded. No old file delete.
    await folder.rename('${wrapper.path}/snapshots');
    await _folder();
    return PreservedDocuments(id, now);
  });

  @override
  Future<Uint8List> exportPreserved(String id) => _serial(() async {
    final folder = await _preservedFolder(id);
    final archive = Archive(), hashes = <String, String>{};
    var total = 0;
    await for (final entity in folder.list(followLinks: false)) {
      final name = entity.uri.pathSegments.last;
      if (entity is! File ||
          !{
            'a.json',
            'b.json',
            'a.json.pending',
            'b.json.pending',
          }.contains(name))
        throw const FormatException(
          'Preserved folder contains additional files; all originals remain stored locally',
        );
      final size = await entity.length();
      total += size;
      if (total > 29000000)
        throw const FormatException(
          'Diagnostic export exceeds 29 MB; preserved files remain stored locally',
        );
      final bytes = await entity.readAsBytes();
      if (bytes.length != size)
        throw const FileSystemException('Preserved file changed during export');
      hashes[name] = sha256.convert(bytes).toString();
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }
    final manifest = utf8.encode(
      jsonEncode({
        'format': 'handy-preserved-documents',
        'version': 1,
        'namespace': namespace,
        'id': id,
        'checksums': hashes,
      }),
    );
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    return Uint8List.fromList(ZipEncoder().encodeBytes(archive, level: 0));
  });

  @override
  Future<void> undoReset(String id) => _serial(() async {
    final preserved = await _preservedFolder(id), folder = await _folder();
    if (!await folder.list(followLinks: false).isEmpty)
      throw const FormatException(
        'New library contains data; preserve it before undoing reset',
      );
    // Only this verified empty directory is removed. Archived data is renamed
    // atomically into its original namespace, never overwritten or deleted.
    await folder.delete();
    await preserved.rename(folder.path);
  });
}
