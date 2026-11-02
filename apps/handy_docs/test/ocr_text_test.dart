import 'dart:convert';
import 'package:archive/archive.dart';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_docs/scan/scan_store.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_pdf/handy_pdf.dart';
import 'package:handy_ocr/handy_ocr.dart';
import 'package:handy_ui/kit.dart';
import 'a11y_test.dart' show busyDesk;
import 'helpers.dart';

/// An engine that answers at once with two lines.
class FakeOcr implements OcrEngine {
  OcrSupport value = const OcrSupport(available: true, engine: 'fake');
  String? asked;
  int reads = 0;
  @override
  OcrPixelFormat get format => OcrPixelFormat.bgra;
  @override
  Future<OcrSupport> support() async => value;
  @override
  Future<Map<Object?, Object?>> read(OcrInput input, String? language) async {
    reads++;
    asked = language;
    return {
      'lines': [
        {
          'text': 'HÓA ĐƠN TIỀN ĐIỆN',
          'box': {'x': 1, 'y': 1, 'w': 6, 'h': 1},
        },
        {
          'text': 'Thành tiền: 512.340 đ',
          'box': {'x': 1, 'y': 4, 'w': 6, 'h': 1},
        },
      ],
    };
  }
}

ImportedBytes file(String name, String text) =>
    ImportedBytes(name, Uint8List.fromList(utf8.encode(text)));

