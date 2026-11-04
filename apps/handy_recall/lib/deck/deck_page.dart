import 'package:handy_recall/handy_recall.dart';
import '../study/sample_deck.dart';
import 'package:handy_ui/kit.dart';
import '../import/paste_page.dart';
import '../scope.dart';
import '../study/schedule.dart';
import '../review/review_page.dart';
import 'card_row.dart';

/// One deck: review it, add to it, and every card with when it is due.
class DeckPage extends StatefulWidget {
  final RecallScope scope;
  final String id;
  const DeckPage({super.key, required this.scope, required this.id});
  @override
  State<DeckPage> createState() => _DeckPageState();
}

class _DeckPageState extends State<DeckPage> {
  final query = TextEditingController();
  RecallScope get scope => widget.scope;

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([scope.store, query]),
    builder: (context, _) {
      final s = scope.state;
      final deck = s.decks.where((d) => d.id == widget.id).firstOrNull;
      if (deck == null) {
        return Scaffold(
          appBar: AppBar(),
          body: HandyEmpty(
            title: tr(
              context,
              'This deck is not here any more.',
              'Bộ thẻ này không còn nữa.',
            ),
          ),
        );
      }
      final theme = Theme.of(context);
      final c = HandyColors.of(context);
      final stats = recallStats(s, now: stamp(scope.now), deckId: deck.id);
      final hard = hardCards(s, deck.id);
      final words = query.text.trim().toLowerCase();
      final cards =
          s.cards
              .where((x) => x.deckId == deck.id)
              .where(
                (x) =>
                    words.isEmpty ||
                    '${x.front} ${x.back}'.toLowerCase().contains(words),
              )
              .toList()
            ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      return Scaffold(
        appBar: AppBar(
          actions: [
            HandyMenuButton(
              items: [
                HandyMenuItem(
                  Icons.tune,
                  tr(context, 'Deck settings', 'Cài đặt bộ thẻ'),
                  () => scope.editDeck(context, deck),
                  key: const Key('deck-rename'),
                ),
                HandyMenuItem(
                  Icons.content_paste,
                  tr(context, 'Paste notes', 'Dán ghi chú'),
                  () => openPaste(context, scope, deck),
                  key: const Key('deck-paste'),
                ),
                HandyMenuItem(
                  Icons.upload_file_outlined,
                  tr(context, 'Import CSV', 'Nhập CSV'),
                  () => scope.importCsv(context, deck.id),
                  key: const Key('deck-import'),
                ),
                HandyMenuItem(
                  Icons.download_outlined,
                  tr(context, 'Export CSV', 'Xuất CSV'),
                  () => scope.exportCsv(context, deck),
                  key: const Key('deck-export'),
                ),
                HandyMenuItem(
                  Icons.delete_outline,
                  tr(context, 'Delete deck', 'Xóa bộ thẻ'),
                  () async {
                    if (await scope.deleteDeck(context, deck) &&
                        context.mounted)
                      Navigator.maybePop(context);
                  },
                  key: const Key('deck-delete'),
                  destructive: true,
                ),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            HandySpace.l,
            0,
            HandySpace.l,
            HandySpace.xxl,
          ),
          children: [
            HandyContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      HandyDot(deckHue(s.decks, deck.id), size: 14),
                      const SizedBox(width: HandySpace.m),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            deck.name,
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isSampleDeck(deck.id)) ...[
                    const SizedBox(height: HandySpace.m),
                    HandyNotice(
                      tr(
                        context,
                        'A sample deck to try reviewing with.',
                        'Bộ mẫu để thử cách ôn.',
                      ),
                      action: TextButton(
                        key: const Key('sample-remove'),
                        onPressed: () async {
                          await scope.store.commit(
                            removeSampleDecks(scope.store.state!),
                          );
                          if (context.mounted) Navigator.maybePop(context);
                        },
                        child: Text(tr(context, 'Remove it', 'Gỡ bộ mẫu')),
                      ),
                    ),
                  ],
                  const SizedBox(height: HandySpace.xs),
                  // The stats end on forgetting; the hard cards follow it.
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: HandySpace.xs,
                    children: [
                      Text(
                        tr(
                          context,
                          '${stats['total']} cards · ${stats['due']} due · ${stats['newCards']} new · forgot ${stats['lapses']} times',
                          '${stats['total']} thẻ · ${stats['due']} cần ôn · ${stats['newCards']} mới · quên ${stats['lapses']} lần',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: c.muted,
                          fontFeatures: tabular,
                        ),
                      ),
                      if (hard.isNotEmpty)
                        TextButton.icon(
                          key: const Key('deck-hard'),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ReviewPage(
                                scope: scope,
                                deckId: deck.id,
                                practice: hard,
                                practiceTitle: tr(
                                  context,
                                  'Hard cards',
                                  'Thẻ khó',
                                ),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.replay_rounded, size: 18),
                          label: Text(
                            tr(
                              context,
                              'Practise ${hard.length} hard',
                              'Luyện ${hard.length} thẻ khó',
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: HandySpace.l),
                  Wrap(
                    spacing: HandySpace.s,
                    runSpacing: HandySpace.s,
                    children: [
                      if (stats['due']! > 0)
                        FilledButton.icon(
                          key: const Key('deck-study'),
                          onPressed: () => scope.review(context, deck.id),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(
                            tr(
                              context,
                              'Review ${stats['due']}',
                              'Ôn ${stats['due']} thẻ',
                            ),
                          ),
                        ),
                      OutlinedButton.icon(
                        key: const Key('card-new'),
                        onPressed: () => scope.editCard(context, deck.id),
                        icon: const Icon(Icons.add),
                        label: Text(tr(context, 'Add cards', 'Thêm thẻ')),
                      ),
                    ],
                  ),
                  const SizedBox(height: HandySpace.l),
                  if (s.cards.any((x) => x.deckId == deck.id))
                    TextField(
                      key: const Key('card-search'),
                      controller: query,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: tr(context, 'Find a card', 'Tìm thẻ'),
                      ),
                    ),
                  const SizedBox(height: HandySpace.m),
                  HandySwap(
                    child: cards.isEmpty
                        ? HandyEmpty(
                            key: const ValueKey('empty'),
                            title: words.isEmpty
                                ? tr(context, 'No cards yet', 'Chưa có thẻ nào')
                                : tr(
                                    context,
                                    'No card matches',
                                    'Không có thẻ nào khớp',
                                  ),
                            action: words.isEmpty
                                ? OutlinedButton(
                                    key: const Key('deck-import-empty'),
                                    onPressed: () =>
                                        scope.importCsv(context, deck.id),
                                    child: Text(
                                      tr(
                                        context,
                                        'Import a CSV file',
                                        'Nhập file CSV',
                                      ),
                                    ),
                                  )
                                : null,
                          )
                        : HandyGroup(
                            key: const ValueKey('cards'),
                            children: [
                              for (final x in cards.take(500))
                                CardRow(
                                  card: x,
                                  now: scope.now,
                                  onTap: () =>
                                      scope.editCard(context, deck.id, x),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
