import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../design/theme.dart';
import '../pro/entitlements.dart';
import '../reader/highlights_sheet.dart';
import '../scope.dart';
import '../ui/visual.dart';

/// The text of the saved offline articles, read once when Search opens.
class DeepIndex extends ChangeNotifier {
  final SaveController c;
  DeepIndex(this.c);
  Map<String, String> articles = const {};
  bool ready = false;

  Future<void> load() async {
    try {
      final copies = await c.allReadingCopies();
      articles = {
        for (final e in copies.entries)
          e.key: [for (final b in e.value.blocks) b.text].join('\n'),
      };
    } catch (_) {
      articles = const {};
    }
    ready = true;
    notifyListeners();
  }
}

/// Text read from the person's pictures on this device, by item id.
Map<String, String> pictureTexts(SaveController c) => {
  for (final e in ((c.preferences['ocrText'] as Map?) ?? const {}).entries)
    if (e.key is String && e.value is String)
      e.key as String: e.value as String,
};

/// Under the ordinary results: items found by words inside them (an
/// offline article, a highlight or its note, a picture's text), each with
/// where it was found. Pro; Free sees only how many there are.
class DeepMatches extends StatelessWidget {
  final SaveScope scope;
  final DeepIndex index;
  const DeepMatches({super.key, required this.scope, required this.index});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([scope.view, index, scope.c]),
    builder: (context, _) {
      final v = scope.view;
      final q = v.text.trim();
      if (q.length < 2 || !index.ready) return const SizedBox.shrink();
      final l = scope.library;
      final live = {
        for (final b in l.bookmarks)
          if (!b.isArchived &&
              (v.filters.kind == null || b.kind == v.filters.kind))
            b.id: b,
      };
      final found = {
        for (final b in searchBookmarks(
          l,
          SearchQuery(text: q, isArchived: false),
        ))
          b.id,
      };
      final marks = readHighlights(
        scope.c.preferences['highlights'],
        live.keys,
      );
      final hits = deepSearch(
        q,
        articles: {
          for (final e in index.articles.entries)
            if (live.containsKey(e.key)) e.key: e.value,
        },
        highlights: marks,
        pictureText: {
          for (final e in pictureTexts(scope.c).entries)
            if (live.containsKey(e.key)) e.key: e.value,
        },
        exclude: found,
      );
      if (hits.isEmpty) return const SizedBox.shrink();
      final theme = Theme.of(context);
      final p = BookmarkPalette.of(context);
      if (!hasPro(context)) {
        return Padding(
          padding: const EdgeInsets.only(top: HandySpace.l),
          child: Material(
            color: p.surface,
            borderRadius: BorderRadius.circular(BookmarkRadii.item),
            child: ListTile(
              key: const Key('deep-locked'),
              leading: const Icon(Icons.manage_search_rounded),
              title: Text(
                tr(
                  context,
                  hits.length == 1
                      ? '1 more inside your articles, highlights or pictures'
                      : '${hits.length} more inside your articles, highlights or pictures',
                  'Thêm ${hits.length} mục trong bài đã lưu, đoạn đánh dấu hoặc ảnh',
                ),
              ),
              trailing: Text('Pro', style: theme.textTheme.labelLarge),
              onTap: () => requirePro(context, ProFeature.deepSearch),
            ),
          ),
        );
      }
      return Column(
        key: const Key('deep-matches'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: HandySpace.l),
          SectionHead(tr(context, 'Found inside', 'Tìm thấy bên trong')),
          for (final h in hits.take(30))
            if (live[h.id] case final b?)
              InkWell(
                key: Key('deep-${h.id}'),
                borderRadius: BorderRadius.circular(BookmarkRadii.item),
                onTap: () => Navigator.pushNamed(
                  context,
                  h.source == DeepSource.picture
                      ? '/bookmark/${b.id}'
                      : '/read/${b.id}',
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: ItemPicture(scope.c, b, compact: true),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.title.isEmpty ? b.sourceDomain : b.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _Source(h.source),
                            const SizedBox(height: 4),
                            Text(
                              h.snippet,
                              maxLines: 2,
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
        ],
      );
    },
  );
}

class _Source extends StatelessWidget {
  final DeepSource source;
  const _Source(this.source);
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final (icon, label, wash) = switch (source) {
      DeepSource.article => (
        Icons.article_outlined,
        tr(context, 'Inside article', 'Trong bài viết'),
        p.tint,
      ),
      DeepSource.highlight => (
        Icons.format_quote_rounded,
        tr(context, 'In a highlight', 'Trong đoạn đánh dấu'),
        highlightWash(context, 'yellow'),
      ),
      DeepSource.picture => (
        Icons.image_search_rounded,
        tr(context, 'From picture', 'Từ ảnh'),
        p.sageTint,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(BookmarkRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: p.ink),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: p.ink),
          ),
        ],
      ),
    );
  }
}
