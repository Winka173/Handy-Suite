import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../ui/collection_picker.dart';
import '../ui/visual.dart';
import '../ui/words.dart';
import 'pastel_blocks.dart';

/// Home's one small card of what waits: the saves not sorted yet (Sort
/// quickly, one at a time) and the saves not opened yet (Focus). A row
/// shows only when it has something; with nothing at all, one calm line.
class HomeQueues extends StatelessWidget {
  final SaveScope scope;
  final VoidCallback onFocus;
  const HomeQueues({super.key, required this.scope, required this.onFocus});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    List<Bookmark> newest(bool Function(Bookmark) keep) => [
      for (final b in scope.library.bookmarks)
        if (!b.isArchived && keep(b)) b,
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final unsorted = newest((b) => b.collectionId == null);
    final waiting = newest((b) => !b.isRead);
    final calm = Semantics(
      button: true,
      child: InkWell(
        key: const Key('place-focus'),
        borderRadius: BorderRadius.circular(BookmarkRadii.item),
        onTap: onFocus,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, size: 20, color: p.sage),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr(
                    context,
                    'All caught up. Nothing waiting in Focus.',
                    'Đã xem hết. Không còn gì chờ trong Tập trung.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (unsorted.isEmpty && waiting.isEmpty) return calm;
    String n(int v) => formatFigure(context, '$v');
    return Material(
      color: p.tint,
      borderRadius: BorderRadius.circular(BookmarkRadii.item),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (unsorted.isNotEmpty)
            _QueueRow(
              key: const Key('home-quick-sort'),
              scope: scope,
              faces: unsorted,
              title: tr(
                context,
                unsorted.length == 1
                    ? '1 save not sorted'
                    : '${n(unsorted.length)} saves not sorted',
                '${n(unsorted.length)} mục chưa xếp',
              ),
              subtitle: tr(
                context,
                'Sort quickly, one at a time',
                'Xếp nhanh, từng mục một',
              ),
              onTap: () => showQuickSort(context, scope),
            ),
          if (unsorted.isNotEmpty)
            Divider(
              height: 1,
              indent: 12,
              endIndent: 12,
              color: p.primary.withValues(alpha: .16),
            ),
          if (waiting.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: calm,
            )
          else
            _QueueRow(
              key: const Key('place-focus'),
              scope: scope,
              faces: waiting,
              title: tr(
                context,
                waiting.length == 1
                    ? '1 thing waiting to revisit'
                    : '${n(waiting.length)} things waiting to revisit',
                '${n(waiting.length)} mục chờ bạn xem lại',
              ),
              subtitle: tr(
                context,
                'One at a time, in Focus',
                'Từng mục một, trong Tập trung',
              ),
              onTap: onFocus,
            ),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  final SaveScope scope;
  final List<Bookmark> faces;
  final String title, subtitle;
  final VoidCallback onTap;
  const _QueueRow({
    super.key,
    required this.scope,
    required this.faces,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    // Fewer faces on narrow screens, so the words keep their room.
    final shown = faces
        .take(MediaQuery.sizeOf(context).width < 360 ? 1 : 3)
        .toList();
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          child: Row(
            children: [
              SizedBox(
                width: 44.0 + 20 * (shown.length - 1),
                height: 44,
                child: Stack(
                  children: [
                    for (final (i, b) in shown.indexed.toList().reversed)
                      Positioned(
                        left: 20.0 * i,
                        child: Container(
                          width: 44,
                          height: 44,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: p.tint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ItemPicture(
                            scope.c,
                            b,
                            radius: 10,
                            compact: true,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: p.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: p.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sort quickly: the saves not sorted yet, one at a time, newest first.
/// One tap on a collection files it and the next one comes; Skip leaves it
/// for later. A failed write keeps the save where it was, on screen.
Future<void> showQuickSort(BuildContext context, SaveScope scope) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _QuickSort(scope: scope),
    );

class _QuickSort extends StatefulWidget {
  final SaveScope scope;
  const _QuickSort({required this.scope});
  @override
  State<_QuickSort> createState() => _QuickSortState();
}

class _QuickSortState extends State<_QuickSort> {
  final skipped = <String>{};
  int sorted = 0;
  bool busy = false;

  List<Bookmark> get left => [
    for (final b in widget.scope.library.bookmarks)
      if (!b.isArchived && b.collectionId == null && !skipped.contains(b.id)) b,
  ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));

  Future<void> _file(Bookmark b, String id) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.scope.file(b, id);
      sorted++;
    } catch (_) {
      // Nothing moved; the save stays on screen.
    }
    if (!mounted) return;
    setState(() => busy = false);
    if (left.isEmpty) Navigator.of(context).pop();
  }

  void _skip(Bookmark b) {
    setState(() => skipped.add(b.id));
    if (left.isEmpty) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scope = widget.scope;
    return ListenableBuilder(
      listenable: scope.c,
      builder: (context, _) {
        final theme = Theme.of(context);
        final p = BookmarkPalette.of(context);
        final l = scope.library;
        final rest = left;
        if (rest.isEmpty) return const SizedBox(height: 120);
        final b = rest.first;
        final total = rest.length + sorted + skipped.length;
        return SafeArea(
          child: Padding(
            key: const Key('quick-sort'),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(context, 'Sort quickly', 'Xếp nhanh'),
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    Text(
                      '${formatFigure(context, '${sorted + skipped.length + 1}')}/${formatFigure(context, '$total')}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: p.muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                KeyedSubtree(
                  key: Key('quick-sort-item-${b.id}'),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 72,
                        child: ItemPicture(scope.c, b, compact: true),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.title.isEmpty ? b.sourceDomain : b.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              b.isImage
                                  ? tr(context, 'Picture', 'Ảnh')
                                  : sourceLine(b),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: p.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  tr(context, 'Put it in', 'Cho vào'),
                  style: theme.textTheme.labelLarge?.copyWith(color: p.muted),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final c in usualCollections(l, take: 4))
                      FileChip(
                        key: Key('file-${b.id}-${c.id}'),
                        collection: c,
                        hue: collectionHue(l, c.id),
                        onTap: () => _file(b, c.id),
                      ),
                    FileChip(
                      key: Key('file-${b.id}-other'),
                      onTap: () async {
                        await scope.move(context, b);
                        if (mounted && left.isEmpty) {
                          Navigator.of(this.context).pop();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    key: const Key('quick-sort-skip'),
                    onPressed: () => _skip(b),
                    child: Text(tr(context, 'Skip', 'Bỏ qua')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
