import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:handy_docs/app.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import '../test/helpers.dart' show Files, Prefs, back, go, menu, tapKey;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native reader preserves original source and reopens ZIP library',
    (tester) async {
      const source =
          '﻿<h1>Local document</h1>\r\n'
          '<p>Find this note &amp; keep the original.</p>'
          '<script>NEVER_EXECUTE()</script><img src="https://private.invalid/">';
      DocumentRepository store() =>
          localDocuments('handy-docs-reader-integration', maxBytes: 8000000);
      await store().save(ReaderLibrary([]).serialize());
      final files = Files()
        ..next = ImportedBytes(
          'Local document.html',
          Uint8List.fromList(utf8.encode(source)),
        );
      final prefs = Prefs()
        ..value = HandyPreferences(locale: 'en', theme: 'light');
      Future<void> show() async {
        await tester.pumpWidget(
          DocsApp(
            files: files,
            preferences: prefs,
            readerDocuments: store(),
            documents: localDocuments('handy-docs-integration'),
            markdownDocuments: localDocuments(
              'handy-docs-markdown-integration',
            ),
          ),
        );
        await tester.pumpAndSettle();
        await go(tester, '/read');
      }

      String content() {
        final w = tester.widget<SelectableText>(
          find.byKey(const Key('reader-content')),
        );
        return w.data ?? w.textSpan!.toPlainText();
      }

      await show();
      await tapKey(tester, 'reader-import');
      expect(ReaderLibrary.parse((await store().load())!).documents, isEmpty);
      await tapKey(tester, 'reader-save');
      final saved = ReaderLibrary.parse((await store().load())!);
      expect(saved.documents.single.source, source);
      expect(content(), contains('Find this note & keep the original.'));
      expect(content(), isNot(contains('NEVER_EXECUTE')));
      await tester.enterText(find.byKey(const Key('reader-search')), 'note');
      await tester.pumpAndSettle();
      expect(find.text('1 matches'), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('HANDY_SCREENSHOTS')) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot('docs-reader-safe-html');
      }
      await menu(tester, 'reader-export');
      expect(files.exported, utf8.encode(source));
      if (find.text('Read').hitTestable().evaluate().isEmpty) {
        // A narrow window: the document sits over the library.
        await back(tester);
      }
      await menu(tester, 'reader-backup');
      final backup = Uint8List.fromList(files.exported!);
      expect(readReaderZip(backup).serialize(), saved.serialize());
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await show();
      expect(find.text('Local document.html'), findsWidgets);
      await store().save(ReaderLibrary([]).serialize());
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await show();
      files.next = ImportedBytes('reader.zip', backup);
      await menu(tester, 'reader-restore');
      await tester.tap(find.byKey(const Key('confirm-action')));
      await tester.pumpAndSettle();
      expect(
        ReaderLibrary.parse((await store().load())!).serialize(),
        saved.serialize(),
      );
      expect(find.text('Local document.html'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
