import 'package:handy_save_engine/handy_save_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/words.dart';

/// One unread link at a time, oldest first: open it, then mark it read,
/// keep it for later, or archive it. "Later" lasts until the page closes.
class FocusPage extends StatefulWidget {
  final SaveScope scope;
  const FocusPage({super.key, required this.scope});
  @override
  State<FocusPage> createState() => _FocusPageState();
}

class _FocusPageState extends State<FocusPage> {
  final skipped = <String>{};
  SaveScope get scope => widget.scope;

  List<Bookmark> get queue => [
    for (final b in scope.library.bookmarks)
      if (!b.isRead && !b.isArchived && !skipped.contains(b.id)) b,
  ]..sort((a, b) => a.savedAt.compareTo(b.savedAt));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.c,
    builder: (context, _) {
      final q = queue;
      final b = q.firstOrNull;
      final theme = Theme.of(context);
      final c = HandyColors.of(context);
      return Scaffold(
        appBar: AppBar(
          title: Text(tr(context, 'Focus', 'Tập trung')),
          actions: [
            if (b != null)
              Padding(
                padding: const EdgeInsets.only(right: HandySpace.l),
                child: Center(
                  child: Text(
                    tr(context, '${q.length} to go', 'còn ${q.length}'),
                    style: const TextStyle(fontFeatures: tabular),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: b == null
            ? null
            : HandyBottomBar(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('focus-later'),
                        onPressed: () => setState(() => skipped.add(b.id)),
                        child: Text(tr(context, 'Later', 'Để sau')),
                      ),
                    ),
                    const SizedBox(width: HandySpace.s),
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('focus-archive'),
                        onPressed: () => scope.toggle(
                          context,
                          b,
                          (x) => x.copyWith(isArchived: true),
                        ),
                        child: Text(tr(context, 'Archive', 'Lưu trữ')),
                      ),
                    ),
                    const SizedBox(width: HandySpace.s),
                    Expanded(
                      child: FilledButton(
                        key: const Key('focus-read'),
                        onPressed: () => scope.toggle(
                          context,
                          b,
                          (x) => x.copyWith(isRead: true),
                        ),
                        child: Text(tr(context, 'Read', 'Đã đọc')),
                      ),
                    ),
                  ],
                ),
              ),
        body: HandySwap(
          child: b == null
              ? HandyEmpty(
                  key: const ValueKey('done'),
                  title: tr(
                    context,
                    'Nothing left to read',
                    'Không còn link nào chưa đọc',
                  ),
                  action: skipped.isEmpty
                      ? null
                      : TextButton(
                          key: const Key('focus-again'),
                          onPressed: () => setState(skipped.clear),
                          child: Text(
                            tr(
                              context,
                              'Bring back the ${skipped.length} for later',
                              'Đưa lại ${skipped.length} link để sau',
                            ),
                          ),
                        ),
                )
              : ListView(
                  key: ValueKey(b.id),
                  padding: const EdgeInsets.all(HandySpace.l),
                  children: [
                    HandyContent(
                      maxWidth: 640,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LayoutBuilder(
                            builder: (context, box) => LinkThumb(
                              scope.c,
                              b,
                              size: box.maxWidth,
                              height: 220,
                            ),
                          ),
                          const SizedBox(height: HandySpace.l),
                          Semantics(
                            header: true,
                            child: Text(
                              b.title.isEmpty ? b.sourceDomain : b.title,
                              style: theme.textTheme.headlineSmall,
                            ),
                          ),
                          const SizedBox(height: HandySpace.xs),
                          Text(
                            '${sourceLine(b)} · ${tr(context, 'saved', 'lưu')} ${ago(context, b.savedAt)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: c.muted,
                            ),
                          ),
                          if ((b.description ?? '').isNotEmpty) ...[
                            const SizedBox(height: HandySpace.l),
                            Text(
                              b.description!,
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: HandySpace.xl),
                          FilledButton.icon(
                            key: const Key('focus-open'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            onPressed: () => scope.open(context, b),
                            icon: const Icon(Icons.open_in_new),
                            label: Text(
                              tr(context, 'Open original', 'Mở bản gốc'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      );
    },
  );
}
