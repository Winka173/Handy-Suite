import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:handy_docs/app.dart';
import 'package:handy_docs/settings_page.dart'
    show docsTools, docsWorkflowSteps;
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/export_history.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_workflow/handy_workflow.dart';
import '../test/helpers.dart' show back, go, menu, tapKey;
import '../test/workflow_test.dart' show WorkflowFiles;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native settings, document batch and export history reopen exactly',
    (tester) async {
      PreferencesRepository repo() => DevicePreferencesRepository(
        'handy-docs-parity-integration',
        knownTools: docsTools,
        workflowSteps: docsWorkflowSteps,
      );
      await repo().save(
        HandyPreferences(
          locale: 'en',
          theme: 'dark',
          drafts: {'md-source': 'PRIVATE_DRAFT'},
        ),
      );
      DocumentRepository reader() => localDocuments(
        'handy-docs-reader-batch-integration',
        maxBytes: 8000000,
      );
      await reader().save(ReaderLibrary([]).serialize());
      final markdown = localDocuments('handy-docs-export-history-integration');
      await markdown.save(serializeMarkdownDraft('# Native export'));
      final history = ExportHistory(
        'docs',
        documents: localDocuments(
          'handy-docs-history-parity-integration',
          maxBytes: 200000,
        ),
      );
      await history.clear();
      final files = WorkflowFiles();
      await tester.pumpWidget(
        DocsApp(
          files: files,
          preferences: repo(),
          documents: localDocuments('handy-docs-integration'),
          markdownDocuments: markdown,
          readerDocuments: reader(),
          history: history,
        ),
      );
      await tester.pumpAndSettle();

      // Settings file: saved inputs never leave, and survive an import.
      await tapKey(tester, 'open-settings');
      await tapKey(tester, 'settings-export');
      expect(files.output, isNot(contains('PRIVATE_DRAFT')));
      files.input = jsonEncode({
        'version': 1,
        'app': 'docs',
        'preferences': {
          'locale': 'en',
          'theme': 'light',
          'favorites': ['md-text'],
        },
        'recipes': [
          Recipe('Readable text', ['md-text']).toJson(),
        ],
      });
      await tapKey(tester, 'settings-import');
      await tester.tap(find.byKey(const Key('confirm-action')));
      await tester.pumpAndSettle();
      expect((await repo().load()).drafts, {'md-source': 'PRIVATE_DRAFT'});
      expect((await repo().load()).recipes.single.steps, ['md-text']);
      Future<void> snap(String name) async {
        if (!const bool.fromEnvironment('HANDY_SCREENSHOTS')) return;
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
        await binding.takeScreenshot(name);
      }

      await snap('docs-settings-backup');

      // Several documents are checked, then kept together.
      files.many = [
        ImportedBytes('First.md', Uint8List.fromList(utf8.encode('# First'))),
        ImportedBytes('Second.txt', Uint8List.fromList(utf8.encode('Second'))),
      ];
      await go(tester, '/read');
      await menu(tester, 'reader-import-many');
      await tester.tap(find.byKey(const Key('confirm-action')));
      await tester.pumpAndSettle();
      final library = ReaderLibrary.parse((await reader().load())!);
      expect(library.documents.map((d) => d.source), ['# First', 'Second']);
      expect(
        readReaderZip(readerZip(library)).serialize(),
        library.serialize(),
      );
      await snap('docs-document-batch');
      await back(tester);

      // A Markdown export is noted by checksum in the export history.
      await go(tester, '/write');
      await tapKey(tester, 'markdown-export');
      await tester.tap(find.byKey(const Key('markdown-export-md')));
      for (var i = 0; i < 150 && files.exported == null; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(files.exported, utf8.encode('# Native export'));
      expect((await history.load()).single.matches(files.exported!), isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
