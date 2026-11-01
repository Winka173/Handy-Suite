import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:handy_docs/app.dart';
import 'package:handy_docs/session.dart';
import 'package:handy_docs/corner_editor.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';

Future<void> go(WidgetTester tester, String route) async {
  Navigator.of(
    tester.element(find.byKey(const Key('docs-desk'))),
  ).pushNamed(route);
  await tester.pumpAndSettle();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native Markdown draft persists and safe GFM preview survives navigation',
    (tester) async {
      final store = localDocuments(
        'handy-docs-markdown-integration',
        maxBytes: 6100000,
      );
      final scans = localDocuments(
        'handy-docs-markdown-scan-integration',
        maxBytes: 24000000,
      );
      final prefs = DevicePreferencesRepository(
        'handy-docs-markdown-integration',
      );
      await prefs.save(HandyPreferences(locale: 'en', theme: 'light'));
      await store.save(serializeMarkdownDraft(''));
      await scans.save(ScanSession([]).serialize());
      final reader = localDocuments('handy-docs-reader-integration');
      await tester.pumpWidget(
        DocsApp(
          preferences: prefs,
          documents: scans,
          markdownDocuments: store,
          readerDocuments: reader,
        ),
      );
      await tester.pumpAndSettle();
      await go(tester, '/write');
      const source =
          '# Hướng dẫn\n\n- [x] Đã lưu\n- [ ] Tiếp theo\n\n| App | Dữ liệu |\n| --- | --- |\n| Handy Docs | Local |\n\n![Private image](file:///private/image.png)\n';
      await tester.enterText(find.byKey(const Key('markdown-source')), source);
      FocusManager.instance.primaryFocus?.unfocus();
      await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('markdown-save')).hitTestable());
      await tester.pumpAndSettle();
      expect(parseMarkdownDraft((await store.load())!), source);
      if (find.text('Preview').evaluate().isNotEmpty) {
        await tester.tap(find.text('Preview'));
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('[Image blocked: Private image]'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('docs-markdown-preview');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        DocsApp(
          preferences: prefs,
          documents: scans,
          markdownDocuments: localDocuments(
            'handy-docs-markdown-integration',
            maxBytes: 6100000,
          ),
          readerDocuments: reader,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('desk-work-write')), findsOneWidget);
      await go(tester, '/write');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('markdown-source')))
            .controller!
            .text,
        source,
      );
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.takeScreenshot('docs-markdown-editor');
      }
      await store.save(serializeMarkdownDraft(''));
    },
  );
  testWidgets(
    'native scanner persists corrected pixels and session import roundtrip',
    (tester) async {
      final store = localDocuments(
        'handy-docs-integration',
        maxBytes: 24000000,
      );
      final pixels = Uint8List(160 * 240 * 4);
      for (var y = 0; y < 240; y++) {
        for (var x = 0; x < 160; x++) {
          final i = (y * 160 + x) * 4,
              ink = x > 12 && x < 148 && y > 20 && y < 220 && y % 24 < 3;
          pixels[i] = ink ? 30 : 240;
          pixels[i + 1] = ink ? 35 : 238;
          pixels[i + 2] = ink ? 45 : 230;
          pixels[i + 3] = 255;
        }
      }
      final png = encodeScanPng(
        ScanRaster(width: 160, height: 240, rgba: pixels),
      );
      await store.save(
        ScanSession([
          ScanPage('integration-page', 'Document fixture', png),
        ]).serialize(),
      );
      final prefs = DevicePreferencesRepository('handy-docs-integration');
      await prefs.save(HandyPreferences(locale: 'en', theme: 'light'));
      await tester.pumpWidget(
        DocsApp(
          documents: store,
          preferences: prefs,
          markdownDocuments: localDocuments('handy-docs-markdown-integration'),
          readerDocuments: localDocuments('handy-docs-reader-integration'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('desk-work-scan')), findsOneWidget);
      await go(tester, '/scan');
      expect(find.text('1. Document fixture'), findsOneWidget);
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('docs-scanner-light');
      }
      await tester.tap(
        find
            .descendant(
              of: find.byKey(const ValueKey('scan-page-integration-page')),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(CornerEditor), findsOneWidget);
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.takeScreenshot('docs-four-corners');
      }
      await tester.tap(find.byKey(const Key('save-scan-page')));
      for (
        var i = 0;
        i < 100 && find.byType(CornerEditor).evaluate().isNotEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(find.byType(CornerEditor), findsNothing);
      await tester.pumpWidget(const SizedBox());
      final restored = ScanSession.parse(
        (await localDocuments(
          'handy-docs-integration',
          maxBytes: 24000000,
        ).load())!,
      );
      expect(restored.pages.single.id, 'integration-page');
      final pdf = await scannerPdf([restored.pages.single.png]);
      expect(inspectScannerPdf(pdf).pages, 1);
      expect(
        ScanSession.parse(restored.serialize()).pages.single.png,
        restored.pages.single.png,
      );
      await store.save(ScanSession([]).serialize());
    },
  );
}
