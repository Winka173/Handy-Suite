import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';
import '../ui/form.dart';
import '../ui/pro.dart';
import 'forecast_chart.dart';

/// One what-if: the copy it started from beside the changed version, the
/// assumptions that make the difference, and the one way into the real
/// ledger.
class WhatIfPage extends StatelessWidget {
  final SpendScope scope;
  final String id;
  const WhatIfPage({super.key, required this.scope, required this.id});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final x = scope.state.scenarios.where((x) => x.id == id).firstOrNull;
      if (x == null) {
        return HandyPage(
          title: tr(context, 'What-if', 'Kịch bản'),
          children: [
            HandyEmpty(
              title: tr(
                context,
                'This what-if is gone',
                'Kịch bản này không còn',
              ),
            ),
          ],
        );
      }
      return _Body(scope: scope, scenario: x);
    },
  );
}

class _Body extends StatelessWidget {
  final SpendScope scope;
  final Scenario scenario;
  const _Body({required this.scope, required this.scenario});

  @override
  Widget build(BuildContext context) {
    final x = scenario;
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final base = SpendState.fromJson(x.baseline);
    // Assumptions are checked against the copy; their effect is shown on
    // the ledger as it is today, over the plan's window, like the plan.
    final live = scope.state;
    final start = scope.today, end = scope.end;
    final accounts = scope.planningAccounts;
    final income = !scope.conservative.value;
    final before = forecast(
      live,
      start,
      end,
      accounts: accounts,
      includeIncome: income,
    );
    final (after, ignored) = whatIfForecast(
      live,
      x,
      start,
      end,
      accounts: accounts,
      includeIncome: income,
    );
    final open = {
      for (final a in live.accounts)
        if (!a.archived) a.id,
    };
    final staged = [
      for (final e in x.staged)
        if (open.contains(e.account) &&
            (e.toAccount == null || open.contains(e.toAccount)))
          e,
    ];
    final safeBefore = safeToSpend(
      live,
      start,
      end,
      accounts: accounts,
      conservative: !income,
    );
    final safeAfter = safeToSpend(
      live,
      start,
      end,
      accounts: accounts,
      conservative: !income,
      staged: staged,
      skipBills: x.skipBills.toSet(),
    );
    SpendState? simulated;
    try {
      simulated = live.copy({
        'entries': [
          ...live.entries.map((e) => e.toJson()),
          ...staged.map((e) => e.copy({'status': 'posted'}).toJson()),
        ],
      });
    } catch (_) {
      // An assumption the ledger cannot hold leaves budgets out.
    }
    final converted =
        (scope.state.settings['convertedScenarios'] as List? ?? []).contains(
          x.id,
        );
    final cur = live.currency;
    // One block per figure: the label, then as-is → with this, whole.
    Widget row(String label, BigInt a, BigInt b, {Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.symmetric(
        horizontal: HandySpace.l,
        vertical: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
          ),
          const SizedBox(height: 2),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: HandySpace.s,
            children: [
              Money(
                scope,
                a,
                cur,
                style: theme.textTheme.bodyLarge?.copyWith(color: c.muted),
              ),
              Icon(Icons.arrow_forward, size: 16, color: c.muted),
              Money(
                scope,
                b,
                cur,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: b < a ? c.negative : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
    final parts = x.staged
        .where((e) => e.payee == 'Purchase simulation')
        .toList();
    String assumptionName(Entry e) {
      final i = parts.indexOf(e);
      if (i >= 0)
        return parts.length == 1
            ? tr(context, 'Paid at once', 'Trả một lần')
            : tr(
                context,
                'Part ${i + 1} of ${parts.length}',
                'Kỳ ${i + 1}/${parts.length}',
              );
      return e.payee.isEmpty ? kindLabel(context, e.kind) : e.payee;
    }

    return HandyPage(
      title: x.name,
      subtitle: tr(
        context,
        'Forecast if… · today to ${dayLabel(context, scope, end)} · assumptions checked against the copy of ${dayLabel(context, scope, x.asOf)}',
        'Dự báo nếu… · từ hôm nay đến ${dayLabel(context, scope, end)} · giả định kiểm tra trên bản sao ngày ${dayLabel(context, scope, x.asOf)}',
      ),
      actions: [
        HandyMenuButton(
          items: [
            HandyMenuItem(
              Icons.edit_outlined,
              tr(context, 'Rename', 'Đổi tên'),
              () => _rename(context),
            ),
            HandyMenuItem(
              Icons.copy_outlined,
              tr(context, 'Duplicate', 'Nhân bản'),
              () => _duplicate(context),
            ),
            HandyMenuItem(
              Icons.delete_outline,
              tr(context, 'Discard', 'Bỏ kịch bản'),
              () => _discard(context),
              destructive: true,
              key: const Key('whatif-discard'),
            ),
          ],
        ),
      ],
      bottom: x.staged.isEmpty || converted
          ? null
          : FilledButton(
              key: const Key('whatif-record'),
              onPressed: () => _record(context),
              child: Text(
                tr(context, 'Record it for real', 'Ghi thành giao dịch thật'),
              ),
            ),
      children: [
        const SizedBox(height: HandySpace.s),
        ForecastChart(
          scope: scope,
          projection: before,
          overlays: [(after, scope.scenarioHue(x.id))],
        ),
        if (ignored > 0)
          Padding(
            padding: const EdgeInsets.only(top: HandySpace.s),
            child: HandyNotice(
              tr(
                context,
                '$ignored assumption(s) use an account that is closed now and are left out.',
                '$ignored giả định dùng tài khoản đã đóng nên không tính.',
              ),
              tone: HandyTone.warning,
            ),
          ),
        HandyLabel(tr(context, 'Effect', 'Ảnh hưởng')),
        HandyGroup(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HandySpace.l,
                HandySpace.m,
                HandySpace.l,
                0,
              ),
              child: Text(
                tr(context, 'As it is → with this', 'Hiện tại → nếu làm'),
                style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
              ),
            ),
            row(
              tr(context, 'At the end', 'Cuối kỳ'),
              before.ending,
              after.ending,
              key: const Key('whatif-month-end'),
            ),
            row(
              tr(context, 'Lowest day', 'Ngày thấp nhất'),
              before.lowest,
              after.lowest,
            ),
            row(
              tr(context, 'Free to spend', 'Có thể chi'),
              safeBefore.available,
              safeAfter.available,
            ),
            if (simulated != null)
              for (final b in live.budgets)
                row(
                  tr(context, '${b.name}: left', '${b.name}: còn'),
                  budgetRemaining(live, b),
                  budgetRemaining(simulated, b),
                ),
            if (after.shortfall != null)
              Padding(
                padding: const EdgeInsets.all(HandySpace.l),
                child: Text(
                  tr(
                    context,
                    'Runs short on ${dayLabel(context, scope, after.shortfall!)}.',
                    'Thiếu tiền từ ngày ${dayLabel(context, scope, after.shortfall!)}.',
                  ),
                  style: TextStyle(color: c.negative),
                ),
              ),
          ],
        ),
        HandyLabel(
          tr(context, 'Assumptions', 'Giả định'),
          trailing: TextButton.icon(
            key: const Key('whatif-add'),
            onPressed: () => openAssumption(context, scope, x),
            icon: const Icon(Icons.add, size: 18),
            label: Text(tr(context, 'Add', 'Thêm')),
          ),
        ),
        HandyGroup(
          children: [
            if (x.staged.isEmpty)
              Padding(
                padding: const EdgeInsets.all(HandySpace.l),
                child: Text(
                  tr(
                    context,
                    'Add income, spending, or move a due payment.',
                    'Thêm khoản thu, khoản chi, hoặc dời một khoản đến hạn.',
                  ),
                ),
              ),
            for (final e in x.staged)
              ListTile(
                key: Key('assumption-${e.id}'),
                title: Text(assumptionName(e)),
                subtitle: Text(
                  dayLabel(context, scope, reportDay(e.when, base.zone)),
                ),
                trailing: Money(
                  scope,
                  e.amount,
                  cur,
                  sign: true,
                  income: e.amount > BigInt.zero,
                ),
                onTap: () => openAssumption(context, scope, x, e),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: HandySpace.l),
          child: Text(
            tr(
              context,
              'Parts divide the total exactly; no interest is assumed. Money set aside stays as it is.',
              'Các kỳ chia đúng tổng tiền; không giả định lãi. Tiền để dành giữ nguyên.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
          ),
        ),
        if (converted)
          Padding(
            padding: const EdgeInsets.only(top: HandySpace.l),
            child: HandyNotice(
              tr(context, 'Already recorded in the ledger.', 'Đã ghi vào sổ.'),
              tone: HandyTone.success,
            ),
          ),
      ],
    );
  }

  Future<void> _change(
    BuildContext context,
    String label,
    SpendState Function(SpendState) f, {
    String Function(BuildContext)? done,
  }) =>
      scope.write(context, () => scope.controller.change(f, label), done: done);

  Future<void> _rename(BuildContext context) => showSpendForm(
    context,
    scope,
    title: tr(context, 'Rename', 'Đổi tên'),
    fields: const [SpendField('name', 'Name', 'Tên')],
    initial: {'name': scenario.name},
    save: (v) => scope.controller.change(
      (s) => s.copy({
        'scenarios': [
          for (final x in s.scenarios)
            if (x.id == scenario.id)
              {...x.toJson(), 'name': v['name']}
            else
              x.toJson(),
        ],
      }),
      'rename_scenario',
    ),
  );

  Future<void> _duplicate(BuildContext context) async {
    if (!scope.pro(context)) {
      await askForPro(context, 'Duplicating a what-if', 'Nhân bản kịch bản');
      return;
    }
    await _change(
      context,
      'duplicate_scenario',
      (s) => s.copy({
        'scenarios': [
          ...s.scenarios.map((x) => x.toJson()),
          {...scenario.toJson(), 'id': newId(), 'name': '${scenario.name} (2)'},
        ],
      }),
      done: (c) => tr(c, 'Duplicated.', 'Đã nhân bản.'),
    );
  }

  Future<void> _discard(BuildContext context) async {
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Discard ${scenario.name}?', 'Bỏ ${scenario.name}?'),
      message: tr(
        context,
        'Your real entries stay as they are.',
        'Giao dịch thật vẫn giữ nguyên.',
      ),
      confirmLabel: tr(context, 'Discard', 'Bỏ'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final navigator = Navigator.of(context);
    await _change(
      context,
      'discard_scenario',
      (s) => s.copy({
        'scenarios': [
          for (final x in s.scenarios)
            if (x.id != scenario.id) x.toJson(),
        ],
      }),
      done: (c) => tr(c, 'What-if discarded.', 'Đã bỏ kịch bản.'),
    );
    navigator.maybePop();
  }

  Future<void> _record(BuildContext context) async {
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Record this in the ledger?', 'Ghi vào sổ thật?'),
      message: tr(
        context,
        'Parts dated today or before are recorded as paid; later ones wait as not yet paid. A what-if is recorded once.',
        'Các kỳ hôm nay hoặc trước đó ghi là đã trả; kỳ sau ghi là chưa trả. Mỗi kịch bản chỉ ghi một lần.',
      ),
      confirmLabel: tr(context, 'Record', 'Ghi vào sổ'),
    );
    if (!ok || !context.mounted) return;
    final note = tr(
      context,
      'From what-if: ${scenario.name}',
      'Từ kịch bản: ${scenario.name}',
    );
    await _change(
      context,
      'convert_scenario',
      (s) {
        final done = s.settings['convertedScenarios'] as List? ?? [];
        if (done.contains(scenario.id)) throw StateError('Already recorded');
        return s.copy({
          'entries': [
            ...s.entries.map((e) => e.toJson()),
            ...scenario.staged.map(
              (e) => e.copy({
                'id': newId(),
                'status': reportDay(e.when, s.zone).compareTo(scope.today) <= 0
                    ? 'posted'
                    : 'pending',
                'note': note,
              }).toJson(),
            ),
          ],
          'settings': {
            ...s.settings,
            'convertedScenarios': [...done, scenario.id],
          },
        });
      },
      done: (c) => tr(c, 'Recorded in the ledger.', 'Đã ghi vào sổ.'),
    );
  }
}

/// An income, a spending or a moved payment inside a what-if.
Future<void> openAssumption(
  BuildContext context,
  SpendScope scope,
  Scenario x, [
  Entry? existing,
]) async {
  final base = SpendState.fromJson(x.baseline);
  final accounts = {
    for (final a in base.accounts.where(
      (a) => a.currency == base.currency && !a.archived,
    ))
      a.id: a.name,
  };
  if (accounts.isEmpty) {
    showHandyMessage(
      context,
      tr(
        context,
        'This copy has no account in ${base.currency}.',
        'Bản sao này không có tài khoản bằng ${base.currency}.',
      ),
    );
    return;
  }
  final due = upcoming(
    base,
    x.asOf,
    day(calendar(x.asOf).add(const Duration(days: 365))),
  );
  await showSpendForm(
    context,
    scope,
    title: tr(context, 'Assumption', 'Giả định'),
    fields: [
      SpendField(
        'kind',
        'It is',
        'Đây là',
        kind: FieldKind.choice,
        options: {
          'expense': kindLabel(context, 'expense'),
          'income': kindLabel(context, 'income'),
          if (existing != null &&
              !{'expense', 'income'}.contains(existing.kind))
            existing.kind: kindLabel(context, existing.kind),
        },
      ),
      SpendField(
        'amount',
        'Amount',
        'Số tiền',
        kind: FieldKind.money,
        currency: (_) => base.currency,
        signed: existing?.kind == 'adjustment',
      ),
      const SpendField('payee', 'What', 'Mô tả'),
      const SpendField('date', 'On', 'Ngày', kind: FieldKind.date),
      SpendField(
        'account',
        'Account',
        'Tài khoản',
        kind: FieldKind.choice,
        options: accounts,
      ),
      SpendField(
        'replace',
        'Instead of a payment due',
        'Thay cho một khoản đến hạn',
        kind: FieldKind.choice,
        required: false,
        options: {
          '': tr(context, 'None', 'Không'),
          for (final o in due)
            o.id: '${dayLabel(context, scope, o.date)} · ${o.bill.name}',
        },
        helpEn: 'To move a payment, pick it here and set the new date above.',
        helpVi: 'Muốn dời một khoản, chọn nó ở đây và đặt ngày mới ở trên.',
      ),
      if (existing != null)
        const SpendField(
          'remove',
          'Remove this assumption',
          'Bỏ giả định này',
          kind: FieldKind.toggle,
        ),
    ],
    initial: {
      'kind': existing?.kind ?? 'expense',
      'amount': existing == null
          ? null
          : existing.kind == 'adjustment'
          ? existing.amount
          : existing.amount.abs(),
      'payee': existing?.payee ?? '',
      'date': existing == null ? x.asOf : reportDay(existing.when, base.zone),
      'account': existing?.account ?? accounts.keys.first,
      'replace': existing?.occurrence ?? '',
      'remove': false,
    },
    save: (v) async {
      final stages = [
        for (final e in x.staged)
          if (e.id != existing?.id) e,
      ];
      final skips = x.skipBills.toSet();
      if (existing?.occurrence != null) skips.remove(existing!.occurrence);
      if (v['remove'] != true) {
        final kind = v['kind'] as String, entered = v['amount'] as BigInt;
        final amount = kind == 'expense' || kind == 'transfer'
            ? -entered
            : entered;
        final replace = (v['replace'] as String).isEmpty
            ? null
            : v['replace'] as String;
        final to = kind == 'transfer'
            ? base.accounts.firstWhere((a) => a.id == existing!.toAccount)
            : null;
        stages.add(
          Entry(
            id: existing?.id ?? newId(),
            account: v['account'] as String,
            kind: kind,
            amount: amount,
            when: localTimestamp(v['date'] as String, base.zone),
            created: existing?.created,
            payee: v['payee'] as String,
            category: kind == 'transfer' ? null : existing?.category,
            status: 'pending',
            occurrence: replace,
            refundOf: kind == 'refund' ? existing?.refundOf : null,
            toAccount: to?.id,
            target: to == null
                ? null
                : to.currency == base.currency
                ? -amount
                : convert(
                    -amount,
                    base.currency,
                    to.currency,
                    existing?.rate ?? '',
                  ),
            rate: to == null ? null : existing?.rate,
            fee: to == null ? BigInt.zero : existing?.fee,
          ),
        );
        if (replace != null) skips.add(replace);
      }
      final next = Scenario(
        id: x.id,
        name: x.name,
        asOf: x.asOf,
        baseline: x.baseline,
        staged: stages,
        skipBills: skips.toList(),
      );
      await scope.controller.change(
        (s) => s.copy({
          'scenarios': [
            for (final old in s.scenarios)
              if (old.id == next.id) next.toJson() else old.toJson(),
          ],
        }),
        'edit_scenario_assumption',
      );
    },
  );
}
