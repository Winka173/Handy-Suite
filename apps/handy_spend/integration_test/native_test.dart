import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_spend/app.dart';
import 'package:handy_spend/controller.dart';
import 'package:handy_spend/data/store_native.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'package:handy_files/handy_files.dart';

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
      final files = _StatementFiles(
        ImportedBytes(
          'native-statement.csv',
          Uint8List.fromList(
            utf8.encode(
              'date,payee,amount,balance\n$date,CSV expense,-100,944900\n',
            ),
          ),
        ),
      );
      await tester.pumpWidget(SpendApp(controller: controller, files: files));
      Future<void> waitForIo() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 700)),
        );
        await tester.pumpAndSettle();
      }

      Future<void> tap(String key) async {
        final f = find.byKey(Key(key));
        if (f.evaluate().isEmpty)
          await tester.scrollUntilVisible(
            f,
            300,
            scrollable: find
                .byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                )
                .hitTestable()
                .first,
            maxScrolls: 40,
          );
        await tester.ensureVisible(f.first);
        await tester.pumpAndSettle();
        await tester.tap(f.first);
        await tester.pumpAndSettle();
      }

      // Phones use the bottom bar; wide screens the switch in the top bar.
      Future<void> go(int area) => tap(
        find.byKey(Key('nav-$area')).evaluate().isEmpty
            ? 'area-$area'
            : 'nav-$area',
      );

      await waitForIo();
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('spend-home');
      await go(1);
      await binding.takeScreenshot('spend-transactions');
      await go(2);
      await binding.takeScreenshot('spend-plan');
      // What-ifs are drawn on the forecast once turned on ("Dự báo nếu…").
      await tap('whatif-toggle-qa-scenario');
      await tap('whatif-qa-scenario');
      await binding.takeScreenshot('spend-sandbox');
      expect(
        jsonEncode(controller.state!.toJson()),
        jsonEncode(seeded.toJson()),
        reason: 'Opening/reading a simulation must not modify the real ledger',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await go(0);
      await tap('spend-add');
      await binding.takeScreenshot('spend-add-transaction');
      await tester.enterText(find.byKey(const Key('field-amount')), '5000');
      // Close the keyboard, then open the account list and wait for it.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final cashItem = find.byKey(const Key('pick-account-qa-cash'));
      for (var i = 0; i < 5 && cashItem.evaluate().isEmpty; i++) {
        await tap('entry-account');
        await waitForIo();
      }
      await tester.tap(cashItem.last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editor-save')));
      await waitForIo();
      expect(controller.state!.entries, hasLength(4));
      await tester.runAsync(() async {
        await controller.load();
        expect(controller.state!.entries, hasLength(4));
        expect(
          balances(controller.state!, date)['qa-cash'],
          BigInt.from(945000),
        );
      });
      await tester.pumpAndSettle();

      // A statement into the cash account: columns, review, commit, undo.
      await go(3);
      await binding.takeScreenshot('spend-accounts');
      await tap('account-qa-cash');
      await tap('account-import');
      await tap('import-pick');
      await waitForIo();
      await binding.takeScreenshot('spend-import-map');
      await tap('map-balance');
      await tester.tap(find.text('4. balance').last);
      await tester.pumpAndSettle();
      await tap('import-validate');
      await waitForIo();
      expect(controller.state!.entries, hasLength(4));
      await binding.takeScreenshot('spend-import-review');
      await tap('import-commit');
      await tap('confirm-action');
      await waitForIo();
      expect(controller.state!.entries, hasLength(5));
      expect(balances(controller.state!, date)['qa-cash'], BigInt.from(944900));
      expect(
        (controller.state!.imports.last['reconciliation'] as Map)['difference'],
        '0',
      );
      await binding.takeScreenshot('spend-import-result');
      await tap('import-undo');
      await waitForIo();
      expect(controller.state!.entries, hasLength(4));
      await tester.runAsync(() async {
        await controller.load();
        expect(
          balances(controller.state!, date)['qa-cash'],
          BigInt.from(945000),
        );
        expect(await controller.store!.integrity(), 'ok');
      });
      await tester.pumpAndSettle();
      // Back from the account page to the home, which holds settings.
      while (find.byType(BackButton).hitTestable().evaluate().isNotEmpty) {
        await tester.tap(find.byType(BackButton).hitTestable().first);
        await tester.pumpAndSettle();
      }
      await tap('open-settings');
      await binding.takeScreenshot('spend-settings');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

/// The statement the import picks; exports go to the real system dialog.
class _StatementFiles extends SystemHandyFiles {
  final ImportedBytes statement;
  const _StatementFiles(this.statement);
  @override
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  }) async => statement;
}
