import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_habit/habits/habit_appearance.dart';
import 'package:handy_habit/routines/routine_view.dart';
import 'ui_test.dart' show start, seeded, tapKey;

void main() {
  testWidgets(
    'routine appearance preserves steps, weekdays, habit links and history through Undo',
    (t) async {
      final c = await start(t, state: seeded(), tab: 2);
      final before = c.state!.routines.single.toJson();
      final habits = c.state!.habits.map((h) => h.toJson()).toList();
      final sessions = c.state!.sessions.map((s) => s.toJson()).toList();
      await tapKey(t, 'routine-r');
      await t.tap(
        find.descendant(
          of: find.byType(RoutineMenu),
          matching: find.byType(HandyMenuButton),
        ),
      );
      await t.pumpAndSettle();
      await tapKey(t, 'routine-appearance');
      await tapKey(t, 'habit-icon-3');
      await tapKey(t, 'habit-color-4');
      await tapKey(t, 'habit-appearance-save');
      final after = c.state!.routines.single.toJson();
      expect(after['icon'], habitIcons[3].codePoint);
      expect(after['color'], habitColors[4].$1);
      expect(
        {...after}
          ..remove('icon')
          ..remove('color'),
        {...before}
          ..remove('icon')
          ..remove('color'),
      );
      expect(c.state!.habits.map((h) => h.toJson()).toList(), habits);
      expect(c.state!.sessions.map((s) => s.toJson()).toList(), sessions);
      await c.undo();
      expect(c.state!.routines.single.toJson(), before);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
  test(
    'saved color stays legible on light/dark without mutating stored value',
    () {
      for (final saved in [
        0xffffffff,
        0xff000000,
        ...habitColors.map((c) => c.$1),
      ]) {
        for (final background in [Colors.white, const Color(0xff111111)]) {
          final a = habitInk(saved, background).computeLuminance();
          final b = background.computeLuminance();
          final ratio = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
          expect(ratio, greaterThanOrEqualTo(4.5));
        }
      }
    },
  );

  for (final save in [true, false]) {
    testWidgets(
      'appearance ${save ? 'save and Undo' : 'cancel'} preserves schedules and linked routine',
      (t) async {
        final c = await start(t, state: seeded());
        final before = c.state!.habits.single.toJson();
        final routine = c.state!.routines.single.toJson();
        await tapKey(t, 'habit-h');
        await t.tap(find.byType(HandyMenuButton).first);
        await t.pumpAndSettle();
        await tapKey(t, 'habit-appearance');
        await tapKey(t, 'habit-icon-2');
        await tapKey(t, 'habit-color-1');
        if (save) {
          await tapKey(t, 'habit-appearance-save');
          final after = c.state!.habits.single.toJson();
          expect(after['icon'], habitIcons[2].codePoint);
          expect(after['color'], habitColors[1].$1);
          expect(
            {...after}
              ..remove('icon')
              ..remove('color'),
            {...before}
              ..remove('icon')
              ..remove('color'),
          );
          expect(c.state!.routines.single.toJson(), routine);
          await c.undo();
          expect(c.state!.habits.single.toJson(), before);
        } else {
          await t.tap(find.text('Cancel').last);
          await t.pumpAndSettle();
          expect(c.state!.habits.single.toJson(), before);
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        c.dispose();
      },
    );
  }
}
