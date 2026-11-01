import 'package:handy_save_engine/handy_save_engine.dart';
import 'package:handy_ui/kit.dart';
import '../data/import_export.dart';
import '../scope.dart';

/// Backups, upkeep and, last, deleting everything.
class SaveDataSection extends StatelessWidget {
  final SaveScope scope;
  const SaveDataSection({super.key, required this.scope});

  @override
  Widget build(BuildContext context) {
    final c = scope.c;
    return HandySettingsSection(
      title: tr(context, 'Your links', 'Dữ liệu link'),
      description: tr(
        context,
        'Everything stays on this device. Exported files can contain private addresses.',
        'Mọi thứ chỉ nằm trên máy này. File xuất có thể chứa địa chỉ riêng tư.',
      ),
      children: [
        HandyTile(
          key: const Key('save-export'),
          icon: Icons.archive_outlined,
          title: tr(context, 'Export or back up', 'Xuất hoặc sao lưu'),
          subtitle: 'JSON · ZIP · HTML · CSV · Markdown · TXT',
          onTap: () => scope.exportLinks(context),
        ),
        HandyTile(
          key: const Key('save-import'),
          icon: Icons.unarchive_outlined,
          title: tr(context, 'Import or restore', 'Nhập hoặc khôi phục'),
          subtitle: tr(
            context,
            'You see what a file holds before anything changes',
            'Xem trước nội dung file rồi mới thay đổi',
          ),
          onTap: () => scope.importLinks(context),
        ),
        if (scope.view.canUndo)
          HandyTile(
            key: const Key('save-undo'),
            icon: Icons.undo,
            title: tr(
              context,
              'Undo the last change',
              'Hoàn tác thay đổi gần nhất',
            ),
            onTap: () => scope.run(context, scope.view.undo),
          ),
        HandyTile(
          key: const Key('save-thumbnails'),
          icon: Icons.image_not_supported_outlined,
          title: tr(context, 'Clear saved pictures', 'Xóa ảnh đã lưu'),
          onTap: () => scope.run(context, () async {
            await c.store!.clearThumbnails();
            c.clearThumbnailMemory();
            if (context.mounted)
              showHandyMessage(
                context,
                tr(
                  context,
                  'Pictures cleared. Links are untouched.',
                  'Đã xóa ảnh. Link vẫn còn nguyên.',
                ),
              );
          }),
        ),
        HandyTile(
          key: const Key('save-integrity'),
          icon: Icons.fact_check_outlined,
          title: tr(context, 'Check the database', 'Kiểm tra cơ sở dữ liệu'),
          onTap: () => scope.run(context, () async {
            final status = await c.store!.integrity();
            if (context.mounted) {
              showHandyMessage(
                context,
                status == 'ok'
                    ? tr(
                        context,
                        'The database is healthy.',
                        'Cơ sở dữ liệu ổn.',
                      )
                    : '${tr(context, 'Problem found', 'Phát hiện lỗi')}: $status',
              );
            }
          }),
        ),
        HandyTile(
          key: const Key('save-privacy'),
          icon: Icons.privacy_tip_outlined,
          title: tr(context, 'Privacy', 'Quyền riêng tư'),
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(tr(context, 'Privacy', 'Quyền riêng tư')),
              scrollable: true,
              content: Text(
                tr(
                  context,
                  'Your links, notes and collections stay on this device or browser. No account, no tracking of addresses, no server, no cloud sync. Page details contact only that public website, and only when you turn it on or ask. The clipboard is read only when you press Paste. Exported files may include private addresses. The local database is not encrypted.',
                  'Link, ghi chú và bộ sưu tập chỉ nằm trên máy hoặc trình duyệt này. Không tài khoản, không theo dõi địa chỉ, không máy chủ, không đồng bộ đám mây. Thông tin trang chỉ liên hệ đúng website công khai đó, và chỉ khi bạn bật hoặc bấm. Clipboard chỉ được đọc khi bạn bấm Dán. File xuất có thể chứa địa chỉ riêng tư. Cơ sở dữ liệu trên máy không mã hóa.',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr(context, 'Close', 'Đóng')),
                ),
              ],
            ),
          ),
        ),
        HandyTile(
          key: const Key('save-reset'),
          icon: Icons.delete_forever_outlined,
          destructive: true,
          title: tr(
            context,
            'Delete all links and collections',
            'Xóa mọi link và bộ sưu tập',
          ),
          onTap: () async {
            final ok = await confirmHandy(
              context,
              title: tr(context, 'Delete everything?', 'Xóa toàn bộ?'),
              message: tr(
                context,
                'Every link, collection, tag and reminder on this device. Export a backup first if you may want it back.',
                'Mọi link, bộ sưu tập, thẻ và hẹn nhắc trên máy này. Hãy xuất bản sao lưu trước nếu còn cần.',
              ),
              confirmLabel: tr(context, 'Delete everything', 'Xóa hết'),
              destructive: true,
            );
            if (!ok || !context.mounted) return;
            await scope.run(context, () async {
              await scope.view.change((_) => SaveLibrary(), prefs: {});
              await c.store!.clearThumbnails();
              await scope.reminders.cancelAll();
              c.clearThumbnailMemory();
            });
          },
        ),
      ],
    );
  }
}
