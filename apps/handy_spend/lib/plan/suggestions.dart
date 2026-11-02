import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';
import 'recurring.dart';

/// Payments the history says repeat but no recurring item covers yet. Each
/// waits for the person: Add opens the recurring editor filled in (nothing
/// is saved until its Save), Not recurring hides it for good, with Undo.
class SuggestionList extends StatelessWidget {
  final SpendScope scope;
  const SuggestionList({super.key, required this.scope});

  Future<void> _dismiss(BuildContext context, RecurringSuggestion g) =>
      scope.write(
        context,
        () => scope.controller.change(
          (s) => dismissSuggestion(s, g.key),
          'dismiss_recurring_suggestion',
        ),
        done: (c) => tr(
          c,
          '${g.name} will not be suggested again.',
          'Sẽ không gợi ý ${g.name} nữa.',
        ),
      );

  @override
  Widget build(BuildContext context) {
    final found = recurringSuggestions(scope.state, scope.today);
    if (found.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return HandySection(
      title: tr(context, 'Looks like it repeats', 'Có vẻ lặp lại'),
      children: [
        for (final g in found.take(5))
          Padding(
            key: Key('suggest-${g.key}'),
            padding: const EdgeInsets.fromLTRB(
              HandySpace.l,
              HandySpace.m,
              HandySpace.s,
              HandySpace.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        g.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(width: HandySpace.s),
                    Padding(
                      padding: const EdgeInsets.only(right: HandySpace.s),
                      child: Money(
                        scope,
                        g.amount,
                        scope.account(g.account).currency,
                        sign: true,
                        income: g.kind == 'income',
                      ),
                    ),
                  ],
                ),
                Text(
                  [
                    frequencyLabel(context, g.frequency),
                    tr(
                      context,
                      '${g.count} times, last ${dayLabel(context, scope, g.last)}',
                      '${g.count} lần, gần nhất ${dayLabel(context, scope, g.last)}',
                    ),
                    if (g.varies)
                      tr(context, 'amount varies a little', 'số tiền xê dịch'),
                    scope.account(g.account).name,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
                ),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: HandySpace.xs,
                  children: [
                    TextButton(
                      key: Key('suggest-dismiss-${g.key}'),
                      onPressed: () => _dismiss(context, g),
                      child: Text(
                        tr(context, 'Not recurring', 'Không định kỳ'),
                      ),
                    ),
                    OutlinedButton(
                      key: Key('suggest-add-${g.key}'),
                      onPressed: () async {
                        final saved = await openBillEditor(
                          context,
                          scope,
                          g.bill(),
                        );
                        if (saved && context.mounted)
                          scope.announce(
                            context,
                            tr(
                              context,
                              '${g.name} added to what repeats.',
                              'Đã thêm ${g.name} vào khoản định kỳ.',
                            ),
                          );
                      },
                      child: Text(
                        tr(context, 'Add as recurring', 'Thêm định kỳ'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HandySpace.l,
            0,
            HandySpace.l,
            HandySpace.m,
          ),
          child: Text(
            tr(
              context,
              'Found in your history: the same payee at least three times, a week or a month apart, within 10% of the usual amount.',
              'Tìm trong lịch sử: cùng đối tác ít nhất ba lần, cách nhau một tuần hoặc một tháng, lệch không quá 10%.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
          ),
        ),
      ],
    );
  }
}
