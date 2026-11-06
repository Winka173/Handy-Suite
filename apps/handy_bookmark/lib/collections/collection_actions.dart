import '../pro/entitlements.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../editors.dart';
import '../scope.dart';
import '../ui/collection_picker.dart';

/// Making, changing and removing collections, smart collections and tags.
extension CollectionActions on SaveScope {
  Future<void> editCollection(
    BuildContext context, [
    SaveCollection? initial,
  ]) => _collectionSheet(context, initial: initial);

  /// A new collection inside [parentId].
  Future<void> newSubCollection(BuildContext context, String parentId) =>
      _collectionSheet(context, parentId: parentId);

  Future<void> _collectionSheet(
    BuildContext context, {
    SaveCollection? initial,
    String? parentId,
  }) async {
    final edited = await showCollectionSheet(
      context,
      initial: initial,
      library: library,
      parentId: parentId,
    );
    if (edited == null || !context.mounted) return;
    await run(
      context,
      () => view.change(
        (l) => l.copyWith(
          collections: initial == null
              ? [...l.collections, edited]
              : [for (final x in l.collections) x.id == edited.id ? edited : x],
        ),
      ),
    );
  }

  /// Removes a collection; its subcollections move up a level. Its links go
  /// to "Not sorted", to another collection, or (asked twice) away.
  Future<bool> deleteCollection(
    BuildContext context,
    SaveCollection item,
  ) async {
    final count = library.bookmarks
        .where((b) => b.collectionId == item.id)
        .length;
    var target = 'inbox';
    if (count > 0) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (context) {
          final theme = Theme.of(context);
          final c = HandyColors.of(context);
          Widget option(
            Key key,
            IconData icon,
            String title,
            String note,
            String value, {
            bool danger = false,
          }) => ListTile(
            key: key,
            leading: Icon(icon, color: danger ? c.negative : null),
            title: Text(
              title,
              style: danger ? TextStyle(color: c.negative) : null,
            ),
            subtitle: Text(note),
            onTap: () => Navigator.pop(context, value),
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          tr(
                            context,
                            'Delete ${item.name}?',
                            'Xóa ${item.name}?',
                          ),
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(
                          context,
                          count == 1
                              ? 'It holds 1 item. Where should it go?'
                              : 'It holds $count items. Where should they go?',
                          'Bộ này có $count mục. Chuyển chúng đi đâu?',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                option(
                  const Key('delcol-inbox'),
                  Icons.inbox_outlined,
                  tr(context, 'To Not sorted', 'Về Chưa xếp'),
                  tr(
                    context,
                    'Keep them, without a collection',
                    'Giữ lại, không thuộc bộ nào',
                  ),
                  'inbox',
                ),
                option(
                  const Key('delcol-move'),
                  Icons.drive_file_move_outline,
                  tr(context, 'To another collection…', 'Sang bộ khác…'),
                  tr(context, 'Choose where next', 'Chọn nơi chuyển đến'),
                  'move',
                ),
                const SizedBox(height: 8),
                option(
                  const Key('delcol-delete'),
                  Icons.delete_outline,
                  tr(context, 'Delete them too…', 'Xóa luôn các mục…'),
                  tr(
                    context,
                    'They wait 30 days in Recently Deleted',
                    'Chúng nằm 30 ngày trong Thùng rác',
                  ),
                  'delete',
                  danger: true,
                ),
              ],
            ),
          );
        },
      );
      if (choice == null || !context.mounted) return false;
      target = choice;
      if (choice == 'move') {
        // Offer the tree as it will be once this one is gone (its
        // subcollections moved up a level), so the picker never meets a
        // missing parent.
        final id = await pickCollection(
          context,
          removeCollection(library, item.id, now: saveTime()),
        );
        if (id == null || !context.mounted) return false;
        target = id.isEmpty ? 'inbox' : id;
      }
      if (target == 'delete' &&
          !await confirmHandy(
            context,
            title: tr(
              context,
              'Delete ${item.name} and move its $count items to Recently Deleted?',
              'Xóa ${item.name} và chuyển $count mục bên trong vào Thùng rác?',
            ),
            message: tr(
              context,
              'They can be restored for 30 days; restored items go to Not sorted.',
              'Có thể khôi phục trong 30 ngày; mục khôi phục sẽ vào Chưa xếp.',
            ),
            confirmLabel: tr(context, 'Delete', 'Xóa'),
            destructive: true,
          )) {
        return false;
      }
    } else if (!await confirmHandy(
      context,
      title: tr(context, 'Delete ${item.name}?', 'Xóa ${item.name}?'),
      confirmLabel: tr(context, 'Delete', 'Xóa'),
      destructive: true,
    )) {
      return false;
    }
    if (!context.mounted) return false;
    final ok = await run(
      context,
      () => view.change(
        (l) => removeCollection(
          l,
          item.id,
          now: saveTime(),
          // Its items go to Recently Deleted (when asked), to another
          // collection, or stay in Not sorted; subcollections move up.
          contents: switch (target) {
            'delete' => CollectionContents.trash,
            'inbox' => CollectionContents.unfile,
            _ => CollectionContents.move,
          },
          moveTo: target == 'delete' || target == 'inbox' ? null : target,
        ),
      ),
    );
    if (ok && context.mounted)
      undoMessage(
        context,
        tr(context, 'Collection deleted.', 'Đã xóa bộ sưu tập.'),
      );
    return ok;
  }

  /// Smart collections are part of Pro; without it, say so plainly.
  Future<void> editSmart(
    BuildContext context, [
    SmartCollection? initial,
  ]) async {
    if (!await requirePro(context, ProFeature.smartCollections) ||
        !context.mounted)
      return;
    final value = await Navigator.push<SmartCollection>(
      context,
      MaterialPageRoute(
        fullscreenDialog: initial == null,
        builder: (_) =>
            SmartCollectionEditor(initial: initial, library: library),
      ),
    );
    if (value == null || !context.mounted) return;
    await run(
      context,
      () => view.change(
        (l) => l.copyWith(
          smartCollections: initial == null
              ? [...l.smartCollections, value]
              : [
                  for (final x in l.smartCollections)
                    x.id == value.id ? value : x,
                ],
        ),
      ),
    );
  }

  Future<void> deleteSmart(BuildContext context, SmartCollection item) async {
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Delete ${item.name}?', 'Xóa ${item.name}?'),
      message: tr(
        context,
        'Your links stay where they are.',
        'Các link vẫn ở nguyên chỗ cũ.',
      ),
      confirmLabel: tr(context, 'Delete', 'Xóa'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await run(
      context,
      () => view.change(
        (l) => l.copyWith(
          smartCollections: [
            for (final x in l.smartCollections)
              if (x.id != item.id) x,
          ],
        ),
      ),
    );
  }

  /// Renames a tag on every link; an empty name removes it (asked first).
  Future<void> renameTag(BuildContext context, String tag) async {
    final input = TextEditingController(text: tag);
    final next = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'Rename #$tag', 'Đổi tên #$tag')),
        content: TextField(
          key: const Key('tag-name'),
          controller: input,
          autofocus: true,
          maxLength: 512,
          decoration: const InputDecoration(prefixText: '#', counterText: ''),
        ),
        actions: [
          TextButton(
            key: const Key('tag-remove'),
            style: TextButton.styleFrom(
              foregroundColor: HandyColors.of(context).negative,
            ),
            onPressed: () => Navigator.pop(context, ''),
            child: Text(tr(context, 'Remove tag', 'Bỏ thẻ')),
          ),
          FilledButton(
            key: const Key('tag-save'),
            onPressed: () => Navigator.pop(context, input.text),
            child: Text(tr(context, 'Save', 'Lưu')),
          ),
        ],
      ),
    );
    if (next == null || !context.mounted) return;
    final name = next.trim().replaceFirst(RegExp('^#'), '');
    if (name.isEmpty &&
        !await confirmHandy(
          context,
          title: tr(
            context,
            'Remove #$tag from every link?',
            'Bỏ #$tag khỏi mọi link?',
          ),
          confirmLabel: tr(context, 'Remove', 'Bỏ'),
          destructive: true,
        )) {
      return;
    }
    if (!context.mounted) return;
    List<String> swap(List<String> tags) => {
      for (final t in tags)
        if (t != tag) t else if (name.isNotEmpty) name,
    }.toList();
    await run(
      context,
      () => view.change(
        (l) => l.copyWith(
          tags: swap(l.tags),
          bookmarks: [
            for (final b in l.bookmarks)
              b.tags.contains(tag)
                  ? b.copyWith(tags: swap(b.tags), updatedAt: saveTime())
                  : b,
          ],
        ),
      ),
    );
  }
}
