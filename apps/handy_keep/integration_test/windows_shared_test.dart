// The shared pieces that only run natively, on Windows:
// flutter test integration_test/windows_shared_test.dart -d windows
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_files/auto_backup.dart';
import 'package:handy_notifications/handy_notifications.dart';
import 'package:handy_notifications/native.dart';
import 'package:integration_test/integration_test.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows schedules, lists and cancels a toast', (t) async {
    final port = DeviceNotifications(windows: windowsIdentity('keep'));
    expect(await port.allowed(false), isTrue);
    final zone = await deviceLocation();
    final when = tz.TZDateTime.now(zone).add(const Duration(hours: 2));
    final r = ReminderRequest('keep:windows-check', when);
    await port.schedule('keep', r);
    expect((await port.pending('keep'))[r.id], r.signature);
    await port.cancel(r.id);
    expect((await port.pending('keep')).containsKey(r.id), isFalse);
  });

  testWidgets('a folder backup is written, listed and pruned', (t) async {
    final dir = await Directory.systemTemp.createTemp('handy-backup-');
    addTearDown(() => dir.delete(recursive: true));
    final folders = systemBackupFolders();
    final folder = BackupFolder('path', dir.path, 'test');
    File('${dir.path}/notes.txt').writeAsStringSync('keep me');
    var s = AutoBackupSettings(enabled: true, folder: folder, keep: 3);
    for (var day = 1; day <= 4; day++) {
      s = await runAutoBackup(
        app: 'keep',
        extension: 'zip',
        settings: s,
        folders: folders,
        build: () async => Uint8List.fromList([day]),
        now: DateTime(2026, 10, day, 9),
      );
      expect(s.lastError, isNull);
    }
    final names = dir.listSync().map((e) => e.uri.pathSegments.last).toList()
      ..sort();
    expect(names, [
      'handy-keep-2026-10-02-0900.zip',
      'handy-keep-2026-10-03-0900.zip',
      'handy-keep-2026-10-04-0900.zip',
      'notes.txt',
    ]);
  });
}
