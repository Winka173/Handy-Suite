import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
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
          key: const Key('save-trash'),
          icon: Icons.delete_outline,
          title: tr(context, 'Recently Deleted', 'Thùng rác'),
          subtitle: c.library!.trash.isEmpty
              ? tr(
                  context,
                  'Deleted items wait here for 30 days.',
                  'Mục bị xóa nằm ở đây 30 ngày.',
                )
              : tr(
                  context,
                  '${c.library!.trash.length} items, restorable for up to 30 days.',
                  '${c.library!.trash.length} mục, khôi phục được trong tối đa 30 ngày.',
                ),
          onTap: () => Navigator.of(context).pushNamed('/trash'),
        ),
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
        HandyTile(
          key: const Key('save-import-pocket'),
          icon: Icons.move_to_inbox_outlined,
          title: tr(context, 'Import from Pocket', 'Nhập từ Pocket'),
          subtitle: tr(
            context,
            'Pocket\'s CSV or ril_export.html: read state, tags and saved dates kept',
            'File CSV hoặc ril_export.html của Pocket: giữ trạng thái đọc, thẻ và ngày lưu',
          ),
          onTap: () => scope.importPocket(context),
        ),
        HandyTile(
          key: const Key('save-import-raindrop'),
          icon: Icons.move_to_inbox_outlined,
          title: tr(context, 'Import from Raindrop', 'Nhập từ Raindrop'),
          subtitle: tr(
            context,
            'Raindrop.io CSV or HTML: folders, tags, notes and favourites kept',
            'File CSV hoặc HTML của Raindrop.io: giữ thư mục, thẻ, ghi chú và yêu thích',
          ),
          onTap: () => scope.importRaindrop(context),
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
          key: const Key('save-copies-clear'),
          icon: Icons.offline_pin_outlined,
          title: tr(
            context,
            'Offline copies: ${c.readingIds.length}',
            'Bản đọc offline: ${c.readingIds.length}',
          ),
          subtitle: c.readingIds.isEmpty
              ? tr(
                  context,
                  'Save one from a link\'s details',
                  'Lưu từ phần chi tiết của một link',
                )
              : tr(
                  context,
                  'Remove them all; the links stay',
                  'Xóa hết bản đọc; link vẫn giữ',
                ),
          onTap: c.readingIds.isEmpty
              ? null
              : () async {
                  final ok = await confirmHandy(
                    context,
                    title: tr(
                      context,
                      'Remove every offline copy?',
                      'Xóa mọi bản đọc offline?',
                    ),
                    message: tr(
                      context,
                      'The links stay. Copies can be saved again while the pages are online.',
                      'Link vẫn giữ. Có thể lưu lại khi trang còn trên mạng.',
                    ),
                    confirmLabel: tr(context, 'Remove', 'Xóa'),
                    destructive: true,
                  );
                  if (!ok || !context.mounted) return;
                  await scope.run(context, () async {
                    await c.store!.clearReadingCopies();
                    await c.refreshReading();
                  });
                },
        ),
        // Shown only while some link is saved more than once.
        if (duplicateGroups(c.library!) case final groups
            when groups.isNotEmpty)
          HandyTile(
            key: const Key('save-duplicates'),
            icon: Icons.merge_type,
            title: tr(
              context,
              groups.length == 1
                  ? '1 link saved twice'
                  : '${groups.length} links saved twice',
              '${groups.length} link lưu trùng',
            ),
            subtitle: tr(
              context,
              'Review and merge each into one.',
              'Xem lại và gộp mỗi link thành một.',
            ),
            onTap: () => Navigator.of(context).pushNamed('/duplicates'),
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
              await c.store!.clearReadingCopies();
              await c.refreshReading();
              await scope.reminders.cancelAll();
              c.clearThumbnailMemory();
            });
          },
        ),
      ],
    );
  }
}
