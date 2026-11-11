import 'dart:io';
import 'dart:typed_data';
import 'package:handy_habit_engine/handy_habit_engine.dart';

/// R15 bytes and immutable generations over a user-owned Windows folder.
/// The desktop cloud client only transports files; Habit performs the merge.
class FolderSyncProvider implements HabitSyncProvider {
  final String root;
  FolderSyncProvider(this.root);
  bool _equal(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<String> _path(String path) async {
    if (!RegExp(
      r'^handy-habit/(commits|versions)(/[a-zA-Z0-9-]+\.json)?$',
    ).hasMatch(path)) {
      throw const FormatException('Invalid sync path');
    }
    if (!await Directory(root).exists())
      throw FileSystemException('Sync folder unavailable');
    var current = root;
    for (final part in path.split('/')) {
      current = '$current${Platform.pathSeparator}$part';
      if (await FileSystemEntity.type(current, followLinks: false) ==
          FileSystemEntityType.link)
        throw const FormatException('Linked sync path refused');
    }
    return current;
  }

  @override
  Future<Uint8List?> read(String path) async {
    final file = File(await _path(path));
    if (!await file.exists()) return null;
    if (await file.length() > backupLimit)
      throw const FormatException('Sync file exceeds 30MB');
    return file.readAsBytes();
  }

  @override
  Future<Set<String>> list(String folder) async {
    final dir = Directory(await _path(folder));
    if (!await dir.exists()) return {};
    final names = <String>{};
    await for (final entry in dir.list(followLinks: false)) {
      final name = entry.path.split(Platform.pathSeparator).last;
      // Only app-owned final files participate. An interrupted staging write
      // never appears in the protocol's complete listing.
      if (name.endsWith('.part') || name.endsWith('.lock')) continue;
      if (entry is! File || !RegExp(r'^[a-zA-Z0-9-]+\.json$').hasMatch(name))
        throw const FormatException(
          'Unexpected sync file; review folder conflict copies',
        );
      names.add(name);
    }
    return names;
  }

  @override
  Future<void> put(String path, Uint8List bytes) async {
    if (bytes.length > backupLimit)
      throw const FormatException('Sync exceeds 30MB');
    final file = File(await _path(path));
    await file.parent.create(recursive: true);
    final lock = await File('${file.path}.lock').open(mode: FileMode.append);
    File? part;
    try {
      await lock.lock(FileLock.blockingExclusive);
      if (await file.exists()) {
        if (!_equal(await file.readAsBytes(), bytes))
          throw const FormatException('Immutable sync file changed');
        return;
      }
      part = File('${file.path}.${uid()}.part');
      await part.writeAsBytes(bytes, flush: true);
      await part.rename(file.path);
      part = null;
    } finally {
      if (part != null && await part.exists()) await part.delete();
      await lock.close();
    }
  }
}
