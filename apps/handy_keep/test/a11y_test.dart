import 'package:flutter_test/flutter_test.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';
import 'keep_ui_test.dart' show sample, stored;

Future<void> meetsAll(WidgetTester tester, String state) async {
  for (final g in [
    textContrastGuideline,
    androidTapTargetGuideline,
    iOSTapTargetGuideline,
    labeledTapTargetGuideline,
  ]) {
    await expectLater(tester, meetsGuideline(g), reason: state);
  }
}

/// The system Back (Android button, browser back).
Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

/// Scrolls the home list back to its top (the attention strip).
Future<void> top(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, 4000));
  await tester.pumpAndSettle();
}

void main() {
  for (final theme in ['light', 'dark']) {
    testWidgets(
      'home, item, editor, label and dates meet guidelines ($theme)',
      (tester) async {
        final handle = tester.ensureSemantics();
        final prefs = Preferences()
          ..value = HandyPreferences(locale: 'vi', theme: theme);
        await start(tester, store: stored(sample()), prefs: prefs);
        await meetsAll(tester, 'home');
        await tapKey(tester, 'item-drill');
        await meetsAll(tester, 'item');
        await tapKey(tester, 'item-edit');
        await meetsAll(tester, 'editor');
        await tapKey(tester, 'item-close');
        await tapKey(tester, 'more-menu');
        await tapKey(tester, 'item-label');
        await meetsAll(tester, 'label');
        await back(tester);
        await back(tester);
        await tapKey(tester, 'due-all');
        await meetsAll(tester, 'dates');
        await back(tester);
        await tapKey(tester, 'open-settings');
        await meetsAll(tester, 'settings');
        handle.dispose();
      },
    );
  }

  testWidgets('every Keep screen lays out at 320px without overflow', (
    tester,
  ) async {
    final s = saveAsset(
      sample(),
      createAsset(
        id: 'long',
        name: 'Máy hút bụi cầm tay không dây loại mới có đầu hút dài',
        fields: {'location': 'Tủ âm tường phòng ngủ phía sau cánh cửa trượt'},
      ),
    );
    await start(tester, store: stored(s), size: const Size(320, 640));
    expect(tester.takeException(), isNull);
    for (final f in ['lent', 'boxes', 'loose', 'all']) {
      await tapKey(tester, 'filter-$f');
      expect(tester.takeException(), isNull, reason: f);
    }
    await tapKey(tester, 'item-long');
    expect(tester.takeException(), isNull);
    await tapKey(tester, 'item-edit');
    expect(tester.takeException(), isNull);
    await tapKey(tester, 'item-close');
    await tapKey(tester, 'item-lend');
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await back(tester);
    await top(tester);
    await tapKey(tester, 'due-all');
    expect(tester.takeException(), isNull);
    await back(tester);
    await tapKey(tester, 'open-settings');
    expect(tester.takeException(), isNull);
  });
}
