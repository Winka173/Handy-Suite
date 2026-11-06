import 'package:handy_files/backup_folder.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import 'sync_service.dart';

/// Settings > Sync through a folder. On a computer the person picks a
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
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final at = DateTime.tryParse(
      scope.c.preferences['syncedAt'] as String? ?? '',
    );
    final note = scope.c.preferences['syncNote'] as String? ?? '';
    String when(DateTime t) =>
        '${MaterialLocalizations.of(context).formatShortDate(t.toLocal())} '
        '${TimeOfDay.fromDateTime(t.toLocal()).format(context)}';
    return HandySettingsSection(
      title: tr(context, 'Sync through a folder', 'Đồng bộ qua thư mục'),
      description: tr(
        context,
        'For computers. Choose a folder that OneDrive, Google Drive, Dropbox or iCloud keeps in step, then press Sync now on each computer. Nothing syncs by itself, and it is not a backup.',
        'Dành cho máy tính. Chọn một thư mục do OneDrive, Google Drive, Dropbox hoặc iCloud giữ đồng bộ, rồi bấm Đồng bộ ngay trên từng máy. Không có gì tự đồng bộ, và đây không phải bản sao lưu.',
      ),
      children: [
        if (!available)
          // Said plainly, not a greyed-out control nobody can use.
          Padding(
            key: const Key('sync-unavailable'),
            padding: const EdgeInsets.all(HandySpace.l),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sync_disabled, size: 20, color: c.muted),
                const SizedBox(width: HandySpace.l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(
                          context,
                          'Not available on this device',
                          'Chưa có trên thiết bị này',
                        ),
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr(
                          context,
                          'Folder sync works on computers only. To move your library here, export it on one device and import it on the other.',
                          'Đồng bộ qua thư mục chỉ chạy trên máy tính. Để chuyển thư viện, hãy xuất ở máy này rồi nhập ở máy kia.',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else ...[
          HandyTile(
            key: const Key('sync-folder'),
            icon: Icons.folder_shared_outlined,
            title: f == null
                ? tr(context, 'Choose a synced folder', 'Chọn thư mục đồng bộ')
                : f.name,
            subtitle: f == null
                ? tr(
                    context,
                    'One your cloud app already keeps in step.',
                    'Thư mục mà app đám mây của bạn đang giữ đồng bộ.',
                  )
                : tr(
                    context,
                    'Tap to choose another',
                    'Chạm để chọn thư mục khác',
                  ),
            navigates: true,
            onTap: busy ? null : _choose,
          ),
          if (f != null)
            ListTile(
              key: const Key('sync-now'),
              leading: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync, size: 20),
              title: Text(
                busy
                    ? tr(context, 'Syncing…', 'Đang đồng bộ…')
                    : tr(context, 'Sync now', 'Đồng bộ ngay'),
              ),
              subtitle: Text(
                at == null
                    ? tr(context, 'Not synced yet', 'Chưa đồng bộ lần nào')
                    : [
                        tr(
                          context,
                          'Last synced ${when(at)}',
                          'Lần cuối ${when(at)}',
                        ),
                        if (note.isNotEmpty) note,
                      ].join(' · '),
              ),
              onTap: busy ? null : _sync,
            ),
        ],
      ],
    );
  }
}
