import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/sealed.dart';
import 'package:handy_files/auto_backup.dart';

class MemoryFolders implements BackupFolders {
  final files = <String, Uint8List>{};
  bool reach = true, failWrite = false;
  @override
  bool get supported => true;
  @override
  bool get canChoose => true;
  @override
  Future<BackupFolder?> choose() async => const BackupFolder('path', '/b', 'b');
  @override
  Future<bool> reachable(BackupFolder folder) async => reach;
  @override
  Future<BackupEntry> write(
    BackupFolder f,
    String name,
    Uint8List bytes,
  ) async {
    if (failWrite) throw StateError('disk full');
    files[name] = bytes;
    return BackupEntry(name, name);
  }

  @override
  Future<List<BackupEntry>> list(BackupFolder folder) async => [
    for (final n in files.keys) BackupEntry(n, n),
  ];
  @override
  Future<void> delete(BackupFolder folder, BackupEntry entry) async =>
      files.remove(entry.name);
  @override
  Future<void> forget(BackupFolder folder) async {}
}

void main() {
  const folder = BackupFolder('path', '/b', 'b');
  final data = Uint8List.fromList(utf8.encode('zip bytes'));

  test('names, ownership and settings roundtrip', () {
    final name = autoBackupName('keep', DateTime(2026, 11, 2, 9, 5), 'zip');
    expect(name, 'handy-keep-2026-11-02-0905.zip');
    expect(isAutoBackup('keep', name), isTrue);
    expect(
      isAutoBackup('keep', 'handy-keep-2026-11-02-0905 (2).zip.hseal'),
      isTrue,
    );
    expect(isAutoBackup('keep', 'handy-save-2026-11-02-0905.zip'), isFalse);
    expect(isAutoBackup('keep', 'my handy-keep-2026-11-02-0905.zip'), isFalse);
    expect(isAutoBackup('keep', 'thesis.docx'), isFalse);
    final s = AutoBackupSettings(
      enabled: true,
      folder: folder,
      keep: 14,
      last: DateTime.utc(2026, 11, 1),
      lastRevision: 'r1',
    );
    final back = AutoBackupSettings.fromJson(
      jsonDecode(jsonEncode(s.toJson())),
    );
    expect(back.enabled, isTrue);
    expect(back.folder, folder);
    expect(back.keep, 14);
    expect(back.last, DateTime.utc(2026, 11, 1));
    expect(
      AutoBackupSettings.fromJson({
        'keep': 999,
        'seal': {'x': 1},
      }).enabled,
      isFalse,
    );
    expect(AutoBackupSettings.fromJson('junk').enabled, isFalse);
  });

  test('due once a day, and not when nothing changed', () {
    final now = DateTime(2026, 11, 2, 12);
    const off = AutoBackupSettings();
    expect(autoBackupDue(off, now), isFalse);
    final s = AutoBackupSettings(enabled: true, folder: folder);
    expect(autoBackupDue(s, now), isTrue);
    final done = s.copyWith(last: now, lastRevision: 'r1');
    expect(autoBackupDue(done, now.add(const Duration(hours: 2))), isFalse);
    expect(
      autoBackupDue(done, now.add(const Duration(hours: 25)), revision: 'r1'),
      isFalse,
    );
    expect(
      autoBackupDue(done, now.add(const Duration(hours: 25)), revision: 'r2'),
      isTrue,
    );
  });

  test(
    'keeps the newest automatic backups and never touches other files',
    () async {
      final folders = MemoryFolders()..files['notes.txt'] = data;
      var s = AutoBackupSettings(enabled: true, folder: folder, keep: 3);
      for (var day = 1; day <= 5; day++) {
        s = await runAutoBackup(
          app: 'keep',
          extension: 'zip',
          settings: s,
          folders: folders,
          build: () async => data,
          now: DateTime(2026, 10, day, 8),
        );
      }
      expect(folders.files.keys.toList()..sort(), [
        'handy-keep-2026-10-03-0800.zip',
        'handy-keep-2026-10-04-0800.zip',
        'handy-keep-2026-10-05-0800.zip',
        'notes.txt',
      ]);
      expect(s.lastName, 'handy-keep-2026-10-05-0800.zip');
      expect(s.lastError, isNull);
    },
  );

  test('failures are recorded and keep the old backups', () async {
    final folders = MemoryFolders();
    var s = AutoBackupSettings(enabled: true, folder: folder);
    s = await runAutoBackup(
      app: 'keep',
      extension: 'zip',
      settings: s,
      folders: folders,
      build: () async => data,
      now: DateTime(2026, 10, 1),
    );
    folders.failWrite = true;
    s = await runAutoBackup(
      app: 'keep',
      extension: 'zip',
      settings: s,
      folders: folders,
      build: () async => data,
      now: DateTime(2026, 10, 2),
    );
    expect(s.lastError, 'write');
    expect(s.last, DateTime(2026, 10, 1));
    expect(folders.files, hasLength(1));
    folders.reach = false;
    s = await runAutoBackup(
      app: 'keep',
      extension: 'zip',
      settings: s,
      folders: folders,
      build: () async => throw StateError('x'),
      now: DateTime(2026, 10, 3),
    );
    expect(s.lastError, 'unreachable');
    folders.reach = true;
    s = await runAutoBackup(
      app: 'keep',
      extension: 'zip',
      settings: s,
      folders: folders,
      build: () async => throw StateError('x'),
      now: DateTime(2026, 10, 3),
    );
    expect(s.lastError, 'write');
  });

  test('sealed backups open only with the password', () async {
    final folders = MemoryFolders();
    final key = await SealKey.create('pw', iterations: 10000);
    final s = await runAutoBackup(
      app: 'keep',
      extension: 'zip',
      settings: AutoBackupSettings(enabled: true, folder: folder, seal: key),
      folders: folders,
      build: () async => data,
      now: DateTime(2026, 10, 1),
    );
    expect(s.lastName, endsWith('.zip.hseal'));
    final stored = folders.files[s.lastName]!;
    expect(isSealed(stored), isTrue);
    expect(await unseal(stored, 'pw'), data);
  });
}
