import 'package:flutter_test/flutter_test.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';

Entry coffee(String id, int daysAgo) => Entry(
  id: id,
  account: 'cash',
  kind: 'expense',
  amount: -BigInt.from(45000),
  when: localTimestamp(inDays(-daysAgo), 'Asia/Ho_Chi_Minh'),
  payee: 'Coffee',
);

void main() {
  testWidgets('a usual entry is recorded again in one tap, and undone', (
    tester,
  ) async {
    final c = await start(
      tester,
      store: TestSpendStore()
        ..value = SpendState(
          accounts: [cash()],
          entries: [coffee('a', 2), coffee('b', 1)],
        ),
    );
    final chip = find.byKey(const Key('usual-0'));
    expect(chip, findsOneWidget);
    expect(
      find.descendant(of: chip, matching: find.textContaining('Coffee')),
      findsOneWidget,
    );

    await tapKey(tester, 'usual-0');
    expect(c.state!.entries, hasLength(3));
    final added = c.state!.entries.firstWhere(
      (e) => !{'a', 'b'}.contains(e.id),
    );
    expect(added.payee, 'Coffee');
    expect(added.amount, BigInt.from(-45000));
    expect(reportDay(added.when, c.state!.zone), today());

    await tester.tap(find.byKey(const Key('snack-undo')));
    await tester.pumpAndSettle();
    expect(c.state!.entries, hasLength(2));

    // Typing hides them: the line is being written.
    await typeKey(tester, 'quick-line', 'bread 20k');
    expect(find.byKey(const Key('usual-0')), findsNothing);
  });

  testWidgets('one-off spending offers nothing to repeat', (tester) async {
    await start(
      tester,
      store: TestSpendStore()
        ..value = SpendState(accounts: [cash()], entries: [coffee('a', 1)]),
    );
    expect(find.byKey(const Key('usual-0')), findsNothing);
  });
}
