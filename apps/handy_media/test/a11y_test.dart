import 'package:flutter_test/flutter_test.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media/capture_library.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'capture_test.dart' show Store;
import 'guide_export_test.dart' show guideBundle;
import 'helpers.dart';
import 'quick_tools_test.dart' show Files, png;

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

/// Opens each place with something in it.
Future<void> visit(
  WidgetTester tester,
  Future<void> Function(String) check,
) async {
  await check('studio');
  await tapKey(tester, 'guide-fixture');
  await check('editor');
  await tester.tap(find.byKey(const ValueKey('layer-mask')));
  await tester.pumpAndSettle();
  await check('editor with a note chosen');
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  await go(tester, '/image');
  await tapKey(tester, 'media-import');
  await check('image');
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  await go(tester, '/subtitles');
  await tester.enterText(
    find.byKey(const Key('subtitle-input')),
    '1\n00:00:01,000 --> 00:00:02,000\nXin chào\n',
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
  await check('subtitles');
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  await go(tester, '/settings');
  await check('settings');
}

void main() {
  for (final theme in ['light', 'dark']) {
    testWidgets('every place meets the guidelines ($theme)', (tester) async {
      final handle = tester.ensureSemantics();
      await start(
        tester,
        documents: Store()..text = CaptureLibrary([guideBundle()]).serialize(),
        files: Files()..next = ImportedBytes('Ảnh.png', png()),
        drafts: {},
        prefs: Prefs()..value = HandyPreferences(locale: 'vi', theme: theme),
      );
      await visit(tester, (state) => meetsAll(tester, state));
      handle.dispose();
    });
  }

  for (final size in [const Size(320, 640), const Size(1440, 900)]) {
    testWidgets('nothing overflows at ${size.width.toInt()} px', (
      tester,
    ) async {
      await start(
        tester,
        documents: Store()..text = CaptureLibrary([guideBundle()]).serialize(),
        files: Files()
          ..next = ImportedBytes('Ảnh chụp màn hình rất dài.png', png()),
        drafts: {},
        prefs: Prefs()..value = HandyPreferences(locale: 'vi'),
        size: size,
      );
      await visit(tester, (state) async {
        expect(tester.takeException(), isNull, reason: state);
      });
    });
  }
}
