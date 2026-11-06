import 'package:handy_files/backup_folder.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import 'sync_service.dart';

/// Settings > Sync between devices. On a computer the person picks a
/// folder their cloud client keeps in step; every device syncing with that
/// folder ends up with the same items, pictures and deletions. On phones
/// and the web this build has no cloud adapter yet and says so.
class SyncSection extends StatefulWidget {
  final SaveScope scope;
  final BackupFolders folders;
  const SyncSection({super.key, required this.scope, required this.folders});
  @override
  State<SyncSection> createState() => _SyncSectionState();
}

class _SyncSectionState extends State<SyncSection> {
  bool busy = false;
  SaveScope get scope => widget.scope;

  BackupFolder? get folder =>
      BackupFolder.fromJson(scope.c.preferences['syncFolder']);

  Future<void> _set(Map<String, Object?> values) => scope.c.update(
    (l) => l,
    prefs: {
      ...scope.c.preferences,
      for (final e in values.entries)
        if (e.value != null) e.key: e.value,
    }..removeWhere((k, _) => values.containsKey(k) && values[k] == null),
  );

  Future<void> _choose() async {
    final chosen = await widget.folders.choose();
    if (chosen == null || !mounted) return;
    if (!folderSyncSupported(chosen.kind)) {
      showHandyMessage(
        context,
        tr(
          context,
          'That place cannot hold sync here. Pick a folder on this computer.',
          'Nơi này không dùng để đồng bộ được. Hãy chọn một thư mục trên máy tính.',
        ),
      );
      return;
    }
    await scope.run(context, () => _set({'syncFolder': chosen.toJson()}));
  }

  Future<void> _sync() async {
    final f = folder;
    final remote = f == null ? null : folderSyncProvider(f.kind, f.ref);
    if (remote == null || busy) return;
    setState(() => busy = true);
    final vi = Localizations.localeOf(context).languageCode == 'vi';
    final ok = await scope.run(context, () async {
      final r = await syncLibrary(scope.c, remote);
      await _set({
        'syncedAt': DateTime.now().toUtc().toIso8601String(),
        'syncNote': vi
            ? 'gửi ${r.picturesSent} ảnh, nhận ${r.picturesReceived} ảnh'
            : '${r.picturesSent} pictures sent, ${r.picturesReceived} received',
      });
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (ok) showHandyMessage(context, tr(context, 'In sync.', 'Đã đồng bộ.'));
  }

  @override
  Widget build(BuildContext context) {
    final f = folder;
    final available = folderSyncSupported('path') && widget.folders.canChoose;
    final at = DateTime.tryParse(
      scope.c.preferences['syncedAt'] as String? ?? '',
    );
    return HandySettingsSection(
      title: tr(context, 'Sync between devices', 'Đồng bộ giữa các máy'),
      description: tr(
        context,
        'Every device that syncs with the same folder ends up with the same links, pictures and deletions. It is not a backup: keep backups too.',
        'Mọi máy đồng bộ cùng một thư mục sẽ có cùng link, ảnh và các lần xóa. Đây không phải bản sao lưu: vẫn nên sao lưu.',
      ),
      children: [
        if (!available)
          ListTile(
            key: const Key('sync-unavailable'),
            title: Text(
              tr(
                context,
                'Sync through iCloud Drive or Google Drive is not in this build yet on this device. On a computer, sync works through any folder your cloud keeps in step.',
                'Bản này chưa có đồng bộ qua iCloud Drive hay Google Drive trên thiết bị này. Trên máy tính, đồng bộ chạy qua bất kỳ thư mục nào được dịch vụ đám mây giữ đồng bộ.',
              ),
            ),
          )
        else ...[
          ListTile(
            key: const Key('sync-folder'),
            leading: const Icon(Icons.folder_shared_outlined),
            title: Text(
              f == null
                  ? tr(
                      context,
                      'Choose a synced folder',
                      'Chọn thư mục đồng bộ',
                    )
                  : f.name,
            ),
            subtitle: Text(
              tr(
                context,
                'A folder OneDrive, Google Drive, Dropbox or iCloud keeps in step.',
                'Một thư mục do OneDrive, Google Drive, Dropbox hoặc iCloud giữ đồng bộ.',
              ),
            ),
            onTap: _choose,
          ),
          if (f != null)
            ListTile(
              key: const Key('sync-now'),
              leading: busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              title: Text(tr(context, 'Sync now', 'Đồng bộ ngay')),
              subtitle: Text(
                at == null
                    ? tr(context, 'Not synced yet', 'Chưa đồng bộ lần nào')
                    : '${MaterialLocalizations.of(context).formatShortDate(at.toLocal())} ${TimeOfDay.fromDateTime(at.toLocal()).format(context)} · ${scope.c.preferences['syncNote'] ?? ''}',
              ),
              onTap: busy ? null : _sync,
            ),
        ],
      ],
    );
  }
}
