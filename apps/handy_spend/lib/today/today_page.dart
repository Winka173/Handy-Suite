import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../accounts/account_editor.dart';
import '../entry/entry_sheet.dart';
import '../ledger/entry_row.dart';
import '../plan/recurring.dart';
import '../scope.dart';
import '../ui/figures.dart';
import 'coming_up.dart';
import 'promised_bar.dart';
import 'promised_logic.dart';

/// Today: how much is free to spend until the plan's end, what is already
/// promised out of the money held, what is due next and what was spent.
class TodayPage extends StatelessWidget {
  final SpendScope scope;
  const TodayPage({super.key, required this.scope});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([scope.horizon, scope.conservative]),
    builder: (context, _) => LayoutBuilder(
      builder: (context, size) {
        final s = scope.state;
        if (s.accounts.isEmpty) return _FirstRun(scope: scope);
        final promised = promisedMoney(
          s,
          scope.today,
          scope.end,
          accounts: scope.planningAccounts,
          conservative: scope.conservative.value,
        );
        final lead = _Lead(scope: scope, promised: promised);
        final side = [
          ..._notices(context),
          _ComingUp(scope: scope),
          _Recent(scope: scope),
        ];
        final wide = size.maxWidth >= 1000;
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            HandySpace.l,
            HandySpace.l,
            HandySpace.l,
            96,
          ),
          children: [
            HandyContent(
              maxWidth: HandySpace.contentWide,
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              lead,
                              _Recent(scope: scope),
                            ],
                          ),
                        ),
                        const SizedBox(width: HandySpace.xl),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: side.sublist(0, side.length - 1),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [lead, ...side],
                    ),
            ),
          ],
        );
      },
    ),
  );

  List<Widget> _notices(BuildContext context) {
    final s = scope.state;
    final latest = lastRecordedDays(s, scope.today);
    final stale = [
      for (final a in scope.openAccounts)
        if (latest[a.id] != null &&
            calendar(scope.today).difference(calendar(latest[a.id]!)).inDays >=
                30)
          a,
    ];
    return [
      if (stale.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: HandySpace.l),
          child: HandyNotice(
            tr(
              context,
              '${stale.map((a) => a.name).join(', ')}: nothing recorded for 30 days or more. Check the real balance.',
              '${stale.map((a) => a.name).join(', ')}: hơn 30 ngày chưa ghi gì. Hãy đối chiếu số dư thật.',
            ),
            tone: HandyTone.warning,
            action: TextButton(
              key: const Key('stale-open'),
              onPressed: () {
                scope.openAccount.value = stale.first.id;
                scope.area.value = 3;
              },
              child: Text(tr(context, 'Check', 'Đối chiếu')),
            ),
          ),
        ),
      if (s.bills.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: HandySpace.l),
          child: HandyNotice(
            tr(
              context,
              'Add your pay and rent to see what is already promised.',
              'Thêm lương và tiền nhà để thấy khoản nào đã hứa trả.',
            ),
            action: TextButton(
              key: const Key('setup-bill'),
              onPressed: () => openBillEditor(context, scope),
              child: Text(tr(context, 'Add', 'Thêm')),
            ),
          ),
        ),
    ];
  }
}

