import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';
import '../ui/form.dart';
import 'ledger_filter.dart';

/// Budgets that overlap the period: a track as long as the allowance,
/// what is spent filled in, an overrun past its end in the negative colour.
class BudgetList extends StatelessWidget {
  final SpendScope scope;
  final LedgerFilter filter;
  const BudgetList({super.key, required this.scope, required this.filter});

  @override
  Widget build(BuildContext context) {
    final s = scope.state;
    final shown = s.budgets
        .where(
          (b) =>
              b.start.compareTo(filter.until) < 0 &&
              b.end.compareTo(filter.from) > 0,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandyLabel(
          tr(context, 'Budgets', 'Ngân sách'),
          trailing: TextButton.icon(
            key: const Key('budget-add'),
            onPressed: () => openBudgetEditor(context, scope, null, filter),
            icon: const Icon(Icons.add, size: 18),
            label: Text(tr(context, 'Add', 'Thêm')),
          ),
        ),
        if (shown.isEmpty)
          Text(
            s.budgets.isEmpty
                ? tr(
                    context,
                    'Set a limit for a category or for everything.',
                    'Đặt hạn mức cho một danh mục hoặc cho tất cả.',
                  )
                : tr(
                    context,
                    'No budget covers this period.',
                    'Không có ngân sách nào trong kỳ này.',
                  ),
            style: TextStyle(color: HandyColors.of(context).muted),
          ),
        for (final b in shown)
          _BudgetRow(scope: scope, budget: b, filter: filter),
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final SpendScope scope;
  final Budget budget;
  final LedgerFilter filter;
  const _BudgetRow({
    required this.scope,
    required this.budget,
    required this.filter,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final b = budget;
    final left = budgetRemaining(scope.state, b);
    final spent = report(
      scope.state,
      b.start,
      b.end,
      currency: b.currency,
      account: b.account,
      category: b.category,
    )['expense']!;
    final allowance = left + spent;
    final over = left.isNegative;
    final ratio = allowance <= BigInt.zero
        ? 1.0
        : (spent.toDouble() / allowance.toDouble()).clamp(0.0, 1.0);
    return InkWell(
      key: Key('budget-${b.id}'),
      onTap: () => openBudgetEditor(context, scope, b, filter),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(b.name, overflow: TextOverflow.ellipsis)),
                Text(
                  over
                      ? tr(
                          context,
                          '${moneyText(context, scope, -left, b.currency)} over',
                          'Vượt ${moneyText(context, scope, -left, b.currency)}',
                        )
                      : tr(
                          context,
                          '${moneyText(context, scope, left, b.currency)} left',
                          'Còn ${moneyText(context, scope, left, b.currency)}',
                        ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: tabular,
                    color: over ? c.negative : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    Container(color: c.raised),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(
                        color: over
                            ? c.negative
                            : theme.colorScheme.onSurface.withValues(
                                alpha: .55,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                context,
                '${moneyText(context, scope, spent, b.currency)} of ${moneyText(context, scope, allowance, b.currency)} · ${dayLabel(context, scope, b.start)} – ${dayLabel(context, scope, day(calendar(b.end).subtract(const Duration(days: 1))))}',
                '${moneyText(context, scope, spent, b.currency)} trên ${moneyText(context, scope, allowance, b.currency)} · ${dayLabel(context, scope, b.start)} – ${dayLabel(context, scope, day(calendar(b.end).subtract(const Duration(days: 1))))}',
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// A limit over a period, for everything or one category or account.
Future<bool> openBudgetEditor(
  BuildContext context,
  SpendScope scope,
  Budget? b,
  LedgerFilter period,
) {
  final s = scope.state;
  return showSpendForm(
    context,
    scope,
    title: b == null ? tr(context, 'New budget', 'Ngân sách mới') : b.name,
    fields: [
      const SpendField('name', 'Name', 'Tên'),
      SpendField(
        'limit',
        'Limit',
        'Hạn mức',
        kind: FieldKind.money,
        currency: (v) => v['currency'] as String,
      ),
      SpendField(
        'currency',
        'Currency',
        'Loại tiền',
        kind: FieldKind.choice,
        options: {for (final k in scales.keys) k: k},
      ),
      const SpendField('start', 'First day', 'Từ ngày', kind: FieldKind.date),
      const SpendField(
        'last',
        'Last day',
        'Đến hết ngày',
        kind: FieldKind.date,
      ),
      SpendField(
        'category',
        'Category',
        'Danh mục',
        kind: FieldKind.choice,
        required: false,
        options: {
          '': tr(context, 'All spending', 'Mọi khoản chi'),
          for (final c in s.categories.where((c) => c.kind == 'expense'))
            c.id: c.name,
        },
      ),
      SpendField(
        'account',
        'Account',
        'Tài khoản',
        kind: FieldKind.choice,
        required: false,
        options: {
          '': tr(context, 'All accounts', 'Mọi tài khoản'),
          for (final a in scope.openAccounts) a.id: a.name,
        },
      ),
      const SpendField(
        'rollover',
        'Carry over what is unused',
        'Cộng phần chưa dùng của kỳ trước',
        kind: FieldKind.toggle,
        helpEn: 'From the period just before, of the same length. Once only.',
        helpVi: 'Từ kỳ liền trước cùng độ dài. Chỉ một kỳ.',
      ),
    ],
    initial: {
      'name': b?.name ?? '',
      'limit': b?.limit,
      'currency': b?.currency ?? s.currency,
      'start': b?.start ?? period.from,
      'last': day(
        calendar(b?.end ?? period.until).subtract(const Duration(days: 1)),
      ),
      'category': b?.category ?? '',
      'account': b?.account ?? '',
      'rollover': b?.rollover ?? false,
    },
    save: (v) async {
      final end = day(
        calendar(v['last'] as String).add(const Duration(days: 1)),
      );
      final next = Budget(
        id: b?.id ?? newId(),
        name: v['name'] as String,
        currency: v['currency'] as String,
        start: v['start'] as String,
        end: end,
        limit: v['limit'] as BigInt,
        account: (v['account'] as String).isEmpty
            ? null
            : v['account'] as String,
        category: (v['category'] as String).isEmpty
            ? null
            : v['category'] as String,
        rollover: v['rollover'] == true,
      );
      await scope.controller.change(
        (s) => s.copy({
          'budgets': [
            for (final x in s.budgets)
              if (x.id != next.id) x.toJson(),
            next.toJson(),
          ],
        }),
        'save_budget',
      );
    },
  );
}
