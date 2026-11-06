import 'package:flutter/services.dart';
import '../pro/organize_page.dart';
import 'package:handy_ui/kit.dart';
import '../links/link_actions.dart';
import '../scope.dart';
import '../ui/collection_picker.dart';

/// Actions on every selected link. The common three are buttons; the rest
/// sit in a menu so the bar fits a phone.
class BatchBar extends StatelessWidget {
  final SaveScope scope;
  final VoidCallback onExport;
  const BatchBar({super.key, required this.scope, required this.onExport});

  Future<void> _tag(BuildContext context, {required bool add}) async {
    final input = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          add
              ? tr(context, 'Add a tag', 'Thêm thẻ')
              : tr(context, 'Remove a tag', 'Bỏ thẻ'),
        ),
        content: TextField(
          key: const Key('batch-tag'),
          controller: input,
          autofocus: true,
          decoration: const InputDecoration(prefixText: '#'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'Cancel', 'Hủy')),
          ),
          FilledButton(
            key: const Key('batch-tag-ok'),
            onPressed: () => Navigator.pop(context, input.text),
            child: Text(tr(context, 'Apply', 'Áp dụng')),
          ),
        ],
      ),
    );
    final t = tag?.trim().replaceFirst(RegExp('^#'), '') ?? '';
    if (t.isEmpty || !context.mounted) return;
    await scope.run(
      context,
      () => scope.view.batch(
        (b) => b.copyWith(
          tags: add
              ? {...b.tags, t}.toList()
              : [
                  for (final x in b.tags)
                    if (x != t) x,
                ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = scope.view;
    final n = v.selected.length;
    Future<void> apply(String done, Future<void> Function() task) async {
      if (await scope.run(context, task) && context.mounted)
        scope.undoMessage(context, done);
    }

    return HandyBottomBar(
      child: Row(
        children: [
          IconButton(
            key: const Key('batch-clear'),
            tooltip: tr(context, 'Stop selecting', 'Thôi chọn'),
            icon: const Icon(Icons.close),
            onPressed: v.clearSelection,
          ),
          Expanded(
            child: Text(
              tr(context, '$n selected', 'Đã chọn $n'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontFeatures: tabular),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            key: const Key('batch-move'),
            tooltip: tr(context, 'Move', 'Chuyển'),
            icon: const Icon(Icons.drive_file_move_outline),
            onPressed: () async {
              final id = await pickCollection(context, scope.library);
              if (id == null || !context.mounted) return;
              await apply(
                tr(context, 'Moved $n items.', 'Đã chuyển $n mục.'),
                () => v.batch(
                  (b) => b.copyWith(collectionId: id.isEmpty ? null : id),
                ),
              );
            },
          ),
          IconButton(
            key: const Key('batch-archive'),
            tooltip: tr(context, 'Archive', 'Lưu trữ'),
            icon: const Icon(Icons.archive_outlined),
            onPressed: () => apply(
              tr(context, 'Archived $n items.', 'Đã lưu trữ $n mục.'),
              () => v.batch((b) => b.copyWith(isArchived: true)),
            ),
          ),
          IconButton(
            key: const Key('batch-delete'),
            tooltip: tr(context, 'Delete', 'Xóa'),
            icon: const Icon(Icons.delete_outline),
            // Recoverable for 30 days, so no question first; Undo is offered.
            onPressed: () => apply(
              tr(
                context,
                'Moved $n to Recently Deleted.',
                'Đã chuyển $n mục vào Thùng rác.',
              ),
              v.deleteSelected,
            ),
          ),
          HandyMenuButton(
            key: const Key('batch-more'),
            items: [
              HandyMenuItem(
                Icons.select_all,
                tr(context, 'Select everything here', 'Chọn tất cả ở đây'),
                v.selectAll,
                key: const Key('batch-all'),
              ),
              HandyMenuItem(
                Icons.auto_fix_high_outlined,
                tr(context, 'Organize with rules', 'Xếp theo quy tắc'),
                () => showOrganizePreview(context, scope, ids: v.selected),
                key: const Key('batch-organize'),
              ),
              HandyMenuItem(
                Icons.cleaning_services_outlined,
                tr(context, 'Clean up titles', 'Dọn tiêu đề'),
                () => showTitleCleanup(context, scope, v.selected),
                key: const Key('batch-clean-titles'),
              ),
              HandyMenuItem(
                Icons.tag,
                tr(context, 'Add a tag', 'Thêm thẻ'),
                () => _tag(context, add: true),
                key: const Key('batch-tag-add'),
              ),
              HandyMenuItem(
                Icons.label_off_outlined,
                tr(context, 'Remove a tag', 'Bỏ thẻ'),
                () => _tag(context, add: false),
                key: const Key('batch-tag-remove'),
              ),
              HandyMenuItem(
                Icons.done_all,
                tr(context, 'Mark read', 'Đánh dấu đã đọc'),
                () => apply(
                  tr(context, 'Marked read.', 'Đã đánh dấu đã đọc.'),
                  () => v.batch((b) => b.copyWith(isRead: true)),
                ),
                key: const Key('batch-read'),
              ),
              HandyMenuItem(
                Icons.mark_email_unread_outlined,
                tr(context, 'Mark not read', 'Đánh dấu chưa đọc'),
                () => apply(
                  tr(context, 'Marked not read.', 'Đã đánh dấu chưa đọc.'),
                  () => v.batch((b) => b.copyWith(isRead: false)),
                ),
                key: const Key('batch-unread'),
              ),
              HandyMenuItem(
                Icons.star_outline,
                tr(context, 'Favourite', 'Yêu thích'),
                () => apply(
                  tr(context, 'Added to favourites.', 'Đã thêm vào yêu thích.'),
                  () => v.batch((b) => b.copyWith(isFavorite: true)),
                ),
                key: const Key('batch-favorite'),
              ),
              HandyMenuItem(
                Icons.copy,
                tr(context, 'Copy addresses', 'Chép các địa chỉ'),
                () async {
                  final urls = [
                    for (final b in scope.library.bookmarks)
                      if (v.selected.contains(b.id) && b.hasUrl) b.originalUrl,
                  ];
                  await Clipboard.setData(ClipboardData(text: urls.join('\n')));
                  if (context.mounted)
                    showHandyMessage(
                      context,
                      tr(
                        context,
                        '${urls.length} addresses copied.',
                        'Đã chép ${urls.length} địa chỉ.',
                      ),
                    );
                },
                key: const Key('batch-copy'),
              ),
              HandyMenuItem(
                Icons.download_outlined,
                tr(context, 'Export these', 'Xuất các link này'),
                onExport,
                key: const Key('batch-export'),
              ),
              HandyMenuItem(
                Icons.offline_pin_outlined,
                tr(context, 'Save offline copies', 'Lưu bản đọc offline'),
                () => scope.saveCopies(context, {...v.selected}),
                key: const Key('batch-copies'),
              ),
              HandyMenuItem(
                Icons.link_off,
                tr(context, 'Check links', 'Kiểm tra link'),
                () => scope.checkLinks(context, {...v.selected}),
                key: const Key('batch-check'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
