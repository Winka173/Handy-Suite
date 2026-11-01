import 'package:flutter_test/flutter_test.dart';
import 'package:handy_docs/session.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';
import 'session_test.dart' show samplePng;

/// A desk with something of everything: two scanned pages, a draft and a
/// starred document in a folder.
Docs busyDesk({String theme = 'light', String locale = 'vi'}) {
  final docs = Docs();
  docs.prefs.value = HandyPreferences(locale: locale, theme: theme);
  docs.scan.text = ScanSession([
    ScanPage('a', 'Hóa đơn điện tháng 10.jpg', samplePng()),
    ScanPage('b', 'Trang 2.jpg', samplePng()),
  ]).serialize();
  docs.markdown.text = serializeMarkdownDraft(
    '# Biên bản họp nhóm\n\nNgày 30/10: chốt lịch giao hàng và phân việc cho tuần tới.',
  );
  docs.reader.text = ReaderLibrary([
    ReaderDocument.parse(
      ReaderDocument(
        id: 'doc-1',
        name: 'Hướng dẫn sử dụng máy giặt.md',
        kind: 'markdown',
        folder: 'Nhà',
        favorite: true,
        source: '# Máy giặt\n\nChọn chế độ rồi bấm Bắt đầu.',
        createdAt: '2026-10-30T09:00:00.000Z',
        lastOpenedAt: '2026-10-31T09:00:00.000Z',
      ).toJson(),
    ),
  ]).serialize();
  return docs;
}

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

void main() {
  testWidgets('the desk shows unfinished work and opens each place', (
    tester,
  ) async {
    await start(tester, docs: busyDesk(locale: 'en'));
    expect(find.text('On the desk'), findsOneWidget);
    expect(find.byKey(const Key('desk-work-scan')), findsOneWidget);
    expect(find.text('2 pages · make the PDF'), findsOneWidget);
    expect(find.byKey(const Key('desk-work-write')), findsOneWidget);
    expect(find.byKey(const Key('desk-recent-doc-1')), findsOneWidget);
    await tapKey(tester, 'desk-work-scan');
    expect(find.text('1. Hóa đơn điện tháng 10.jpg'), findsOneWidget);
    await back(tester);
    for (final (key, sign) in [
      ('desk-write', 'markdown-source'),
      ('desk-pdf', 'pdf-import'),
      ('desk-read', 'reader-import'),
      ('desk-scan', 'scan-import'),
    ]) {
      await tapKey(tester, key);
      expect(find.byKey(Key(sign)), findsOneWidget, reason: key);
      await back(tester);
    }
    await tapKey(tester, 'desk-recent-doc-1');
    expect(
      find.text('Chọn chế độ rồi bấm Bắt đầu.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('an empty desk says so and offers the four starts', (
    tester,
  ) async {
    await start(tester);
    expect(find.text('Nothing on the desk'), findsOneWidget);
    expect(find.byKey(const Key('desk-work-scan')), findsNothing);
    for (final k in ['desk-scan', 'desk-write', 'desk-pdf', 'desk-read']) {
      expect(find.byKey(Key(k)), findsOneWidget);
    }
  });

  for (final theme in ['light', 'dark']) {
    testWidgets('every place meets the guidelines ($theme)', (tester) async {
      final handle = tester.ensureSemantics();
      await start(tester, docs: busyDesk(theme: theme));
      await meetsAll(tester, 'desk');
      for (final place in ['/scan', '/write', '/pdf', '/read', '/settings']) {
        await go(tester, place);
        await meetsAll(tester, place);
        await back(tester);
      }
      handle.dispose();
    });
  }

  for (final size in [const Size(320, 640), const Size(1440, 900)]) {
    testWidgets('nothing overflows at ${size.width.toInt()} px', (
      tester,
    ) async {
      await start(tester, docs: busyDesk(), size: size);
      expect(tester.takeException(), isNull);
      for (final place in ['/scan', '/write', '/pdf', '/read', '/settings']) {
        await go(tester, place);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: place);
        await back(tester);
      }
    });
  }
}
