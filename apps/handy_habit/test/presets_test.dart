import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import 'ui_test.dart' show start, tapKey;

void main() {
  test('32 habit presets in 8 groups, 8 routines', () {
    expect(habitPresets, hasLength(32));
    expect(habitPresets.map((p) => p.id).toSet(), hasLength(32));
    for (final g in habitPresetGroups.keys) {
      expect(habitPresets.where((p) => p.group == g), hasLength(4), reason: g);
    }
    expect(routineTemplates(), hasLength(8));
    expect(routineTemplates(vietnamese: true), hasLength(8));
  });

  testWidgets('a preset fills the editor; the person saves it', (tester) async {
    final c = await start(tester);
    await tapKey(tester, 'habit-add');
    await tapKey(tester, 'add-habit');
    await tapKey(tester, 'preset-read');
    expect(find.text('Read'), findsWidgets);
    await tapKey(tester, 'editor-save');
    final h = c.state!.habits.single;
    expect(h.title, 'Read');
    expect(h.type, 'quantity');
    expect(h.unit, 'pages');
    expect(h.schedules.single.target, 10000);
    expect(h.category, 'Study');
    // A preset already used is not offered again.
    await tapKey(tester, 'habit-add');
    await tapKey(tester, 'add-habit');
    expect(find.byKey(const Key('preset-read')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
