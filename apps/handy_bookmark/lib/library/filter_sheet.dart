import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../ui/words.dart';
import '../view/library_view.dart';

const _sorts = [
  'newest',
  'oldest',
  'recentlyOpened',
  'mostOpened',
  'title',
  'domain',
  'manual',
];

String sortName(BuildContext c, String s) => switch (s) {
  'oldest' => tr(c, 'Oldest first', 'Cũ nhất trước'),
  'recentlyOpened' => tr(c, 'Recently opened', 'Mở gần đây'),
  'mostOpened' => tr(c, 'Most opened', 'Mở nhiều nhất'),
  'title' => tr(c, 'Title A–Z', 'Tên A–Z'),
  'domain' => tr(c, 'Website', 'Theo trang web'),
  'manual' => tr(c, 'Your order', 'Thứ tự tự xếp'),
  _ => tr(c, 'Newest first', 'Mới nhất trước'),
};

/// The start of the day [days] ago, as the store compares it.
String savedSince(int days) {
  final d = DateTime.now().subtract(Duration(days: days));
  return DateTime(d.year, d.month, d.day).toUtc().toIso8601String();
}

/// Narrows the list: source, kind, tag, and order. Choices apply at once.
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
          sort: sort ?? f.sort,
          savedAfter: f.savedAfter,
        );
        Widget group(String title, List<Widget> chips) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: HandySpace.l),
            Text(title, style: Theme.of(context).textTheme.titleSmall),
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
              padding: const EdgeInsets.fromLTRB(
                HandySpace.l,
                0,
                HandySpace.l,
                HandySpace.xl,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(context, 'Filter and sort', 'Lọc và sắp xếp'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      key: const Key('filter-reset'),
                      onPressed: f.any ? () => v.filter(const Filters()) : null,
                      child: Text(tr(context, 'Reset', 'Đặt lại')),
                    ),
                  ],
                ),
                group(tr(context, 'Order', 'Thứ tự'), [
                  for (final s in _sorts)
                    ChoiceChip(
                      key: Key('sort-$s'),
                      label: Text(sortName(context, s)),
                      selected: f.sort == s,
                      showCheckmark: false,
                      onSelected: (_) => v.filter(with_(sort: s)),
                    ),
                ]),
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
                        label: Text(
                          sourceName(s).isEmpty
                              ? tr(context, 'Websites', 'Trang web')
                              : sourceName(s),
                        ),
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
      bool sort = false,
      bool saved = false,
    }) => Filters(
      platform: platform ? null : f.platform,
      contentType: kind ? null : f.contentType,
      tag: tag ? null : f.tag,
      sort: sort ? 'newest' : f.sort,
      savedAfter: saved ? null : f.savedAfter,
    );
    return Wrap(
      spacing: HandySpace.s,
      runSpacing: HandySpace.s,
      children: [
        if (f.platform != null)
          InputChip(
            label: Text(
              sourceName(f.platform!).isEmpty
                  ? f.platform!
                  : sourceName(f.platform!),
            ),
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
        if (f.sort != 'newest')
          InputChip(
            label: Text(sortName(context, f.sort)),
            onDeleted: () => view.filter(drop(sort: true)),
          ),
      ],
    );
  }
}
