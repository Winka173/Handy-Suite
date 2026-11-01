import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';
import 'budgets.dart';
import 'ledger_filter.dart';

/// The month at a glance: what came in, what went out, six months of
/// spending (each column picks its month), and where the money went.
class MonthPanel extends StatelessWidget {
  final SpendScope scope;
  final LedgerFilter filter;
  final ValueChanged<LedgerFilter> onFilter;
  const MonthPanel({
    super.key,
    required this.scope,
    required this.filter,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final s = scope.state;
    final r = report(s, filter.from, filter.until, account: filter.account);
    final spent = r['expense']!, came = r['income']!;
    final categories = [
      for (final e in r.entries)
        if (e.key.startsWith('category:') && e.value != BigInt.zero)
          (e.key.substring(9), e.value),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Totals(scope: scope, income: came, spent: spent),
        if (filter.isMonth) ...[
          const SizedBox(height: HandySpace.l),
          _Trend(scope: scope, filter: filter, onFilter: onFilter),
        ],
        HandyLabel(tr(context, 'Where it went', 'Tiền đi đâu')),
        if (categories.isEmpty)
          Text(
            tr(
              context,
              'No spending in this period.',
              'Không có khoản chi trong kỳ này.',
            ),
            style: TextStyle(color: HandyColors.of(context).muted),
          )
        else
          _Categories(
            scope: scope,
            rows: categories,
            selected: filter.category,
            onTap: (id) => onFilter(
              filter.copyWith(category: filter.category == id ? null : id),
            ),
          ),
        BudgetList(scope: scope, filter: filter),
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  final SpendScope scope;
  final BigInt income, spent;
  const _Totals({
    required this.scope,
    required this.income,
    required this.spent,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    Widget cell(
      String label,
      BigInt v, {
      bool lead = false,
      bool sign = false,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: c.muted)),
        const SizedBox(height: 2),
        Money(
          scope,
          v,
          scope.currency,
          sign: sign,
          style: lead
              ? theme.textTheme.headlineSmall
              : theme.textTheme.titleMedium,
        ),
      ],
    );
    // The answer (what went out) on its own line, never cut short.
    return Column(
      key: const Key('ledger-totals'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cell(tr(context, 'Spent', 'Đã chi'), spent, lead: true),
        const SizedBox(height: HandySpace.m),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cell(tr(context, 'Came in', 'Đã thu'), income)),
            const SizedBox(width: HandySpace.m),
            Expanded(
              child: cell(
                tr(context, 'Left over', 'Còn lại'),
                income - spent,
                sign: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Six months of spending as columns; the month on screen in the app's hue.
class _Trend extends StatelessWidget {
  final SpendScope scope;
  final LedgerFilter filter;
  final ValueChanged<LedgerFilter> onFilter;
  const _Trend({
    required this.scope,
    required this.filter,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    final theme = Theme.of(context);
    final now = calendar(scope.today), shown = calendar(filter.from);
    // The six months ending with the later of this month and the one shown.
    final last = shown.isAfter(now)
        ? shown
        : DateTime.utc(now.year, now.month, 1);
    final months = [
      for (var i = 5; i >= 0; i--) DateTime.utc(last.year, last.month - i, 1),
    ];
    final values = [
      for (final m in months)
        report(
          scope.state,
          day(m),
          day(DateTime.utc(m.year, m.month + 1, 1)),
          account: filter.account,
          category: filter.category,
        )['expense']!,
    ];
    final top = values.fold(BigInt.zero, (n, v) => v > n ? v : n);
    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, m) in months.indexed)
            Expanded(
              child: Semantics(
                button: true,
                selected: day(m) == filter.from,
                label:
                    '${m.month}/${m.year}: ${moneyText(context, scope, values[i], scope.currency)}',
                excludeSemantics: true,
                child: InkWell(
                  key: Key('month-${day(m).substring(0, 7)}'),
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => onFilter(
                    filter.shiftMonth(
                      (m.year - shown.year) * 12 + m.month - shown.month,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // The bar takes what the label leaves, at any text size.
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: top == BigInt.zero
                                  ? 0
                                  : values[i].toDouble() / top.toDouble(),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: day(m) == filter.from
                                      ? c.accent
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: .16,
                                        ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(height: 1, color: c.border),
                        const SizedBox(height: 4),
                        Text(
                          tr(context, _monthEn[m.month - 1], 'T${m.month}'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: day(m) == filter.from ? null : c.muted,
                            fontWeight: day(m) == filter.from
                                ? FontWeight.w600
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _monthEn = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Categories by what went to them, with a thin bar for size; the top
/// one in ink. A tap narrows the list to that category.
class _Categories extends StatelessWidget {
  final SpendScope scope;
  final List<(String, BigInt)> rows;
  final String? selected;
  final ValueChanged<String> onTap;
  const _Categories({
    required this.scope,
    required this.rows,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final top = rows.first.$2 > BigInt.zero ? rows.first.$2 : BigInt.one;
    return Column(
      children: [
        for (final (i, (id, v)) in rows.indexed)
          InkWell(
            key: Key('spent-$id'),
            onTap: id == 'uncategorized' ? null : () => onTap(id),
            child: Container(
              color: selected == id ? c.select : null,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (id != 'uncategorized') ...[
                        HandyDot(scope.categoryHue(id), size: 8),
                        const SizedBox(width: HandySpace.s),
                      ],
                      Expanded(
                        child: Text(
                          scope.category(id)?.name ??
                              tr(context, 'No category', 'Chưa phân loại'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Money(
                        scope,
                        v,
                        scope.currency,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: (v.toDouble() / top.toDouble()).clamp(0, 1),
                      child: Container(
                        height: 2,
                        color: i == 0
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurface.withValues(
                                alpha: .25,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
