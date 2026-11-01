import 'dart:convert';
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
    'Docs uses real Markdown workflow and preserves preferences on failed save and recipe roundtrip',
    (tester) async {
      final docs = WorkflowDocs(), prefs = docs.prefs, files = docs.files;
      prefs.value = HandyPreferences(
        locale: 'en',
        theme: 'dark',
        favorites: ['md-text'],
      );
      await start(tester, docs: docs);
      await tapKey(tester, 'open-settings');
      await tapKey(tester, 'docs-text-workflows');
      Future<void> press(String label) async {
        final finder = find.text(label);
        if (finder.evaluate().isEmpty) {
          tester
              .state<ScrollableState>(find.byType(Scrollable).last)
              .position
              .jumpTo(0);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            finder,
            160,
            scrollable: find.byType(Scrollable).last,
          );
        }
        await Scrollable.ensureVisible(
          tester.element(finder.last),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        await tester.tap(finder.last);
        await tester.pumpAndSettle();
      }

      await tester.enterText(
        find.widgetWithText(TextField, 'Workflow name'),
        'Local text',
      );
      await press('Add step');
      const source = '# Title\n\n**Bold** and plain.';
      await tester.enterText(
        find.widgetWithText(TextField, 'Input text'),
        source,
      );
      await press('Run workflow');
      expect(find.text(parseMarkdownDocument(source).text), findsOneWidget);
      prefs.fail = true;
      await press('Save workflow');
      expect(prefs.value.recipes, isEmpty);
      prefs.fail = false;
      await press('Save workflow');
      expect(prefs.value.recipes.single.steps, ['md-text']);
      expect(prefs.value.theme, 'dark');
      expect(prefs.value.favorites, ['md-text']);
      await press('Export workflow');
      final exported = files.output!;
      expect(
        Recipe.fromJson(jsonDecode(exported)).toJson(),
        prefs.value.recipes.single.toJson(),
      );
      files.input = exported;
      await press('Import workflow');
      expect(find.byType(SelectableText), findsNothing);
      await press('Run workflow');
      expect(find.text(parseMarkdownDocument(source).text), findsOneWidget);
      files.input = Recipe('Foreign', ['jwt']).export();
      await press('Import workflow');
      expect(prefs.value.recipes.single.steps, ['md-text']);
    },
  );
}
