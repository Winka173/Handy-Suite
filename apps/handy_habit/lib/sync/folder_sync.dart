import 'package:flutter/foundation.dart';
import 'package:handy_files/backup_folder.dart';
import '../controller.dart';
import 'drive_sync.dart';
import 'folder_provider.dart';

bool get folderSyncOffered =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

class HabitFolderSync {
  String? folder;
  late final HabitDriveSync driver;
  HabitFolderSync(HabitController c) {
    driver = HabitDriveSync(
      c,
      provider: () =>
          FolderSyncProvider(folder ?? (throw StateError('Choose a folder'))),
      authorize: () async => folder != null,
      revoke: () async {},
      account: () => folder,
      metadata: FileSyncMetadata(name: 'habit-folder-device.json'),
    );
  }
  Future<void> start() async {
    await driver.initialize();
    folder = driver.account;
    await driver.start();
  }

  Future<void> choose() async {
    final picked = await systemBackupFolders().choose();
    if (picked == null || picked.kind != 'path') return;
    await driver.disable();
    folder = picked.ref;
    await driver.enable();
  }

  void dispose() => driver.dispose();
}
