import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../money.dart';
import '../scope.dart';
import '../today/coming_up.dart';
import '../ui/figures.dart';
import '../ui/form.dart';

/// Adds or edits something that repeats: rent, a subscription, pay day.
Future<bool> openBillEditor(
  BuildContext context,
  SpendScope scope, [
  Bill? b,
]) async {
  final s = scope.state;
  if (scope.openAccounts.isEmpty) return false;
  final accounts = {
    for (final a in scope.openAccounts) a.id: '${a.name} · ${a.currency}',
  };
  final first = b?.account ?? scope.openAccounts.first.id;
  return showSpendForm(
    context,
    scope,
    title: b == null
        ? tr(context, 'Something that repeats', 'Khoản định kỳ')
        : b.name,
    fields: [
      const SpendField(
        'name',
        'Name',
        'Tên',
        helpEn: 'Rent, Electricity, Salary…',
        helpVi: 'Tiền nhà, Tiền điện, Lương…',
      ),
      SpendField(
        'direction',
        'It is',
        'Đây là',
        kind: FieldKind.choice,
        options: {
          'out': tr(context, 'A payment', 'Khoản phải trả'),
          'in': tr(context, 'Money coming in', 'Khoản thu'),
        },
      ),
      SpendField(
        'amount',
        'Amount each time',
        'Số tiền mỗi lần',
        kind: FieldKind.money,
        currency: (v) => scope.account(v['account'] as String).currency,
      ),
      SpendField(
        'frequency',
        'Repeats',
        'Lặp lại',
        kind: FieldKind.choice,
        options: {
          for (final f in ['monthly', 'weekly', 'yearly', 'once'])
            f: frequencyLabel(context, f),
        },
      ),
      const SpendField(
        'due',
        'Next due',
        'Lần đến hạn',
        kind: FieldKind.date,
        helpEn:
            'Monthly dates keep this day; the 31st becomes the month\'s last day.',
        helpVi: 'Hàng tháng giữ ngày này; ngày 31 thành ngày cuối tháng.',
      ),
      SpendField(
        'account',
        'Account',
        'Tài khoản',
        kind: FieldKind.choice,
        options: accounts,
      ),
      SpendField(
        'to',
        'Moves into (optional)',
        'Chuyển vào (không bắt buộc)',
        kind: FieldKind.choice,
        required: false,
        options: {
          '': tr(context, 'Nowhere, it is spent', 'Không, đây là khoản chi'),
          ...accounts,
        },
        helpEn: 'For a saving plan or a card repayment between your accounts.',
        helpVi:
            'Cho khoản gửi tiết kiệm hoặc trả thẻ giữa các tài khoản của bạn.',
      ),
      SpendField(
        'category',
        'Category',
        'Danh mục',
        kind: FieldKind.choice,
        required: false,
        options: {
          '': tr(context, 'None', 'Không'),
          for (final c in s.categories.where(
            (c) => !c.archived || c.id == b?.category,
          ))
            c.id: c.name,
        },
      ),
      const SpendField(
        'reliable',
        'Count before it arrives',
        'Tính trước khi nhận',
        kind: FieldKind.toggle,
        helpEn:
            'Income only. Free to spend adds it when the plan includes reliable income.',
        helpVi:
            'Chỉ cho khoản thu. Có thể chi cộng khoản này khi kế hoạch gồm thu nhập chắc chắn.',
      ),
      const SpendField(
        'remind',
        'Remind me on the day',
        'Nhắc vào ngày đến hạn',
        kind: FieldKind.toggle,
        helpEn: 'The notice names nothing and shows no amount.',
        helpVi: 'Thông báo không ghi tên hay số tiền.',
      ),
      const SpendField(
        'rate',
        'Rate, if the currencies differ',
        'Tỷ giá, nếu khác loại tiền',
        required: false,
      ),
    ],
    initial: {
      'name': b?.name ?? '',
      'direction': (b?.amount.isNegative ?? true) ? 'out' : 'in',
      'amount': b?.amount.abs(),
      'frequency': b?.frequency ?? 'monthly',
      'due': b?.due ?? scope.today,
      'account': first,
      'to': b?.toAccount ?? '',
      'category': b?.category ?? '',
      'reliable': b?.reliable ?? false,
      'remind': b?.remind ?? false,
      'rate': b?.rate ?? '',
    },
    save: (v) async {
      final from = scope.account(v['account'] as String);
      final to = (v['to'] as String).isEmpty
          ? null
          : scope.account(v['to'] as String);
      if (to != null && v['direction'] == 'in')
        throw const FormatException(
          'A move between accounts is a payment out / Chuyển giữa tài khoản là khoản trả ra',
        );
      final magnitude = v['amount'] as BigInt;
      if (magnitude <= BigInt.zero)
        throw const FormatException('Enter an amount / Nhập số tiền');
      final amount = v['direction'] == 'out' ? -magnitude : magnitude;
      final rate = (v['rate'] as String).trim();
      final next = Bill(
        id: b?.id ?? newId(),
        name: v['name'] as String,
        account: from.id,
        amount: amount,
        due: v['due'] as String,
        frequency: v['frequency'] as String,
        category: (v['category'] as String).isEmpty
            ? null
            : v['category'] as String,
        reliable: v['direction'] == 'in' && v['reliable'] == true,
        enabled: b?.enabled ?? true,
        remind: v['remind'] == true,
        toAccount: to?.id,
        target: to == null
            ? null
            : to.currency == from.currency
            ? -amount
            : convert(-amount, from.currency, to.currency, rate),
        rate: to == null || to.currency == from.currency || rate.isEmpty
            ? null
            : rate,
      );
      await scope.controller.change(
        (s) => s.copy({
          'bills': [
            for (final x in s.bills)
              if (x.id != next.id) x.toJson(),
            next.toJson(),
          ],
        }),
        'save_bill',
      );
    },
  );
}

