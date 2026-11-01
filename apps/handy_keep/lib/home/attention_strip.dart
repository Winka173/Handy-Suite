import 'package:handy_ui/kit.dart';
import '../inventory/whereabouts.dart';
import '../ui/words.dart';

/// The finding of the day: what is overdue or due soon, three at most.
class AttentionStrip extends StatelessWidget {
  final List<DueItem> due;
  final ValueChanged<String> onOpen;
  final VoidCallback onAll;
  const AttentionStrip({
    super.key,
    required this.due,
    required this.onOpen,
    required this.onAll,
  });
  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandyLabel(
          tr(context, 'Needs a look', 'Cần để ý'),
          trailing: TextButton(
            key: const Key('due-all'),
            onPressed: onAll,
            child: Text(tr(context, 'All dates', 'Xem tất cả')),
          ),
        ),
        HandyGroup(
          color: c.lead,
          children: [
            for (final d in due.take(3))
              ListTile(
                key: Key('due-${d.item.id}-${d.kind}'),
                onTap: () => onOpen(d.item.id),
                title: Text(
                  d.item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  d.kind == 'loan'
                      ? '${dueKind(context, d.kind)} · ${d.item.borrower}'
                      : dueKind(context, d.kind),
                ),
                trailing: Text(
                  dueWhen(context, d.kind, d.days),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: d.overdue ? c.negative : null,
                    fontWeight: d.overdue ? FontWeight.w500 : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
