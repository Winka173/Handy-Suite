import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../inventory/keep_store.dart' show today;
import '../scope.dart';
import '../ui/words.dart';

/// The answer to "where is it now?", with the one action it suggests:
/// lend it, or take it back. A change of answer fades in.
class WherePanel extends StatelessWidget {
  final KeepScope scope;
  final InventoryAsset item;
  const WherePanel({super.key, required this.scope, required this.item});

  int _days(String date) => DateTime.parse(
    '${date}T00:00:00Z',
  ).difference(DateTime.parse('${today()}T00:00:00Z')).inDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final a = item;
    final lent = a.borrower.isNotEmpty;
    return HandyGroup(
      color: c.lead,
      children: [
        HandyReveal(
          child: HandySwap(
            child: Padding(
              // Lending or getting it back changes the answer: let it show.
              key: ValueKey('${a.borrower}|${a.boxId}|${a.location}'),
              padding: const EdgeInsets.all(HandySpace.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, 'Where it is now', 'Đang ở đâu'),
                    style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                  ),
                  const SizedBox(height: HandySpace.xs),
                  Text(
                    whereNow(context, a, scope.state),
                    key: const Key('item-where'),
                    style: theme.textTheme.headlineMedium,
                  ),
                  if (lent) ...[
                    const SizedBox(height: HandySpace.xs),
                    Text.rich(
                      key: const Key('item-loan'),
                      TextSpan(
                        style: theme.textTheme.bodyMedium,
                        children: [
                          TextSpan(
                            text: tr(
                              context,
                              'since ${formatDay(context, a.lentOn)}',
                              'từ ${formatDay(context, a.lentOn)}',
                            ),
                          ),
                          if (a.returnDue.isNotEmpty) ...[
                            TextSpan(
                              text: tr(
                                context,
                                ' · back by ${formatDay(context, a.returnDue)} · ',
                                ' · hẹn trả ${formatDay(context, a.returnDue)} · ',
                              ),
                            ),
                            // Only the late fact is red, never the whole line.
                            TextSpan(
                              text: dueWhen(
                                context,
                                'loan',
                                _days(a.returnDue),
                              ),
                              style: _days(a.returnDue) < 0
                                  ? TextStyle(
                                      color: c.negative,
                                      fontWeight: FontWeight.w500,
                                    )
                                  : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: HandySpace.l),
                  lent
                      ? FilledButton.icon(
                          key: const Key('item-return'),
                          onPressed: () => scope.giveBack(context, a),
                          icon: const Icon(Icons.assignment_return_outlined),
                          label: Text(tr(context, 'It is back', 'Đã trả lại')),
                        )
                      : OutlinedButton.icon(
                          key: const Key('item-lend'),
                          onPressed: () => scope.lend(context, a),
                          icon: const Icon(Icons.handshake_outlined),
                          label: Text(tr(context, 'Lend it', 'Cho mượn')),
                        ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
