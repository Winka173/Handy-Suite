import 'package:flutter_test/flutter_test.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_workflow/handy_workflow.dart';
import 'helpers.dart';

class WorkflowFiles extends Files {
  String? input, output;
  @override
  Future<ImportedText?> importText({
    int maxBytes = 1000000,
    CancellationToken? cancellation,
  }) async => input == null ? null : ImportedText('workflow.json', input!);
  @override
  Future<String?> exportText(
    String name,
    String text, {
    CancellationToken? cancellation,
  }) async {
    output = text;
    return 'saved';
  }
}

class WorkflowDocs extends Docs {
  @override
  final WorkflowFiles files = WorkflowFiles();
}

void main() {
  testWidgets(
    'text workflows left Docs; recipes saved before still load and are kept',
    (tester) async {
      final docs = WorkflowDocs(), prefs = docs.prefs;
      prefs.value = HandyPreferences(
        locale: 'en',
        theme: 'dark',
        recipes: [
          Recipe('Readable text', ['md-text']),
        ],
      );
      await start(tester, docs: docs);
      await tapKey(tester, 'open-settings');
      expect(find.byKey(const Key('docs-text-workflows')), findsNothing);
      // Any later save keeps the old recipe untouched.
      await tester.tap(find.text('Light').first);
      await tester.pumpAndSettle();
      expect(prefs.value.recipes.single.steps, ['md-text']);
      expect(
        parseMarkdownDocument('# Title\n\n**Bold**').text,
        isNot(contains('#')),
      );
    },
  );
}
