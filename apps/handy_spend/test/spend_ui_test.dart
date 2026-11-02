import 'package:flutter_test/flutter_test.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_spend/plan/whatif_page.dart';
import 'helpers.dart';

TestSpendStore seeded(SpendState s) => TestSpendStore()..value = s;

void main() {
  testWidgets(
    'first run: add an account, record spending, cancel keeps the ledger, Undo takes one back',
    (tester) async {
      final c = await start(tester);
      expect(find.text('Start with the money you have'), findsOneWidget);
      await tapKey(tester, 'add-first-account');
      await typeKey(tester, 'field-name', 'Cash');
      await typeKey(tester, 'field-opening', '100000');
      await tapKey(tester, 'editor-save');
      expect(c.state!.accounts.single.opening, BigInt.from(100000));

      // The amount is in focus and typed the short way.
      await tapKey(tester, 'spend-add');
      await typeKey(tester, 'field-amount', '12k');
      await tapKey(tester, 'editor-save');
      expect(c.state!.entries.single.amount, BigInt.from(-12000));
      expect(balances(c.state!, today()).values.single, BigInt.from(88000));
      expect(find.textContaining('Recorded'), findsOneWidget);

      // Cancel writes nothing.
      await tapKey(tester, 'spend-add');
      await typeKey(tester, 'field-amount', '999');
      await tapKey(tester, 'sheet-cancel');
      expect(c.state!.entries, hasLength(1));

      // A second entry, then Undo from its message.
      await tapKey(tester, 'spend-add');
      await typeKey(tester, 'field-amount', '5000');
      await tapKey(tester, 'editor-save');
      expect(c.state!.entries, hasLength(2));
      await tester.tap(find.byKey(const Key('snack-undo')));
      await tester.pumpAndSettle();
      expect(c.state!.entries, hasLength(1));
    },
  );

  testWidgets('a bad amount keeps the sheet and what was typed', (
    tester,
  ) async {
    final c = await start(
      tester,
      store: seeded(SpendState(accounts: [cash()])),
    );
    await tapKey(tester, 'spend-add');
    await typeKey(tester, 'field-amount', 'abc');
    await typeKey(tester, 'field-payee', 'Phở 24');
    await tapKey(tester, 'editor-save');
    expect(find.byKey(const Key('sheet-error')), findsOneWidget);
    expect(find.text('Phở 24'), findsOneWidget);
    expect(c.state!.entries, isEmpty);
  });

  testWidgets(
    'recording again makes a new entry and never changes the original',
    (tester) async {
      final original = Entry(
        id: 'coffee',
        account: 'cash',
        kind: 'expense',
        amount: BigInt.from(-45000),
        when: localTimestamp(today(), 'Asia/Ho_Chi_Minh'),
        payee: 'Highlands',
        batch: 'b1',
        occurrence: 'bill@2026-01-01',
      );
      final c = await start(
        tester,
        store: seeded(SpendState(accounts: [cash()], entries: [original])),
      );
      final before = c.state!.entries.single.toJson();
      Future<void> openPreset() async {
        await tapKey(tester, 'nav-1');
        await tapKey(tester, 'entry-coffee');
        await tapKey(tester, 'more-menu');
        await tapKey(tester, 'entry-preset');
      }

      await openPreset();
      await tapKey(tester, 'sheet-cancel');
      expect(c.state!.entries.single.toJson(), before);

      await openPreset();
      await typeKey(tester, 'field-amount', '8000');
      await tapKey(tester, 'editor-save');
      expect(c.state!.entries, hasLength(2));
      expect(c.state!.entries.first.toJson(), before);
      final copy = c.state!.entries.last;
      expect(copy.id, isNot('coffee'));
      expect(copy.amount, BigInt.from(-8000));
      expect(copy.batch, isNull);
      expect(copy.occurrence, isNull);
      expect(reportDay(copy.when, c.state!.zone), today());
    },
  );

  testWidgets('a refund points at its expense; deleting asks first', (
    tester,
  ) async {
    final c = await start(
      tester,
      store: seeded(
        SpendState(
          accounts: [cash()],
          entries: [
            Entry(
              id: 'shoes',
              account: 'cash',
              kind: 'expense',
              amount: BigInt.from(-500000),
              when: localTimestamp(today(), 'Asia/Ho_Chi_Minh'),
              payee: 'Shoes',
            ),
          ],
        ),
      ),
    );
    await tapKey(tester, 'nav-1');
    await tapKey(tester, 'entry-shoes');
    await tapKey(tester, 'more-menu');
    await tapKey(tester, 'entry-refund');
    await typeKey(tester, 'field-amount', '200000');
    await tapKey(tester, 'editor-save');
    final refund = c.state!.entries.firstWhere((e) => e.kind == 'refund');
    expect(refund.refundOf, 'shoes');
    expect(refund.amount, BigInt.from(200000));

    // The refund holds the expense in place.
    await tapKey(tester, 'entry-shoes');
    await tapKey(tester, 'more-menu');
    await tapKey(tester, 'entry-delete');
    await tapKey(tester, 'confirm-action');
    expect(c.state!.entries, hasLength(2));
    expect(find.byKey(const Key('sheet-error')), findsOneWidget);
  });

  testWidgets('free to spend is the money held less what is promised', (
    tester,
  ) async {
    final c = await start(
      tester,
      store: seeded(
        SpendState(
          accounts: [cash()],
          bills: [
            Bill(
              id: 'rent',
              name: 'Rent',
              account: 'cash',
              amount: BigInt.from(-300000),
              due: inDays(5),
              frequency: 'once',
            ),
          ],
          goals: [
            Goal(
              id: 'trip',
              name: 'Trip',
              account: 'cash',
              due: inDays(60),
              target: BigInt.from(500000),
              reserved: BigInt.from(100000),
            ),
          ],
          settings: {'buffer': '50000'},
        ),
      ),
    );
    expect(find.textContaining('550,000'), findsWidgets);
    expect(find.byKey(const Key('promised-bar')), findsOneWidget);
    expect(find.textContaining('Next: Rent'), findsOneWidget);

    // Paid: recorded once, gone from what is coming.
    await tapKey(tester, 'paid-rent@${inDays(5)}');
    expect(c.state!.entries.single.occurrence, 'rent@${inDays(5)}');
    expect(find.byKey(Key('paid-rent@${inDays(5)}')), findsNothing);
  });

  testWidgets('a shortfall is shown as one, never as zero', (tester) async {
    await start(
      tester,
      store: seeded(
        SpendState(
          accounts: [cash(opening: 100000)],
          bills: [
            Bill(
              id: 'rent',
              name: 'Rent',
              account: 'cash',
              amount: BigInt.from(-300000),
              due: inDays(3),
              frequency: 'once',
            ),
          ],
        ),
      ),
    );
    expect(find.textContaining('Short until'), findsOneWidget);
    expect(find.textContaining('−200,000'), findsWidgets);
  });

  testWidgets('a what-if takes income without posting anything to the ledger', (
    tester,
  ) async {
    final c = await start(
      tester,
      store: seeded(SpendState(accounts: [cash(opening: 100000, since: 0)])),
    );
    await tapKey(tester, 'nav-2');
    // A window outside 1–3660 days is refused and the form stays.
    await tapKey(tester, 'horizon-custom');
    await typeKey(tester, 'field-days', '0');
    await tapKey(tester, 'editor-save');
    expect(find.byKey(const Key('sheet-error')), findsOneWidget);
    await typeKey(tester, 'field-days', '14');
    await tapKey(tester, 'editor-save');
    expect(find.byKey(const Key('sheet-error')), findsNothing);
    expect(c.state!.entries, isEmpty);

    await tapKey(tester, 'whatif-new');
    await typeKey(tester, 'field-name', 'Income case');
    await tapKey(tester, 'editor-save');
    expect(c.state!.scenarios, hasLength(1));
    // A new what-if opens on its assumptions and is drawn on the forecast.
    expect(find.byType(WhatIfPage), findsOneWidget);
    expect(find.textContaining('Your ledger has changed'), findsNothing);
    await tapKey(tester, 'whatif-add');
    await tapKey(tester, 'field-kind-income');
    await typeKey(tester, 'field-amount', '50000');
    await typeKey(tester, 'field-payee', 'Extra pay');
    await tapKey(tester, 'editor-save');
    final x = c.state!.scenarios.single;
    expect(x.staged.single.kind, 'income');
    expect(c.state!.entries, isEmpty);
    expect(
      forecast(
        SpendState.fromJson(x.baseline),
        today(),
        today(),
        staged: x.staged,
      ).ending,
      BigInt.from(150000),
    );
  });

  testWidgets('checking a balance records only the difference', (tester) async {
    final c = await start(
      tester,
      store: seeded(SpendState(accounts: [cash(opening: 100000)])),
    );
    await tapKey(tester, 'nav-3');
    await tapKey(tester, 'account-cash');
    await tapKey(tester, 'account-reconcile');
    await typeKey(tester, 'field-balance', '120000');
    await tapKey(tester, 'editor-save');
    final e = c.state!.entries.single;
    expect(e.kind, 'adjustment');
    expect(e.amount, BigInt.from(20000));
  });

  testWidgets('the ledger narrows by category and search, without accents', (
    tester,
  ) async {
    final c = await start(
      tester,
      store: seeded(
        SpendState(
          accounts: [cash()],
          categories: [
            Category(
              id: 'food',
              name: 'Food',
              kind: 'expense',
              color: '#000000',
              icon: 'food',
            ),
          ],
          entries: [
            for (final (id, payee, cat) in [
              ('a', 'Phở Hòa', 'food'),
              ('b', 'Grab', null),
            ])
              Entry(
                id: id,
                account: 'cash',
                kind: 'expense',
                amount: BigInt.from(-40000),
                when: localTimestamp(today(), 'Asia/Ho_Chi_Minh'),
                payee: payee,
                category: cat,
              ),
          ],
        ),
      ),
    );
    await tapKey(tester, 'nav-1');
    expect(find.byKey(const Key('entry-a')), findsOneWidget);
    expect(find.byKey(const Key('entry-b')), findsOneWidget);
    await tapKey(tester, 'spent-food');
    expect(find.byKey(const Key('entry-b')), findsNothing);
    await tapKey(tester, 'spent-food');
    await typeKey(tester, 'spend-search', 'pho hoa');
    expect(find.byKey(const Key('entry-a')), findsOneWidget);
    expect(find.byKey(const Key('entry-b')), findsNothing);
    expect(c.state!.entries, hasLength(2));
  });

  for (final width in [320.0, 1000.0, 1440.0])
    testWidgets('every area at $width wide with large text', (tester) async {
      await start(
        tester,
        store: seeded(
          SpendState(
            accounts: [
              cash(),
              cash(id: 'Vietcombank'),
            ],
            entries: [
              Entry(
                id: 'x',
                account: 'cash',
                kind: 'expense',
                amount: BigInt.from(-45000),
                when: localTimestamp(today(), 'Asia/Ho_Chi_Minh'),
                payee: 'A rather long payee name for a narrow phone',
              ),
            ],
          ),
        ),
        size: Size(width, 900),
        textScale: 1.5,
      );
      for (final area in [1, 2, 3, 0]) {
        await tapKey(tester, width >= 840 ? 'area-$area' : 'nav-$area');
        expect(tester.takeException(), isNull, reason: 'area $area');
      }
    });
}
