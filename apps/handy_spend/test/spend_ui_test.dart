import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/handy_ui.dart';
import 'package:handy_spend/app.dart';
import 'package:handy_spend/controller.dart';
import 'package:handy_spend_engine/handy_spend_engine.dart';
import 'controller_test.dart' show TestSpendStore;

void main() {
  testWidgets(
    'create account, save expense, cancel preserves, reports show exact balance',
    (tester) async {
      final store = TestSpendStore(),
          c = SpendController(open: () async => store);
      await c.load();
      await tester.pumpWidget(
        MaterialApp(home: SpendHome(controller: c, enableDrop: false)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('field-name')), 'Cash');
      await tester.enterText(find.byKey(const Key('field-opening')), '100000');
      await tester.ensureVisible(find.byKey(const Key('editor-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editor-save')));
      await tester.pumpAndSettle();
      expect(c.state!.accounts, hasLength(1));
      await tester.tap(find.byKey(const Key('spend-add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('field-amount')), '12000');
      await tester.ensureVisible(find.byKey(const Key('editor-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editor-save')));
      await tester.pumpAndSettle();
      expect(c.state!.entries.single.amount, BigInt.from(-12000));
      expect(
        balances(
          c.state!,
          reportDay(DateTime.now().toUtc().toIso8601String(), c.state!.zone),
        ).values.single,
        BigInt.from(88000),
      );
      await tester.tap(find.byKey(const Key('spend-add')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(c.state!.entries, hasLength(1));
      await tester.tap(find.text('Reports').last);
      await tester.pumpAndSettle();
      expect(find.text('Actual income vs expense'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  for (final width in [320.0, 1000.0])
    testWidgets('all tabs at width $width with large text', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = TestSpendStore(),
          c = SpendController(open: () async => store);
      await c.load();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: SpendHome(controller: c, enableDrop: false),
        ),
      );
      await tester.pumpAndSettle();
      for (final tab in ['Transactions', 'Plan', 'Reports', 'Home']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
}
