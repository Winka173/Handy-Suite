import 'package:flutter_test/flutter_test.dart';
import 'package:handy_spend/entry/entry_logic.dart';
import 'package:handy_spend/ledger/ledger_filter.dart';
import 'package:handy_spend/money.dart';
import 'package:handy_spend/today/promised_logic.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'helpers.dart';

void main() {
  group('amounts typed the local way', () {
    BigInt vnd(String t, {bool vi = true}) => parseAmount(t, 'VND', vi: vi);
    BigInt usd(String t, {bool vi = false}) => parseAmount(t, 'USD', vi: vi);
    test('grouping and decimals in either language', () {
      expect(vnd('45.000'), BigInt.from(45000));
      expect(vnd('45,000'), BigInt.from(45000));
      expect(vnd('1.250.000 ₫'), BigInt.from(1250000));
      expect(vnd('45.000', vi: false), BigInt.from(45000));
      expect(usd('1,234.56'), BigInt.from(123456));
      expect(usd('1.234,56', vi: true), BigInt.from(123456));
      expect(usd('12,5', vi: true), BigInt.from(1250));
      expect(usd('12.50'), BigInt.from(1250));
      expect(vnd('-20.000'), BigInt.from(-20000));
    });
    test('k for thousands and tr for millions', () {
      expect(vnd('45k'), BigInt.from(45000));
      expect(vnd('1,5tr'), BigInt.from(1500000));
      expect(vnd('2tr'), BigInt.from(2000000));
      expect(usd('1.5k'), BigInt.from(150000));
    });
    test('what is not an amount is refused, not guessed', () {
      for (final bad in ['', 'abc', '1..2', '12,34,5x', '₫']) {
        expect(() => vnd(bad), throwsFormatException, reason: bad);
      }
      // VND has no minor unit.
      expect(() => vnd('12,5'), throwsFormatException);
    });
    test('what the form shows reads back the same', () {
      for (final (v, cur) in [
        (BigInt.from(1250000), 'VND'),
        (BigInt.from(-123456), 'USD'),
        (BigInt.from(1250), 'USD'),
        (BigInt.from(1250), 'KWD'),
      ]) {
        for (final vi in [true, false]) {
          expect(
            parseAmount(editableAmount(v, cur, vi: vi), cur, vi: vi),
            v,
            reason: '$v $cur vi=$vi',
          );
        }
      }
    });
    test('axis figures are short', () {
      expect(compactAmount(BigInt.from(12000000), 'VND', vi: true), '12tr');
      expect(compactAmount(BigInt.from(850000), 'VND', vi: false), '850K');
      expect(compactAmount(BigInt.from(-1500000), 'VND', vi: true), '−1,5tr');
    });
  });

  group('the entry sheet', () {
    final s = SpendState(
      accounts: [
        cash(),
        cash(id: 'bank'),
      ],
      categories: [
        Category(
          id: 'cafe',
          name: 'Café',
          kind: 'expense',
          color: '#000000',
          icon: 'food',
        ),
        Category(
          id: 'ride',
          name: 'Rides',
          kind: 'expense',
          color: '#000000',
          icon: 'travel',
        ),
      ],
      rules: [
        {'id': 'r', 'contains': 'grab', 'category': 'ride'},
      ],
      entries: [
        Entry(
          id: 'e1',
          account: 'bank',
          kind: 'expense',
          amount: BigInt.from(-45000),
          when: localTimestamp(inDays(-1), 'Asia/Ho_Chi_Minh'),
          payee: 'Highlands Coffee',
          category: 'cafe',
        ),
      ],
    );
    test('a payee brings its category: rules first, then last time', () {
      expect(categoryForPayee(s, 'expense', 'GRAB Bike'), 'ride');
      expect(categoryForPayee(s, 'expense', 'highlands coffee'), 'cafe');
      expect(categoryForPayee(s, 'expense', 'Someone new'), isNull);
      expect(payeeSuggestions(s, 'expense', 'high'), ['Highlands Coffee']);
      expect(defaultAccount(s, 'expense'), 'bank');
      expect(recentCategories(s, 'expense'), ['cafe']);
    });
    test('spending is negative, a transfer moves, a refund points back', () {
      Entry make(String kind, {String? to, Entry? refundOf}) => buildEntry(
        s: s,
        kind: kind,
        account: 'cash',
        entered: BigInt.from(1000),
        date: today(),
        pending: false,
        toAccount: to,
        refundOf: refundOf,
      );
      expect(make('expense').amount, BigInt.from(-1000));
      expect(make('income').amount, BigInt.from(1000));
      final t = make('transfer', to: 'bank');
      expect(
        (t.amount, t.target, t.category),
        (BigInt.from(-1000), BigInt.from(1000), null),
      );
      expect(make('refund', refundOf: s.entries.single).refundOf, 'e1');
      expect(() => make('transfer'), throwsFormatException);
      expect(() => make('transfer', to: 'cash'), throwsFormatException);
      expect(
        () => buildEntry(
          s: s,
          kind: 'expense',
          account: 'cash',
          entered: BigInt.from(-5),
          date: today(),
          pending: false,
        ),
        throwsFormatException,
      );
    });
    test('editing on the same day keeps the original time', () {
      final e = s.entries.single;
      final same = buildEntry(
        s: s,
        existing: e,
        kind: 'expense',
        account: 'bank',
        entered: BigInt.from(50000),
        date: reportDay(e.when, s.zone),
        pending: false,
      );
      expect((same.id, same.when), (e.id, e.when));
    });
    test('a preset is a new entry from today without import marks', () {
      final p = presetFrom(
        s.entries.single.copy({'batch': 'b', 'occurrence': 'o'}),
        today(),
        s.zone,
      );
      expect(p.id, isNot('e1'));
      expect((p.batch, p.occurrence), (null, null));
      expect(reportDay(p.when, s.zone), today());
    });
  });

  test('the promised parts add up to the engine figures', () {
    final s = SpendState(
      accounts: [
        cash(opening: 2000000),
        cash(id: 'save', opening: 0),
      ],
      bills: [
        for (final (id, amount, due) in [
          ('rent', -900000, 3),
          ('net', -200000, 10),
          ('pay', 1500000, 6),
        ])
          Bill(
            id: id,
            name: id,
            account: 'cash',
            amount: BigInt.from(amount),
            due: inDays(due),
            frequency: 'monthly',
            reliable: id == 'pay',
          ),
      ],
      entries: [
        Entry(
          id: 'p',
          account: 'cash',
          kind: 'expense',
          amount: BigInt.from(-50000),
          when: localTimestamp(inDays(2), 'Asia/Ho_Chi_Minh'),
          status: 'pending',
          payee: 'Gift',
        ),
      ],
      settings: {'buffer': '100000'},
    );
    for (final conservative in [true, false]) {
      final p = promisedMoney(
        s,
        today(),
        inDays(29),
        accounts: eligible(s, s.currency),
        conservative: conservative,
      );
      expect(p.others, BigInt.zero, reason: 'every payment is named');
      expect(p.outs.map((o) => o.name), ['Gift', 'rent', 'net']);
      final ins = p.ins.fold(BigInt.zero, (n, x) => n + x.amount);
      expect(ins, p.safe.income);
      expect(p.safe.liquid + p.safe.income - p.promised, p.safe.available);
    }
  });

  test('the ledger filter keeps the period and narrows without accents', () {
    final s = SpendState(
      accounts: [cash()],
      entries: [
        for (final (id, payee, days) in [
          ('a', 'Bún bò', 0),
          ('b', 'Grab', 0),
          ('c', 'Old', -40),
        ])
          Entry(
            id: id,
            account: 'cash',
            kind: 'expense',
            amount: BigInt.from(-10000),
            when: localTimestamp(inDays(days), 'Asia/Ho_Chi_Minh'),
            payee: payee,
          ),
      ],
    );
    final month = LedgerFilter.month(today());
    expect(applyFilter(s, month).map((e) => e.id).toSet(), {'a', 'b'});
    expect(applyFilter(s, month.copyWith(search: 'bun bo')).single.id, 'a');
    expect(applyFilter(s, month.copyWith(min: BigInt.from(20000))), isEmpty);
    expect(month.shiftMonth(-1).shiftMonth(1).from, month.from);
    expect(month.copyWith(search: 'x').narrowed, isTrue);
    expect(month.copyWith(search: 'x').cleared().narrowed, isFalse);
  });
}
