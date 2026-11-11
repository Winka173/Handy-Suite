import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'run14_test.dart' as f;
import 'run15_fixtures.dart';
import 'run3_ui_test.dart' as host;
import 'run4_routines_test.dart' show tap;

void main() {
  for (final locale in ['en', 'vi']) {
    for (final density in [2.6, 3.0]) {
      testWidgets('guide logical headlines $locale density $density', (
        t,
      ) async {
        await f.bootRun14(t, locale: locale);
        t.view.physicalSize = const Size(1080, 2400);
        t.view.devicePixelRatio = density;
        await host.go(t, '/welcome');
        void headline(String key, double size) {
          final text = find.byKey(Key(key));
          final paragraph = t.renderObject<RenderParagraph>(
            find.descendant(of: text, matching: find.byType(RichText)).last,
          );
          expect(paragraph.text.style!.fontSize, size);
          expect(paragraph.textScaler.scale(size), greaterThanOrEqualTo(size));
          expect(paragraph.getTransformTo(null).getMaxScaleOnAxis(), 1);
        }

        headline('welcome-title-0-false', 30);
        await tap(t, 'welcome-next');
        headline('welcome-title-0-true', 30);
        await tap(t, 'welcome-next');
        headline('welcome-title-1-true', 30);
        expect(t.takeException(), isNull);
      });
    }
    testWidgets('batch preview uses natural $locale sentences', (t) async {
      await f.bootRun14(
        t,
        state: convenienceSeed(locale: locale),
        locale: locale,
      );
      await host.go(t, '/habits/batch');
      await tap(t, 'batch-water');
      await tap(t, 'batch-preview');
      await tap(t, 'editor-save');
      expect(
        find.text(locale == 'vi' ? 'Sẽ lưu trữ' : 'Will be archived'),
        findsOneWidget,
      );
    });
  }
}
