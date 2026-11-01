import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';
import '../ui/form.dart';
import '../ui/pro.dart';
import 'forecast_chart.dart';
import 'goals.dart';
import 'recurring.dart';
import 'whatifs.dart';

/// The plan: will the money last to the end of the window, and what is
/// already promised out of it.
class PlanPage extends StatelessWidget {
  final SpendScope scope;
  const PlanPage({super.key, required this.scope});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([scope.horizon, scope.conservative]),
    builder: (context, _) => LayoutBuilder(
      builder: (context, size) {
        if (scope.state.accounts.isEmpty) {
          return Center(
            child: HandyEmpty(
              title: tr(
                context,
                'Nothing to plan yet',
                'Chưa có gì để lập kế hoạch',
              ),
              message: tr(
                context,
                'Add an account on Today first.',
                'Hãy thêm một tài khoản ở Hôm nay trước.',
              ),
            ),
          );
        }
        final wide = size.maxWidth >= 1000;
        final p = forecast(
          scope.state,
          scope.today,
          scope.end,
          accounts: scope.planningAccounts,
          includeIncome: !scope.conservative.value,
        );
        final left = [
          _Window(scope: scope),
          const SizedBox(height: HandySpace.l),
          _Outlook(scope: scope, projection: p),
          _Counted(scope: scope),
        ];
        final right = [
          RecurringSection(scope: scope),
          GoalsSection(scope: scope),
          const SizedBox(height: HandySpace.l),
          WhatIfSection(scope: scope),
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            HandySpace.l,
            HandySpace.l,
            HandySpace.l,
            48,
          ),
          children: [
            HandyContent(
              maxWidth: HandySpace.contentWide,
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: left,
                          ),
                        ),
                        const SizedBox(width: HandySpace.xl),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: right,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [...left, ...right],
                    ),
            ),
          ],
        );
      },
    ),
  );
}

/// How far ahead, and whether reliable income counts.
class _Window extends StatelessWidget {
  final SpendScope scope;
  const _Window({required this.scope});

  Future<void> choose(BuildContext context, int days) async {
    if (days > 30 && !scope.pro(context)) {
      await askForPro(context, 'Planning past 30 days', 'Kế hoạch quá 30 ngày');
      return;
    }
    scope.horizon.value = days;
  }

  Future<void> custom(BuildContext context) => showSpendForm(
    context,
    scope,
    title: tr(context, 'Plan ahead', 'Kế hoạch trước'),
    saveLabel: tr(context, 'Use', 'Dùng'),
    fields: const [
      SpendField(
        'days',
        'Days, today included',
        'Số ngày, tính cả hôm nay',
        kind: FieldKind.count,
        helpEn: '1 to 3660. Past 30 days needs Pro.',
        helpVi: 'Từ 1 đến 3660. Quá 30 ngày cần Pro.',
      ),
    ],
    initial: {'days': '${scope.horizon.value}'},
    save: (v) async {
      final days = v['days'] as int;
      if (days < 1 || days > 3660)
        throw const FormatException('1 to 3660 days / Từ 1 đến 3660 ngày');
      if (days > 30 && !scope.pro(context))
        throw const FormatException(
          'Past 30 days needs Pro / Quá 30 ngày cần Pro',
        );
      scope.horizon.value = days;
    },
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = scope.horizon.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            tr(
              context,
              'Until ${dayLabel(context, scope, scope.end)}',
              'Đến ${dayLabel(context, scope, scope.end)}',
            ),
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: HandySpace.m),
        Wrap(
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          children: [
            for (final d in [7, 30, 90])
              ChoiceChip(
                key: Key('horizon-$d'),
                label: Text(tr(context, '$d days', '$d ngày')),
                selected: h == d,
                onSelected: (_) => choose(context, d),
              ),
            ChoiceChip(
              key: const Key('horizon-custom'),
              label: Text(
                [7, 30, 90].contains(h)
                    ? tr(context, 'Other…', 'Khác…')
                    : tr(context, '$h days', '$h ngày'),
              ),
              selected: ![7, 30, 90].contains(h),
              onSelected: (_) => custom(context),
            ),
          ],
        ),
        SwitchListTile.adaptive(
          key: const Key('plan-income'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            tr(context, 'Count reliable income', 'Tính thu nhập chắc chắn'),
          ),
          subtitle: Text(
            tr(
              context,
              'Off: only money already held. On: add pay marked reliable.',
              'Tắt: chỉ tiền đang có. Bật: cộng khoản lương đã đánh dấu chắc chắn.',
            ),
          ),
          value: !scope.conservative.value,
          onChanged: (v) => scope.conservative.value = !v,
        ),
      ],
    );
  }
}

