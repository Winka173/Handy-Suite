import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import 'ui_test.dart' show start, tapKey;

void main() {
  test('catalog preserves at least 32 habits and 8 routines', () {
    expect(habitPresets, hasLength(44));
    expect(habitPresets.map((p) => p.id).toSet(), hasLength(44));
    for (final g in habitPresetGroups.keys) {
      expect(habitPresets.where((p) => p.group == g), isNotEmpty, reason: g);
    }
    expect(routineTemplates(), hasLength(11));
    expect(routineTemplates(vietnamese: true), hasLength(11));
  });

  testWidgets('a preset fills the editor; the person saves it', (tester) async {
    final c = await start(tester);
    await tapKey(tester, 'today-add-habit');
    await tester.enterText(find.byKey(const Key('template-search')), 'read');
    await tester.pumpAndSettle();
    await tapKey(tester, 'preset-read');
    await tapKey(tester, 'template-customise');
    expect(find.text('Read'), findsWidgets);
    await tapKey(tester, 'editor-save');
    final h = c.state!.habits.single;
    expect(h.title, 'Read');
    expect(h.type, 'quantity');
    expect(h.unit, 'pages');
    expect(h.schedules.single.target, 10000);
    expect(h.category, 'Reading');
    // A used template can create a separate copy; preview itself never saves.
    await tapKey(tester, 'today-new');
    await tester.enterText(find.byKey(const Key('template-search')), 'read');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('preset-read')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
