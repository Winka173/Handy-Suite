import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';

/// Sync through a folder on this computer that a cloud client keeps in
/// step (OneDrive, Google Drive for desktop, Dropbox, iCloud Drive for
/// Windows, a network share). A file's tag is the hash of its bytes, so a
/// write meant for an older version is refused even when the cloud client
/// has just replaced the file. Writes go to a temporary file first and
/// are renamed into place.
class FolderSyncProvider implements SyncProvider {
  final String root;
  FolderSyncProvider(this.root);

  File _file(String path) {
    if (path.contains('..')) throw const FormatException('Bad sync path');
    return File(
      '$root${Platform.pathSeparator}${path.replaceAll('/', Platform.pathSeparator)}',
    );
  }

  static String _tag(Uint8List bytes) => sha256.convert(bytes).toString();

  @override
  Future<RemoteFile?> read(String path) async {
    final f = _file(path);
    if (!await f.exists()) return null;
    final bytes = await f.readAsBytes();
    return RemoteFile(bytes, _tag(bytes));
  }

  @override
  Future<String> write(
    String path,
    Uint8List bytes, {
    String? ifMatch,
    bool ifAbsent = false,
  }) async {
    final f = _file(path);
    final exists = await f.exists();
    if (ifAbsent && exists) throw const SyncConflict();
    if (ifMatch != null) {
      if (!exists || _tag(await f.readAsBytes()) != ifMatch)
        throw const SyncConflict();
    }
    await f.parent.create(recursive: true);
    final temp = File(
      '${f.path}.tmp-${Random.secure().nextInt(1 << 32).toRadixString(16)}',
    );
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(f.path);
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
    return _tag(bytes);
  }

  @override
  Future<Set<String>> list(String folder) async {
    final d = Directory(_file(folder).path);
    if (!await d.exists()) return {};
    return {
      await for (final e in d.list())
        if (e is File && !e.path.contains('.tmp-')) e.uri.pathSegments.last,
    };
  }
}

/// Whether a chosen folder can carry sync here (a real path on disk).
bool folderSyncSupported(String kind) => kind == 'path';

FolderSyncProvider? folderSyncProvider(String kind, String ref) =>
    folderSyncSupported(kind) ? FolderSyncProvider(ref) : null;
