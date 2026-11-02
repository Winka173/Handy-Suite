import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';

/// Where a word turns up in one kept file: how often, and the first place
/// with a little of the text around it.
class DocHit {
  final ReaderDocument doc;
  final int count;
  final bool inName;
  final String before, match, after;
  const DocHit(
    this.doc,
    this.count,
    this.inName,
    this.before,
    this.match,
    this.after,
  );
}

/// [s] folded for matching: lower case, accents off ("hop dong" finds
/// "Hợp đồng"). Kept the same length so a place in it is a place in [s].
String foldForSearch(String s) {
  final folded = foldAccents(s);
  return folded.length == s.length ? folded : s.toLowerCase();
}

/// The kept files that hold [query], most matches first. [folded] caches
/// each file's folded text between keystrokes.
List<DocHit> searchKept(
  Iterable<ReaderDocument> docs,
  String query, {
  Map<String, (String, String)>? folded,
}) {
  final q = foldForSearch(query.trim());
  if (q.length < 2) return const [];
  final hits = <DocHit>[];
  for (final d in docs) {
    final cached = folded?[d.id];
    final text = cached != null && identical(cached.$1, d.source)
        ? cached.$2
        : foldForSearch(d.source);
    folded?[d.id] = (d.source, text);
    var count = 0, first = -1;
    for (var at = text.indexOf(q); at >= 0; at = text.indexOf(q, at + 1)) {
      if (first < 0) first = at;
      if (++count == 999) break;
    }
    final inName = foldForSearch(d.name).contains(q);
    if (count == 0 && !inName) continue;
    final source = d.source.length == text.length ? d.source : text;
    String clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ');
    hits.add(
      first < 0
          ? DocHit(d, 0, true, '', '', '')
          : DocHit(
              d,
              count,
              inName,
              clean(source.substring((first - 48).clamp(0, first), first)),
              source.substring(first, first + q.length),
              clean(
                source.substring(
                  first + q.length,
                  (first + q.length + 72).clamp(0, source.length),
                ),
              ),
            ),
    );
  }
  hits.sort((a, b) {
    if (a.inName != b.inName) return a.inName ? -1 : 1;
    return b.count.compareTo(a.count);
  });
  return hits;
}

/// The desk's search: one field over every kept file, words matched
/// without minding accents, each hit shown in its sentence.
class DeskSearch extends StatefulWidget {
  final DocsScope scope;
  final VoidCallback onOpened;
  const DeskSearch({super.key, required this.scope, required this.onOpened});
  @override
  State<DeskSearch> createState() => _DeskSearchState();
}

class _DeskSearchState extends State<DeskSearch> {
  final folded = <String, (String, String)>{};
  String query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final docs = widget.scope.reader.store.recent;
    final hits = searchKept(docs, query, folded: folded);
    final searching = query.trim().length >= 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandySearchField(
          key: const Key('desk-search'),
          hint: tr(
            context,
            'Find words in ${docs.length} kept files',
            'Tìm chữ trong ${docs.length} tệp đã giữ',
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        if (searching)
          Semantics(
            liveRegion: true,
            child: HandyLabel(
              hits.isEmpty
                  ? tr(context, 'No kept file has it', 'Không tệp nào có')
                  : tr(
                      context,
                      'In ${hits.length} files',
                      'Có trong ${hits.length} tệp',
                    ),
            ),
          ),
        if (searching && hits.isNotEmpty)
          HandyGroup(
            children: [
              for (final h in hits.take(20))
                ListTile(
                  key: Key('desk-hit-${h.doc.id}'),
                  title: Text(h.doc.name),
                  subtitle: h.count == 0
                      ? null
                      : Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: h.before.isEmpty ? '' : '…${h.before}',
                              ),
                              TextSpan(
                                text: h.match,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: c.accent,
                                  decorationThickness: 2,
                                ),
                              ),
                              TextSpan(text: '${h.after}…'),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: h.count < 2
                      ? null
                      : Text(
                          tr(context, '${h.count}×', '${h.count} chỗ'),
                          style: theme.textTheme.bodySmall,
                        ),
                  onTap: () async {
                    final ok = await widget.scope.reader.open(context, h.doc);
                    if (ok && context.mounted) widget.onOpened();
                  },
                ),
            ],
          ),
      ],
    );
  }
}
