import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:handy_ui/handy_ui.dart';
import 'package:handy_spend/app.dart';
import 'package:handy_spend/controller.dart';
import 'package:handy_spend/data/store_native.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'actual native ledger, credit repayment, refund, restore, sandbox and screenshots',
    (tester) async {
      late SpendController controller;
      late SpendState seeded;
      late String date;
      await tester.runAsync(() async {
        final directory = await getApplicationSupportDirectory(),
            path =
                '${directory.path}/spend-integration-${DateTime.now().microsecondsSinceEpoch}.sqlite';
        controller = SpendController(open: () async => NativeSpendStore(path));
        await controller.load();
        expect(controller.error, isNull);
        date = reportDay(
          DateTime.now().toUtc().toIso8601String(),
          'Asia/Ho_Chi_Minh',
        );
        final when = localTimestamp(date, 'Asia/Ho_Chi_Minh');
        final cash = Account(
              id: 'qa-cash',
              name: 'Daily cash',
              currency: 'VND',
              opening: BigInt.from(1000000),
              asOf: date,
            ),
            card = Account(
              id: 'qa-card',
              name: 'Credit card',
              currency: 'VND',
              type: 'credit',
              opening: BigInt.from(-200000),
              asOf: date,
              liquid: false,
            ),
            purchase = Entry(
              id: 'qa-purchase',
              account: card.id,
              kind: 'expense',
              amount: BigInt.from(-100000),
              when: when,
              payee: 'Groceries',
            ),
            payment = Entry(
              id: 'qa-payment',
              account: cash.id,
              kind: 'transfer',
              amount: BigInt.from(-50000),
              toAccount: card.id,
              target: BigInt.from(50000),
              when: when,
              payee: 'Card repayment',
            ),
            refund = Entry(
              id: 'qa-refund',
              account: card.id,
              kind: 'refund',
              amount: BigInt.from(20000),
              refundOf: purchase.id,
              when: when,
              payee: 'Grocery refund',
            );
        var library = SpendState(
          accounts: [cash, card],
          entries: [purchase, payment, refund],
          goals: [
            Goal(
              id: 'qa-goal',
              name: 'Emergency reserve',
              account: cash.id,
              due: day(calendar(date).add(const Duration(days: 90))),
              target: BigInt.from(500000),
              reserved: BigInt.from(200000),
            ),
          ],
          bills: [
            Bill(
              id: 'qa-rent',
              name: 'Rent',
              account: cash.id,
              amount: BigInt.from(-700000),
              due: day(calendar(date).add(const Duration(days: 3))),
              frequency: 'once',
            ),
          ],
          budgets: [
            Budget(
              id: 'qa-budget',
              name: 'Monthly essentials',
              currency: 'VND',
              start: date,
              end: day(calendar(date).add(const Duration(days: 30))),
              limit: BigInt.from(500000),
            ),
          ],
          settings: {
            'currency': 'VND',
            'zone': 'Asia/Ho_Chi_Minh',
            'buffer': '100000',
          },
        );
        final scenario = Scenario(
          id: 'qa-scenario',
          name: 'Phone what-if',
          asOf: date,
          baseline: library.toJson(),
          staged: purchasePlan(
            account: cash.id,
            cost: BigInt.from(1200000),
            date: date,
            zone: library.zone,
            installments: 3,
          ),
        );
        library = library.copy({
          'scenarios': [scenario.toJson()],
        });
        await controller.change((_) => library, 'qa_seed');
        seeded = controller.state!;
        expect(balances(seeded, date)[card.id], BigInt.from(-230000));
        expect(
          report(
            seeded,
            date,
            day(calendar(date).add(const Duration(days: 1))),
          )['expense'],
          BigInt.from(80000),
        );
        final bytes = backup(seeded);
        expect(restore(bytes).toJson(), seeded.toJson());
        await controller.load();
        expect(controller.state!.toJson(), seeded.toJson());
        expect(await controller.store!.integrity(), 'ok');
      });
      await tester.pumpWidget(SpendApp(controller: controller));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pumpAndSettle();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('spend-home');
      await tester.tap(find.text('Transactions').last);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('spend-transactions');
      await tester.tap(find.text('Reports').last);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('spend-reports');
      await tester.tap(find.text('Plan').last);
      await tester.pumpAndSettle();
      await binding.takeScreenshot('spend-plan');
      await tester.scrollUntilVisible(
        find.text('Phone what-if'),
        400,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 30,
      );
      await tester.tap(find.text('Phone what-if'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('spend-sandbox');
      expect(
        jsonEncode(controller.state!.toJson()),
        jsonEncode(seeded.toJson()),
        reason: 'Opening/reading a simulation must not modify the real ledger',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('spend-add')));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('spend-add-transaction');
      await tester.enterText(find.byKey(const Key('field-amount')), '5000');
      await tester.tap(find.byKey(const Key('editor-save')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();
      expect(controller.state!.entries, hasLength(4));
      await tester.runAsync(() async {
        await controller.load();
        expect(controller.state!.entries, hasLength(4));
        expect(
          balances(controller.state!, date)['qa-cash'],
          BigInt.from(945000),
        );
      });
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
