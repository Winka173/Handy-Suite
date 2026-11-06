import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../ui/visual.dart';

/// Recently Deleted: what was deleted in the last 30 days, newest first,
/// with the days each has left. Restore puts an item back as it was (to
/// Not sorted if its collection is gone); Delete forever and Empty are
/// the only irreversible actions, kept apart from Restore, and say so
/// before they act.
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
      final p = BookmarkPalette.of(context);
      final items = [...c.library!.trash]
        ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
      final names = {for (final x in c.library!.collections) x.id: x.name};
      final now = DateTime.now();
      final soonest = items.isEmpty
          ? 0
          : items
                .map((b) => trashDaysLeft(b, now))
                .reduce((a, b) => a < b ? a : b);
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
                    destructive: true,
                  ),
                ],
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: items.isEmpty
            ? const _NothingDeleted(key: Key('trash-empty'))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  HandyContent(
                    maxWidth: 720,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          items.length == 1
                              ? tr(context, '1 item', '1 mục')
                              : tr(
                                  context,
                                  '${items.length} items',
                                  '${items.length} mục',
                                ),
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr(
                            context,
                            'Each one is deleted for good 30 days after you deleted it. Restore puts it back where it was.',
                            'Mỗi mục bị xóa vĩnh viễn 30 ngày sau khi bạn xóa. Khôi phục sẽ trả mục về chỗ cũ.',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: p.muted,
                          ),
                        ),
                        if (soonest <= 3) ...[
                          const SizedBox(height: 12),
                          HandyNotice(
                            tr(
                              context,
                              'Some items go for good within 3 days.',
                              'Có mục sẽ bị xóa vĩnh viễn trong 3 ngày tới.',
                            ),
                            tone: HandyTone.warning,
                          ),
                        ],
                        const SizedBox(height: 16),
                        for (final b in items) ...[
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
                          const SizedBox(height: 10),
                        ],
                        if (items.length > 1) ...[
                          const SizedBox(height: 20),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              key: const Key('trash-empty-all'),
                              style: TextButton.styleFrom(
                                foregroundColor: p.danger,
                              ),
                              onPressed: () =>
                                  purge(context, [for (final b in items) b.id]),
                              icon: const Icon(
                                Icons.delete_forever_outlined,
                                size: 20,
                              ),
                              label: Text(
                                tr(
                                  context,
                                  'Empty Recently Deleted',
                                  'Dọn sạch Thùng rác',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      );
    },
  );
}

/// Nothing waits here: a calm note on how the 30 days work.
class _NothingDeleted extends StatelessWidget {
  const _NothingDeleted({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
      children: [
        HandyContent(
          maxWidth: 420,
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? p.raised
                      : p.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline, size: 32, color: p.muted),
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  tr(context, 'Nothing in Recently Deleted', 'Thùng rác trống'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  context,
                  'What you delete waits here for 30 days, so you can put it back.',
                  'Mục bạn xóa nằm ở đây 30 ngày để bạn có thể lấy lại.',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
    final p = BookmarkPalette.of(context);
    final dark = theme.brightness == Brightness.dark;
    final title = item.title.isNotEmpty
        ? item.title
        : item.isImage
        ? tr(context, 'Picture', 'Ảnh')
        : item.sourceDomain;
    final left = days <= 1
        ? tr(context, 'Goes today or tomorrow', 'Sắp bị xóa')
        : tr(context, '$days days left', 'Còn $days ngày');
    final soon = days <= 3;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(BookmarkRadii.item),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: ItemPicture(controller, item, compact: true),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [left, if (place.isNotEmpty) place].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: soon ? p.warning : p.muted,
                          fontWeight: soon ? FontWeight.w600 : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              FilledButton.tonalIcon(
                key: Key('trash-restore-${item.id}'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  backgroundColor: p.tint,
                  foregroundColor: dark ? p.ink : p.pressed,
                  shape: const StadiumBorder(),
                ),
                onPressed: onRestore,
                icon: const Icon(Icons.restore, size: 20),
                label: Text(tr(context, 'Restore', 'Khôi phục')),
              ),
              // Quiet until asked: the confirmation carries the warning.
              TextButton.icon(
                key: Key('trash-purge-${item.id}'),
                style: TextButton.styleFrom(foregroundColor: p.muted),
                onPressed: onPurge,
                icon: const Icon(Icons.delete_forever_outlined, size: 20),
                label: Text(tr(context, 'Delete forever', 'Xóa vĩnh viễn')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
