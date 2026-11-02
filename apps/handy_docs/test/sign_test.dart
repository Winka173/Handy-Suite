import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_docs/pdf/pdf_desk.dart';
import 'package:handy_docs/sign/fill_controller.dart';
import 'package:handy_docs/sign/signature_store.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_pdf/handy_pdf.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';

/// Pages that need no PDFium: an A4 portrait and an A4 landscape page.
class FakePages implements FillSource {
  final sizes = <(double, double)>[(595, 842), (842, 595)];
  final List<List<PdfStamp>> made = [];
  int closed = 0;
  bool fail = false;
  static Uint8List picture = Uint8List(0);

  @override
  int get pageCount => sizes.length;
  @override
  (double, double) size(int index) => sizes[index];
  @override
  Future<Uint8List> render(int index) async => picture;
  @override
  Future<Uint8List> flatten(
    List<PdfStamp> stamps,
    CancellationToken token,
  ) async {
    token.check();
    if (fail) throw const FormatException('Could not place a mark');
    made.add(stamps);
    return Uint8List.fromList('%PDF-1.7 signed'.codeUnits);
  }

  @override
  Future<FillSource> reopen(Uint8List bytes) async => FakePages();
  @override
  Future<void> close() async => closed++;
}

/// A tiny opaque PNG made with the engine (no dart:ui decoding needed).
Future<Uint8List> inkPng(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 40, 20),
        Paint()..color = const Color(0xFF1B2A4A),
      );
      final image = await recorder.endRecording().toImage(40, 20);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    }))!;

/// A PDF desk holding one file, without PDFium.
class FakeDesk extends PdfDesk {
  final original = Uint8List.fromList('%PDF-1.7 form'.codeUnits);
  bool strong = false;
  FakeDesk() {
    inputs.add(ImportedBytes('form.pdf', Uint8List.fromList(original)));
  }
  @override
  int get pages => 1;
  @override
  Future<void> compress(bool strong, CancellationToken token) async {
    this.strong = strong;
    before = 2400000;
    output = Uint8List(600000);
    outputNote = strong ? 'strong' : 'smaller';
    notifyListeners();
  }
}

