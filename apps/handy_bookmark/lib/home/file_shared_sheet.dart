import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../collections/identity.dart';
import '../design/clipping.dart';
import '../design/theme.dart';
import '../editors.dart' show showCollectionSheet;
import '../scope.dart';
import '../ui/collection_picker.dart';

/// After a Share from another app has been saved (it is already in Not
/// sorted, safe): where should it go? One choice for everything that came
/// in, "New collection" in place, and Pin. Closing the sheet leaves it in
/// Not sorted, which is a fine answer too.
Future<void> showFileShared(
  BuildContext context,
  SaveScope scope,
  List<String> ids,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => _FileShared(scope: scope, ids: ids),
);

class _FileShared extends StatefulWidget {
  final SaveScope scope;
  final List<String> ids;
  const _FileShared({required this.scope, required this.ids});
  @override
  State<_FileShared> createState() => _FileSharedState();
}

class _FileSharedState extends State<_FileShared> {
  /// The chosen collection; null is Not sorted.
  String? _into;
  bool _pin = false;
  bool _busy = false;

  SaveScope get scope => widget.scope;

  List<Bookmark> get _items {
    final ids = widget.ids.toSet();
    return [
      for (final b in scope.library.bookmarks)
        if (ids.contains(b.id)) b,
    ];
  }

  Future<void> _newCollection() async {
    final made = await showCollectionSheet(context, library: scope.library);
    if (made == null || !mounted) return;
    final ok = await scope.run(
      context,
      () => scope.view.change(
        (l) => l.copyWith(collections: [...l.collections, made]),
      ),
    );
    if (ok && mounted) setState(() => _into = made.id);
  }

  Future<void> _done() async {
    final items = _items;
    if ((_into == null && !_pin) || items.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _busy = true);
    final into = _into, pin = _pin;
    final ids = {for (final b in items) b.id};
    final ok = await scope.run(
      context,
      () => scope.view.change(
        (l) => l.copyWith(
          bookmarks: [
            for (final b in l.bookmarks)
              ids.contains(b.id)
                  ? b.copyWith(
                      collectionId: into ?? b.collectionId,
                      isPinned: pin || b.isPinned,
                    )
                  : b,
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    final name = scope.library.collections
        .where((c) => c.id == into)
        .firstOrNull
        ?.name;
    Navigator.pop(context);
    if (name != null)
      showHandyMessage(
        context,
        tr(context, 'Put in $name.', 'Đã cho vào $name.'),
      );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.c,
    builder: (context, _) {
      final theme = Theme.of(context);
      final p = BookmarkPalette.of(context);
      final items = _items;
      final l = scope.library;
      final tree = collectionTree(l);
      final chosen = tree.where((e) => e.$1.id == _into).firstOrNull?.$1;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          key: const Key('file-shared'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(
              before: tr(context, 'Saved. ', 'Đã lưu. '),
              words: tr(context, 'Where to?', 'Cho vào đâu?'),
            ),
            const SizedBox(height: HandySpace.l),
            if (items.isNotEmpty)
              Clipping(
                controller: scope.c,
                bookmark: items.first,
                note: items.length > 1
                    ? tr(
                        context,
                        'and ${items.length - 1} more',
                        'và ${items.length - 1} mục nữa',
                      )
                    : null,
              ),
            const SizedBox(height: HandySpace.l),
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr(context, 'Put it in', 'Cho vào'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const Key('file-shared-new'),
                  onPressed: _busy ? null : _newCollection,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                  label: Text(tr(context, 'New collection', 'Bộ sưu tập mới')),
                ),
              ],
            ),
            const SizedBox(height: HandySpace.xs),
            Flexible(
              child: Material(
                color: p.surface,
                borderRadius: BorderRadius.circular(BookmarkRadii.item),
                clipBehavior: Clip.antiAlias,
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    _Place(
                      key: const Key('file-shared-none'),
                      leading: Icon(Icons.inbox_outlined, color: p.muted),
                      title: tr(context, 'Not sorted', 'Chưa xếp'),
                      subtitle: tr(context, 'Decide later', 'Để sau mới xếp'),
                      selected: _into == null,
                      onTap: () => setState(() => _into = null),
                    ),
                    for (final (col, depth) in tree)
                      _Place(
                        key: Key('file-shared-${col.id}'),
                        depth: depth,
                        leading: CollectionBadge(
                          hue: collectionHue(l, col.id),
                          mark: markOf(col.icon),
                          size: 12,
                        ),
                        title: col.name,
                        subtitle: _count(context, l, col.id),
                        selected: _into == col.id,
                        onTap: () => setState(() => _into = col.id),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: HandySpace.s),
            MergeSemantics(
              child: SwitchListTile.adaptive(
                key: const Key('file-shared-pin'),
                contentPadding: EdgeInsets.zero,
                value: _pin,
                onChanged: (v) => setState(() => _pin = v),
                title: Text(tr(context, 'Pin it', 'Ghim lên đầu')),
                subtitle: Text(
                  tr(
                    context,
                    'Shown first wherever it is',
                    'Luôn hiện đầu tiên ở nơi nó nằm',
                  ),
                ),
              ),
            ),
            const SizedBox(height: HandySpace.s),
            FilledButton(
              key: const Key('file-shared-done'),
              style: sheetButtonStyle(context),
              onPressed: _busy ? null : _done,
              child: Text(
                chosen == null
                    ? tr(context, 'Done', 'Xong')
                    : tr(
                        context,
                        'Put in ${chosen.name}',
                        'Cho vào ${chosen.name}',
                      ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    },
  );

  String _count(BuildContext context, SaveLibrary l, String id) {
    final n = l.bookmarks
        .where((b) => b.collectionId == id && !b.isArchived)
        .length;
    return tr(context, n == 1 ? '1 item' : '$n items', '$n mục');
  }
}

/// One place to put it, chosen like a radio.
class _Place extends StatelessWidget {
  final Widget leading;
  final String title, subtitle;
  final bool selected;
  final int depth;
  final VoidCallback onTap;
  const _Place({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.depth = 0,
  });
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: ListTile(
        onTap: onTap,
        selected: selected,
        selectedTileColor: p.tint,
        contentPadding: EdgeInsetsDirectional.only(
          start: HandySpace.l + depth * 20.0,
          end: HandySpace.m,
        ),
        leading: SizedBox(width: 32, child: Center(child: leading)),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? p.primary : p.muted,
        ),
      ),
    );
  }
}
