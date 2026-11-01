import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_save_engine/handy_save_engine.dart';
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
  ]) async {
    final edited = await Navigator.push<SaveCollection>(
      context,
      MaterialPageRoute(
        fullscreenDialog: initial == null,
        builder: (_) => CollectionEditor(initial: initial, library: library),
      ),
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
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(tr(context, 'Delete ${item.name}?', 'Xóa ${item.name}?')),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HandySpace.xl,
                0,
                HandySpace.xl,
                HandySpace.m,
              ),
              child: Text(
                tr(
                  context,
                  'It holds $count links. Where should they go?',
                  'Bộ này có $count link. Chuyển chúng đi đâu?',
                ),
              ),
            ),
            SimpleDialogOption(
              key: const Key('delcol-inbox'),
              onPressed: () => Navigator.pop(context, 'inbox'),
              child: Text(tr(context, 'To Not sorted', 'Về Chưa xếp')),
            ),
            SimpleDialogOption(
              key: const Key('delcol-move'),
              onPressed: () => Navigator.pop(context, 'move'),
              child: Text(
                tr(context, 'To another collection…', 'Sang bộ khác…'),
              ),
            ),
            SimpleDialogOption(
              key: const Key('delcol-delete'),
              onPressed: () => Navigator.pop(context, 'delete'),
              child: Text(
                tr(context, 'Delete them too…', 'Xóa luôn các link…'),
              ),
            ),
          ],
        ),
      );
      if (choice == null || !context.mounted) return false;
      target = choice;
      if (choice == 'move') {
        final id = await pickCollection(
          context,
          library.copyWith(
            collections: [
              for (final x in library.collections)
                if (x.id != item.id) x,
            ],
          ),
        );
        if (id == null || !context.mounted) return false;
        target = id.isEmpty ? 'inbox' : id;
      }
      if (target == 'delete' &&
          !await confirmHandy(
            context,
            title: tr(
              context,
              'Delete ${item.name} and its $count links?',
              'Xóa ${item.name} và $count link bên trong?',
            ),
            confirmLabel: tr(context, 'Delete all', 'Xóa hết'),
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
        (l) => l.copyWith(
          collections: [
            for (final x in l.collections)
              if (x.id != item.id)
                x.parentId == item.id ? x.copyWith(parentId: item.parentId) : x,
          ],
          bookmarks: [
            for (final b in l.bookmarks)
              if (b.collectionId != item.id)
                b
              else if (target != 'delete')
                b.copyWith(
                  collectionId: target == 'inbox' ? null : target,
                  updatedAt: saveTime(),
                ),
          ],
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
    if (LifetimeScope.maybeOf(context)?.pro != true) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            tr(
              context,
              'Smart collections are in Pro',
              'Bộ sưu tập thông minh có trong bản Pro',
            ),
          ),
          content: Text(
            tr(
              context,
              'A smart collection fills itself from rules, like "videos saved this week". Pro Lifetime is a one-time purchase in Settings.',
              'Bộ sưu tập thông minh tự gom link theo điều kiện, ví dụ "video lưu trong tuần này". Pro Lifetime mua một lần trong Cài đặt.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr(context, 'Close', 'Đóng')),
            ),
          ],
        ),
      );
      return;
    }
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
