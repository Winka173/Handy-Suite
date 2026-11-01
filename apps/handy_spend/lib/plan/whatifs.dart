import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';
import '../ui/form.dart';
import '../ui/pro.dart';

/// The ledger as it is now, without the history a what-if never needs.
Map<String, dynamic> scenarioBaseline(SpendState s) => s.toJson()
  ..['scenarios'] = []
  ..['audit'] = []
  ..['imports'] = []
  ..['profiles'] = []
  ..['rules'] = [];

/// The month-end balance a what-if changes, against its own baseline.
(BigInt base, BigInt changed, String currency) scenarioEffect(Scenario x) {
  final base = SpendState.fromJson(x.baseline);
  final start = calendar(x.asOf);
  final end = day(DateTime.utc(start.year, start.month + 1, 0));
  return (
    forecast(base, x.asOf, end).ending,
    forecast(
      base,
      x.asOf,
      end,
      staged: x.staged,
      skipBills: x.skipBills.toSet(),
    ).ending,
    base.currency,
  );
}

/// Try a purchase or any change on a copy of the ledger.
class WhatIfSection extends StatelessWidget {
  final SpendScope scope;
  const WhatIfSection({super.key, required this.scope});

  @override
  Widget build(BuildContext context) {
    final list = scope.state.scenarios;
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandySection(
          title: tr(context, 'Try first', 'Thử trước'),
          trailing: list.length >= 2
              ? TextButton(
                  key: const Key('whatif-compare'),
                  onPressed: () => compareScenarios(context, scope),
                  child: Text(tr(context, 'Compare', 'So sánh')),
                )
              : null,
          children: [
            Padding(
              padding: const EdgeInsets.all(HandySpace.l),
              child: Text(
                tr(
                  context,
                  'A what-if works on a copy taken today. Your ledger only changes if you record it for real.',
                  'Thử trước chạy trên bản sao chụp hôm nay. Sổ thật chỉ đổi khi bạn chọn ghi thật.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
              ),
            ),
            for (final x in list)
              Builder(
                builder: (context) {
                  final (base, changed, cur) = scenarioEffect(x);
                  return HandyTile(
                    key: Key('whatif-${x.id}'),
                    title: x.name,
                    subtitle: tr(
                      context,
                      'Month end ${moneyText(context, scope, changed - base, cur, sign: true)} against the copy of ${dayLabel(context, scope, x.asOf)}',
                      'Cuối tháng ${moneyText(context, scope, changed - base, cur, sign: true)} so với bản sao ngày ${dayLabel(context, scope, x.asOf)}',
                    ),
                    navigates: true,
                    onTap: () =>
                        Navigator.pushNamed(context, '/whatif/${x.id}'),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: HandySpace.m),
        Wrap(
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          children: [
            OutlinedButton.icon(
              key: const Key('whatif-purchase'),
              onPressed: () => openPurchase(context, scope),
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: Text(tr(context, 'Try a purchase', 'Thử một khoản mua')),
            ),
            OutlinedButton.icon(
              key: const Key('whatif-new'),
              onPressed: () => newScenario(context, scope),
              icon: const Icon(Icons.add, size: 18),
              label: Text(tr(context, 'New what-if', 'Kịch bản mới')),
            ),
          ],
        ),
      ],
    );
  }
}

bool _gate(BuildContext context, SpendScope scope) {
  if (scope.state.scenarios.isEmpty || scope.pro(context)) return true;
  askForPro(context, 'A second what-if', 'Kịch bản thứ hai');
  return false;
}

Future<void> newScenario(BuildContext context, SpendScope scope) async {
  if (!_gate(context, scope)) return;
  await showSpendForm(
    context,
    scope,
    title: tr(context, 'New what-if', 'Kịch bản mới'),
    saveLabel: tr(context, 'Create', 'Tạo'),
    fields: const [
      SpendField(
        'name',
        'Name',
        'Tên',
        helpEn: 'Then add income, spending or a moved due date to it.',
        helpVi: 'Sau đó thêm khoản thu, khoản chi hoặc dời ngày đến hạn.',
      ),
    ],
    initial: {'name': ''},
    save: (v) => scope.controller.change(
      (s) => s.copy({
        'scenarios': [
          ...s.scenarios.map((x) => x.toJson()),
          Scenario(
            id: newId(),
            name: v['name'] as String,
            asOf: scope.today,
            baseline: scenarioBaseline(s),
            staged: [],
          ).toJson(),
        ],
      }),
      'create_financial_scenario',
    ),
  );
}

/// One purchase, paid at once or in equal monthly parts (no interest is
/// assumed), optionally replacing something that repeats.
Future<void> openPurchase(
  BuildContext context,
  SpendScope scope, [
  Scenario? existing,
]) async {
  final s = scope.state;
  final accounts = {
    for (final a in s.accounts.where(
      (a) => !a.archived && !a.liability && a.currency == s.currency,
    ))
      a.id: a.name,
  };
  if (accounts.isEmpty) return;
  if (existing == null && !_gate(context, scope)) return;
  final first = existing?.staged.firstOrNull;
  final total = existing?.staged.fold(
    BigInt.zero,
    (BigInt n, e) => n - e.amount,
  );
  await showSpendForm(
    context,
    scope,
    title: tr(context, 'Try a purchase', 'Thử một khoản mua'),
    saveLabel: tr(context, 'See the effect', 'Xem ảnh hưởng'),
    fields: [
      const SpendField(
        'name',
        'What',
        'Mua gì',
        helpEn: 'A new phone, a laptop on 6 months…',
        helpVi: 'Điện thoại mới, laptop trả góp 6 tháng…',
      ),
      SpendField(
        'cost',
        'Total cost',
        'Tổng giá',
        kind: FieldKind.money,
        currency: (_) => s.currency,
        helpEn: 'No interest or lender fees are added.',
        helpVi: 'Không cộng lãi hay phí của bên cho vay.',
      ),
      const SpendField(
        'installments',
        'Monthly parts (1 = pay at once)',
        'Số kỳ trả hàng tháng (1 = trả một lần)',
        kind: FieldKind.count,
      ),
      const SpendField('date', 'Bought on', 'Ngày mua', kind: FieldKind.date),
      SpendField(
        'account',
        'Paid from',
        'Trả từ',
        kind: FieldKind.choice,
        options: accounts,
      ),
      SpendField(
        'category',
        'Category',
        'Danh mục',
        kind: FieldKind.choice,
        required: false,
        options: {
          '': tr(context, 'None', 'Không'),
          for (final c in s.categories.where((c) => c.kind == 'expense'))
            c.id: c.name,
        },
      ),
      SpendField(
        'skip',
        'It replaces',
        'Thay cho',
        kind: FieldKind.choice,
        required: false,
        options: {
          '': tr(context, 'Nothing', 'Không thay gì'),
          for (final b in s.bills.where((b) => b.enabled)) b.id: b.name,
        },
      ),
    ],
    initial: {
      'name': existing?.name ?? '',
      'cost': total,
      'installments': '${existing?.staged.length ?? 1}',
      'date': first == null ? scope.today : reportDay(first.when, s.zone),
      'account': first?.account ?? accounts.keys.first,
      'category': first?.category ?? '',
      'skip': existing?.skipBills.firstOrNull ?? '',
    },
    save: (v) async {
      final base = existing?.baseline ?? scenarioBaseline(s);
      final baseState = SpendState.fromJson(base);
      final next = Scenario(
        id: existing?.id ?? newId(),
        name: v['name'] as String,
        asOf: existing?.asOf ?? scope.today,
        baseline: base,
        staged: purchasePlan(
          account: v['account'] as String,
          cost: v['cost'] as BigInt,
          date: v['date'] as String,
          zone: baseState.zone,
          installments: v['installments'] as int,
          category: (v['category'] as String).isEmpty
              ? null
              : v['category'] as String,
        ),
        skipBills: (v['skip'] as String).isEmpty ? [] : [v['skip'] as String],
      );
      await scope.controller.change(
        (s) => s.copy({
          'scenarios': [
            for (final x in s.scenarios)
              if (x.id != next.id) x.toJson(),
            next.toJson(),
          ],
        }),
        'save_scenario',
      );
    },
  );
}

Future<void> compareScenarios(BuildContext context, SpendScope scope) async {
  if (!scope.pro(context)) {
    await askForPro(context, 'Comparing what-ifs', 'So sánh kịch bản');
    return;
  }
  await Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (context) => HandyPage(
        title: tr(context, 'Compare what-ifs', 'So sánh kịch bản'),
        children: [
          HandySection(
            children: [
              for (final x in scope.state.scenarios.take(3))
                Builder(
                  builder: (context) {
                    final (base, changed, cur) = scenarioEffect(x);
                    return ListTile(
                      title: Text(x.name),
                      subtitle: Text(
                        tr(
                          context,
                          'Month end against its copy: ${moneyText(context, scope, changed - base, cur, sign: true)}',
                          'Cuối tháng so với bản sao: ${moneyText(context, scope, changed - base, cur, sign: true)}',
                        ),
                      ),
                      trailing: Money(scope, changed, cur),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
