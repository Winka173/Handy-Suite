import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';

ImportedBytes file(String name, String text) =>
    ImportedBytes(name, Uint8List.fromList(utf8.encode(text)));

Future<Docs> read(WidgetTester tester, {Docs? docs, Size? size}) async {
  final d = await start(tester, docs: docs, size: size ?? const Size(800, 900));
  await go(tester, '/read');
  return d;
}

String content(WidgetTester tester) {
  final w = tester.widget(find.byKey(const Key('reader-content')));
  return w is SelectableText ? (w.data ?? w.textSpan!.toPlainText()) : '';
}

void main() {
  testWidgets(
    'several files are all checked before any is kept; cancel and a failed save keep the library',
    (tester) async {
      final docs = await read(tester);
      docs.files.next = file('unsaved.txt', 'Unsaved original');
      await tapKey(tester, 'reader-import');
      expect(content(tester), 'Unsaved original');
      await back(tester);
      await tester.tap(find.byKey(const Key('confirm-cancel')));
      await tester.pumpAndSettle();
      expect(content(tester), 'Unsaved original');
      await back(tester);
      await tester.tap(find.text('Close it'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reader-content')), findsNothing);
      final good = file('one.md', '# One');
      docs.files.many = [
        good,
        ImportedBytes('bad.txt', Uint8List.fromList([255])),
      ];
      await menu(tester, 'reader-import-many');
      expect(docs.reader.text, isNull);
      docs.files.many = [good, file('two.txt', 'Two')];
      await menu(tester, 'reader-import-many');
      await tester.tap(find.byKey(const Key('confirm-cancel')));
      await tester.pumpAndSettle();
      expect(docs.reader.text, isNull);
      docs.reader.fail = true;
      await menu(tester, 'reader-import-many');
      await tester.tap(find.byKey(const Key('confirm-action')));
      await tester.pumpAndSettle();
      expect(docs.reader.text, isNull);
      docs.reader.fail = false;
      await menu(tester, 'reader-import-many');
      await tester.tap(find.byKey(const Key('confirm-action')));
      await tester.pumpAndSettle();
      final saved = ReaderLibrary.parse(docs.reader.text!);
      expect(saved.documents.map((d) => d.source), ['# One', 'Two']);
      expect(find.text('one.md'), findsOneWidget);
      expect(readReaderZip(readerZip(saved)).serialize(), saved.serialize());
      docs.files.many = [];
      final before = docs.reader.text;
      await menu(tester, 'reader-import-many');
      expect(docs.reader.text, before);
    },
  );

  testWidgets(
    'a file is kept only when saved; HTML reads safely, find is literal, names, stars and ZIPs keep the source',
    (tester) async {
      const source =
          '﻿<h1>Tiếng Việt</h1>\r\n<p>Find me &amp; hello</p><script>steal()</script><img src="https://private/">\r\n';
      final docs = await read(tester);
      docs.files.next = file('sample.html', source);
      await tapKey(tester, 'reader-import');
      expect(docs.reader.text, isNull);
      expect(find.textContaining('Unsaved import'), findsOneWidget);
      expect(content(tester), contains('Find me & hello'));
      expect(content(tester), isNot(contains('steal')));
      await tapKey(tester, 'reader-save');
      final saved = ReaderLibrary.parse(docs.reader.text!);
      expect(saved.documents.single.source, source);
      await menu(tester, 'reader-properties');
      await tester.enterText(
        find.byKey(const Key('reader-name')),
        'renamed.html',
      );
      await tester.enterText(find.byKey(const Key('reader-folder')), 'Work');
      await tester.tap(find.byKey(const Key('reader-properties-apply')));
      await tester.pumpAndSettle();
      final doc = ReaderLibrary.parse(docs.reader.text!).documents.single;
      expect((doc.name, doc.folder), ('renamed.html', 'Work'));
      await tapKey(tester, 'reader-favorite-${doc.id}');
      expect(
        ReaderLibrary.parse(docs.reader.text!).documents.single.favorite,
        isTrue,
      );
      await tester.enterText(find.byKey(const Key('reader-search')), 'hello');
      await tester.pumpAndSettle();
      expect(find.text('1 matches'), findsOneWidget);
      await menu(tester, 'reader-export');
      expect(docs.files.exported, utf8.encode(source));
      await back(tester);
      expect(find.text('renamed.html'), findsOneWidget);
      await menu(tester, 'reader-backup');
      final zip = docs.files.exported!;
      expect(readReaderZip(zip).documents.single.source, source);
      final before = docs.reader.text;
      docs.files.next = ImportedBytes('backup.zip', zip);
      await menu(tester, 'reader-restore');
      await tester.tap(find.byKey(const Key('confirm-cancel')));
      await tester.pumpAndSettle();
      expect(docs.reader.text, before);
      docs.files.next = ImportedBytes('bad.zip', Uint8List.fromList([1, 2]));
      await menu(tester, 'reader-restore');
      expect(docs.reader.text, before);
    },
  );

  testWidgets(
    'a failed save, a canceled or bad pick and a canceled export keep the document and library',
    (tester) async {
      final docs = await read(tester);
      docs.files.next = file('note.txt', 'Local note');
      await tapKey(tester, 'reader-import');
      docs.reader.fail = true;
      await tapKey(tester, 'reader-save');
      expect(docs.reader.text, isNull);
      expect(find.textContaining('Unsaved import'), findsOneWidget);
      docs.reader.fail = false;
      await tapKey(tester, 'reader-save');
      final before = docs.reader.text;
      docs.files.cancel = true;
      await menu(tester, 'reader-export');
      expect(docs.reader.text, before);
      expect(docs.files.exported, isNull);
      await back(tester);
      docs.files.next = null;
      await tapKey(tester, 'reader-import');
      expect(find.text('note.txt'), findsOneWidget);
      docs.files.next = ImportedBytes('bad.txt', Uint8List.fromList([255]));
      await tapKey(tester, 'reader-import');
      expect(docs.reader.text, before);
      await tester.pumpWidget(const SizedBox());
      await read(tester, docs: docs);
      expect(find.text('note.txt'), findsOneWidget);
      expect(
        ReaderLibrary.parse(docs.reader.text!).documents.single.source,
        'Local note',
      );
    },
  );

  testWidgets('wide screens show the library and the document together', (
    tester,
  ) async {
    final docs = Docs();
    docs.reader.text = ReaderLibrary([
      ReaderDocument.parse(
        ReaderDocument(
          id: 'doc-1',
          name: 'plan.md',
          kind: 'markdown',
          source: '# Plan\n\nStep one',
          createdAt: '2026-10-30T09:00:00.000Z',
          lastOpenedAt: '2026-10-30T09:00:00.000Z',
        ).toJson(),
      ),
    ]).serialize();
    await read(tester, docs: docs, size: const Size(1280, 800));
    expect(find.text('Pick a document to read'), findsOneWidget);
    await tapKey(tester, 'reader-open-doc-1');
    expect(find.text('Step one'), findsOneWidget);
    expect(find.byKey(const Key('reader-open-doc-1')), findsOneWidget);
  });
}
