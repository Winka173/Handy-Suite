import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'pilot_test.dart';

/// Flutter's own accessibility guidelines on every bench state, light and
/// dark: text contrast, tap target size on Android and iOS, and a label on
/// every tappable thing.
Future<void> meetsAll(WidgetTester tester, String state) async {
  await expectLater(
    tester,
    meetsGuideline(textContrastGuideline),
    reason: state,
  );
  await expectLater(
    tester,
    meetsGuideline(androidTapTargetGuideline),
    reason: state,
  );
  await expectLater(
    tester,
    meetsGuideline(iOSTapTargetGuideline),
    reason: state,
  );
  await expectLater(
    tester,
    meetsGuideline(labeledTapTargetGuideline),
    reason: state,
  );
}

void main() {
  for (final theme in ['light', 'dark']) {
    testWidgets('bench states meet accessibility guidelines ($theme)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repo = MemoryPreferences()
        ..state = MemoryPreferences().state.copyWith(
          theme: theme,
          favorites: ['loan'],
        );
      await start(tester, repo: repo);
      await meetsAll(tester, 'empty');
      await enter(tester, '1.385.000 / 3', submit: true);
      await enter(tester, 'b\na\nb');
      await tester.tap(find.byKey(const Key('transform-sort')));
      await tester.pumpAndSettle();
      await meetsAll(tester, 'text chain + tape');
      await openTool(tester, 'loan');
      await tester.enterText(find.byKey(const Key('field-principal')), '1000');
      await tester.enterText(find.byKey(const Key('field-rate')), '12');
      await tester.pumpAndSettle();
      await meetsAll(tester, 'loan form');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-catalog')));
      await tester.pumpAndSettle();
      await meetsAll(tester, 'catalog');
      handle.dispose();
    });
  }
}
