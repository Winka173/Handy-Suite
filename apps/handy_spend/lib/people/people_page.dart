import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/figures.dart';
import '../ui/form.dart';
import '../ui/sheet.dart';
import 'people_logic.dart';
import 'split_sheet.dart';

/// "Who owes whom": what people owe you and what you owe them, person by
/// person. Money owed to you is not in Free to spend until it is paid;
/// what you owe is already taken out of it.
class PeoplePage extends StatelessWidget {
  final SpendScope scope;
  const PeoplePage({super.key, required this.scope});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final s = scope.state;
      final theme = Theme.of(context);
      final c = HandyColors.of(context);
      final owed = owedByPerson(s);
      final (them, you) = iouTotals(s, scope.currency);
      final people =
          [
            for (final p in s.people)
              if (!p.archived || owed.containsKey(p.id)) p,
          ]..sort(
            (a, b) =>
                (owed.containsKey(b.id) ? 1 : 0) -
                (owed.containsKey(a.id) ? 1 : 0),
          );
      Widget figure(String label, BigInt v, Key key) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
            ),
            const SizedBox(height: 2),
            Money(
              scope,
              v,
              scope.currency,
              key: key,
              style: theme.textTheme.headlineSmall,
            ),
          ],
        ),
      );
      return HandyPage(
        title: tr(context, 'Who owes whom', 'Ai nợ ai'),
        bottom: FilledButton.icon(
          key: const Key('people-paid-for-me'),
          onPressed: () => openPaidForYou(context, scope),
          icon: const Icon(Icons.add),
          label: Text(
            tr(context, 'Someone paid for you', 'Người khác trả giúp bạn'),
          ),
        ),
        children: [
          const SizedBox(height: HandySpace.s),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              figure(
                tr(context, 'People owe you', 'Người khác nợ bạn'),
                them,
                const Key('people-owed'),
              ),
              const SizedBox(width: HandySpace.l),
              figure(
                tr(context, 'You owe', 'Bạn nợ'),
                you,
                const Key('people-owe'),
              ),
            ],
          ),
          const SizedBox(height: HandySpace.s),
          Text(
            tr(
              context,
              'Money owed to you counts in Free to spend only once it is paid. What you owe is already taken out.',
              'Tiền người khác nợ chỉ tính vào Có thể chi khi đã trả. Khoản bạn nợ đã được trừ sẵn.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
          ),
          if (people.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: HandySpace.l),
              child: HandyEmpty(
                title: tr(context, 'Nothing shared yet', 'Chưa chia khoản nào'),
                message: tr(
                  context,
                  'Open a spending entry and choose Split, or record what someone paid for you.',
                  'Mở một khoản chi và chọn Chia tiền, hoặc ghi khoản người khác trả giúp bạn.',
                ),
              ),
            )
          else
            HandySection(
              title: tr(context, 'People', 'Mọi người'),
              children: [
                for (final p in people)
                  HandyTile(
                    key: Key('person-${p.id}'),
                    title: p.name,
                    hue: scope.personHue(p.id),
                    subtitle: balanceLine(context, scope, p, owed[p.id]),
                    navigates: true,
                    onTap: () =>
                        Navigator.pushNamed(context, '/person/${p.id}'),
                  ),
              ],
            ),
        ],
      );
    },
  );
}

/// "Owes you 300.000 đ", "You owe 120.000 đ" or "Settled".
String balanceLine(
  BuildContext context,
  SpendScope scope,
  Person p,
  Map<String, BigInt>? owed,
) {
  if (owed == null || owed.isEmpty) return tr(context, 'Settled', 'Hết nợ');
  return [
    for (final e in owed.entries)
      e.value.isNegative
          ? tr(
              context,
              'You owe ${moneyText(context, scope, -e.value, e.key)}',
              'Bạn nợ ${moneyText(context, scope, -e.value, e.key)}',
            )
          : tr(
              context,
              'Owes you ${moneyText(context, scope, e.value, e.key)}',
              'Nợ bạn ${moneyText(context, scope, e.value, e.key)}',
            ),
  ].join(' · ');
}

