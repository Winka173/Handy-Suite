import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../ui/words.dart';
import '../view/library_view.dart';

/// The orders a list can be shown in; Newest first is the default.
const listSorts = [
  'newest',
  'oldest',
  'recentlyOpened',
  'mostOpened',
  'title',
  'domain',
];

String sortName(BuildContext c, String s) => switch (s) {
  'oldest' => tr(c, 'Oldest first', 'Cũ nhất trước'),
  'recentlyOpened' => tr(c, 'Recently opened', 'Mở gần đây'),
  'mostOpened' => tr(c, 'Most opened', 'Mở nhiều nhất'),
  'title' => tr(c, 'Title A–Z', 'Tên A–Z'),
  'domain' => tr(c, 'Website', 'Theo trang web'),
  // Kept for searches saved before 2026-11-03, when hand order was dropped.
  'manual' => tr(c, 'Your order', 'Thứ tự tự xếp'),
  _ => tr(c, 'Newest first', 'Mới nhất trước'),
};

/// A source's name for a filter: its known name, else the platform's own
/// (Shopee), and "Websites" only for plain pages, so no two chips read alike.
String sourceLabel(BuildContext c, String s) {
  if (sourceName(s).isNotEmpty) return sourceName(s);
  if (s.isEmpty || s == 'web') return tr(c, 'Websites', 'Trang web');
  return s[0].toUpperCase() + s.substring(1);
}

/// The start of the day [days] ago, as the store compares it.
String savedSince(int days) {
  final d = DateTime.now().subtract(Duration(days: days));
  return DateTime(d.year, d.month, d.day).toUtc().toIso8601String();
}

