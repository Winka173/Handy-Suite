import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/design/identity.dart';
import 'package:handy_bookmark/design/theme.dart';
import 'package:handy_bookmark/pro/entitlements.dart';
import 'package:handy_bookmark/pro/pro_demos.dart';
import 'package:handy_ui/kit.dart';
import 'welcome_test.dart' show open;
import 'new_flows_test.dart' show settle;
import 'pro_looks_test.dart' show saveAccentForTest;

void main() {
  for (final locale in ['en', 'vi'])
    for (final b in Brightness.values)
      testWidgets('every Pro demo fits its stage at every moment '
          '($locale, ${b.name})', (t) async {
        for (final f in ProFeature.values)
          for (final at in [0.0, .25, .5, .75, 1.0]) {
            await t.pumpWidget(
              MaterialApp(
                locale: Locale(locale),
                supportedLocales: const [Locale('en'), Locale('vi')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                theme: bookmarkTheme(
                  buildHandyTheme(saveAccentForTest, b, bookmarkIdentity),
                ),
                home: Center(
                  child: SizedBox(
                    width: 320,
                    height: 180,
                    child: Builder(
                      builder: (context) => bookmarkProDemo(context, f, at),
                    ),
                  ),
                ),
              ),
            );
            expect(t.takeException(), isNull, reason: '${f.name} at $at');
          }
      });

  testWidgets('opened from a Pro part, Explore Pro plays that part first, '
      'and a row plays another', (t) async {
    await open(t, urls: ['https://a.com/one']);
    Navigator.of(
      t.element(find.byType(Scaffold).first),
      rootNavigator: true,
    ).pushNamed('/pro', arguments: ProFeature.autoOrganize);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('explore-pro')), findsOneWidget);
    expect(
      t.widget<Text>(find.byKey(const Key('pro-stage-title'))).data,
      'Auto organize',
    );
    await t.ensureVisible(find.byKey(const Key('pro-part-deepSearch')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('pro-part-deepSearch')));
    await settle(t);
    await t.pumpAndSettle();
    expect(
      t.widget<Text>(find.byKey(const Key('pro-stage-title'))).data,
      'Deep search',
    );
    expect(find.byKey(const Key('pro-free-and-pro')), findsOneWidget);
  });
}
