import 'package:flutter/foundation.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../pro/entitlements.dart';
import '../scope.dart';

SharedImport _read((Uint8List, SaveLibrary, bool, String, DateTime) v) =>
    readSharedCollections(
      v.$1,
      current: v.$2,
      keepFolders: v.$3,
      suffix: v.$4,
      now: v.$5,
    );

extension ReceiveCollections on SaveScope {
  /// A file a friend sent (see [ShareCollection.sendCollections]): what it
  /// holds, checked whole, then added on one tap. Pictures go in first, so
  /// no item ever points at a missing one; previews for links follow the
  /// links. Folders stay folders with Pro; without it they spread into
  /// their collection, their names kept as tags.
  Future<void> receiveCollections(BuildContext context, Uint8List bytes) async {
    final keep = hasPro(context);
    final suffix = tr(context, '(shared)', '(từ bạn)');
    final baseline = library;
    final got = await compute(_read, (
      bytes,
      baseline,
      keep,
      suffix,
      DateTime.now(),
    ));
    if (!context.mounted) return;
    final fresh = got.preview.fresh(baseline).length;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (context) => _ReceiveSheet(got: got, fresh: fresh),
    );
    if (ok != true || !context.mounted) return;
    await run(context, () async {
      final items = [...got.preview.library.bookmarks];
      for (final e in got.preview.pictures.entries) {
        final ref = items.firstWhere((b) => b.media?.id == e.key).media!;
        await c.store!.putMedia(
          ref.toJson(),
          e.value.original,
          e.value.preview,
        );
      }
      await view.change((l) => got.preview.commit(l));
      final added = {for (final b in library.bookmarks) b.id};
      for (final e in got.thumbnails.entries) {
        if (!added.contains(e.key)) continue;
        try {
          await c.store!.putThumbnail(e.key, e.value);
          c.thumbnailChanged(e.key);
        } catch (_) {
          /* A missing preview loses no link. */
        }
      }
      if (context.mounted)
        undoMessage(
          context,
          tr(
            context,
            '$fresh ${fresh == 1 ? 'item' : 'items'} added in ${got.names.length} ${got.names.length == 1 ? 'collection' : 'collections'}.',
            'Đã thêm $fresh mục vào ${got.names.length} bộ sưu tập.',
          ),
        );
    });
  }
}

/// What arrives: each collection by the name it will have, how many items
/// are new, and what changes on the way (folders spread out, a name taken).
class _ReceiveSheet extends StatelessWidget {
  final SharedImport got;
  final int fresh;
  const _ReceiveSheet({required this.got, required this.fresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final l = got.preview.library;
    final top = {
      for (final c in l.collections)
        if (c.parentId == null) c.id: c,
    };
    final parent = {
      for (final c in l.collections)
        if (c.parentId != null) c.id: c.parentId!,
    };
    int count(String id) => l.bookmarks
        .where((b) => b.collectionId == id || parent[b.collectionId] == id)
        .length;
    String items(int n) =>
        tr(context, '$n ${n == 1 ? 'item' : 'items'}', '$n mục');
    final n = top.length;
    return Column(
      key: const Key('receive-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            children: [
              Semantics(
                header: true,
                child: Text(
                  tr(
                    context,
                    n == 1
                        ? 'Add a shared collection'
                        : 'Add $n shared collections',
                    'Thêm $n bộ sưu tập được gửi',
                  ),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  items(l.bookmarks.length),
                  if (got.preview.duplicateCount > 0)
                    tr(
                      context,
                      '${got.preview.duplicateCount} already here',
                      '${got.preview.duplicateCount} đã có sẵn',
                    ),
                ].join(' · '),
                style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
              ),
              const SizedBox(height: 12),
              for (final c in top.values)
                ListTile(
                  key: Key('receive-${c.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.collections_bookmark_outlined,
                    color: p.muted,
                  ),
                  title: Text(
                    c.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(items(count(c.id))),
                ),
              if (got.flattened) ...[
                const SizedBox(height: 8),
                HandyNotice(
                  tr(
                    context,
                    '${got.folders} ${got.folders == 1 ? 'folder goes' : 'folders go'} into ${got.folders == 1 ? 'its collection' : 'their collections'}; each folder name becomes a tag on its items. Keeping folders needs Pro.',
                    '${got.folders} thư mục sẽ được gộp vào bộ sưu tập của chúng; tên thư mục thành thẻ trên từng mục. Cần Pro để giữ nguyên thư mục.',
                  ),
                  key: const Key('receive-flattened'),
                ),
              ],
              if (got.renamed > 0) ...[
                const SizedBox(height: 8),
                HandyNotice(
                  tr(
                    context,
                    'You already have a collection with that name, so the new one is marked "(shared)".',
                    'Bạn đã có bộ sưu tập cùng tên, nên bộ mới được thêm chữ "(từ bạn)".',
                  ),
                  key: const Key('receive-renamed'),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(tr(context, 'Cancel', 'Hủy')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  key: const Key('receive-add'),
                  onPressed: fresh == 0
                      ? null
                      : () => Navigator.pop(context, true),
                  child: Text(
                    fresh == 0
                        ? tr(context, 'All already here', 'Đã có hết')
                        : tr(
                            context,
                            'Add ${items(fresh)}',
                            'Thêm ${items(fresh)}',
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