/// One person: what is open between you, item by item, and settling up.
class PersonPage extends StatelessWidget {
  final SpendScope scope;
  final String id;
  const PersonPage({super.key, required this.scope, required this.id});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final p = scope.person(id);
      if (p == null)
        return HandyPage(
          title: tr(context, 'Person', 'Người'),
          children: [
            HandyEmpty(
              title: tr(
                context,
                'Not in your list',
                'Không có trong danh sách',
              ),
            ),
          ],
        );
      final theme = Theme.of(context);
      final c = HandyColors.of(context);
      final s = scope.state;
      final items = personItems(s, id);
      final open = items.where((i) => i.open > BigInt.zero).toList();
      final done = items.where((i) => i.open == BigInt.zero).toList();
      final owed = owedByPerson(s)[id];
      Widget row(PersonItem i) {
        final x = i.split;
        final what = i.theyOwe
            ? tr(
                context,
                'Their share ${moneyText(context, scope, i.share, x.currency)}',
                'Phần của ${p.name} ${moneyText(context, scope, i.share, x.currency)}',
              )
            : tr(
                context,
                '${p.name} paid; your share ${moneyText(context, scope, i.share, x.currency)}',
                '${p.name} trả; phần bạn ${moneyText(context, scope, i.share, x.currency)}',
              );
        return ListTile(
          key: Key('item-${x.id}'),
          title: Text(
            x.name.isEmpty ? tr(context, 'Shared cost', 'Khoản chung') : x.name,
          ),
          subtitle: Text('${dayLabel(context, scope, x.date)} · $what'),
          trailing: i.open == BigInt.zero
              ? Text(
                  tr(context, 'Settled', 'Đã xong'),
                  style: TextStyle(color: c.muted),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Money(scope, i.open, x.currency),
                    Text(
                      i.theyOwe
                          ? tr(context, 'owes you', 'nợ bạn')
                          : tr(context, 'you owe', 'bạn nợ'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
          onTap: i.open == BigInt.zero
              ? null
              : () => openSettle(context, scope, p, item: i),
        );
      }

      return HandyPage(
        title: p.name,
        actions: [
          HandyMenuButton(
            items: [
              HandyMenuItem(
                Icons.edit_outlined,
                tr(context, 'Rename', 'Đổi tên'),
                () => _rename(context, p),
              ),
              if (owed == null)
                HandyMenuItem(
                  p.archived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  p.archived
                      ? tr(
                          context,
                          'Show in lists again',
                          'Hiện lại trong danh sách',
                        )
                      : tr(context, 'Hide from lists', 'Ẩn khỏi danh sách'),
                  () => _archive(context, p),
                ),
            ],
          ),
        ],
        bottom: open.isEmpty
            ? null
            : FilledButton(
                key: const Key('person-settle'),
                onPressed: () => openSettle(context, scope, p),
                child: Text(tr(context, 'Settle up', 'Thanh toán')),
              ),
        children: [
          const SizedBox(height: HandySpace.s),
          Text(
            balanceLine(context, scope, p, owed),
            key: const Key('person-balance'),
            style: theme.textTheme.headlineSmall,
          ),
          if (open.isNotEmpty)
            HandySection(
              title: tr(context, 'Open', 'Còn mở'),
              children: [for (final i in open) row(i)],
            ),
          if (done.isNotEmpty)
            HandySection(
              title: tr(context, 'Settled', 'Đã xong'),
              children: [for (final i in done.reversed.take(20)) row(i)],
            ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: HandySpace.l),
              child: HandyEmpty(
                title: tr(
                  context,
                  'Nothing shared with ${p.name} yet',
                  'Chưa chia gì với ${p.name}',
                ),
              ),
            ),
        ],
      );
    },
  );

  Future<void> _rename(BuildContext context, Person p) => showSpendForm(
    context,
    scope,
    title: tr(context, 'Rename', 'Đổi tên'),
    fields: const [SpendField('name', 'Name', 'Tên')],
    initial: {'name': p.name},
    save: (v) => scope.controller.change(
      (s) => s.copy({
        'people': [
          for (final x in s.people)
            if (x.id == p.id)
              {...x.toJson(), 'name': v['name']}
            else
              x.toJson(),
        ],
      }),
      'rename_person',
    ),
  );

  Future<void> _archive(BuildContext context, Person p) => scope.write(
    context,
    () => scope.controller.change(
      (s) => s.copy({
        'people': [
          for (final x in s.people)
            if (x.id == p.id)
              {...x.toJson(), 'archived': !p.archived}
            else
              x.toJson(),
        ],
      }),
      'archive_person',
    ),
    done: (c) => p.archived
        ? tr(c, '${p.name} is back in lists.', '${p.name} đã hiện lại.')
        : tr(c, '${p.name} is hidden from lists.', 'Đã ẩn ${p.name}.'),
  );
}

