import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/pro/pro_demos.dart';
import 'package:handy_boards/design/theme.dart';
import 'package:handy_boards/pro/pro.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_store/handy_store.dart';
import 'package:handy_ui/kit.dart';

class _Store implements LifetimeStorePort {
  StoreSnapshot next = const StoreSnapshot(
    status: 'owned',
    productId: 'pro',
    owned: true,
    verified: true,
    price: '99.000 ₫',
  );
  @override
  Future<StoreSnapshot> read() async =>
      const StoreSnapshot(status: 'not_owned', productId: 'pro');
  @override
  Future<StoreSnapshot> purchase() async => next;
  @override
  Future<StoreSnapshot> restore() async => next;
  @override
  void listen(void Function(StoreSnapshot) listener) {}
  @override
  Future<void> dispose() async {}
}

Future<LifetimeController> open(WidgetTester t, {ProFeature? focus}) async {
  final store = LifetimeController(
    const MonetizationConfig(productId: 'pro'),
    _Store(),
  );
  addTearDown(store.dispose);
  store.accept(
    const StoreSnapshot(
      status: 'not_owned',
      productId: 'pro',
      price: '99.000 ₫',
    ),
  );
  await t.pumpWidget(
    MaterialApp(
      theme: boardsTheme(ThemeData(useMaterial3: true)),
      builder: (context, child) =>
          LifetimeScope(notifier: store, child: child!),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => ProPage(focus: focus)),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('opened from a part, the stage plays that part first and a '
      'row plays another', (t) async {
    await open(t, focus: ProFeature.automation);
    expect(find.text('Pay once. Keep it.'), findsNothing);
    expect(
      t.widget<Text>(find.byKey(const Key('pro-stage-title'))).data,
      'Automation rules',
    );
    await t.ensureVisible(find.byKey(const Key('pro-part-history')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('pro-part-history')));
    await t.pumpAndSettle();
    expect(
      t.widget<Text>(find.byKey(const Key('pro-stage-title'))).data,
      'Board history',
    );
    // The page went back up to the stage.
    expect(find.byKey(const Key('pro-stage')).hitTestable(), findsOneWidget);
  });

  testWidgets('the store\'s own price; buying thanks and offers to go back '
      'to the part', (t) async {
    final store = await open(t, focus: ProFeature.export);
    expect(find.text('Get Pro · 99.000 ₫'), findsOneWidget);
    expect(find.byKey(const Key('pro-continue')), findsNothing);
    await t.tap(find.byKey(const Key('pro-buy')));
    await t.pumpAndSettle();
    expect(store.pro, isTrue);
    expect(find.text('Pro is active on this device. Thank you.'), findsOne);
    expect(find.byKey(const Key('pro-buy')), findsNothing);
    await t.tap(find.byKey(const Key('pro-continue')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('pro-page')), findsNothing);
  });

  testWidgets('a cancel and an unreachable store say nothing was charged', (
    t,
  ) async {
    final store = await open(t);
    expect(find.text('Pay once. Keep it.'), findsOneWidget);
    store.accept(const StoreSnapshot(status: 'canceled', productId: 'pro'));
    await t.pump();
    expect(find.text('Purchase cancelled. Nothing was charged.'), findsOne);
    store.accept(const StoreSnapshot(status: 'unavailable', productId: 'pro'));
    await t.pump();
    expect(find.textContaining('could not be reached'), findsOne);
    store.accept(const StoreSnapshot(status: 'pending', productId: 'pro'));
    await t.pump();
    expect(find.textContaining('Waiting for the store'), findsOne);
    final buy = t.widget<FilledButton>(find.byKey(const Key('pro-buy')));
    expect(buy.onPressed, isNull, reason: 'no second purchase while pending');
  });

  testWidgets('with less motion the stage shows only its last frame', (
    t,
  ) async {
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await open(t, focus: ProFeature.automation);
    // Nothing runs, so there is nothing to replay and the frame is final.
    expect(t.hasRunningAnimations, isFalse);
    expect(find.byKey(const Key('demo-replay')), findsNothing);
  });

  for (final locale in ['en', 'vi'])
    testWidgets('every demo fits its stage at every moment ($locale)', (
      t,
    ) async {
      for (final f in ProFeature.values)
        for (final at in [0.0, .3, .5, .7, 1.0]) {
          await t.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              supportedLocales: const [Locale('en'), Locale('vi')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: boardsTheme(ThemeData(useMaterial3: true)),
              home: Center(
                child: SizedBox(
                  width: 320,
                  height: 180,
                  child: Builder(
                    builder: (context) => boardsProDemo(context, f, at),
                  ),
                ),
              ),
            ),
          );
          expect(t.takeException(), isNull, reason: '${f.name} at $at');
        }
    });

  test('the demo clock plays, then holds the last frame', () {
    const p = Duration(milliseconds: 3200), h = Duration(milliseconds: 1000);
    expect(HandyDemoLoop.at(Duration.zero, p, h), 0);
    expect(HandyDemoLoop.at(const Duration(milliseconds: 1600), p, h), .5);
    expect(HandyDemoLoop.at(const Duration(milliseconds: 3900), p, h), 1);
    expect(HandyDemoLoop.at(const Duration(milliseconds: 4200), p, h), 0);
  });
}
