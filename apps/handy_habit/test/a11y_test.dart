import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'ui_test.dart' as fixtures;

void main() {
  for (final theme in ['light', 'dark']) {
    for (final width in [390.0, 1440.0]) {
      testWidgets(
        'Vietnamese areas meet automated accessibility guidelines $theme $width',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final semantics = tester.ensureSemantics();
          final c = await fixtures.start(
            tester,
            locale: 'vi',
            state: fixtures.seeded().copy({
              'settings': {'onboarded': true, 'theme': theme},
            }),
          );
          await fixtures.tapKey(tester, 'today-all-habits');
          for (final guideline in [
            textContrastGuideline,
            androidTapTargetGuideline,
            iOSTapTargetGuideline,
            labeledTapTargetGuideline,
          ]) {
            await expectLater(
              tester,
              meetsGuideline(guideline),
              reason: '$theme $width habits',
            );
          }
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          for (final label in ['Hôm nay', 'Quy trình', 'Tiến bộ']) {
            await tester.tap(find.text(label).last);
            await tester.pumpAndSettle();
            for (final guideline in [
              textContrastGuideline,
              androidTapTargetGuideline,
              iOSTapTargetGuideline,
              labeledTapTargetGuideline,
            ]) {
              await expectLater(
                tester,
                meetsGuideline(guideline),
                reason: '$theme $width $label',
              );
            }
          }
          await tester.pumpWidget(const SizedBox());
          c.dispose();
          semantics.dispose();
        },
      );
    }
  }
}
