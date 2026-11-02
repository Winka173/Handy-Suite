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
  ..['receipts'] = []
  ..['rules'] = [];

/// One what-if drawn over the plan's forecast.
class WhatIfLine {
  final Scenario scenario;
  final Projection projection;

  /// Assumptions on an account that is gone or archived, left out.
  final int ignored;
  final int hue;
  const WhatIfLine(this.scenario, this.projection, this.ignored, this.hue);
}

/// The what-ifs in [on], each run on the live ledger over the plan's
/// window. The ledger is read, never written.
List<WhatIfLine> whatIfLines(
  SpendState s,
  Set<String> on,
  String start,
  String end, {
  required Set<String> accounts,
  required bool includeIncome,
}) {
  final out = <WhatIfLine>[];
  for (final (i, x) in s.scenarios.indexed) {
    if (!on.contains(x.id)) continue;
    final (p, ignored) = whatIfForecast(
      s,
      x,
      start,
      end,
      accounts: accounts,
      includeIncome: includeIncome,
    );
    out.add(WhatIfLine(x, p, ignored, i));
  }
  return out;
}

/// Turns a what-if on or off over the forecast. More than one at a time
/// is comparing, which needs Pro (as before).
Future<void> toggleWhatIf(
  BuildContext context,
  SpendScope scope,
  String id,
  bool on,
) async {
  final now = {...scope.overlays.value};
  if (on && now.isNotEmpty && !now.contains(id) && !scope.pro(context)) {
    await askForPro(context, 'Comparing what-ifs', 'So sánh kịch bản');
    return;
  }
  on ? now.add(id) : now.remove(id);
  scope.overlays.value = now;
}

/// Shows a what-if that was just made, alone unless Pro compares.
void showWhatIf(BuildContext context, SpendScope scope, String id) {
  scope.overlays.value = scope.pro(context)
      ? {...scope.overlays.value, id}
      : {id};
}

/// "Dự báo nếu…": the what-ifs as switches under the forecast (each chip
/// is the legend of its line), and the two ways to make one.
class WhatIfSwitches extends StatelessWidget {
  final SpendScope scope;
  const WhatIfSwitches({super.key, required this.scope});

  @override
  Widget build(BuildContext context) {
    final list = scope.state.scenarios;
    final on = scope.overlays.value;
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            tr(context, 'Forecast if…', 'Dự báo nếu…'),
            style: theme.textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: HandySpace.xs),
        Text(
          list.isEmpty
              ? tr(
                  context,
                  'Try a purchase or any change and see its line over this forecast. Your ledger only changes if you record it for real.',
                  'Thử một khoản mua hay thay đổi nào đó và xem đường của nó trên dự báo này. Sổ thật chỉ đổi khi bạn chọn ghi thật.',
                )
              : tr(
                  context,
                  'Tap one to draw it over the forecast. Assumptions only; the ledger stays as it is.',
                  'Chạm để vẽ lên dự báo. Chỉ là giả định; sổ thật giữ nguyên.',
                ),
          style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
        ),
        const SizedBox(height: HandySpace.s),
        Wrap(
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          children: [
            for (final (i, x) in list.indexed)
              FilterChip(
                key: Key('whatif-toggle-${x.id}'),
                avatar: HandyDot(i, size: 10),
                showCheckmark: false,
                label: Text(x.name),
                tooltip: on.contains(x.id)
                    ? tr(
                        context,
                        'Shown on the forecast',
                        'Đang vẽ trên dự báo',
                      )
                    : tr(context, 'Draw on the forecast', 'Vẽ lên dự báo'),
                selected: on.contains(x.id),
                onSelected: (v) => toggleWhatIf(context, scope, x.id, v),
              ),
            ActionChip(
              key: const Key('whatif-purchase'),
              avatar: const Icon(Icons.shopping_bag_outlined, size: 16),
              label: Text(tr(context, 'Try a purchase', 'Thử một khoản mua')),
              onPressed: () => openPurchase(context, scope),
            ),
            ActionChip(
              key: const Key('whatif-new'),
              avatar: const Icon(Icons.add, size: 16),
              label: Text(tr(context, 'Other change', 'Thay đổi khác')),
              onPressed: () => newScenario(context, scope),
            ),
          ],
        ),
      ],
    );
  }
}

