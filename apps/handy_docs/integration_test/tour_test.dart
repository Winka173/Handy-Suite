// A guided walk through the app for a screen recording on a device:
// python tooling/device-tour.py --device <serial> docs
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_docs/app.dart';
import 'package:handy_docs/session.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'package:integration_test/integration_test.dart';
import '../test/helpers.dart' show Docs, menu;
import '../tool/screens_test.dart' show photo;

/// Lets the viewer see the screen before the next step.
Future<void> pause(WidgetTester t, [int ms = 1200]) async {
  await t.pumpAndSettle();
  await Future<void>.delayed(Duration(milliseconds: ms));
  await t.pump();
}

Future<void> tapOn(WidgetTester t, Finder f) async {
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  await t.tap(f.first);
  await pause(t, 700);
}

Future<void> tap(WidgetTester t, String key) => tapOn(t, find.byKey(Key(key)));

Future<void> type(WidgetTester t, String key, String text) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  // A new text-input client after the last one closed on the device.
  await t.tap(f);
  await t.pumpAndSettle();
  await t.enterText(f, text);
  await pause(t, 700);
}

/// Goes back the way a person does: the top bar's back arrow, or the
/// system back when the screen has none.
Future<void> back(WidgetTester t) async {
  await t.pumpAndSettle();
  final arrow = find.byType(BackButton).hitTestable();
  if (arrow.evaluate().isNotEmpty) {
    await t.tap(arrow.last);
  } else {
    await t.binding.handlePopRoute();
  }
  await pause(t, 700);
}

/// Puts the keyboard away before the next tap.
Future<void> hideKeyboard(WidgetTester t) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await pause(t, 400);
}

/// Waits for real work (PDFium, straightening a page) that shows a progress
/// bar: settling would never end while the bar runs.
Future<void> waitFor(
  WidgetTester t,
  String what,
  bool Function() done, {
  int seconds = 40,
}) async {
  for (var i = 0; i < seconds * 10 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await t.pump();
  }
  expect(done(), isTrue, reason: 'Still waiting for $what');
  await t.pumpAndSettle();
}

bool shown(String key) => find.byKey(Key(key)).evaluate().isNotEmpty;

/// Taps a button that starts work with a progress bar, then waits for it.
Future<void> press(
  WidgetTester t,
  String key,
  String what,
  bool Function() done,
) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f.first);
  await t.pumpAndSettle();
  await t.tap(f.first);
  await t.pump();
  await waitFor(t, what, done);
}

/// Drags a corner dot sideways first, so the drag beats the page's scroll,
/// then up or down.
Future<void> dragCorner(WidgetTester t, int i, Offset by) async {
  final dot = find.byKey(Key('scan-corner-$i'));
  await t.ensureVisible(dot);
  await t.pumpAndSettle();
  final g = await t.startGesture(t.getCenter(dot));
  for (final leg in [Offset(by.dx, 0), Offset(0, by.dy)]) {
    for (var k = 0; k < 12; k++) {
      await g.moveBy(leg / 12);
      await t.pump(const Duration(milliseconds: 16));
    }
  }
  await g.up();
  await pause(t, 500);
}

const _draft = '''# Biên bản họp nhóm dự án

**Ngày:** 30/10/2026 · **Người ghi:** Lan

## Đã chốt
- [x] Lịch giao hàng đợt 1: thứ Hai, 9/11
- [x] Kho Bình Dương nhận hàng từ 8 giờ sáng
- [ ] Gửi báo giá giao hàng cho anh Minh

## Phân việc tuần tới
| Việc | Người làm | Hạn |
| --- | --- | --- |
| In hợp đồng | Hùng | 3/11 |
| Kiểm kho | Mai | 5/11 |
''';

