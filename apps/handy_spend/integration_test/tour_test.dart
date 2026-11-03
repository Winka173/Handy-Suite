// A guided walk through the app for a screen recording on a device:
// python tooling/device-tour.py --device <serial> spend
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_spend/app.dart';
import 'package:handy_spend/controller.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'package:integration_test/integration_test.dart';
import '../test/helpers.dart';
import '../tool/screens_test.dart' show household;

/// Lets the viewer see the screen before the next step.
Future<void> pause(WidgetTester t, [int ms = 1200]) async {
  await t.pumpAndSettle();
  await Future<void>.delayed(Duration(milliseconds: ms));
  await t.pump();
}

Finder _down() => find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .hitTestable();

/// Scrolls every list on screen back to its top, the way a thumb would.
Future<void> toTop(WidgetTester t) async {
  for (final list in t.stateList<ScrollableState>(_down())) {
    unawaited(
      list.position.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      ),
    );
  }
  await pause(t, 700);
}

Future<void> tap(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty) await toTop(t);
  if (f.evaluate().isEmpty)
    await t.scrollUntilVisible(f, 300, scrollable: _down().first);
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  await t.tap(f.first);
  await pause(t, 700);
}

Future<void> type(WidgetTester t, String key, String text) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  // A new text-input client after the last one closed on the device.
  await t.tap(f.first);
  await t.pumpAndSettle();
  await t.enterText(f.first, text);
  await pause(t, 700);
}

/// Scrolls smoothly until [key] is in view, so the film shows the way.
Future<void> show(WidgetTester t, String key, [int ms = 1500]) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty)
    await t.scrollUntilVisible(f, 300, scrollable: _down().first);
  unawaited(
    Scrollable.ensureVisible(
      t.element(f.first),
      alignment: .3,
      duration: const Duration(milliseconds: 600),
    ),
  );
  await pause(t, ms);
}

Future<void> back(WidgetTester t) async {
  await t.pumpAndSettle();
  final arrow = find.byType(BackButton).hitTestable();
  if (arrow.evaluate().isNotEmpty) {
    await t.tap(arrow.last);
  } else {
    await t.binding.handlePopRoute();
  }
  await pause(t, 700);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Handy Spend tour', (t) async {
    final c = SpendController(
      open: () async => TestSpendStore()..value = household(),
    );
    await c.load();
    addTearDown(c.dispose);
    final width = t.view.physicalSize.width / t.view.devicePixelRatio;
    final wide = width >= HandySpace.wide;
    Future<void> area(int i) => tap(t, wide ? 'area-$i' : 'nav-$i');

    await t.pumpWidget(
      SpendApp(
        controller: c,
        files: Files(),
        preferences: Preferences('vi')..value = HandyPreferences(locale: 'vi'),
        privacy: NoLock(),
        enableDrop: false,
      ),
    );
    await pause(t, 2500);

    // Today: what is free to spend, and what is already promised.
    await show(t, 'promised-answer', 2500);
    await toTop(t);

    // Record a coffee the short way: 45k, a payee used before, its category.
    await tap(t, 'spend-add');
    await type(t, 'field-amount', '45k');
    await tap(t, 'category-food');
    await type(t, 'field-payee', 'Highlands Coffee');
    await pause(t, 1000);
    await tap(t, 'editor-save');
    await pause(t, 2000);

    // Rent is due: paid, recorded once.
    final rent = c.state!.bills.firstWhere((b) => b.id == 'rent');
    await show(t, 'paid-rent@${rent.due}');
    await tap(t, 'paid-rent@${rent.due}');
    await pause(t, 2000);

    // The ledger: last month, where it went, narrowed to food, then a search.
    await area(1);
    await pause(t, 1500);
    await tap(t, 'month-prev');
    await pause(t, 2000);
    await tap(t, 'spent-food');
    await pause(t, 2000);
    await tap(t, 'spent-food');
    await type(t, 'spend-search', 'pho');
    await pause(t, 2000);

    // The plan: the forecast, then try a phone on six monthly parts.
    await area(2);
    await pause(t, 2500);
    await tap(t, 'plan-income');
    await pause(t, 2000);

    // Accounts: net worth, then one account and its check.
    await area(3);
    await pause(t, 2000);
    await tap(t, 'account-vcb');
    await pause(t, 2000);
    await tap(t, 'account-reconcile');
    await pause(t, 1500);
    await tap(t, 'sheet-cancel');
    if (width < 1000) await back(t);

    // Settings: privacy, categories and the ledger's backups.
    await tap(t, 'open-settings');
    await pause(t, 1500);
    await show(t, 'set-hide', 1500);
    await show(t, 'spend-backup', 2000);
    await back(t);
    await pause(t, 1500);
  }, timeout: const Timeout(Duration(minutes: 6)));
}
