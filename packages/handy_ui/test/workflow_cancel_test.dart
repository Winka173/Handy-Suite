import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/handy_ui.dart';
import 'package:handy_ui/workflows.dart';
import 'package:handy_workflow/handy_workflow.dart';

void main() {
  testWidgets(
    'cancel stops before following step and never exposes a partial export',
    (tester) async {
      final pending = Completer<String>();
      var laterCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SharedWorkflowPage(
              preferences: HandyPreferences(),
              onSave: (_) async {},
              files: const SystemHandyFiles(),
              registry: {
                'first': WorkflowStep(
                  'first',
                  'text/plain',
                  'text/plain',
                  (_) => pending.future,
                ),
                'second': WorkflowStep('second', 'text/plain', 'text/plain', (
                  s,
                ) async {
                  laterCalls++;
                  return s;
                }),
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Workflow name'),
        'Cancelable',
      );
      await tester.tap(find.text('Add step'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('second').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add step'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Input text'),
        'Original input',
      );
      await tester.scrollUntilVisible(
        find.text('Run workflow'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Run workflow'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.scrollUntilVisible(
        find.byKey(const Key('workflow-cancel')),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('workflow-cancel'))),
        alignment: .5,
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('workflow-cancel')));
      pending.complete('Partial result must not export');
      await tester.pumpAndSettle();
      expect(laterCalls, 0);
      expect(find.text('Export result'), findsNothing);
      expect(find.text('Workflow canceled'), findsOneWidget);
      expect(find.text('Original input'), findsOneWidget);
    },
  );
}