/// A desk with work on it: three photographed pages, a draft and a small
/// reading library, all in memory.
Future<Docs> seed() async {
  final docs = Docs();
  docs.prefs.value = HandyPreferences(locale: 'vi', theme: 'light');
  final pages = [
    await photo('HÓA ĐƠN TIỀN ĐIỆN', [
      'Kỳ: tháng 10/2026',
      'Khách hàng: Nguyễn Thị Lan',
      'Chỉ số mới: 4.812 · Chỉ số cũ: 4.603',
      'Điện năng tiêu thụ: 209 kWh',
      'Thành tiền: 512.340 đ',
      'Hạn thanh toán: 15/11/2026',
    ], 4),
    await photo('Trang 2', [
      'Bậc 1 (0–50 kWh): 1.806 đ/kWh',
      'Bậc 2 (51–100 kWh): 1.866 đ/kWh',
      'Bậc 3 (101–200 kWh): 2.167 đ/kWh',
      'Bậc 4 (201–300 kWh): 2.729 đ/kWh',
      'Thuế GTGT 8%',
    ], 8),
    await photo('Giấy xác nhận', [
      'Xác nhận ông/bà Trần Văn Hùng',
      'đã nộp đủ hồ sơ đăng ký học phần',
      'học kỳ I năm học 2026–2027.',
      '',
      'Hà Nội, ngày 28/10/2026',
    ], 2),
  ];
  docs.scan.text = ScanSession([
    ScanPage('p1', 'Hóa đơn điện T10.jpg', pages[0]),
    ScanPage('p2', 'Hóa đơn điện T10 (2).jpg', pages[1]),
    ScanPage('p3', 'Giấy xác nhận.jpg', pages[2]),
  ]).serialize();
  docs.markdown.text = serializeMarkdownDraft(_draft);
  docs.reader.text = ReaderLibrary([
    for (final (i, n, k, f, s) in [
      (
        1,
        'Hướng dẫn máy giặt.md',
        'markdown',
        'Nhà',
        '# Máy giặt\n\nChọn chế độ **Cotton** cho đồ thường. Đồ len dùng chế độ **Len**, nước lạnh.\n\n1. Cho đồ vào lồng, không quá 8 kg.\n2. Đổ nước giặt vào ngăn II.\n3. Bấm **Bắt đầu**.\n',
      ),
      (
        2,
        'ghi-chu-hop.txt',
        'text',
        'Công việc',
        'Họp thứ Hai: chốt lịch giao hàng.\nGửi báo giá trước thứ Tư.',
      ),
      (
        3,
        'config.yaml',
        'code',
        '',
        'server:\n  port: 8080\n  host: 0.0.0.0\nlog: info\n',
      ),
    ])
      ReaderDocument.parse(
        ReaderDocument(
          id: 'doc-$i',
          name: n,
          kind: k,
          folder: f,
          favorite: i == 1,
          source: s,
          createdAt: '2026-10-2${i}T09:00:00.000Z',
          lastOpenedAt: DateTime.now()
              .subtract(Duration(days: i - 1))
              .toUtc()
              .toIso8601String(),
        ).toJson(),
      ),
  ]).serialize();
  // The PDF screen opens a real three-page PDF made from the same photos,
  // handed over by the fake file picker.
  docs.files.next = ImportedBytes(
    'Hóa đơn điện T10.pdf',
    await scannerPdf([
      for (final p in pages) encodeScanPng(decodeScanImage(p)),
    ]),
  );
  return docs;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Handy Docs tour', (t) async {
    final docs = await seed();
    await t.pumpWidget(
      DocsApp(
        files: docs.files,
        documents: docs.scan,
        markdownDocuments: docs.markdown,
        readerDocuments: docs.reader,
        preferences: docs.prefs,
        camera: docs.camera,
        history: docs.history,
      ),
    );
    await pause(t, 2000);

    // The desk: the scan, the draft, and the ways to start something.
    await pause(t, 1500);

    // The scan: straighten page 2 from its four corners, then save it.
    await tap(t, 'desk-work-scan');
    await pause(t, 1500);
    await tapOn(
      t,
      find.descendant(
        of: find.byKey(const ValueKey('scan-page-p2')),
        matching: find.byType(InkWell),
      ),
    );
    await pause(t, 1500);
    await dragCorner(t, 0, const Offset(44, 30));
    await dragCorner(t, 1, const Offset(-44, 30));
    await dragCorner(t, 2, const Offset(-44, -26));
    await dragCorner(t, 3, const Offset(44, -26));
    final slider = find.byType(Slider);
    await t.ensureVisible(slider);
    await t.pumpAndSettle();
    await t.timedDragFrom(
      t.getTopLeft(slider) + Offset(24, t.getSize(slider).height / 2),
      const Offset(90, 0),
      const Duration(milliseconds: 700),
    );
    await pause(t, 1200);
    await press(
      t,
      'save-scan-page',
      'the straightened page',
      () => !shown('scan-reset-corners'),
    );
    await pause(t, 1800);

    // All pages as one PDF (the fake file picker takes it).
    await press(t, 'scan-export', 'the scan PDF', () => !shown('scan-cancel'));
    await pause(t, 2000);
    await back(t);
    await pause(t, 1200);

    // The Markdown draft: text and page side by side.
    await tap(t, 'desk-work-write');
    await pause(t, 2000);
    var text = _draft;
    for (final line in [
      '\n## Việc phát sinh\n',
      '- [ ] Đặt xe tải cho đợt giao hàng thứ 2\n',
      '- [ ] Gọi kho Bình Dương xác nhận chỗ trống\n',
    ]) {
      text += line;
      await type(t, 'markdown-source', text);
      await pause(t, 900);
    }
    await hideKeyboard(t);
    await pause(t, 1200);
    await tap(t, 'markdown-save');
    await pause(t, 1200);

    // Find and replace, one row over the text.
    await menu(t, 'markdown-find-open');
    await pause(t, 800);
    await type(t, 'markdown-find', 'giao hàng');
    await pause(t, 1200);
    await type(t, 'markdown-replacement', 'giao xe');
    await hideKeyboard(t);
    await tap(t, 'markdown-replace-all');
    await pause(t, 1500);
    await tap(t, 'markdown-save');
    await tap(t, 'markdown-find-close');
    await pause(t, 800);

    // The export choices, then put away.
    await tap(t, 'markdown-export');
    await pause(t, 2000);
    await back(t);
    await back(t);
    await pause(t, 1000);

    // PDF: open a real file, turn its pages, make a new PDF from them.
    await tap(t, 'desk-pdf');
    await pause(t, 1200);
    await press(
      t,
      'pdf-import',
      'the PDF to open',
      () => shown('pdf-preview') && !shown('pdf-cancel'),
    );
    await pause(t, 2000);
    for (final key in ['pdf-next', 'pdf-next', 'pdf-previous']) {
      await press(t, key, 'the page to turn', () => !shown('pdf-cancel'));
      await pause(t, 1200);
    }
    await type(t, 'pdf-range', '3, 1-2');
    await hideKeyboard(t);
    await tapOn(
      t,
      find.descendant(
        of: find.byKey(const Key('pdf-rotation')),
        matching: find.text('90°'),
      ),
    );
    if (shown('pdf-watermark')) {
      await type(t, 'pdf-watermark', 'BAN SAO');
      await hideKeyboard(t);
    }
    await press(
      t,
      'pdf-transform',
      'the new PDF',
      () => shown('pdf-export') && !shown('pdf-cancel'),
    );
    await pause(t, 2500);
    await press(t, 'pdf-export', 'the PDF to save', () => !shown('pdf-cancel'));
    await pause(t, 2000);
    await back(t);
    await pause(t, 1500);

    // Reading: the library beside the document.
    await tap(t, 'desk-read');
    await pause(t, 1200);
    await tap(t, 'reader-open-doc-1');
    await pause(t, 2000);
    await type(t, 'reader-search', 'chế độ');
    await hideKeyboard(t);
    await pause(t, 1500);
    for (final id in ['doc-3', 'doc-2']) {
      if (find.byKey(Key('reader-open-$id')).hitTestable().evaluate().isEmpty) {
        // A narrow window: the document sits over the library.
        await back(t);
      }
      await tap(t, 'reader-open-$id');
      await pause(t, 1800);
    }
    // Back to the desk (twice when a document sat over the library).
    for (var i = 0; i < 3 && !shown('docs-desk'); i++) {
      await back(t);
    }
    await pause(t, 1000);

    // Settings.
    await tap(t, 'open-settings');
    await pause(t, 1500);
    final list = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .hitTestable();
    if (list.evaluate().isNotEmpty) {
      await t.timedDrag(
        list.first,
        const Offset(0, -360),
        const Duration(milliseconds: 900),
      );
      await pause(t, 1500);
    }
    await back(t);
    await pause(t, 1500);
  });
}
