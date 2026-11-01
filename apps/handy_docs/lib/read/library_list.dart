import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_ui/kit.dart';
import 'reader_actions.dart';

/// The library, most recently read first, narrowed by star or folder.
class LibraryList extends StatefulWidget {
  final ReaderActions actions;
  final ValueChanged<ReaderDocument> onOpen;
  const LibraryList({super.key, required this.actions, required this.onOpen});
  @override
  State<LibraryList> createState() => _LibraryListState();
}

class _LibraryListState extends State<LibraryList> {
  /// '' is everything, '*' starred, anything else a folder.
  String filter = '';

  static IconData icon(String kind) => switch (kind) {
    'markdown' => Icons.notes,
    'html' => Icons.public,
    'code' => Icons.code,
    _ => Icons.description_outlined,
  };

  static String opened(BuildContext context, String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    final now = DateTime.now();
    final days = DateTime(
      d.year,
      d.month,
      d.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    return days > -7 ? relativeDays(context, days) : formatDay(context, iso);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.actions.store;
    final folders = store.folders;
    if (filter != '' && filter != '*' && !folders.contains(filter)) filter = '';
    final shown = store.recent.where(
      (d) => switch (filter) {
        '' => true,
        '*' => d.favorite,
        final f => d.folder == f,
      },
    );
    final current = store.saved ? store.current?.id : null;
    final c = HandyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (store.recent.any((d) => d.favorite) || folders.isNotEmpty)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: HandySpace.l),
              children: [
                for (final (value, label) in [
                  ('', tr(context, 'All', 'Tất cả')),
                  ('*', tr(context, 'Starred', 'Gắn sao')),
                  for (final f in folders) (f, f),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: HandySpace.s),
                    child: ChoiceChip(
                      key: Key('reader-filter-$value'),
                      avatar: folders.contains(value)
                          ? HandyDot(folders.indexOf(value))
                          : null,
                      label: Text(label),
                      selected: filter == value,
                      onSelected: (_) => setState(() => filter = value),
                    ),
                  ),
              ],
            ),
          ),
        for (final d in shown)
          Material(
            color: d.id == current ? c.select : Colors.transparent,
            child: HandyTile(
              key: Key('reader-open-${d.id}'),
              icon: icon(d.kind),
              hue: d.folder.isEmpty ? null : folders.indexOf(d.folder),
              title: d.name,
              subtitle: [
                if (d.folder.isNotEmpty) d.folder,
                opened(context, d.lastOpenedAt),
              ].join(' · '),
              trailing: d.favorite
                  ? Icon(
                      Icons.star,
                      size: 18,
                      semanticLabel: tr(context, 'Starred', 'Gắn sao'),
                      color: c.muted,
                    )
                  : null,
              onTap: () => widget.onOpen(d),
            ),
          ),
      ],
    );
  }
}
