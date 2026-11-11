import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'ui_test.dart';

void main() {
  testWidgets('a quick start opens the filled editor; its reminder is saved', (
    tester,
  ) async {
    final c = await start(tester);
    await tapKey(tester, 'today-add-habit');
    expect(find.byKey(const Key('quick-add')), findsOneWidget);
    await tapKey(tester, 'quick-add-walk');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('field-title')))
          .controller!
          .text,
      'Walk',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('field-remind')),
      200,
      scrollable: find
          .ancestor(
            of: find.byKey(const Key('field-title')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tapKey(tester, 'field-remind');
    expect(find.byKey(const Key('field-remindAt')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('editor-save')));
    await tapKey(tester, 'editor-save');
    // Reminders ask for permission first, after saying why.
    final allow = find.widgetWithText(FilledButton, 'Continue');
    if (allow.evaluate().isNotEmpty) {
      await tester.tap(allow);
      await tester.pumpAndSettle();
    }
    final h = c.state!.habits.single;
    expect(h.title, 'Walk');
    final rules = (c.state!.settings['reminders'] as List).cast<Map>();
    expect(rules.single['target'], h.id);
    expect(rules.single['time'], '08:00');
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('a typed name goes straight to the editor; nothing saved yet', (
    tester,
  ) async {
    final c = await start(tester);
    await tapKey(tester, 'today-add-habit');
    await tester.enterText(find.byKey(const Key('quick-add-name')), 'Floss');
    await tester.pump();
    await tapKey(tester, 'quick-add-next');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('field-title')))
          .controller!
          .text,
      'Floss',
    );
    expect(c.state!.habits, isEmpty);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
