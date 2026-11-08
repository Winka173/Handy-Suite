import 'package:handy_ui/kit.dart';
import '../settings/settings_parts.dart';
import 'drive_sync.dart';

/// Settings › Sync › Google Drive (Android): on and off, what it is doing,
/// and Sync now. Says plainly where the boards go and what it is not.
class DriveSyncPanel extends StatefulWidget {
  final BoardsDriveSync drive;
  const DriveSyncPanel({super.key, required this.drive});
  @override
  State<DriveSyncPanel> createState() => _DriveSyncPanelState();
}

class _DriveSyncPanelState extends State<DriveSyncPanel> {
  bool _asking = false;
  BoardsDriveSync get d => widget.drive;

  Future<void> _turnOn() async {
    setState(() => _asking = true);
    final ok = await d.enable();
    if (!mounted) return;
    setState(() => _asking = false);
    if (!ok) {
      showHandyMessage(
        context,
        tr(
          context,
          'Google did not allow access. Nothing changed.',
          'Google chưa cho phép truy cập. Không có gì thay đổi.',
        ),
      );
    }
  }

  String _when(DateTime t) =>
      '${MaterialLocalizations.of(context).formatShortDate(t)} '
      '${TimeOfDay.fromDateTime(t).format(context)}';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: d,
    builder: (context, _) {
      final at = d.lastSync;
      final pictures = d.sent + d.received == 0
          ? null
          : tr(
              context,
              '${d.sent} photos sent, ${d.received} received',
              'gửi ${d.sent} ảnh, nhận ${d.received} ảnh',
            );
      final (IconData icon, String title, String? note) = switch (d.state) {
        DriveSyncState.syncing => (
          Icons.sync,
          tr(context, 'Syncing…', 'Đang đồng bộ…'),
          null,
        ),
        DriveSyncState.offline => (
          Icons.cloud_off_outlined,
          tr(context, 'Will sync when online', 'Sẽ đồng bộ khi có mạng'),
          tr(context, 'Tap to try now', 'Chạm để thử ngay'),
        ),
        DriveSyncState.authNeeded => (
          Icons.lock_outline,
          tr(context, 'Allow access again', 'Cho phép truy cập lại'),
          tr(
            context,
            'Google stopped this app’s access. Tap to allow it.',
            'Google đã ngừng quyền của app. Chạm để cho phép lại.',
          ),
        ),
        DriveSyncState.quota => (
          Icons.cloud_off_outlined,
          tr(context, 'Google Drive is full', 'Google Drive đã đầy'),
          tr(
            context,
            'Free some space in Drive, then tap to sync.',
            'Dọn bớt dung lượng Drive rồi chạm để đồng bộ.',
          ),
        ),
        DriveSyncState.failed => (
          Icons.error_outline,
          tr(
            context,
            'Could not sync; your boards are unchanged',
            'Chưa đồng bộ được; bảng của bạn không đổi',
          ),
          tr(context, 'Tap to try again', 'Chạm để thử lại'),
        ),
        _ => (
          Icons.cloud_done_outlined,
          at == null
              ? tr(context, 'Not synced yet', 'Chưa đồng bộ lần nào')
              : tr(context, 'Synced ${_when(at)}', 'Đã đồng bộ ${_when(at)}'),
          [
            ?pictures,
            tr(context, 'Tap to sync now', 'Chạm để đồng bộ ngay'),
          ].join(' · '),
        ),
      };
      final busy = d.state == DriveSyncState.syncing || _asking;
      return SettingsPanel(
        gap: false,
        title: 'Google Drive',
        note: tr(
          context,
          'Your boards, cards and photos go to a hidden folder in your own Google Drive that only Handy Boards can see, and to your other Android devices signed in to it. Theme, language and reminders stay on each device. It syncs while the app is open. It is not end-to-end encrypted, and it is not a backup.',
          'Bảng, thẻ và ảnh được lưu vào một thư mục ẩn trong Google Drive của chính bạn, chỉ Handy Boards thấy được, và tới các máy Android khác đăng nhập cùng tài khoản. Giao diện, ngôn ngữ và lời nhắc ở riêng từng máy. Đồng bộ khi app đang mở. Không mã hoá đầu-cuối, và không thay cho bản sao lưu.',
        ),
        rows: [
          if (!d.enabled)
            SettingsRow(
              key: const Key('drive-on'),
              icon: Icons.add_to_drive_outlined,
              title: tr(
                context,
                'Turn on Google Drive sync',
                'Bật đồng bộ Google Drive',
              ),
              subtitle: tr(
                context,
                'Google asks you to allow this app’s own folder only.',
                'Google sẽ hỏi bạn cho phép, chỉ với thư mục riêng của app.',
              ),
              trailing: _asking ? const _Spinner() : null,
              onTap: busy ? null : _turnOn,
            )
          else ...[
            SettingsRow(
              key: const Key('drive-now'),
              icon: icon,
              title: title,
              subtitle: note,
              trailing: busy ? const _Spinner() : null,
              onTap: busy
                  ? null
                  : d.state == DriveSyncState.authNeeded
                  ? _turnOn
                  : d.syncNow,
            ),
            SettingsRow(
              key: const Key('drive-off'),
              icon: Icons.sync_disabled,
              title: tr(context, 'Turn off sync', 'Tắt đồng bộ'),
              subtitle: tr(
                context,
                'Nothing is deleted here or in Drive. To remove the Drive copy: Drive › Settings › Manage apps.',
                'Không xoá gì trên máy hay trên Drive. Muốn xoá bản trên Drive: Drive › Cài đặt › Quản lý ứng dụng.',
              ),
              onTap: busy ? null : () => d.disable(forget: true),
            ),
          ],
        ],
      );
    },
  );
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(right: HandySpace.s),
    child: SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
  );
}
