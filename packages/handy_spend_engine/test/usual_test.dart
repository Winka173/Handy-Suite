import 'package:flutter_test/flutter_test.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';

Entry entry(
  String id,
  int amount, {
  String date = '2026-11-01',
  String payee = 'Cà phê',
  String kind = 'expense',
  String account = 'cash',
  String? category = 'food',
  String? occurrence,
  String status = 'posted',
}) => Entry(
  id: id,
  account: account,
  kind: kind,
  amount: kind == 'expense' ? -BigInt.from(amount) : BigInt.from(amount),
  when: localTimestamp(date, 'Asia/Ho_Chi_Minh'),
  payee: payee,
  category: category,
  occurrence: occurrence,
  status: status,
);

SpendState library(List<Entry> entries, {bool archived = false}) => SpendState(
  accounts: [
    Account(
      id: 'cash',
      name: 'Cash',
      currency: 'VND',
      type: 'cash',
      opening: BigInt.zero,
      asOf: '2026-01-01',
      archived: archived,
    ),
  ],
  categories: [Category(id: 'food', name: 'Food', kind: 'expense')],
  entries: entries,
);

void main() {
  test('repeats are found, most frequent first', () {
    final s = library([
      entry('a1', 45000, date: '2026-11-01'),
      entry('a2', 45000, date: '2026-11-02'),
      entry('a3', 45000, date: '2026-11-03'),
      entry('b1', 50000, payee: 'Cơm trưa', date: '2026-10-20'),
      entry('b2', 50000, payee: 'cơm trưa ', date: '2026-11-03'),
      entry('once', 120000, payee: 'Sách'),
      // The same payee at another price is another habit.
      entry('c1', 55000, date: '2026-11-03'),
    ]);
    final usual = usualEntries(s, today: '2026-11-04');
    expect(usual.map((u) => (u.payee, u.amount.toInt(), u.count)), [
      ('Cà phê', 45000, 3),
      ('cơm trưa', 50000, 2),
    ]);
    expect(usual.first.category, 'food');
    expect(usual.first.kind, 'expense');
  });

  test('old, planned, pending and archived entries are not usual', () {
    final old = library([
      entry('o1', 45000, date: '2026-08-01'),
      entry('o2', 45000, date: '2026-08-02'),
    ]);
    expect(usualEntries(old, today: '2026-11-04'), isEmpty);
    final planned = library([
      entry('p1', 9000000, payee: 'Rent', occurrence: 'r:2026-10'),
      entry('p2', 9000000, payee: 'Rent', occurrence: 'r:2026-11'),
      entry('q1', 45000, status: 'pending'),
      entry('q2', 45000, status: 'pending'),
    ]);
    expect(usualEntries(planned, today: '2026-11-04'), isEmpty);
    final archived = library([
      entry('a1', 45000),
      entry('a2', 45000),
    ], archived: true);
    expect(usualEntries(archived, today: '2026-11-04'), isEmpty);
  });

  test('the limit keeps the top ones', () {
    final s = library([
      for (var i = 0; i < 6; i++) ...[
        entry('x$i-1', 10000 + i, payee: 'P$i'),
        entry('x$i-2', 10000 + i, payee: 'P$i'),
      ],
    ]);
    expect(usualEntries(s, today: '2026-11-04'), hasLength(4));
    expect(usualEntries(s, today: '2026-11-04', limit: 6), hasLength(6));
  });
}