void main() {
  group('saved signatures', () {
    test('round-trip, and refuse what is not a small PNG', () async {
      final png = Uint8List.fromList([
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2, 3, //
      ]);
      final book = SignatureBook([
        SavedSignature('sig-1', png, '2026-11-02T09:00:00.000Z'),
      ]);
      final back = SignatureBook.parse(book.serialize());
      expect(back.signatures.single.png, png);
      expect(back.serialize(), book.serialize());
      for (final bad in [
        Uint8List.fromList([1, 2, 3]),
        Uint8List(SignatureBook.maxBytes + 1)..setAll(0, png.sublist(0, 8)),
      ]) {
        expect(
          () => SignatureBook([
            SavedSignature('sig-2', bad, '2026-11-02T09:00:00.000Z'),
          ]),
          throwsFormatException,
        );
      }
      expect(
        () => SignatureBook.parse('{"format":"other","version":1}'),
        throwsFormatException,
      );
      expect(
        () => SignatureBook([
          for (var i = 0; i < 7; i++)
            SavedSignature('s$i', png, '2026-11-02T09:00:00.000Z'),
        ]),
        throwsFormatException,
      );

      final disk = Store();
      final store = SignatureStore(disk);
      await store.load();
      final kept = await store.add(png);
      expect(SignatureBook.parse(disk.text!).signatures.single.id, kept.id);
      disk.fail = true;
      await expectLater(store.add(png), throwsStateError);
      expect(store.signatures.length, 1);
      disk.fail = false;
      await store.remove(kept.id);
      expect(SignatureBook.parse(disk.text!).signatures, isEmpty);

      // A damaged file is reported and never replaced by an empty list.
      final damaged = Store()..text = '{broken';
      final again = SignatureStore(damaged);
      await again.load();
      expect(again.error, isNotNull);
      await expectLater(again.add(png), throwsStateError);
      expect(damaged.text, '{broken');
    });
  });

  group('placing marks', () {
    test('boxes keep their shape on the page and become stamps', () async {
      final pages = FakePages();
      final fill = FillController(pages, 'Đơn xin phép.pdf');
      await fill.open();
      // 40 × 20 picture, 30% of an A4 page wide.
      fill.addSignature(Uint8List(3), Uint8List(40 * 20 * 4), 40, 20);
      final sig = fill.items.single;
      expect(sig.box.width, closeTo(.3, 1e-9));
      expect(sig.box.height * 842 / (sig.box.width * 595), closeTo(.5, 1e-9));
      fill.move(sig.id, 5, 5);
      final moved = fill.items.single.box;
      expect(moved.left + moved.width, closeTo(1, 1e-9));
      expect(moved.top + moved.height, closeTo(1, 1e-9));
      fill.move(sig.id, -2, -2);
      fill.resize(sig.id, .1);
      final big = fill.items.single.box;
      expect(big.width, closeTo(.4, 1e-9));
      expect(
        big.height / big.width,
        closeTo(sig.box.height / sig.box.width, 1e-9),
      );
      fill.addText('Nguyễn Thị Lan', 6);
      final text = fill.items.last;
      expect(text.box.height * 842, closeTo(12 * textLineHeight, 1e-6));
      expect(fill.selected, text.id);
      await fill.turn(1);
      expect(fill.onPage, isEmpty);
      fill.addText('02/11/2026', 4, kind: MarkKind.date);
      expect(fill.items.last.page, 1);

      final token = CancellationToken();
      await fill.make(token);
      expect(fill.output, isNotNull);
      final stamps = pages.made.single;
      expect(stamps.whereType<PdfImageStamp>().single.page, 0);
      expect(
        stamps.whereType<PdfTextStamp>().map((s) => (s.page, s.text, s.fit)),
        [(0, 'Nguyễn Thị Lan', true), (1, '02/11/2026', true)],
      );
      expect(fill.outputName, 'Đơn xin phép-signed.pdf');
      // Changing a mark drops the copy; the marks stay.
      fill.remove(text.id);
      expect(fill.output, isNull);
      expect(fill.items.length, 2);
      await expectLater(
        fill.make(CancellationToken()..cancel()),
        throwsA(isA<Cancelled>()),
      );
      expect(fill.output, isNull);
      fill.dispose();
      expect(pages.closed, 1);
    });
  });

  testWidgets(
    'sign and fill: place text and a saved signature, look, then save a new copy',
    (tester) async {
      final docs = Docs();
      final png = await inkPng(tester);
      FakePages.picture = png;
      docs.signatures.text = SignatureBook([
        SavedSignature('sig-1', png, '2026-11-02T09:00:00.000Z'),
      ]).serialize();
      final desk = FakeDesk();
      final pages = FakePages();
      await start(
        tester,
        docs: docs,
        desk: desk,
        fill: (_) async => pages,
        size: const Size(1280, 900),
      );
      await go(tester, '/pdf/fill');
      expect(find.byKey(const Key('fill-page')), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('fill-make')))
            .onPressed,
        isNull,
      );
      await tapKey(tester, 'fill-text');
      await tester.enterText(
        find.byKey(const Key('fill-text-field')),
        'Nguyễn Thị Lan',
      );
      await tester.tap(find.byKey(const Key('fill-text-apply')));
      await tester.pumpAndSettle();
      expect(find.text('Nguyễn Thị Lan'), findsOneWidget);
      await tester.tap(find.byKey(const Key('fill-signature-sig-1')));
      // Decoding the picture is real work: let it finish step by step.
      for (var i = 0; i < 20 && pages.made.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fill-mark-mark-1')), findsOneWidget);
      // Leaving with marks placed asks first.
      await back(tester);
      expect(find.text('Leave without saving?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-cancel')));
      await tester.pumpAndSettle();
      await tapKey(tester, 'fill-make');
      expect(find.byKey(const Key('fill-preview')), findsOneWidget);
      expect(pages.made.single.length, 2);
      docs.files.cancel = true;
      await tapKey(tester, 'fill-save');
      expect(docs.files.exported, isNull);
      docs.files.cancel = false;
      await tapKey(tester, 'fill-save');
      expect(docs.files.name, 'form-signed.pdf');
      expect(String.fromCharCodes(docs.files.exported!), '%PDF-1.7 signed');
      expect(desk.inputs.single.bytes, desk.original);
      // A deleted signature leaves this device.
      await tapKey(tester, 'fill-edit');
      await tapKey(tester, 'fill-signature-delete-sig-1');
      await tester.tap(find.byKey(const Key('confirm-action')));
      await tester.pumpAndSettle();
      expect(SignatureBook.parse(docs.signatures.text!).signatures, isEmpty);
    },
  );

  testWidgets('a failed copy says so and keeps the marks', (tester) async {
    final docs = Docs();
    FakePages.picture = await inkPng(tester);
    final pages = FakePages()..fail = true;
    await start(
      tester,
      docs: docs,
      desk: FakeDesk(),
      fill: (_) async => pages,
      size: const Size(390, 844),
    );
    await go(tester, '/pdf/fill');
    await tapKey(tester, 'fill-tools');
    await tapKey(tester, 'fill-text');
    await tester.enterText(find.byKey(const Key('fill-text-field')), 'Lan');
    await tester.tap(find.byKey(const Key('fill-text-apply')));
    await tester.pumpAndSettle();
    await tapKey(tester, 'fill-make');
    expect(find.textContaining('Could not place a mark'), findsOneWidget);
    expect(find.text('Lan'), findsOneWidget);
    expect(find.byKey(const Key('fill-preview')), findsNothing);
  });

  testWidgets('a smaller copy shows both sizes and keeps the original', (
    tester,
  ) async {
    final docs = Docs();
    final desk = FakeDesk();
    await start(tester, docs: docs, desk: desk, size: const Size(1280, 900));
    await go(tester, '/pdf');
    await tapKey(tester, 'pdf-compress');
    expect(find.text('2.4 MB → 600 KB'), findsOneWidget);
    expect(find.textContaining('75% smaller'), findsOneWidget);
    await tapKey(tester, 'pdf-export');
    expect(docs.files.name, 'form-smaller.pdf');
    expect(docs.files.exported!.length, 600000);
    await tapKey(tester, 'pdf-compress-strong');
    expect(desk.strong, isTrue);
    expect(find.textContaining('pages are pictures now'), findsOneWidget);
    expect(desk.inputs.single.bytes, desk.original);
  });

  for (final size in [const Size(320, 640), const Size(1440, 900)]) {
    testWidgets('signing fits at ${size.width.toInt()} px', (tester) async {
      FakePages.picture = await inkPng(tester);
      await start(
        tester,
        desk: FakeDesk(),
        fill: (_) async => FakePages(),
        size: size,
      );
      await go(tester, '/pdf/fill');
      if (size.width < 900) await tapKey(tester, 'fill-tools');
      await tapKey(tester, 'fill-date');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fill-mark-mark-0')), findsOneWidget);
      await tapKey(tester, 'fill-make');
      expect(find.byKey(const Key('fill-preview')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