/// Settles with [p]: everything open in one currency, or one [item]. The
/// person picks the account the money really moved through; nothing is
/// chosen for them.
Future<void> openSettle(
  BuildContext context,
  SpendScope scope,
  Person p, {
  PersonItem? item,
}) async {
  final s = scope.state;
  final items = [
    for (final i in personItems(s, p.id))
      if (i.open > BigInt.zero && (item == null || i.split.id == item.split.id))
        i,
  ];
  if (items.isEmpty) return;
  final currency = items.first.split.currency;
  final theirs = items
      .where((i) => i.theyOwe && i.split.currency == currency)
      .fold(BigInt.zero, (BigInt n, i) => n + i.open);
  final yours = items
      .where((i) => !i.theyOwe && i.split.currency == currency)
      .fold(BigInt.zero, (BigInt n, i) => n + i.open);
  final theyPay = theirs >= yours;
  final net = (theirs - yours).abs();
  final accounts = {
    for (final a in scope.openAccounts.where((a) => a.currency == currency))
      a.id: a.name,
  };
  if (accounts.isEmpty) {
    showHandyMessage(
      context,
      tr(
        context,
        'Add an account in $currency first.',
        'Hãy thêm một tài khoản bằng $currency trước.',
      ),
    );
    return;
  }
  final done = await showSpendForm(
    context,
    scope,
    title: theyPay
        ? tr(context, '${p.name} pays you', '${p.name} trả bạn')
        : tr(context, 'You pay ${p.name}', 'Bạn trả ${p.name}'),
    saveLabel: tr(context, 'Record payment', 'Ghi khoản trả'),
    fields: [
      SpendField(
        'amount',
        'Amount',
        'Số tiền',
        kind: FieldKind.money,
        currency: (_) => currency,
        helpEn:
            'Up to ${moneyText(context, scope, net, currency)}. Less settles part of it.',
        helpVi:
            'Tối đa ${moneyText(context, scope, net, currency)}. Ít hơn là trả một phần.',
      ),
      SpendField(
        'account',
        theyPay ? 'Paid into' : 'Paid from',
        theyPay ? 'Nhận vào' : 'Trả từ',
        kind: FieldKind.choice,
        options: accounts,
        helpEn: 'The account the money really moved through.',
        helpVi: 'Tài khoản tiền thật sự đi qua.',
      ),
      const SpendField('date', 'On', 'Ngày', kind: FieldKind.date),
    ],
    initial: {'amount': net, 'account': '', 'date': scope.today},
    save: (v) async {
      final entries = settleUp(
        scope.state,
        p.id,
        currency,
        v['amount'] as BigInt,
        account: v['account'] as String,
        date: v['date'] as String,
        payee: (i) => '${p.name} · ${i.split.name}',
        only: item?.split.id,
      );
      await scope.controller.change(
        (s) => s.copy({
          'entries': [
            ...s.entries.map((e) => e.toJson()),
            ...entries.map((e) => e.toJson()),
          ],
        }),
        'settle_up',
      );
    },
  );
  if (done && context.mounted)
    scope.announce(
      context,
      tr(context, 'Payment recorded.', 'Đã ghi khoản trả.'),
    );
}

/// Someone else paid and you owe them your share: what it was, the total
/// and the day, then who paid and how it divides. No ledger entry is made
/// until you pay them back.
Future<void> openPaidForYou(BuildContext context, SpendScope scope) async {
  final s = scope.state;
  Map<String, dynamic>? values;
  final ok = await showSpendForm(
    context,
    scope,
    title: tr(context, 'Someone paid for you', 'Người khác trả giúp bạn'),
    saveLabel: tr(context, 'Next: who and how', 'Tiếp: ai và chia thế nào'),
    fields: [
      const SpendField(
        'name',
        'What',
        'Khoản gì',
        helpEn: 'Dinner, tickets, a taxi…',
        helpVi: 'Bữa tối, vé xem phim, taxi…',
      ),
      SpendField(
        'total',
        'Total paid',
        'Tổng đã trả',
        kind: FieldKind.money,
        currency: (_) => s.currency,
      ),
      const SpendField('date', 'On', 'Ngày', kind: FieldKind.date),
      SpendField(
        'category',
        'Category',
        'Danh mục',
        kind: FieldKind.choice,
        required: false,
        options: {
          '': tr(context, 'None', 'Không'),
          for (final c in s.categories.where(
            (c) => c.kind == 'expense' && !c.archived,
          ))
            c.id: c.name,
        },
      ),
    ],
    initial: {'name': '', 'total': null, 'date': scope.today, 'category': ''},
    save: (v) async {
      if ((v['total'] as BigInt) <= BigInt.zero)
        throw const FormatException('Enter an amount / Nhập số tiền');
      values = v;
    },
  );
  if (!ok || values == null || !context.mounted) return;
  final v = values!;
  final result = await openSheet<SplitResult>(
    context,
    scope,
    (_) => SplitSheet(
      scope: scope,
      total: v['total'] as BigInt,
      currency: s.currency,
      askPayer: true,
    ),
  );
  final draft = result?.draft;
  if (draft == null || !context.mounted) return;
  await scope.write(
    context,
    () => scope.controller.change((s) {
      final x = draft.build(
        total: v['total'] as BigInt,
        currency: s.currency,
        date: v['date'] as String,
        name: v['name'] as String,
        category: (v['category'] as String).isEmpty
            ? null
            : v['category'] as String,
      );
      return s.copy({
        'people': [
          ...s.people.map((p) => p.toJson()),
          ...draft.added.map((p) => p.toJson()),
        ],
        'splits': [...s.splits.map((x) => x.toJson()), x.toJson()],
      });
    }, 'record_iou'),
    done: (c) => tr(c, 'Recorded what you owe.', 'Đã ghi khoản bạn nợ.'),
  );
}