/// The list's order, as one menu: the current order is its label.
class SortButton extends StatelessWidget {
  final LibraryView view;
  const SortButton({super.key, required this.view});
  @override
  Widget build(BuildContext context) {
    final now = view.filters.sort;
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return PopupMenuButton<String>(
      key: const Key('save-sort'),
      tooltip: tr(context, 'Order', 'Thứ tự'),
      position: PopupMenuPosition.under,
      initialValue: now,
      onSelected: (s) => view.filter(view.filters.withSort(s)),
      itemBuilder: (context) => [
        for (final s in [
          ...listSorts,
          // A search saved in the person's own order keeps it on offer.
          if (!listSorts.contains(now)) now,
        ])
          PopupMenuItem<String>(
            key: Key('sort-$s'),
            value: s,
            height: 44,
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: s == now
                      ? Icon(Icons.check, size: 18, color: c.accent)
                      : null,
                ),
                Flexible(
                  child: Text(
                    sortName(context, s),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: HandySpace.s),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_vert, size: 20, color: c.muted),
              const SizedBox(width: HandySpace.xs),
              Flexible(
                child: Text(
                  sortName(context, now),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Narrows the list: when it was saved, its source, kind and tag. Choices
/// apply at once. The order has its own menu ([SortButton]).
Future<void> showFilterSheet(
  BuildContext context,
  SaveLibrary l,
  LibraryView v,
) {
  final sources = {for (final b in l.bookmarks) b.platform}.toList()..sort();
  final kinds = {for (final b in l.bookmarks) b.contentType}.toList()..sort();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => ListenableBuilder(
      listenable: v,
      builder: (context, _) {
        final f = v.filters;
        Filters with_({
          String? platform,
          String? contentType,
          String? tag,
          String? sort,
          bool clearPlatform = false,
          bool clearKind = false,
          bool clearTag = false,
        }) => Filters(
          platform: clearPlatform ? null : (platform ?? f.platform),
          contentType: clearKind ? null : (contentType ?? f.contentType),
          tag: clearTag ? null : (tag ?? f.tag),
          kind: f.kind,
          sort: sort ?? f.sort,
          savedAfter: f.savedAfter,
          savedBefore: f.savedBefore,
        );
        Widget group(String title, List<Widget> chips) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: HandySpace.l),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: HandySpace.s),
            Wrap(
              spacing: HandySpace.s,
              runSpacing: HandySpace.s,
              children: chips,
            ),
          ],
        );
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .8,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, HandySpace.l),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(context, 'Filter', 'Lọc'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      key: const Key('filter-reset'),
                      // The order is not a filter; it stays.
                      onPressed: f.narrows
                          ? () => v.filter(Filters(sort: f.sort))
                          : null,
                      child: Text(tr(context, 'Reset', 'Đặt lại')),
                    ),
                  ],
                ),
                group(tr(context, 'Saved', 'Lưu trong'), [
                  for (final (days, label) in [
                    (0, tr(context, 'Any time', 'Mọi lúc')),
                    (7, tr(context, 'Last 7 days', '7 ngày qua')),
                    (30, tr(context, 'Last 30 days', '30 ngày qua')),
                    (365, tr(context, 'Last year', '1 năm qua')),
                  ])
                    ChoiceChip(
                      key: Key('saved-$days'),
                      label: Text(label),
                      selected: days == 0
                          ? f.savedAfter == null
                          : f.savedAfter == savedSince(days),
                      showCheckmark: false,
                      onSelected: (_) => v.filter(
                        Filters(
                          platform: f.platform,
                          contentType: f.contentType,
                          tag: f.tag,
                          kind: f.kind,
                          sort: f.sort,
                          savedAfter: days == 0 ? null : savedSince(days),
                        ),
                      ),
                    ),
                ]),
                if (sources.length > 1)
                  group(tr(context, 'From', 'Nguồn'), [
                    for (final s in sources)
                      ChoiceChip(
                        key: Key('source-$s'),
                        label: Text(sourceLabel(context, s)),
                        selected: f.platform == s,
                        showCheckmark: false,
                        onSelected: (on) => v.filter(
                          on ? with_(platform: s) : with_(clearPlatform: true),
                        ),
                      ),
                  ]),
                if (kinds.length > 1)
                  group(tr(context, 'Kind', 'Loại'), [
                    for (final k in kinds)
                      ChoiceChip(
                        key: Key('kind-$k'),
                        label: Text(kindName(context, k)),
                        selected: f.contentType == k,
                        showCheckmark: false,
                        onSelected: (on) => v.filter(
                          on ? with_(contentType: k) : with_(clearKind: true),
                        ),
                      ),
                  ]),
                if (l.tags.isNotEmpty)
                  group(tr(context, 'Tag', 'Thẻ'), [
                    for (final t in l.tags.take(40))
                      ChoiceChip(
                        key: Key('tag-$t'),
                        label: Text('#$t'),
                        selected: f.tag == t,
                        showCheckmark: false,
                        onSelected: (on) => v.filter(
                          on ? with_(tag: t) : with_(clearTag: true),
                        ),
                      ),
                  ]),
                const SizedBox(height: HandySpace.xl),
                // Choices apply at once; this only closes the sheet.
                FilledButton(
                  key: const Key('filter-done'),
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr(context, 'Done', 'Xong')),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// The filters in force, each with a way to drop it.
class FilterChips extends StatelessWidget {
  final LibraryView view;
  const FilterChips({super.key, required this.view});
  @override
  Widget build(BuildContext context) {
    final f = view.filters;
    Filters drop({
      bool platform = false,
      bool kind = false,
      bool tag = false,
      bool saved = false,
    }) => Filters(
      platform: platform ? null : f.platform,
      contentType: kind ? null : f.contentType,
      tag: tag ? null : f.tag,
      kind: f.kind,
      sort: f.sort,
      savedAfter: saved ? null : f.savedAfter,
      savedBefore: f.savedBefore,
    );
    return Wrap(
      spacing: HandySpace.s,
      runSpacing: HandySpace.s,
      children: [
        if (f.platform != null)
          InputChip(
            label: Text(sourceLabel(context, f.platform!)),
            onDeleted: () => view.filter(drop(platform: true)),
          ),
        if (f.contentType != null)
          InputChip(
            label: Text(kindName(context, f.contentType!)),
            onDeleted: () => view.filter(drop(kind: true)),
          ),
        if (f.tag != null)
          InputChip(
            label: Text('#${f.tag}'),
            onDeleted: () => view.filter(drop(tag: true)),
          ),
        if (f.savedAfter != null)
          InputChip(
            label: Text(
              tr(
                context,
                'Saved since ${formatDay(context, DateTime.parse(f.savedAfter!).toLocal().toIso8601String().substring(0, 10))}',
                'Lưu từ ${formatDay(context, DateTime.parse(f.savedAfter!).toLocal().toIso8601String().substring(0, 10))}',
              ),
            ),
            onDeleted: () => view.filter(drop(saved: true)),
          ),
      ],
    );
  }
}
