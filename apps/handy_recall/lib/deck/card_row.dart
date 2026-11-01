import 'package:handy_recall/handy_recall.dart';
import 'package:handy_ui/kit.dart';
import '../study/schedule.dart';

/// A card in its deck: the question, the answer greyed, and when it is due.
class CardRow extends StatelessWidget {
  final RecallCard card;
  final DateTime now;
  final VoidCallback onTap;
  const CardRow({
    super.key,
    required this.card,
    required this.now,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    final theme = Theme.of(context);
    final (state, days) = dueState(card, now);
    final label = switch (state) {
      DueState.fresh => tr(context, 'new', 'mới'),
      DueState.due => tr(context, 'due', 'đến hạn'),
      DueState.later =>
        days == 0
            ? tr(context, 'later today', 'cuối ngày')
            : relativeDays(context, days),
    };
    return ListTile(
      key: Key('card-${card.id}'),
      onTap: onTap,
      leading: card.image == null
          ? null
          : Icon(Icons.image_outlined, color: c.muted),
      title: Text(card.front, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        card.back,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: c.muted),
      ),
      trailing: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          // Due reads in ink, the rest in grey: a signal, not a stripe.
          color: state == DueState.due ? null : c.muted,
          fontFeatures: tabular,
        ),
      ),
    );
  }
}
