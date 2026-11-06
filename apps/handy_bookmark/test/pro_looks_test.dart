import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/design/identity.dart';
import 'package:handy_bookmark/design/looks.dart';
import 'package:handy_bookmark/design/theme.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_store/handy_store.dart';
import 'package:handy_ui/kit.dart';
import 'welcome_test.dart' show open;
import 'widget_test.dart' show tapKey;
import 'new_flows_test.dart' show settle;

class _Store implements LifetimeStorePort {
  @override
  Future<StoreSnapshot> read() async =>
      const StoreSnapshot(status: 'not_owned', productId: 'pro');
  @override
  Future<StoreSnapshot> purchase() => read();
  @override
  Future<StoreSnapshot> restore() => read();
  @override
  void listen(void Function(StoreSnapshot) listener) {}
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('a premium look shows only while Pro is verified, and the '
      'choice waits rather than being lost', (t) async {
    final store = LifetimeController(
      const MonetizationConfig(productId: 'pro'),
      _Store(),
    );
    addTearDown(store.dispose);
    late BookmarkPalette seen;
    await t.pumpWidget(
      MaterialApp(
        theme: bookmarkTheme(
          buildHandyTheme(
            saveAccentForTest,
            Brightness.light,
            bookmarkIdentity,
          ),
        ),
        home: LifetimeScope(
          notifier: store,
          child: LookScope(
            chosen: 'midnight-gallery',
            child: Builder(
              builder: (context) {
                seen = BookmarkPalette.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    expect(seen.canvas, BookmarkPalette.light.canvas, reason: 'not Pro');
    store.accept(
      const StoreSnapshot(
        status: 'owned',
        productId: 'pro',
        owned: true,
        verified: true,
      ),
    );
    await t.pump();
    final midnight = lookById('midnight-gallery')!.dark!;
    expect(seen.canvas, midnight.canvas, reason: 'verified Pro');
    store.accept(const StoreSnapshot(status: 'not_owned', productId: 'pro'));
    await t.pump();
    expect(seen.canvas, BookmarkPalette.light.canvas, reason: 'Pro lost');
  });

  testWidgets('Free can preview every theme; a Pro theme leads to Explore '
      'Pro and previewing never changes the choice', (t) async {
    final c = await open(t, urls: ['https://a.com/one']);
    Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/looks');
    await settle(t);
    expect(find.byKey(const Key('look-library')), findsOneWidget);
    await tapKey(t, 'look-midnight-gallery');
    expect(find.text('Use with Pro'), findsOneWidget);
    await tapKey(t, 'look-next');
    await tapKey(t, 'look-apply');
    expect(find.byKey(const Key('explore-pro')), findsOneWidget);
    // No store in this build: no price, nothing to buy.
    await t.scrollUntilVisible(
      find.byKey(const Key('pro-buy')),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('explore-pro')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const Key('pro-status')), findsOneWidget);
    expect(find.textContaining('Get Pro for'), findsNothing);
    final buy = t.widget<FilledButton>(find.byKey(const Key('pro-buy')));
    expect(buy.onPressed, isNull);
    await t.pageBack();
    await settle(t);
    await tapKey(t, 'look-keep');
    expect(c.preferences['look'], isNull, reason: 'preview only');
  });

  testWidgets('the free look applies at once', (t) async {
    final c = await open(t, urls: ['https://a.com/one']);
    await c.update((l) => l, prefs: {...c.preferences, 'look': 'ink-paper'});
    Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/looks');
    await settle(t);
    await tapKey(t, 'look-library');
    await tapKey(t, 'look-apply');
    expect(c.preferences['look'], 'library');
  });
}

const saveAccentForTest = Color(0xFF0E7490);
