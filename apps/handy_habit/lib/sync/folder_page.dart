import 'package:handy_ui/kit.dart';
import '../scope.dart';
import 'drive_sync.dart';
import 'sync_page.dart' show syncErrorText;

class HabitFolderPage extends StatelessWidget {
  final HabitScope scope;
  const HabitFolderPage({super.key, required this.scope});
  @override
  Widget build(BuildContext c) {
    final folder = scope.folder;
    if (folder == null)
      return HandyPage(
        title: tr(c, 'Sync through a folder', 'Đồng bộ qua thư mục'),
        children: [
          Text(
            tr(
              c,
              'Available on Windows. Use backup on this platform.',
              'Có trên Windows. Dùng sao lưu trên nền tảng này.',
            ),
          ),
        ],
      );
    return ListenableBuilder(
      listenable: folder.driver,
      builder: (c, _) {
        final d = folder.driver;
        return HandyPage(
          title: tr(c, 'Sync through a folder', 'Đồng bộ qua thư mục'),
          children: [
            if (d.lastError == 'capacity') Text(syncErrorText(c, 'capacity')),
            Text(
              tr(
                c,
                'Free · optional. Choose the same folder on your Windows computers, for example OneDrive or Drive for desktop. Habit merges check-ins; your desktop client carries the files. This is separate from Backup.',
                'Miễn phí · tùy chọn. Chọn cùng thư mục trên các máy Windows, ví dụ OneDrive hoặc Drive cho máy tính. Habit hợp nhất ghi nhận; ứng dụng máy tính chuyển tệp. Tính năng này tách biệt với Sao lưu.',
              ),
            ),
            Text(
              folder.folder ?? tr(c, 'No folder chosen', 'Chưa chọn thư mục'),
            ),
            Text(switch (d.state) {
              DriveSyncState.synced => tr(
                c,
                'Merged with this folder',
                'Đã hợp nhất với thư mục này',
              ),
              DriveSyncState.error || DriveSyncState.newerRemote => tr(
                c,
                'Could not sync. Local data is safe. Check access and let all files download, then retry.',
                'Chưa đồng bộ được. Dữ liệu cục bộ vẫn an toàn. Kiểm tra quyền, đợi tải đủ tệp rồi thử lại.',
              ),
              _ =>
                d.enabled
                    ? tr(
                        c,
                        'Waiting for folder sync',
                        'Đang chờ đồng bộ thư mục',
                      )
                    : tr(c, 'Off', 'Đã tắt'),
            }),
            Text(
              tr(
                c,
                'Runs while Habit is open. “Merged” does not confirm delivery to another computer. Keep complete generations; do not edit or delete sync files. Turning off keeps all local data.',
                'Chạy khi mở Habit. “Đã hợp nhất” không xác nhận tệp đã đến máy khác. Giữ đủ các thế hệ tệp; không sửa hoặc xóa tệp đồng bộ. Tắt vẫn giữ dữ liệu cục bộ.',
              ),
            ),
            if (d.lastSync != null)
              Text(
                tr(
                  c,
                  'Last merge: ${d.lastSync!.toLocal()}',
                  'Hợp nhất lần cuối: ${d.lastSync!.toLocal()}',
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: d.busy
                      ? null
                      : () async {
                          try {
                            await folder.choose();
                          } catch (_) {
                            if (c.mounted)
                              showHandyMessage(
                                c,
                                tr(
                                  c,
                                  'Folder unavailable. Nothing was removed.',
                                  'Thư mục không khả dụng. Không xóa gì.',
                                ),
                              );
                          }
                        },
                  child: Text(tr(c, 'Choose folder', 'Chọn thư mục')),
                ),
                if (d.enabled)
                  TextButton(
                    onPressed: d.busy ? null : d.syncNow,
                    child: Text(tr(c, 'Sync now', 'Đồng bộ ngay')),
                  ),
                if (d.enabled)
                  TextButton(
                    onPressed: () => d.disable(),
                    child: Text(tr(c, 'Turn off', 'Tắt')),
                  ),
                if (!d.enabled && folder.folder != null)
                  TextButton(
                    onPressed: d.busy ? null : d.enable,
                    child: Text(tr(c, 'Turn on', 'Bật')),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
