import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/design/identity.dart';
import 'package:handy_habit/design/palette.dart';
import 'package:handy_habit/design/theme.dart';
import 'package:handy_habit/habits/habit_appearance.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
}

void main() {
  for (final brightness in Brightness.values) {
    final p = brightness == Brightness.dark
        ? HabitPalette.dark
        : HabitPalette.light;
    test(
      '$brightness Habit text, actions, selection and controls contrast',
      () {
        for (final surface in [
          p.canvas,
          p.surface,
          p.raised,
          p.tint,
          p.ochreField,
        ]) {
          for (final ink in [p.ink, p.muted]) {
            expect(
              contrast(ink, surface),
              greaterThanOrEqualTo(4.5),
              reason: '$ink on $surface',
            );
          }
        }
        for (final pair in [
          (p.anchor, p.canvas),
          (p.onAnchor, p.anchor),
          (p.vermilion, p.canvas),
          (p.vermilion, p.surface),
          (p.vermilion, p.tint),
          (p.onVermilion, p.vermilion),
          (p.ochre, p.canvas),
          (p.ochre, p.ochreField),
        ]) {
          expect(
            contrast(pair.$1, pair.$2),
            greaterThanOrEqualTo(4.5),
            reason: '$pair',
          );
        }
        for (final surface in [p.canvas, p.surface]) {
          expect(contrast(p.control, surface), greaterThanOrEqualTo(3));
          for (final saved in habitColors) {
            final ink = habitInk(saved.$1, surface);
            expect(contrast(ink, surface), greaterThanOrEqualTo(4.5));
            final check = ink.computeLuminance() > .179
                ? Colors.black
                : Colors.white;
            expect(contrast(check, ink), greaterThanOrEqualTo(4.5));
          }
        }
        // Dark brand hue stays orange-red rather than the kit's pink seed tone.
        expect(HSLColor.fromColor(p.vermilion).hue, lessThan(20));
      },
    );

    test('$brightness Nunito and Habit actions reach component themes', () {
      final theme = habitTheme(
        buildHandyTheme(const Color(0xffb42318), brightness, habitIdentity),
      );
      for (final style in [
        theme.textTheme.headlineMedium,
        theme.textTheme.headlineSmall,
        theme.textTheme.titleLarge,
        theme.textTheme.titleMedium,
        theme.textTheme.bodyLarge,
        theme.textTheme.bodyMedium,
        theme.textTheme.bodySmall,
        theme.textTheme.labelLarge,
        theme.textTheme.labelMedium,
        theme.textTheme.labelSmall,
        theme.appBarTheme.titleTextStyle,
        theme.filledButtonTheme.style!.textStyle!.resolve({}),
      ]) {
        expect(style!.fontFamily, 'Nunito');
      }
      expect(
        theme.filledButtonTheme.style!.backgroundColor!.resolve({}),
        p.anchor,
      );
      expect(
        theme.filledButtonTheme.style!.foregroundColor!.resolve({}),
        p.onAnchor,
      );
      expect(theme.chipTheme.selectedColor, p.tint);
    });
  }

  testWidgets('legacy identities are dots, saved appearance keeps its hue', (
    t,
  ) async {
    final legacy = Habit(
      id: 'legacy',
      title: 'Read',
      created: '2026-11-01',
      schedules: [Schedule(id: 's', from: '2026-11-01')],
    );
    final chosen = legacy.copy({
      'icon': Icons.menu_book_outlined.codePoint,
      'color': 0xffb42318,
    });
    expect(hasHabitIcon(legacy), isFalse);
    expect(hasHabitIcon(legacy.copy({'icon': 1})), isFalse);
    expect(hasHabitIcon(chosen), isTrue);
    for (final brightness in Brightness.values) {
      final theme = habitTheme(
        buildHandyTheme(const Color(0xffb42318), brightness, habitIdentity),
      );
      await t.pumpWidget(
        MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: theme,
          home: Builder(
            builder: (context) {
              expect(
                habitMark(context, legacy),
                isNot(habitInk(legacy.color, theme.colorScheme.surface)),
              );
              expect(
                contrast(habitMark(context, chosen), theme.colorScheme.surface),
                greaterThanOrEqualTo(4.5),
              );
              return const SizedBox();
            },
          ),
        ),
      );
    }
  });
}
