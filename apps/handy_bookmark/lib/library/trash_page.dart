import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../scope.dart';
import '../ui/words.dart';

/// Recently Deleted: what was deleted in the last 30 days, newest first,
/// with the days each has left. Restore puts an item back as it was (to
/// Not sorted if its collection is gone); Delete for good and Empty are
/// the only irreversible actions and say so before they act.
class TrashPage extends StatelessWidget {
  final SaveScope scope;
  const TrashPage({super.key, required this.scope});

  SaveController get c => scope.c;

  Future<void> restore(BuildContext context, Iterable<String> ids) async {
    final list = ids.toList();
    final known = {for (final x in c.library!.collections) x.id};
    final orphans = c.library!.trash
        .where(
          (b) =>
              list.contains(b.id) &&
              b.collectionId != null &&
              !known.contains(b.collectionId),
        )
        .length;
    final ok = await scope.run(
      context,
      () => scope.view.change((l) => restoreFromTrash(l, list, saveTime())),
    );
    if (!ok || !context.mounted) return;
    scope.undoMessage(
      context,
      list.length == 1
          ? tr(context, 'Restored.', 'Đã khôi phục.')
          : tr(
              context,
              'Restored ${list.length} items.',
              'Đã khôi phục ${list.length} mục.',
            ),
    );
    if (orphans > 0 && context.mounted)
      showHandyMessage(
        context,
        tr(
          context,
          'Its collection was deleted, so it is back in Not sorted.',
          'Bộ sưu tập cũ đã bị xóa nên mục này về Chưa xếp.',
        ),
      );
  }

  Future<void> purge(BuildContext context, List<String> ids) async {
    final all = ids.length == c.library!.trash.length && ids.length > 1;
    final ok = await confirmHandy(
      context,
      title: all
          ? tr(context, 'Empty Recently Deleted?', 'Dọn sạch Thùng rác?')
          : ids.length == 1
          ? tr(context, 'Delete for good?', 'Xóa vĩnh viễn?')
          : tr(
              context,
              'Delete ${ids.length} items for good?',
              'Xóa vĩnh viễn ${ids.length} mục?',
            ),
      message: tr(
        context,
        'This cannot be undone. Pictures and offline copies that only these items use are removed from this device. Backups you exported keep their own copy.',
        'Không thể hoàn tác. Ảnh và bản đọc chỉ các mục này dùng sẽ bị xóa khỏi máy. Bản sao lưu đã xuất vẫn giữ bản riêng của nó.',
      ),
      confirmLabel: all
          ? tr(context, 'Empty', 'Dọn sạch')
          : tr(context, 'Delete for good', 'Xóa vĩnh viễn'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final done = await scope.run(context, () async {
      await c.update((l) => purgeTrash(l, ids, saveTime()));
      // The pictures nothing uses any more can go now (after the grace).
      try {
        await c.store!.collectMedia(mediaInUse(c.library!));
      } catch (_) {}
    });
    if (done && context.mounted)
      showHandyMessage(
        context,
        tr(context, 'Deleted for good.', 'Đã xóa vĩnh viễn.'),
      );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final theme = Theme.of(context);
      final colors = HandyColors.of(context);
      final items = [...c.library!.trash]
        ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
      final names = {for (final x in c.library!.collections) x.id: x.name};
      final now = DateTime.now();
      return Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'Recently Deleted', 'Thùng rác')),
          actions: [
            if (items.length > 1)
              HandyMenuButton(
                items: [
                  HandyMenuItem(
                    Icons.restore,
                    tr(context, 'Restore all', 'Khôi phục tất cả'),
                    () => restore(context, [for (final b in items) b.id]),
                  ),
                  HandyMenuItem(
                    Icons.delete_forever_outlined,
                    tr(context, 'Empty', 'Dọn sạch'),
                    () => purge(context, [for (final b in items) b.id]),
                  ),
                ],
              ),
          ],
        ),
        body: items.isEmpty
            ? HandyEmpty(
                key: const Key('trash-empty'),
                title: tr(
                  context,
                  'Nothing in Recently Deleted',
                  'Thùng rác trống',
                ),
                message: tr(
                  context,
                  'Deleted items wait here for 30 days before they go for good.',
                  'Mục bị xóa nằm ở đây 30 ngày rồi mới bị xóa vĩnh viễn.',
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(HandySpace.l),
                children: [
                  HandyContent(
                    maxWidth: 720,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          tr(
                            context,
                            'Items stay here for 30 days, then they are deleted for good. Restoring puts them back as they were.',
                            'Mục nằm ở đây 30 ngày rồi bị xóa vĩnh viễn. Khôi phục sẽ trả mục về như cũ.',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.muted,
                          ),
                        ),
                        const SizedBox(height: HandySpace.m),
                        HandyGroup(
                          children: [
                            for (final b in items)
                              _TrashRow(
                                key: Key('trash-${b.id}'),
                                controller: c,
                                item: b,
                                days: trashDaysLeft(b, now),
                                place: b.collectionId == null
                                    ? tr(context, 'Not sorted', 'Chưa xếp')
                                    : names[b.collectionId] ?? '',
                                onRestore: () => restore(context, [b.id]),
                                onPurge: () => purge(context, [b.id]),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      );
    },
  );
}

class _TrashRow extends StatelessWidget {
  final SaveController controller;
  final Bookmark item;
  final int days;
  final String place;
  final VoidCallback onRestore, onPurge;
  const _TrashRow({
    super.key,
    required this.controller,
    required this.item,
    required this.days,
    required this.place,
    required this.onRestore,
    required this.onPurge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final title = item.title.isNotEmpty
        ? item.title
        : item.isImage
        ? tr(context, 'Picture', 'Ảnh')
        : item.sourceDomain;
    final left = days <= 1
        ? tr(context, 'Goes today or tomorrow', 'Sắp bị xóa')
        : tr(context, '$days days left', 'Còn $days ngày');
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: HandySpace.m,
        vertical: HandySpace.s,
      ),
      child: Row(
        children: [
          LinkThumb(controller, item, size: 48),
          const SizedBox(width: HandySpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(
                  [left, if (place.isNotEmpty) place].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: days <= 1 ? theme.colorScheme.error : c.muted,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            key: Key('trash-restore-${item.id}'),
            onPressed: onRestore,
            child: Text(tr(context, 'Restore', 'Khôi phục')),
          ),
          IconButton(
            key: Key('trash-purge-${item.id}'),
            tooltip: tr(context, 'Delete for good', 'Xóa vĩnh viễn'),
            icon: const Icon(Icons.delete_forever_outlined),
            onPressed: onPurge,
          ),
        ],
      ),
    );
  }
}
