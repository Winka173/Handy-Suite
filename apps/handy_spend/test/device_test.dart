import 'package:flutter_test/flutter_test.dart';
import 'package:handy_spend/home_widget.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_spend/links/keep_link.dart';
import 'helpers.dart';

void main() {
  SafeSpend safe(int available) => SafeSpend(
    BigInt.zero,
    BigInt.zero,
    BigInt.zero,
    BigInt.zero,
    BigInt.zero,
    BigInt.from(available),
    BigInt.from(available ~/ 10),
    10,
  );

  test('the widget shows the figure, and hides it behind a lock', () {
    final s = SpendState(accounts: [cash()]);
    final view = spendWidgetView(s, safe(1250000), vi: true);
    expect(view.value, '1.250.000 đ');
    expect(view.detail, '125.000 đ mỗi ngày · 10 ngày');
    for (final key in ['deviceLock', 'hideAmounts']) {
      final locked = s.copy({
        'settings': {...s.settings, key: true},
      });
      final hidden = spendWidgetView(locked, safe(1250000), vi: true);
      expect(hidden.value, 'Mở để xem');
      expect(hidden.toData().values.join(), isNot(contains('1.250.000')));
    }
    expect(spendWidgetView(s, safe(-300000), vi: false).value, '−300,000 đ');
  });

  test('a purchase goes to Keep as a pre-filled new thing', () {
    final e = Entry(
      id: 'e',
      account: 'cash',
      kind: 'expense',
      when: '2026-11-02T03:00:00Z',
      amount: BigInt.from(-1290000),
      payee: 'Máy xay',
    );
    final uri = keepLink(SpendState(accounts: [cash()]), e);
    expect(uri.scheme, 'handy-keep');
    expect(uri.host, 'new');
    expect(uri.queryParameters, {
      'name': 'Máy xay',
      'price': '1290000',
      'currency': 'VND',
      'date': '2026-11-02',
    });
  });
}
