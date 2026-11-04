import 'package:flutter_test/flutter_test.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';

const zone = 'Asia/Ho_Chi_Minh';

Entry spent(
  String id,
  int amount,
  String date, {
  String status = 'posted',
  String payee = 'Shop',
}) => Entry(
  id: id,
  account: 'cash',
  kind: 'expense',
  amount: -BigInt.from(amount),
  when: localTimestamp(date, zone),
  status: status,
  payee: payee,
);

SpendState state(List<Entry> entries, {List<Bill> bills = const []}) =>
    SpendState(
      accounts: [
        Account(
          id: 'cash',
          name: 'Cash',
          currency: 'VND',
          type: 'cash',
          opening: BigInt.from(1000000),
          asOf: '2026-09-01',
        ),
      ],
      entries: entries,
      bills: bills,
    );

void main() {
  const today = '2026-11-04';

  test('no gap, no hints', () {
    expect(reconcileHints(state([]), 'cash', BigInt.zero, today), isEmpty);
  });

  test('pending entries, an unpaid bill and an entry recorded twice', () {
    final s = state(
      [
        spent('a', 45000, '2026-11-02'),
        spent('p', 120000, '2026-11-03', status: 'pending'),
      ],
      bills: [
        Bill(
          id: 'net',
          name: 'Internet',
          account: 'cash',
          amount: BigInt.from(-220000),
          due: '2026-10-15',
        ),
      ],
    );
    // Real is 45.000 more than the ledger: as if the coffee was never paid.
    final hints = reconcileHints(s, 'cash', BigInt.from(45000), today);
    expect(hints.map((h) => h.kind), ['pending', 'unpaid', 'twice']);
    expect(hints[0].amount, BigInt.from(-120000));
    expect(hints[0].count, 1);
    expect(hints[1].dates, ['2026-10-15']);
    expect(hints[1].amount, BigInt.from(-220000));
    expect(hints[2].entries, ['a']);
  });

  test('a long silence is named with its days', () {
    final s = state([spent('old', 10000, '2026-10-01')]);
    final hints = reconcileHints(s, 'cash', BigInt.from(-500000), today);
    expect(hints.single.kind, 'quiet');
    expect(hints.single.days, 34);
  });
}
