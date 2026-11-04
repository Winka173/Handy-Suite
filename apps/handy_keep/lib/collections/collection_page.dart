import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/words.dart';
import 'collection_actions.dart';
import 'shelf.dart' show CoverTile;

/// One collection as a gallery: how far it is, then its items' covers, the
/// owned first in the person's order, the wanted ones after them, marked.
/// Its question: "what do I have, and what is still missing?"
class CollectionPage extends StatelessWidget {
  final KeepScope scope;
  final String id;
  const CollectionPage({super.key, required this.scope, required this.id});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.store,
    builder: (context, _) {
      final s = scope.state;
      final col = s.collections.where((c) => c.id == id).firstOrNull;
      if (col == null) {
        return HandyPage(
          title: tr(context, 'Collection', 'Bộ sưu tập'),
          children: [
            HandyEmpty(
              title: tr(
                context,
                'This collection is not here',
                'Không có bộ sưu tập này',
              ),
              message: tr(
                context,
                'It may have been removed. Its items are still in Keep.',
                'Có thể bộ đã bị bỏ. Các món vẫn ở trong Keep.',
              ),
            ),
          ],
        );
      }
      return _Gallery(scope: scope, col: col);
    },
  );
}

class _Gallery extends StatelessWidget {
  final KeepScope scope;
  final InventoryCollection col;
  const _Gallery({required this.scope, required this.col});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final s = scope.state;
    final done = collectionCompletion(s, col.id);
    final all = collectionItems(s, col.id);
    final owned = all.where((a) => a.owned).toList();
    final wanted = all.where((a) => !a.owned).toList();
    final hue = col.hue < 0 ? null : col.hue;
    return HandyPage(
      title: col.name,
      actions: [
        IconButton(
          key: const Key('collection-edit'),
          tooltip: tr(context, 'Edit collection', 'Sửa bộ sưu tập'),
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => scope.editCollection(context, old: col),
        ),
        HandyMenuButton(
          key: const Key('collection-menu'),
          items: [
            if (isSample(col.id))
              HandyMenuItem(
                Icons.delete_sweep_outlined,
                tr(context, 'Remove the sample', 'Gỡ bộ mẫu'),
                () async {
                  await scope.removeSample(context);
                  if (context.mounted) Navigator.pop(context);
                },
                key: const Key('sample-remove'),
              ),
            HandyMenuItem(
              Icons.delete_outline,
              tr(context, 'Remove collection', 'Bỏ bộ sưu tập'),
              () async {
                if (await scope.deleteCollection(context, col) &&
                    context.mounted) {
                  Navigator.pop(context);
                }
              },
              key: const Key('collection-delete'),
              destructive: true,
            ),
          ],
        ),
      ],
      bottom: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('collection-add-wanted'),
              onPressed: () =>
                  scope.edit(context, collections: [col.id], status: 'wanted'),
              icon: const Icon(Icons.favorite_border),
              label: Text(tr(context, 'Want one', 'Muốn có')),
            ),
          ),
          const SizedBox(width: HandySpace.m),
          Expanded(
            child: FilledButton.icon(
              key: const Key('collection-add'),
              onPressed: () => scope.edit(context, collections: [col.id]),
              icon: const Icon(Icons.add),
              label: Text(tr(context, 'Add one', 'Thêm món')),
            ),
          ),
        ],
      ),
      children: [
        Row(
          children: [
            if (hue != null) ...[HandyDot(hue), const SizedBox(width: 6)],
            Expanded(
              child: Text(
                kindLabel(context, col.kind),
                style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: HandySpace.m),
        // The answer first: how many are here and, with a target, how many
        // are still to find.
        Text(
          done.target > 0
              ? tr(
                  context,
                  '${done.owned} of ${done.target}',
                  '${done.owned}/${done.target}',
                )
              : itemCount(context, done.owned),
          key: const Key('collection-count'),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          [
            completionLine(context, done),
            if (done.target > 0)
              done.missing == 0
                  ? tr(context, 'complete', 'đã đủ bộ')
                  : tr(
                      context,
                      '${done.missing} still to find',
                      'còn thiếu ${done.missing}',
                    ),
          ].join(' · '),
          style: theme.textTheme.bodyMedium,
        ),
        if (done.target > 0) ...[
          const SizedBox(height: HandySpace.s),
          Semantics(
            label: tr(
              context,
              '${done.owned} of ${done.target} owned',
              'Đã có ${done.owned}/${done.target}',
            ),
            child: LinearProgressIndicator(
              value: (done.owned / done.target).clamp(0, 1).toDouble(),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
              color: hue == null ? null : HandyPalette.of(context, hue).mark,
            ),
          ),
        ],
        if (isSample(col.id)) ...[
          const SizedBox(height: HandySpace.l),
          HandyNotice(
            tr(
              context,
              'A sample to try things with. Remove it from the ⋯ menu.',
              'Bộ mẫu để thử. Gỡ ở menu ⋯.',
            ),
          ),
        ],
        const SizedBox(height: HandySpace.l),
        if (all.isEmpty)
          HandyEmpty(
            title: tr(context, 'Nothing in it yet', 'Bộ chưa có món nào'),
            message: tr(
              context,
              'Add what you have, and what you still want, so the shelf shows what is missing.',
              'Thêm món đã có và món còn muốn, để kệ cho thấy còn thiếu gì.',
            ),
          )
        else ...[
          _Grid(scope: scope, items: owned, hue: hue),
          if (wanted.isNotEmpty) ...[
            HandyLabel(tr(context, 'Still wanted', 'Còn muốn có')),
            _Grid(scope: scope, items: wanted, hue: hue),
          ],
        ],
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  final KeepScope scope;
  final List<InventoryAsset> items;
  final int? hue;
  const _Grid({required this.scope, required this.items, this.hue});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns = (box.maxWidth / 150).floor().clamp(2, 8);
      final size = (box.maxWidth - (columns - 1) * HandySpace.m) / columns;
      return Wrap(
        spacing: HandySpace.m,
        runSpacing: HandySpace.l,
        children: [
          for (final a in items)
            _Tile(scope: scope, item: a, size: size, hue: hue),
        ],
      );
    },
  );
}

class _Tile extends StatelessWidget {
  final KeepScope scope;
  final InventoryAsset item;
  final double size;
  final int? hue;
  const _Tile({
    required this.scope,
    required this.item,
    required this.size,
    this.hue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final a = item;
    final detail = a.owned
        ? [a.series, a.number, a.variant].where((t) => t.isNotEmpty).join(' · ')
        : a.status == 'ordered'
        ? tr(context, 'On order', 'Đang đặt')
        : tr(context, 'Wanted', 'Muốn có');
    return SizedBox(
      width: size,
      child: InkWell(
        key: Key('collection-item-${a.id}'),
        onTap: () => Navigator.pushNamed(context, '/item/${a.id}'),
        borderRadius: BorderRadius.circular(HandyRadius.control),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Not here yet: the cover is faded, and the line says so.
            Opacity(
              opacity: a.owned ? 1 : 0.45,
              child: CoverTile(
                item: a,
                blobs: scope.store.library!.blobs,
                size: size,
                hue: hue,
              ),
            ),
            const SizedBox(height: HandySpace.s),
            Text(
              a.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
            if (detail.isNotEmpty)
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
              ),
          ],
        ),
      ),
    );
  }
}
