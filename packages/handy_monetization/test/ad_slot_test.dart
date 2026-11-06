import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'monetization_test.dart' show Store;

class FakeAds implements AdProvider {
  int privacy = 0;
  @override
  Widget banner(LifetimeController model) => const Text('AD');
  @override
  void privacyOptions(LifetimeController model) => privacy++;
}

Widget host(LifetimeController model, Widget child) => MaterialApp(
  home: LifetimeScope(
    notifier: model,
    child: Scaffold(body: child),
  ),
);

void main() {
  tearDown(() => HandyAdSlot.provider = null);
  const withAds = MonetizationConfig(
    productId: 'app.pro',
    adUnitId: 'ca-app-pub-0000000000000000/0000000000',
    adsEnabled: true,
  );

  testWidgets('without an installed ad provider there is no banner, no ad '
      'privacy button, and Pro is not sold as removing ads', (t) async {
    final model = LifetimeController(withAds, Store());
    await t.pumpWidget(
      host(
        model,
        const Column(children: [LifetimeBanner(), LifetimeSettings()]),
      ),
    );
    expect(find.text('AD'), findsNothing);
    expect(find.text('Advertising privacy choices'), findsNothing);
    expect(find.textContaining('There are no ads'), findsOneWidget);
    expect(
      find.textContaining('removes supported advertisements'),
      findsNothing,
    );
  });

  testWidgets('an installed provider shows its banner to Free users only', (
    t,
  ) async {
    final ads = FakeAds();
    HandyAdSlot.provider = ads;
    final model = LifetimeController(withAds, Store());
    await t.pumpWidget(
      host(
        model,
        const Column(children: [LifetimeBanner(), LifetimeSettings()]),
      ),
    );
    expect(find.text('AD'), findsOneWidget);
    await t.tap(find.text('Advertising privacy choices'));
    expect(ads.privacy, 1);
    expect(
      find.textContaining('removes supported advertisements'),
      findsOneWidget,
    );
  });
}