class _Lead extends StatelessWidget {
  final SpendScope scope;
  final Promised promised;
  const _Lead({required this.scope, required this.promised});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final safe = promised.safe;
    final short = safe.shortfall > BigInt.zero;
    final until = dayLabel(context, scope, scope.end);
    final next = promised.outs.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            short
                ? tr(context, 'Short until $until', 'Thiếu đến $until')
                : tr(
                    context,
                    'Free to spend until $until',
                    'Có thể chi đến $until',
                  ),
            style: theme.textTheme.titleMedium?.copyWith(color: c.muted),
          ),
        ),
        const SizedBox(height: HandySpace.xs),
        Money(
          scope,
          short ? -safe.shortfall : safe.available,
          scope.currency,
          key: const Key('safe-figure'),
          style: theme.textTheme.displaySmall?.copyWith(
            color: short ? c.negative : null,
          ),
        ),
        const SizedBox(height: HandySpace.xs),
        Text(
          short
              ? tr(
                  context,
                  'What is promised is more than the money held. See the plan.',
                  'Khoản đã hứa nhiều hơn tiền đang có. Xem kế hoạch.',
                )
              : tr(
                  context,
                  '${moneyText(context, scope, safe.perDay, scope.currency)} a day for ${safe.days} days',
                  '${moneyText(context, scope, safe.perDay, scope.currency)} mỗi ngày trong ${safe.days} ngày',
                ),
          style: theme.textTheme.bodyLarge,
        ),
        if (next != null)
          Padding(
            padding: const EdgeInsets.only(top: HandySpace.xs),
            child: Text(
              tr(
                context,
                'Next: ${partName(context, next)}, ${moneyText(context, scope, next.amount, scope.currency)}, ${whenLabel(context, scope, next.date).toLowerCase()}',
                'Tiếp theo: ${partName(context, next)}, ${moneyText(context, scope, next.amount, scope.currency)}, ${whenLabel(context, scope, next.date).toLowerCase()}',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
            ),
          ),
        const SizedBox(height: HandySpace.l),
        PromisedBar(scope: scope, promised: promised),
        const SizedBox(height: HandySpace.m),
        PromisedSum(scope: scope, promised: promised),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const Key('open-plan'),
            onPressed: () => scope.area.value = 2,
            child: Text(
              scope.conservative.value
                  ? tr(
                      context,
                      'Posted money only · change in Plan',
                      'Chỉ tính tiền đã có · đổi trong Kế hoạch',
                    )
                  : tr(
                      context,
                      'With reliable income · change in Plan',
                      'Gồm thu nhập chắc chắn · đổi trong Kế hoạch',
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ComingUp extends StatelessWidget {
  final SpendScope scope;
  const _ComingUp({required this.scope});
  @override
  Widget build(BuildContext context) {
    final due = upcoming(scope.state, scope.today, scope.end);
    return HandySection(
      title: tr(context, 'Coming up', 'Sắp tới'),
      trailing: TextButton(
        onPressed: () => scope.area.value = 2,
        child: Text(tr(context, 'All in Plan', 'Xem kế hoạch')),
      ),
      children: [
        if (due.isEmpty)
          Padding(
            padding: const EdgeInsets.all(HandySpace.l),
            child: Text(
              tr(
                context,
                'Nothing due until ${dayLabel(context, scope, scope.end)}.',
                'Không có khoản nào đến hạn trước ${dayLabel(context, scope, scope.end)}.',
              ),
            ),
          ),
        for (final o in due.take(5)) DueRow(scope: scope, occurrence: o),
        if (due.length > 5)
          Padding(
            padding: const EdgeInsets.all(HandySpace.l),
            child: Text(
              tr(
                context,
                '${due.length - 5} more in Plan',
                'Còn ${due.length - 5} khoản trong Kế hoạch',
              ),
              style: TextStyle(color: HandyColors.of(context).muted),
            ),
          ),
      ],
    );
  }
}

class _Recent extends StatelessWidget {
  final SpendScope scope;
  const _Recent({required this.scope});
  @override
  Widget build(BuildContext context) {
    final rows = [...scope.state.entries]
      ..sort((a, b) => b.when.compareTo(a.when));
    return HandySection(
      title: tr(context, 'Recent', 'Gần đây'),
      trailing: TextButton(
        onPressed: () => scope.area.value = 1,
        child: Text(tr(context, 'Open ledger', 'Mở sổ')),
      ),
      children: [
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(HandySpace.l),
            child: Text(
              tr(
                context,
                'Nothing recorded yet. Record what you spend as you go.',
                'Chưa ghi gì. Tiêu khoản nào ghi khoản đó.',
              ),
            ),
          ),
        for (final e in rows.take(5))
          EntryRow(
            scope: scope,
            entry: e,
            showDate: true,
            onTap: () => openEntry(context, scope, entry: e),
          ),
      ],
    );
  }
}

class _FirstRun extends StatelessWidget {
  final SpendScope scope;
  const _FirstRun({required this.scope});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(HandySpace.l),
    children: [
      HandyContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                tr(context, 'Free to spend', 'Có thể chi'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: HandyColors.of(context).muted,
                ),
              ),
            ),
            const SizedBox(height: HandySpace.l),
            HandyEmpty(
              title: tr(
                context,
                'Start with the money you have',
                'Bắt đầu bằng số tiền bạn đang có',
              ),
              message: tr(
                context,
                'Add cash, a bank account or an e-wallet with today\'s balance. Nothing connects to a bank; it all stays on this device.',
                'Thêm tiền mặt, tài khoản ngân hàng hoặc ví điện tử với số dư hôm nay. Không kết nối ngân hàng; mọi thứ ở trên máy này.',
              ),
              action: FilledButton.icon(
                key: const Key('add-first-account'),
                onPressed: () => openAccountEditor(context, scope),
                icon: const Icon(Icons.add),
                label: Text(tr(context, 'Add account', 'Thêm tài khoản')),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
