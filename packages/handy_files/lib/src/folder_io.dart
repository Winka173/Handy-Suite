import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../backup_folder.dart';

BackupFolders create() {
  if (Platform.isAndroid) return _Tree();
  if (Platform.isIOS) return _Documents();
  return _Desktop();
}

BackupFolders private() => _Private();

/// The app's own `backups` folder; [choose] makes it and hands it back.
class _Private extends _Disk {
  @override
  bool get canChoose => false;
  @override
  Future<BackupFolder?> choose() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}backups');
    await dir.create(recursive: true);
    return BackupFolder('path', dir.path, 'This device');
  }
}

bool _plain(String name) =>
    name.isNotEmpty &&
    !name.startsWith('.') &&
    !name.contains('/') &&
    !name.contains(r'\') &&
    !name.contains('..');

/// A folder on disk; desktops pick it, iOS uses the app's Documents.
abstract class _Disk implements BackupFolders {
  @override
  bool get supported => true;
  @override
  Future<bool> reachable(BackupFolder folder) => Directory(folder.ref).exists();

  @override
  Future<BackupEntry> write(
    BackupFolder folder,
    String name,
    Uint8List bytes,
  ) async {
    if (!_plain(name)) throw ArgumentError('Bad file name');
    final dir = Directory(folder.ref);
    if (!await dir.exists()) throw const FileSystemException('Folder missing');
    var file = File('${dir.path}${Platform.pathSeparator}$name');
    final dot = name.indexOf('.');
    for (var i = 2; await file.exists(); i++) {
      final stem = dot < 0 ? name : name.substring(0, dot);
      final ext = dot < 0 ? '' : name.substring(dot);
      file = File('${dir.path}${Platform.pathSeparator}$stem ($i)$ext');
    }
    // Written beside, then moved, so a half-written file never has the name.
    final part = File('${file.path}.part');
    try {
      await part.writeAsBytes(bytes, flush: true);
      await part.rename(file.path);
    } catch (_) {
      if (await part.exists()) await part.delete();
      rethrow;
    }
    final name0 = file.uri.pathSegments.last;
    return BackupEntry(
      name0,
      file.path,
      size: bytes.length,
      modified: DateTime.now(),
    );
  }

  @override
  Future<List<BackupEntry>> list(BackupFolder folder) async {
    final dir = Directory(folder.ref);
    if (!await dir.exists()) return const [];
    return [
      await for (final e in dir.list(followLinks: false))
        if (e is File)
          BackupEntry(
            e.uri.pathSegments.last,
            e.path,
            size: await e.length(),
            modified: await e.lastModified(),
          ),
    ];
  }

  @override
  Future<void> delete(BackupFolder folder, BackupEntry entry) async {
    final file = File(entry.ref);
    // Only a file directly inside the chosen folder.
    if (file.parent.absolute.path != Directory(folder.ref).absolute.path ||
        !_plain(entry.name))
      throw ArgumentError('Not in folder');
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> forget(BackupFolder folder) async {}
}

class _Desktop extends _Disk {
  @override
  bool get canChoose => true;
  @override
  Future<BackupFolder?> choose() async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null) return null;
    return BackupFolder(
      'path',
      path,
      Directory(
        path,
      ).uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => path),
    );
  }
}

class _Documents extends _Disk {
  @override
  bool get canChoose => false;
  @override
  Future<BackupFolder?> choose() async {
    final dir = await getApplicationDocumentsDirectory();
    return BackupFolder('documents', dir.path, 'Files');
  }
}

class _Tree implements BackupFolders {
  static const _channel = MethodChannel('handy_files/folder');
  @override
  bool get supported => true;
  @override
  bool get canChoose => true;

  @override
  Future<BackupFolder?> choose() async {
    final picked = await _channel.invokeMapMethod<String, Object?>('pick');
    if (picked == null) return null;
    return BackupFolder(
      'tree',
      picked['uri']! as String,
      (picked['name'] as String?) ?? '',
    );
  }

  @override
  Future<bool> reachable(BackupFolder folder) async =>
      await _channel.invokeMethod<bool>('access', {'tree': folder.ref}) ??
      false;

  @override
  Future<BackupEntry> write(
    BackupFolder folder,
    String name,
    Uint8List bytes,
  ) async {
    if (!_plain(name)) throw ArgumentError('Bad file name');
    final done = (await _channel.invokeMapMethod<String, Object?>('write', {
      'tree': folder.ref,
      'name': name,
      'mime': 'application/octet-stream',
      'bytes': bytes,
    }))!;
    return BackupEntry(
      done['name']! as String,
      done['uri']! as String,
      size: bytes.length,
      modified: DateTime.now(),
    );
  }

  @override
  Future<List<BackupEntry>> list(BackupFolder folder) async {
    final rows =
        await _channel.invokeListMethod<Map>('list', {'tree': folder.ref}) ??
        const [];
    return [
      for (final r in rows)
        BackupEntry(
          r['name'] as String,
          r['uri'] as String,
          size: r['size'] as int?,
          modified: r['modified'] is int
              ? DateTime.fromMillisecondsSinceEpoch(r['modified'] as int)
              : null,
        ),
    ];
  }

  @override
  Future<void> delete(BackupFolder folder, BackupEntry entry) =>
      _channel.invokeMethod('delete', {'tree': folder.ref, 'uri': entry.ref});

  @override
  Future<void> forget(BackupFolder folder) =>
      _channel.invokeMethod('release', {'tree': folder.ref});
}
