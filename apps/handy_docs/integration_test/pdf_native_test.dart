import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_pdf/handy_pdf.dart';
import 'package:handy_docs/app.dart';
import 'package:handy_pdf/preview.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_files/handy_files.dart';
import '../test/helpers.dart' show Prefs, go, menu, tapKey;

Future<void> openDocs(
  WidgetTester tester,
  HandyFiles files, {
  DocumentRepository? markdown,
}) async {
  await tester.pumpWidget(
    DocsApp(
      files: files,
      preferences: Prefs()
        ..value = HandyPreferences(locale: 'en', theme: 'light'),
      documents: localDocuments('handy-docs-integration'),
      markdownDocuments:
          markdown ?? localDocuments('handy-docs-markdown-integration'),
      readerDocuments: localDocuments('handy-docs-reader-integration'),
    ),
  );
  await tester.pumpAndSettle();
}

/// Waits for real PDFium work, which fake time does not advance.
Future<void> settle(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 150 && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

class PdfFiles implements HandyFiles {
  Uint8List? bytes, exported;
  bool canceled = false;
  @override
  Future<ImportedBytes?> importBytes({
    required List<String> extensions,
    int maxBytes = 30000000,
    CancellationToken? cancellation,
  }) async =>
      bytes == null ? null : ImportedBytes('Actual scanner PDF.pdf', bytes!);
  @override
  Future<String?> exportBytes(
    String name,
    Uint8List bytes, {
    required String mimeType,
    CancellationToken? cancellation,
  }) async {
    if (canceled) return null;
    exported = bytes;
    return 'integration-export';
  }

  @override
  Future<ImportedText?> importText({
    int maxBytes = 1000000,
    CancellationToken? cancellation,
  }) async => null;
  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) async => null;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Markdown PDF text and ZIP export/import use real native PDFium', (
    tester,
  ) async {
    const source =
        '# Tiếng Việt\n\n**Đậm** và *nghiêng*.\n\n- [x] Xong\n- [ ] Chưa\n\n| A | B |\n| --- | --- |\n| Một | Hai |\n';
    final docs = localDocuments('handy-docs-markdown-export-integration');
    await docs.save(serializeMarkdownDraft(source));
    final files = PdfFiles();
    await openDocs(tester, files, markdown: docs);
    await go(tester, '/write');
    Future<void> export(String kind) async {
      final before = files.exported;
      await tapKey(tester, 'markdown-export');
      await tester.tap(find.byKey(Key('markdown-export-$kind')));
      await tester.pump();
      await settle(
        tester,
        () =>
            find.byKey(const Key('markdown-cancel')).evaluate().isEmpty &&
            (files.canceled || !identical(files.exported, before)),
      );
    }

    await export('pdf');
    expect(files.exported, isNotNull);
    final pdfBytes = Uint8List.fromList(files.exported!);
    final pdf = await LocalPdf.open(pdfBytes);
    try {
      expect(pdf.pages.length, 1);
      final text = await pdf.pageText(0);
      expect(text, contains('Tiếng Việt'));
      expect(text, contains('Đậm'));
      expect(text, contains('[x] Xong'));
      expect(text, contains('Một'));
    } finally {
      await pdf.close();
    }
    await export('zip');
    final zip = Uint8List.fromList(files.exported!);
    final pack = parseDocumentPack(zip);
    expect(pack.source, source);
    final packedPdf = await LocalPdf.open(pack.pdfBytes);
    expect(await packedPdf.pageText(0), contains('Tiếng Việt'));
    await packedPdf.close();
    files.bytes = zip;
    await menu(tester, 'markdown-import-pack');
    await settle(tester, () => true);
    expect(await docs.load(), serializeMarkdownDraft(source));
    files.canceled = true;
    await export('zip');
    expect(files.exported, zip);
    expect(find.text('Export canceled'), findsOneWidget);
    files.bytes = Uint8List.fromList('corrupt ZIP'.codeUnits);
    await menu(tester, 'markdown-import-pack');
    await settle(tester, () => true);
    expect(await docs.load(), serializeMarkdownDraft(source));
    await tester.pumpWidget(
      MaterialApp(
        home: LocalPdfPreview(
          bytes: pdfBytes,
          title: 'Markdown PDF · Tiếng Việt',
        ),
      ),
    );
    for (var i = 0; i < 150 && find.byType(Image).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(Image), findsOneWidget);
    if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
      await binding.takeScreenshot('docs-markdown-pdf');
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  Future<Uint8List> fixture(int width, int height, int red) async {
    final pixels = Uint8List(width * height * 4);
    for (var i = 0; i < pixels.length; i += 4) {
      pixels[i] = red;
      pixels[i + 3] = 255;
    }
    return scannerPdf([
      encodeScanPng(ScanRaster(width: width, height: height, rgba: pixels)),
    ]);
  }

  testWidgets(
    'native PDF merge, duplicate/reorder/rotate, render and reopened output preserve sources',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('PDF native integration'))),
      );
      final first = await fixture(120, 80, 220),
          second = await fixture(80, 120, 40);
      final saved = Uint8List.fromList(first);
      final merged = await LocalPdf.merge([first, second]);
      final document = await LocalPdf.open(merged);
      try {
        expect(document.pages.length, 2);
        expect(document.pages[0].width, closeTo(120, .01));
        expect(document.pages[1].height, closeTo(120, .01));
        final output = await document.transform([1, 0, 1], rotation: 90);
        final reopened = await LocalPdf.open(output);
        try {
          expect(reopened.pages.length, 3);
          expect(reopened.pages.map((p) => p.rotation), everyElement(90));
          expect(reopened.pages[0].width, closeTo(120, .01));
          final png = await reopened.renderPng(0, maxEdge: 600);
          final decoded = decodeBoundedImage(png);
          expect(decoded.width, 600);
          expect(decoded.rgba[0], inInclusiveRange(38, 42));
          expect(first, saved);
        } finally {
          await reopened.close();
        }
        final canceled = CancellationToken()..cancel();
        await expectLater(
          document.transform([0], cancellation: canceled),
          throwsA(isA<Cancelled>()),
        );
        await expectLater(document.transform([99]), throwsFormatException);
      } finally {
        await document.close();
      }
      await expectLater(
        LocalPdf.open(Uint8List.fromList('%PDF-1.7\ncorrupt'.codeUnits)),
        throwsA(isA<Exception>()),
      );
    },
  );
  testWidgets(
    'PDF UI actual import, preview and selected PDF export roundtrip',
    (tester) async {
      final files = PdfFiles()..bytes = await fixture(120, 80, 160);
      await openDocs(tester, files);
      await go(tester, '/pdf');
      await tester.tap(find.byKey(const Key('pdf-import')));
      await settle(
        tester,
        () => find.byKey(const Key('pdf-preview')).evaluate().isNotEmpty,
      );
      expect(find.byKey(const Key('pdf-preview')), findsOneWidget);
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('docs-pdf-preview');
      }
      await tester.ensureVisible(find.byKey(const Key('pdf-watermark')));
      await tester.enterText(
        find.byKey(const Key('pdf-watermark')),
        'DOCS COPY',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tapKey(tester, 'pdf-transform');
      await settle(
        tester,
        () => find.byKey(const Key('pdf-export')).evaluate().isNotEmpty,
      );
      await tapKey(tester, 'pdf-export');
      expect(files.exported, isNotNull);
      final reopened = await LocalPdf.open(files.exported!);
      expect(reopened.pages.length, 1);
      expect(await reopened.pageText(0), contains('DOCS COPY'));
      await reopened.close();
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.takeScreenshot('docs-pdf-watermark');
      }
    },
  );
}