class _Outlook extends StatelessWidget {
  final SpendScope scope;
  final Projection projection;
  const _Outlook({required this.scope, required this.projection});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final p = projection;
    Widget cell(String label, BigInt v, {String? note}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
          ),
          Money(
            scope,
            v,
            scope.currency,
            style: theme.textTheme.titleMedium?.copyWith(
              color: v.isNegative ? c.negative : null,
            ),
          ),
          if (note != null)
            Text(
              note,
              style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
            ),
        ],
      ),
    );
    final low = p.points.isEmpty
        ? null
        : p.points.reduce((a, b) => b.balance < a.balance ? b : a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ForecastChart(scope: scope, projection: p),
        const SizedBox(height: HandySpace.m),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cell(tr(context, 'Today', 'Hôm nay'), p.opening),
            cell(
              tr(context, 'Lowest', 'Thấp nhất'),
              p.lowest,
              note: low == null ? null : dayLabel(context, scope, low.date),
            ),
            cell(tr(context, 'At the end', 'Cuối kỳ'), p.ending),
          ],
        ),
        if (p.shortfall != null)
          Padding(
            padding: const EdgeInsets.only(top: HandySpace.m),
            child: HandyNotice(
              tr(
                context,
                'Runs below zero on ${dayLabel(context, scope, p.shortfall!)}.',
                'Xuống dưới 0 từ ngày ${dayLabel(context, scope, p.shortfall!)}.',
              ),
              tone: HandyTone.error,
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const Key('plan-daily'),
            onPressed: () => showDailyTable(context, scope, p),
            child: Text(tr(context, 'Day by day', 'Xem từng ngày')),
          ),
        ),
        Text(
          tr(
            context,
            'An estimate in calendar days, both ends included. Unpaid payments from the last 366 days count as due today. It is not advice or a promise.',
            'Ước tính theo ngày lịch, tính cả hai đầu. Khoản chưa trả trong 366 ngày qua tính là đến hạn hôm nay. Không phải lời khuyên hay cam kết.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
        ),
      ],
    );
  }
}

/// Which accounts count as money to spend.
class _Counted extends StatelessWidget {
  final SpendScope scope;
  const _Counted({required this.scope});
  @override
  Widget build(BuildContext context) {
    final s = scope.state;
    final ids = scope.planningAccounts;
    final choices = s.accounts
        .where((a) => a.currency == s.currency && !a.archived && !a.liability)
        .toList();
    return HandySection(
      title: tr(context, 'Money counted', 'Tiền được tính'),
      children: [
        for (final a in choices)
          CheckboxListTile.adaptive(
            key: Key('counted-${a.id}'),
            title: Text(a.name),
            subtitle: Text(
              a.type == 'savings'
                  ? tr(
                      context,
                      'Savings: only when you tick it',
                      'Tiết kiệm: chỉ khi bạn chọn',
                    )
                  : accountTypeLabel(context, a.type),
            ),
            value: ids.contains(a.id),
            onChanged: (v) {
              final next = Set<String>.of(ids);
              v == true ? next.add(a.id) : next.remove(a.id);
              scope.write(
                context,
                () => scope.controller.change(
                  (s) => s.copy({
                    'settings': {
                      ...s.settings,
                      'eligibleAccounts': next.toList(),
                    },
                  }),
                  'planning_accounts',
                ),
              );
            },
          ),
        if (choices.isEmpty)
          Padding(
            padding: const EdgeInsets.all(HandySpace.l),
            child: Text(
              tr(
                context,
                'No account in ${s.currency}. Debts never count.',
                'Không có tài khoản bằng ${s.currency}. Nợ không bao giờ được tính.',
              ),
            ),
          ),
      ],
    );
  }
}