/// The forecast as it is, then each what-if on the chart, in the same
/// three columns so they read down: the lowest day, the end of the window
/// and the first day short, with the lowest day's change against now.
class WhatIfCompare extends StatelessWidget {
  final SpendScope scope;
  final Projection base;
  final List<WhatIfLine> lines;
  const WhatIfCompare({
    super.key,
    required this.scope,
    required this.base,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    String? lowDay(Projection p) => p.points.isEmpty
        ? null
        : p.points.reduce((a, b) => b.balance < a.balance ? b : a).date;
    Widget cell(String label, Widget value, [String? note]) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: c.muted)),
        value,
        if (note != null)
          Text(
            note,
            style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
          ),
      ],
    );
    Widget figures(Projection p) {
      final cells = [
        cell(
          tr(context, 'Lowest', 'Thấp nhất'),
          Money(
            scope,
            p.lowest,
            scope.currency,
            style: theme.textTheme.titleSmall?.copyWith(
              color: p.lowest.isNegative ? c.negative : null,
            ),
          ),
          lowDay(p) == null ? null : dayLabel(context, scope, lowDay(p)!),
        ),
        cell(
          tr(context, 'At the end', 'Cuối kỳ'),
          Money(
            scope,
            p.ending,
            scope.currency,
            style: theme.textTheme.titleSmall,
          ),
        ),
        cell(
          tr(context, 'Short from', 'Thiếu từ'),
          Text(
            p.shortfall == null
                ? tr(context, 'Never', 'Không thiếu')
                : dayLabel(context, scope, p.shortfall!),
            style: theme.textTheme.titleSmall?.copyWith(
              color: p.shortfall == null ? null : c.negative,
            ),
          ),
        ),
      ];
      return LayoutBuilder(
        builder: (context, box) => box.maxWidth < 300
            ? Wrap(
                spacing: HandySpace.l,
                runSpacing: HandySpace.s,
                children: cells,
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final w in cells)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: HandySpace.s),
                        child: w,
                      ),
                    ),
                ],
              ),
      );
    }

    Widget head(Widget mark, String name, {Widget? trailing}) => SizedBox(
      height: 40,
      child: Row(
        children: [
          mark,
          const SizedBox(width: HandySpace.s),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
          ?trailing,
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The base line is dashed in the app's hue on the chart.
        head(
          SizedBox(
            width: 10,
            child: Divider(color: c.accent, thickness: 2, height: 2),
          ),
          tr(context, 'As it is', 'Như hiện tại'),
        ),
        figures(base),
        for (final l in lines)
          Padding(
            key: Key('whatif-compare-${l.scenario.id}'),
            padding: const EdgeInsets.only(top: HandySpace.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                head(
                  HandyDot(l.hue),
                  tr(
                    context,
                    'If ${l.scenario.name}',
                    'Nếu ${l.scenario.name}',
                  ),
                  trailing: TextButton(
                    key: Key('whatif-${l.scenario.id}'),
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/whatif/${l.scenario.id}',
                    ),
                    child: Text(tr(context, 'Assumptions', 'Giả định')),
                  ),
                ),
                figures(l.projection),
                const SizedBox(height: 2),
                Builder(
                  builder: (context) {
                    final d = l.projection.lowest - base.lowest;
                    return Text(
                      d == BigInt.zero
                          ? tr(
                              context,
                              'Lowest day as now',
                              'Ngày thấp nhất như hiện tại',
                            )
                          : tr(
                              context,
                              'Lowest day ${moneyText(context, scope, d, scope.currency, sign: true)} against now',
                              'Ngày thấp nhất ${moneyText(context, scope, d, scope.currency, sign: true)} so với hiện tại',
                            ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: d.isNegative ? c.negative : c.muted,
                      ),
                    );
                  },
                ),
                if (l.ignored > 0)
                  Text(
                    tr(
                      context,
                      '${l.ignored} assumption(s) use an account that is closed now and are left out.',
                      '${l.ignored} giả định dùng tài khoản đã đóng nên không tính.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: c.warning,
                    ),
                  ),
              ],
            ),
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
  final id = newId();
  final made = await showSpendForm(
    context,
    scope,
    title: tr(context, 'Forecast if…', 'Dự báo nếu…'),
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
            id: id,
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
  if (!made || !context.mounted) return;
  showWhatIf(context, scope, id);
  // An empty what-if changes nothing: go straight to its assumptions.
  await Navigator.pushNamed(context, '/whatif/$id');
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
  final id = existing?.id ?? newId();
  final made = await showSpendForm(
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
        id: id,
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
  if (made && existing == null && context.mounted)
    showWhatIf(context, scope, id);
}
