import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/pro/export/export_doc.dart';
import 'package:handy_bookmark/pro/export/render_html.dart';
import 'package:handy_bookmark/pro/export/render_pdf.dart';
import 'package:handy_bookmark/pro/export/export_studio.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'widget_test.dart' show start;

List<ExportItem> _items(int n) => [
  for (var i = 0; i < n; i++)
    ExportItem(
      title: i == 0
          ? 'Mùa đẹp nhất để đi Hà Giang <script>alert(1)</script>'
          : 'Bài số $i: ăn gì ở Đà Nẵng',
      source: 'vnexpress.net',
      date: '2026-11-0${1 + i % 9}',
      url: i == 1
          ? safeLink('javascript:alert(1)')
          : 'https://vnexpress.net/$i',
      note: 'Ghi chú riêng $i',
      description: 'Mô tả ngắn $i',
      image: i.isEven
          ? File(
              'assets/welcome/${const ['pho', 'hoi-an', 'guitars'][i % 3]}.jpg',
            ).readAsBytesSync()
          : null,
    ),
];

void main() {
  test('HTML escapes text, links only web addresses, and keeps notes out '
      'unless asked', () {
    for (final t in exportTemplates) {
      final html = renderExportHtml(
        t,
        const ExportOptions(title: 'Đi <b>chơi</b>'),
        _items(4),
      );
      expect(html, startsWith('<!doctype html>'), reason: t.id);
      expect(html, isNot(contains('<script>')), reason: t.id);
      expect(html, isNot(contains('javascript:')), reason: t.id);
      expect(html, contains('Đi &lt;b&gt;chơi&lt;&#47;b&gt;'), reason: t.id);
      expect(
        html,
        isNot(contains('Ghi chú riêng')),
        reason: '${t.id} notes off',
      );
      expect(
        html,
        isNot(contains('http://fonts')),
        reason: '${t.id} no remote fonts',
      );
      final withNotes = renderExportHtml(
        t,
        const ExportOptions(title: 'x', notes: true),
        _items(2),
      );
      if (t.showsNotes)
        expect(withNotes, contains('Ghi chú riêng'), reason: t.id);
    }
  });

  test(
    'every template makes a real, multi-page PDF with embedded fonts',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final fonts = await loadExportFonts();
      for (final t in exportTemplates) {
        final bytes = await renderExportPdf(
          t,
          const ExportOptions(title: 'Hà Giang'),
          _items(14),
          fonts,
        );
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-', reason: t.id);
        final text = String.fromCharCodes(bytes);
        expect(
          RegExp('/Type\\s*/Page[^s]').allMatches(text).length,
          greaterThan(1),
          reason: '${t.id} pages',
        );
        expect(text, contains('FontFile2'), reason: '${t.id} embedded font');
      }
    },
  );

  test('sample exports for the report (fixture data, guide photos)', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Platform.environment['EXPORT_SAMPLES'];
    if (dir == null) return;
    Directory(dir).createSync(recursive: true);
    final fonts = await loadExportFonts();
    const o = ExportOptions(
      title: 'Hà Giang mùa hoa',
      subtitle: 'Một bộ sưu tập mẫu',
    );
    final items = _items(9);
    File('$dir/magazine.html').writeAsStringSync(
      renderExportHtml(
        exportTemplateById('magazine')!,
        o,
        items,
        lang: 'vi',
        serifFont: File('fonts/Newsreader-SemiBold.ttf').readAsBytesSync(),
      ),
    );
    File('$dir/travel.html').writeAsStringSync(
      renderExportHtml(
        exportTemplateById('travel')!,
        o,
        items,
        lang: 'vi',
        serifFont: File('fonts/Newsreader-SemiBold.ttf').readAsBytesSync(),
      ),
    );
    File('$dir/bibliography.pdf').writeAsBytesSync(
      await renderExportPdf(
        exportTemplateById('bibliography')!,
        o,
        items,
        fonts,
      ),
    );
    File('$dir/moodboard.pdf').writeAsBytesSync(
      await renderExportPdf(exportTemplateById('moodboard')!, o, items, fonts),
    );
  });

  testWidgets('Free opens Export Studio and Export leads to Explore Pro', (
    t,
  ) async {
    // No PDFium on the host: the preview says so.
    ExportStudio.rasterize = (_) async => throw UnsupportedError('host');
    await start(
      t,
      seed: (c) async {
        await c.update(
          (l) => l.copyWith(
            collections: [SaveCollection(id: 'food', name: 'Food')],
          ),
        );
        await c.quickSave('https://a.com/x', title: 'Phở');
        await c.update(
          (l) => l.copyWith(
            bookmarks: [
              for (final b in l.bookmarks) b.copyWith(collectionId: 'food'),
            ],
          ),
        );
      },
    );
    Navigator.of(
      t.element(find.byType(Scaffold).first),
    ).pushNamed('/export/food');
    for (var i = 0; i < 6; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(find.byKey(const Key('export-studio')), findsOneWidget);
    expect(find.byKey(const Key('export-quick')), findsOneWidget);
    expect(find.byKey(const Key('export-preview-unavailable')), findsOneWidget);
    expect(find.text('Export with Pro'), findsOneWidget);
    await t.tap(find.byKey(const Key('export-go')));
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(find.byKey(const Key('explore-pro')), findsOneWidget);
  });
}
