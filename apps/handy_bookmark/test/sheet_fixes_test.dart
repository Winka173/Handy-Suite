import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/welcome/welcome_page.dart';
import 'package:handy_ui/kit.dart';
import 'new_flows_test.dart' show boot, settle;
import 'widget_test.dart' show tapKey;

void main() {
  testWidgets('"Save from other apps" shows the steps on a sheet, not the '
      'whole guide', (t) async {
    await boot(t);
    await tapKey(t, 'save-new');
    await tapKey(t, 'save-how');
    expect(find.byType(WelcomePage), findsNothing);
    expect(find.byKey(const Key('share-how-to')), findsOneWidget);
    expect(find.textContaining('tap Share'), findsOneWidget);
    await tapKey(t, 'share-how-done');
    expect(find.byKey(const Key('share-how-to')), findsNothing);
  });

  testWidgets('on a wide screen the collection sheet keeps every choice '
      'inside it', (t) async {
    await boot(t, size: const Size(1280, 800));
    await t.tap(find.byKey(const Key('collection-new')).first);
    await settle(t);
    expect(t.takeException(), isNull);
    final sheet = t.getRect(find.byType(BottomSheet));
    for (final key in ['template-gift-3', 'mark-money', 'hue-auto']) {
      final r = t.getRect(find.byKey(Key(key)));
      expect(r.right, lessThanOrEqualTo(sheet.right), reason: key);
      expect(r.left, greaterThanOrEqualTo(sheet.left), reason: key);
    }
  });

  testWidgets('Create stays in view on a short screen, with More options '
      'open', (t) async {
    await boot(t, size: const Size(390, 560));
    await tapKey(t, 'collection-new');
    await t.tap(find.byKey(const Key('collection-more')));
    await t.pumpAndSettle();
    final button = t.getRect(find.byKey(const Key('editor-save')));
    expect(button.bottom, lessThanOrEqualTo(560));
    expect(button.top, greaterThan(0));
    expect(t.takeException(), isNull);
  });
}
