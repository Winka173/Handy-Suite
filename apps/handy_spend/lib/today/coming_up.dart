import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';

/// Records one scheduled payment (or income) as paid today.
Future<void> markPaid(BuildContext context, SpendScope scope, Occurrence o) =>
    scope.write(
      context,
      () => scope.controller.putEntry(
        o.post(
          scope.state.zone,
          when: localTimestamp(scope.today, scope.state.zone),
        ),
      ),
      done: (c) => tr(
        c,
        '${o.bill.name} recorded as paid today.',
        'Đã ghi ${o.bill.name} là đã trả hôm nay.',
      ),
    );

/// A payment due: when, what, from which account, and the one action it
/// needs. Overdue says so in words, in the negative colour, once.
class DueRow extends StatelessWidget {
  final SpendScope scope;
  final Occurrence occurrence;
  const DueRow({super.key, required this.scope, required this.occurrence});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final o = occurrence, b = o.bill;
    final days = calendar(o.date).difference(calendar(scope.today)).inDays;
    final account = scope.account(b.account);
    final income = b.amount > BigInt.zero && b.toAccount == null;
    final narrow = MediaQuery.sizeOf(context).width < 360;
    return Padding(
      key: Key('due-${o.id}'),
      padding: const EdgeInsets.fromLTRB(HandySpace.l, 10, HandySpace.s, 10),
      child: Row(
        children: [
          SizedBox(
            width: narrow ? 56 : 84,
            child: Text(
              days < 0
                  ? tr(context, '${-days} d late', 'Trễ ${-days} ngày')
                  : whenLabel(context, scope, o.date),
              style: theme.textTheme.bodySmall?.copyWith(
                color: days < 0 ? c.negative : c.muted,
                fontWeight: days <= 0 ? FontWeight.w600 : null,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: HandyDot(scope.accountHue(account.id), size: 8),
                      ),
                      TextSpan(text: ' ${account.name}'),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
          // The figure is never cut; at 320 px the name gives way.
          Money(
            scope,
            b.toAccount != null ? -b.amount : b.amount,
            account.currency,
            sign: b.toAccount == null,
            income: income,
          ),
          const SizedBox(width: HandySpace.xs),
          TextButton(
            key: Key('paid-${o.id}'),
            style: narrow
                ? TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(44, 44),
                  )
                : null,
            onPressed: () => markPaid(context, scope, o),
            child: Text(
              income
                  ? tr(context, 'Received', 'Đã nhận')
                  : tr(context, 'Paid', 'Đã trả'),
            ),
          ),
        ],
      ),
    );
  }
}
