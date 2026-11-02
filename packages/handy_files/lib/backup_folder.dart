import 'dart:typed_data';
import 'src/folder_stub.dart' if (dart.library.io) 'src/folder_io.dart' as impl;

/// A place the user chose for automatic backups.
///
/// `path` is a folder on a desktop; `tree` an Android Storage Access
/// Framework folder (a local folder, Google Drive, OneDrive…) kept with a
/// persistable grant; `documents` the app's own folder that iOS shows in
/// Files (and includes in the device's iCloud backup).
class BackupFolder {
  final String kind, ref, name;
  const BackupFolder(this.kind, this.ref, this.name);
  Map<String, String> toJson() => {'kind': kind, 'ref': ref, 'name': name};
  static BackupFolder? fromJson(Object? json) {
    if (json is! Map) return null;
    final kind = json['kind'], ref = json['ref'], name = json['name'];
    if (kind is! String || ref is! String || name is! String) return null;
    if (!const ['path', 'tree', 'documents'].contains(kind)) return null;
    return BackupFolder(kind, ref, name);
  }

  @override
  bool operator ==(Object other) =>
      other is BackupFolder && other.kind == kind && other.ref == ref;
  @override
  int get hashCode => Object.hash(kind, ref);
}

class BackupEntry {
  final String name, ref;
  final int? size;
  final DateTime? modified;
  const BackupEntry(this.name, this.ref, {this.size, this.modified});
}

abstract interface class BackupFolders {
  /// Whether this platform can keep backups in a folder at all.
  bool get supported;

  /// False where the place is fixed (iOS: the app's folder in Files).
  bool get canChoose;

  /// Asks the user for a folder; null when they back out.
  Future<BackupFolder?> choose();

  /// Whether the app may still write there (the grant can be revoked, a
  /// drive unplugged).
  Future<bool> reachable(BackupFolder folder);

  /// Writes a new file; an existing file is never replaced.
  Future<BackupEntry> write(BackupFolder folder, String name, Uint8List bytes);
  Future<List<BackupEntry>> list(BackupFolder folder);
  Future<void> delete(BackupFolder folder, BackupEntry entry);

  /// Gives back the access the app was granted.
  Future<void> forget(BackupFolder folder);
}

BackupFolders systemBackupFolders() => impl.create();
