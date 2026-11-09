import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../ui/collection_picker.dart';
import '../ui/visual.dart';
import '../ui/words.dart';
import '../view/library_view.dart';
import 'pastel_blocks.dart';

/// Home's one small card of what waits: the saves not sorted yet (Sort
/// quickly, one at a time) and the saves not opened yet (Focus). A row
/// shows only when it has something; with nothing at all, one calm line.
class HomeQueues extends StatelessWidget {
  final SaveScope scope;
  final VoidCallback onFocus;

  /// A wide screen: the two rows side by side in one slim strip.
  final bool across;
  const HomeQueues({
    super.key,
    required this.scope,
    required this.onFocus,
    this.across = false,
  });

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
    final rows = <Widget>[
      if (unsorted.isNotEmpty)
        _QueueRow(
          key: const Key('home-quick-sort'),
          scope: scope,
          strong: true,
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
      if (waiting.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: calm)
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
    ];
    // Not sorted is the job to do, so it sits on the deep band colour;
    // the revisit queue stays on the pale tint.
    Widget card(Widget child) => Material(
      color: _queueField(context, child is _QueueRow && child.strong),
      borderRadius: BorderRadius.circular(BookmarkRadii.item),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
    // Wide: each queue its own card, side by side with air between.
    if (across) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (k, w) in rows.indexed) ...[
              if (k > 0) const SizedBox(width: HandySpace.m),
              Expanded(child: card(w)),
            ],
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (k, w) in rows.indexed) ...[
          if (k > 0) const SizedBox(height: HandySpace.s),
          w is _QueueRow ? card(w) : w,
        ],
      ],
    );
  }
}

/// A queue card's field. Not sorted sits on the deep band colour. On a
/// light ground the revisit queue is the pale teal tint; on a dark one
/// that tint is too close to the band, so it takes a warm terracotta
/// field instead and the two read as different jobs.
Color _queueField(BuildContext context, bool strong) {
  final p = BookmarkPalette.of(context);
  if (strong) return p.band;
  return Theme.of(context).brightness == Brightness.dark
      ? Color.lerp(p.surface, p.warm, .2)!
      : p.tint;
}

class _QueueRow extends StatelessWidget {
  final SaveScope scope;
  final List<Bookmark> faces;
  final String title, subtitle;
  final VoidCallback onTap;

  /// On the deep band colour: white words and a gold arrow.
  final bool strong;
  const _QueueRow({
    super.key,
    this.strong = false,
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
    // Pictures first (a source's icon cut by the next face reads as a
    // stray mark), fewer on narrow screens so the words keep their room.
    final shown = [
      ...faces.where(hasPicture),
      ...faces.where((b) => !hasPicture(b)),
    ].take(MediaQuery.sizeOf(context).width < 360 ? 1 : 3).toList();
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Row(
            children: [
              SizedBox(
                width: 44.0 + 26 * (shown.length - 1),
                height: 44,
                child: Stack(
                  children: [
                    for (final (i, b) in shown.indexed.toList().reversed)
                      Positioned(
                        left: 26.0 * i,
                        child: Container(
                          width: 44,
                          height: 44,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: _queueField(context, strong),
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
                        fontWeight: FontWeight.w700,
                        color: strong ? p.bandInk : p.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: strong ? p.bandSub : p.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                color: strong
                    ? p.gold
                    : Theme.of(context).brightness == Brightness.dark
                    ? p.warm
                    : p.pressed,
              ),
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

  /// The save just filed and where it went, for the line with Undo.
  ({Bookmark before, String into})? last;

  List<Bookmark> get left => [
    for (final b in widget.scope.library.bookmarks)
      if (!b.isArchived && b.collectionId == null && !skipped.contains(b.id)) b,
  ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));

  Future<void> _file(Bookmark b, String id, String name) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await widget.scope.file(b, id);
      sorted++;
      last = (before: b, into: name);
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        HapticFeedback.selectionClick();
      }
    } catch (_) {
      // Nothing moved; the save stays on screen.
    }
    if (mounted) setState(() => busy = false);
  }

  /// Puts the last save back where it was (not sorted).
  Future<void> _undo() async {
    final l = last;
    if (l == null || busy) return;
    setState(() => busy = true);
    try {
      await widget.scope.put(l.before);
      sorted--;
      last = null;
    } catch (_) {
      // It stays filed; the line still offers Undo.
    }
    if (mounted) setState(() => busy = false);
  }

  void _skip(Bookmark b) => setState(() {
    skipped.add(b.id);
    last = null;
  });

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
        final done = last == null
            ? null
            : Padding(
                key: const Key('quick-sort-done'),
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: p.tint,
                  borderRadius: BorderRadius.circular(BookmarkRadii.item),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, size: 20, color: p.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tr(
                              context,
                              'Put in ${last!.into}',
                              'Đã cho vào ${last!.into}',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          key: const Key('quick-sort-undo'),
                          onPressed: busy ? null : _undo,
                          child: Text(tr(context, 'Undo', 'Hoàn tác')),
                        ),
                      ],
                    ),
                  ),
                ),
              );
        if (rest.isEmpty) {
          return SafeArea(
            child: Padding(
              key: const Key('quick-sort'),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?done,
                  Text(
                    tr(context, 'All sorted.', 'Đã xếp xong.'),
                    key: const Key('quick-sort-all-done'),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('quick-sort-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(tr(context, 'Done', 'Xong')),
                  ),
                ],
              ),
            ),
          );
        }
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
                ?done,
                // The next save slides in as the last one goes.
                HandySwap(
                  child: KeyedSubtree(
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
                        onTap: () => _file(b, c.id, c.name),
                      ),
                    FileChip(
                      key: Key('file-${b.id}-other'),
                      onTap: () async {
                        await scope.move(context, b);
                        if (mounted) setState(() => last = null);
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
