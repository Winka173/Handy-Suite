import 'package:handy_recall/handy_recall.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../study/schedule.dart';

/// Every deck with what it holds and what is due; a deck with cards due
/// has its own review button on the row.
class DeckList extends StatelessWidget {
  final RecallScope scope;
  const DeckList({super.key, required this.scope});
  @override
  Widget build(BuildContext context) {
    final s = scope.state;
    final now = stamp(scope.now);
    final c = HandyColors.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandyLabel(
          tr(context, 'Decks', 'Bộ thẻ'),
          trailing: TextButton.icon(
            key: const Key('deck-new'),
            onPressed: () => scope.editDeck(context),
            icon: const Icon(Icons.add, size: 18),
            label: Text(tr(context, 'New deck', 'Bộ thẻ mới')),
          ),
        ),
        if (s.decks.isEmpty)
          HandyEmpty(
            title: tr(
              context,
              'Make a deck for what you are learning',
              'Tạo một bộ thẻ cho thứ bạn đang học',
            ),
            message: tr(
              context,
              'Then add cards one by one, or bring them in from a CSV file.',
              'Sau đó thêm từng thẻ, hoặc nhập cả loạt từ file CSV.',
            ),
            action: FilledButton(
              key: const Key('deck-first'),
              onPressed: () => scope.editDeck(context),
              child: Text(tr(context, 'First deck', 'Bộ thẻ đầu tiên')),
            ),
          )
        else
          HandyGroup(
            children: [
              for (final d
                  in [...s.decks]..sort(
                    (a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                  ))
                Builder(
                  builder: (context) {
                    final stats = recallStats(s, now: now, deckId: d.id);
                    final due = stats['due']!;
                    return ListTile(
                      key: Key('deck-${d.id}'),
                      onTap: () => scope.openDeck(context, d.id),
                      leading: HandyDot(deckHue(s.decks, d.id), size: 12),
                      minLeadingWidth: 12,
                      title: Text(
                        d.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        tr(
                          context,
                          '${stats['total']} cards · ${stats['newCards']} new',
                          '${stats['total']} thẻ · ${stats['newCards']} mới',
                        ),
                        style: TextStyle(color: c.muted, fontFeatures: tabular),
                      ),
                      // A bare 0 left the reader asking zero of what.
                      trailing: due == 0
                          ? Text(
                              tr(context, 'none due', 'chưa đến hạn'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: c.muted,
                              ),
                            )
                          : FilledButton.tonal(
                              key: Key('deck-review-${d.id}'),
                              onPressed: () => scope.review(context, d.id),
                              child: Text(
                                tr(context, 'Review $due', 'Ôn $due'),
                                style: const TextStyle(fontFeatures: tabular),
                              ),
                            ),
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }
}
