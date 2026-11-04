import 'package:flutter_test/flutter_test.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';

void main() {
  testWidgets('the gap is explained as it is typed; saving records only it', (
    tester,
  ) async {
    final c = await start(
      tester,
      store: TestSpendStore()
        ..value = SpendState(
          accounts: [cash(opening: 500000)],
          entries: [
            Entry(
              id: 'pho',
              account: 'cash',
              kind: 'expense',
              amount: -BigInt.from(45000),
              when: localTimestamp(inDays(-2), 'Asia/Ho_Chi_Minh'),
              payee: 'Phở',
            ),
            Entry(
              id: 'wait',
              account: 'cash',
              kind: 'expense',
              amount: -BigInt.from(30000),
              when: localTimestamp(inDays(-1), 'Asia/Ho_Chi_Minh'),
              status: 'pending',
              payee: 'Grab',
            ),
          ],
        ),
    );
    await tapKey(tester, 'nav-3');
    await tapKey(tester, 'account-cash');
    await tapKey(tester, 'account-reconcile');
    // The ledger holds 455.000; the wallet has 500.000.
    await typeKey(tester, 'field-balance', '500000');
    expect(find.byKey(const Key('reconcile-gap')), findsOneWidget);
    expect(find.textContaining('+45,000'), findsWidgets);
    expect(find.byKey(const Key('reconcile-hint-pending')), findsOneWidget);
    expect(find.byKey(const Key('reconcile-hint-twice')), findsOneWidget);
    expect(find.textContaining('Phở'), findsWidgets);

    await typeKey(tester, 'field-balance', '455000');
    expect(find.text('Matches the ledger. Nothing to adjust.'), findsOneWidget);

    await typeKey(tester, 'field-balance', '500000');
    await tapKey(tester, 'editor-save');
    final adjust = c.state!.entries.firstWhere((e) => e.kind == 'adjustment');
    expect(adjust.amount, BigInt.from(45000));
  });
}