void main() {
  tearDown(() => ocrEngineOverride = null);

  testWidgets(
    'a scanned page is read on the device, edited, saved and sent to the writer',
    (tester) async {
      final engine = FakeOcr();
      ocrEngineOverride = engine;
      final docs = await start(tester, docs: busyDesk(locale: 'en'));
      final draftBefore = docs.markdown.text;
      await go(tester, '/scan');
      await menu(tester, 'scan-ocr-a');
      await tester.pumpAndSettle();
      expect(engine.reads, 1);
      final field = find.byKey(const Key('ocr-text'));
      expect(
        tester.widget<TextField>(field).controller!.text,
        'HÓA ĐƠN TIỀN ĐIỆN\n\nThành tiền: 512.340 đ',
      );
      await tester.enterText(field, 'Thành tiền: 512.340 đồng');
      await menu(tester, 'ocr-save-txt');
      expect(docs.files.name, 'Hóa đơn điện tháng 10.txt');
      expect(utf8.decode(docs.files.exported!), 'Thành tiền: 512.340 đồng');
      await menu(tester, 'ocr-save-md');
      expect(docs.files.name, 'Hóa đơn điện tháng 10.md');
      await menu(tester, 'ocr-save-docx');
      expect(docs.files.name, 'Hóa đơn điện tháng 10.docx');
      final word = ZipDecoder().decodeBytes(docs.files.exported!);
      expect(
        utf8.decode(word.findFile('word/document.xml')!.content),
        contains('Thành tiền: 512.340 đồng'),
      );
      // The draft is replaced only after asking, and is not saved by it.
      await menu(tester, 'ocr-writer');
      await tester.tap(find.byKey(const Key('confirm-action')));
      await tester.pumpAndSettle();
      expect(sourceText(tester), 'Thành tiền: 512.340 đồng');
      expect(docs.markdown.text, draftBefore);
    },
  );

  testWidgets(
    'a missing Windows language says so and reads with one that is there',
    (tester) async {
      final engine = FakeOcr()
        ..value = const OcrSupport(
          available: true,
          engine: 'windows-ocr',
          languages: ['en-US'],
        );
      ocrEngineOverride = engine;
      await start(tester, docs: busyDesk());
      await go(tester, '/scan');
      await menu(tester, 'scan-ocr-a');
      expect(
        find.text('Windows chưa cài nhận dạng chữ tiếng Việt'),
        findsOneWidget,
      );
      expect(engine.reads, 0);
      await tapKey(tester, 'ocr-language-en-US');
      expect(engine.asked, 'en-US');
      expect(find.byKey(const Key('ocr-text')), findsOneWidget);
    },
  );

  testWidgets('without an engine the page explains, with no dead buttons', (
    tester,
  ) async {
    ocrEngineOverride = FakeOcr()..value = OcrSupport.none;
    await start(tester, docs: busyDesk(locale: 'en'));
    await go(tester, '/scan');
    await menu(tester, 'scan-ocr-a');
    expect(find.text('Text recognition is in the app'), findsOneWidget);
    expect(find.byKey(const Key('ocr-copy')), findsNothing);
  });

  test('the hidden text layer follows each line, inside its page', () {
    final read = OcrResult.fromMap(
      {
        'lines': [
          {
            'text': 'Số: 0412',
            'box': {'x': 50, 'y': 100, 'w': 200, 'h': 20},
          },
          {
            'text': 'x' * 400,
            'box': {'x': 590, 'y': 790, 'w': 40, 'h': 30},
          },
        ],
      },
      width: 600,
      height: 800,
      engine: 'test',
    );
    final layer = searchableLayer(2, read).cast<PdfTextStamp>();
    expect(layer.map((s) => (s.page, s.invisible, s.fit)), [
      (2, true, true),
      (2, true, true),
    ]);
    final first = layer.first.box;
    expect(first.left, closeTo(50 / 600, 1e-9));
    expect(first.top, closeTo(100 / 800, 1e-9));
    expect(first.width, closeTo(200 / 600, 1e-9));
    final edge = layer.last;
    expect(edge.box.valid, isTrue);
    expect(edge.text.length, 300);
    validateStamps(layer.toList(), 3);
  });

  testWidgets(
    'one way in: Markdown opens in the writer, other text reads with a Markdown copy',
    (tester) async {
      final docs = await start(tester);
      // Not text: refused with a message, nothing changes.
      docs.files.next = ImportedBytes('broken.txt', Uint8List.fromList([255]));
      await tapKey(tester, 'desk-open');
      expect(docs.reader.text, isNull);
      expect(find.byKey(const Key('docs-desk')), findsOneWidget);

      docs.files.next = file('Ghi chú.md', '# Ghi chú\n\nMua sữa');
      await tapKey(tester, 'desk-open');
      expect(sourceText(tester), '# Ghi chú\n\nMua sữa');
      expect(docs.markdown.text, isNull);
      await back(tester);
      await tester.tap(find.byKey(const Key('write-leave-discard')));
      await tester.pumpAndSettle();

      docs.files.next = file('config.yaml', 'port: 8080\n');
      await tapKey(tester, 'desk-open');
      expect(find.text('port: 8080\n'), findsOneWidget);
      expect(docs.reader.text, isNull);
      await menu(tester, 'reader-markdown-copy');
      expect(sourceText(tester), '# config.yaml\n\n```yaml\nport: 8080\n```\n');
    },
  );

  testWidgets(
    'kept files from before keep their folders, stars and ZIP, unchanged',
    (tester) async {
      // A library written by the earlier reader, byte for byte.
      final legacy = ReaderLibrary([
        for (final (id, name, kind, source) in [
          ('doc-1', 'plan.md', 'markdown', '# Kế hoạch\r\n'),
          ('doc-2', 'notes.txt', 'text', '﻿Ghi chú'),
        ])
          ReaderDocument.parse(
            ReaderDocument(
              id: id,
              name: name,
              kind: kind,
              folder: 'Công việc',
              favorite: id == 'doc-2',
              source: source,
              createdAt: '2026-10-01T09:00:00.000Z',
              lastOpenedAt: '2026-10-02T09:00:00.000Z',
            ).toJson(),
          ),
      ]).serialize();
      final docs = Docs()..reader.text = legacy;
      await start(tester, docs: docs);
      await go(tester, '/read');
      expect(find.text('Kept files'), findsOneWidget);
      expect(find.byKey(const Key('reader-filter-Công việc')), findsOneWidget);
      expect(find.byKey(const Key('reader-filter-*')), findsOneWidget);
      await tapKey(tester, 'reader-open-doc-2');
      await back(tester);
      await menu(tester, 'reader-backup');
      final restored = readReaderZip(docs.files.exported!);
      final now = ReaderLibrary.parse(docs.reader.text!);
      expect(restored.serialize(), now.serialize());
      for (final d in now.documents) {
        final was = ReaderLibrary.parse(
          legacy,
        ).documents.firstWhere((x) => x.id == d.id);
        expect(
          (d.source, d.folder, d.favorite, d.name),
          (was.source, was.folder, was.favorite, was.name),
        );
      }
      // The kept Markdown file opens in the writer; the kept copy stays.
      await tapKey(tester, 'reader-open-doc-1');
      expect(sourceText(tester), '# Kế hoạch\r\n');
      expect(
        ReaderLibrary.parse(
          docs.reader.text!,
        ).documents.firstWhere((d) => d.id == 'doc-1').source,
        '# Kế hoạch\r\n',
      );
    },
  );

  for (final size in [const Size(320, 640), const Size(1440, 900)]) {
    testWidgets('reading text fits at ${size.width.toInt()} px', (
      tester,
    ) async {
      ocrEngineOverride = FakeOcr();
      await start(tester, docs: busyDesk(), size: size);
      await go(tester, '/scan');
      await menu(tester, 'scan-ocr-a');
      expect(find.byKey(const Key('ocr-text')), findsOneWidget);
      if (size.width < 900) {
        await tester.tap(find.text('Trang'));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const Key('ocr-page')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