/// Everything that repeats, its next date and what it costs in a year.
class RecurringSection extends StatelessWidget {
  final SpendScope scope;
  const RecurringSection({super.key, required this.scope});

  @override
  Widget build(BuildContext context) {
    final s = scope.state;
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final ahead = upcoming(
      s,
      scope.today,
      day(calendar(scope.today).add(const Duration(days: 400))),
    );
    final last = lastBillPaymentDays(s, scope.today);
    final bills = [...s.bills]
      ..sort((a, b) => a.enabled == b.enabled ? 0 : (a.enabled ? -1 : 1));
    final yearly = <String, BigInt>{};
    for (final b in s.bills.where(
      (b) => b.enabled && b.amount.isNegative && b.toAccount == null,
    )) {
      final cur = scope.account(b.account).currency;
      yearly[cur] =
          (yearly[cur] ?? BigInt.zero) +
          b.amount.abs() * BigInt.from(perYear(b.frequency));
    }
    return HandySection(
      title: tr(context, 'Repeats', 'Khoản định kỳ'),
      trailing: TextButton.icon(
        key: const Key('bill-add'),
        onPressed: () => openBillEditor(context, scope),
        icon: const Icon(Icons.add, size: 18),
        label: Text(tr(context, 'Add', 'Thêm')),
      ),
      children: [
        if (bills.isEmpty)
          Padding(
            padding: const EdgeInsets.all(HandySpace.l),
            child: Text(
              tr(
                context,
                'Rent, bills, subscriptions and pay day. Each one shows here with its next date.',
                'Tiền nhà, hóa đơn, gói đăng ký và ngày lương. Mỗi khoản hiện ở đây kèm lần đến hạn kế tiếp.',
              ),
            ),
          ),
        for (final b in bills)
          _BillRow(
            scope: scope,
            bill: b,
            next: ahead.where((o) => o.bill.id == b.id).firstOrNull,
            lastPaid: last[b.id],
          ),
        for (final e in yearly.entries)
          Padding(
            padding: const EdgeInsets.all(HandySpace.l),
            child: Text(
              tr(
                context,
                'Payments that repeat: about ${moneyText(context, scope, e.value ~/ BigInt.from(12), e.key)} a month, ${moneyText(context, scope, e.value, e.key)} a year (weekly counted 52 times).',
                'Khoản trả định kỳ: khoảng ${moneyText(context, scope, e.value ~/ BigInt.from(12), e.key)} mỗi tháng, ${moneyText(context, scope, e.value, e.key)} mỗi năm (hàng tuần tính 52 lần).',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
            ),
          ),
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  final SpendScope scope;
  final Bill bill;
  final Occurrence? next;
  final String? lastPaid;
  const _BillRow({
    required this.scope,
    required this.bill,
    required this.next,
    required this.lastPaid,
  });

  Future<void> toggle(BuildContext context) => scope.write(
    context,
    () => scope.controller.change(
      (s) => s.copy({
        'bills': [
          for (final b in s.bills)
            if (b.id == bill.id)
              {...b.toJson(), 'enabled': !bill.enabled}
            else
              b.toJson(),
        ],
      }),
      bill.enabled ? 'disable_bill' : 'enable_bill',
    ),
    done: (c) => bill.enabled
        ? tr(
            c,
            '${bill.name} paused. Its history stays.',
            'Đã tạm dừng ${bill.name}. Lịch sử vẫn giữ.',
          )
        : tr(c, '${bill.name} is back on.', 'Đã bật lại ${bill.name}.'),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final account = scope.account(bill.account);
    final meta = [
      frequencyLabel(context, bill.frequency),
      if (!bill.enabled)
        tr(context, 'paused', 'đang dừng')
      else if (next != null)
        tr(
          context,
          'next ${whenLabel(context, scope, next!.date).toLowerCase()}',
          'kế tiếp ${whenLabel(context, scope, next!.date).toLowerCase()}',
        ),
      account.name,
      if (lastPaid != null)
        tr(
          context,
          'last paid ${dayLabel(context, scope, lastPaid!)}',
          'trả lần cuối ${dayLabel(context, scope, lastPaid!)}',
        ),
    ].join(' · ');
    return InkWell(
      key: Key('bill-${bill.id}'),
      onTap: () => openBillEditor(context, scope, bill),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(HandySpace.l, 10, 0, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.name,
                    style: TextStyle(color: bill.enabled ? null : c.muted),
                  ),
                  Text(
                    meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
            Money(
              scope,
              bill.toAccount != null ? -bill.amount : bill.amount,
              account.currency,
              sign: bill.toAccount == null,
              income: bill.amount > BigInt.zero && bill.toAccount == null,
            ),
            HandyMenuButton(
              items: [
                if (next != null && bill.enabled)
                  HandyMenuItem(
                    Icons.check,
                    tr(context, 'Paid today', 'Đã trả hôm nay'),
                    () => markPaid(context, scope, next!),
                  ),
                HandyMenuItem(
                  bill.enabled ? Icons.pause : Icons.play_arrow,
                  bill.enabled
                      ? tr(context, 'Pause', 'Tạm dừng')
                      : tr(context, 'Turn back on', 'Bật lại'),
                  () => toggle(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
