import 'dart:typed_data';
import '../backup_folder.dart';

/// The web has no folder the app can write to later.
BackupFolders create() => _None();
BackupFolders private() => _None();

class _None implements BackupFolders {
  @override
  bool get supported => false;
  @override
  bool get canChoose => false;
  @override
  Future<BackupFolder?> choose() async => null;
  @override
  Future<bool> reachable(BackupFolder folder) async => false;
  @override
  Future<BackupEntry> write(BackupFolder f, String name, Uint8List bytes) =>
      throw UnsupportedError('No backup folder on this platform');
  @override
  Future<List<BackupEntry>> list(BackupFolder folder) async => const [];
  @override
  Future<void> delete(BackupFolder folder, BackupEntry entry) async {}
  @override
  Future<void> forget(BackupFolder folder) async {}
}
