import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/insights/progress_calendar.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:pdf/pdf.dart' show TtfParser;
import 'run3_ui_test.dart' as host;

void main() {
  for (final locale in ['en', 'vi']) {
    testWidgets(
      'calendar text is covered by every bundled Nunito face $locale',
      (t) async {
        await host.boot(
          t,
          state: HabitState(
            habits: [
              Habit(
                id: 'reduce',
                title: 'Less',
                created: '2024-01-01',
                type: 'count',
                direction: 'reduce',
                schedules: [Schedule(id: 's', from: '2024-01-01')],
                negativeGoals: [
                  NegativeGoal(id: 'g', from: '2024-01-01', limit: 3000),
                ],
              ),
            ],
            settings: {'onboarded': true, 'locale': locale},
          ),
        );
        await host.go(t, '/progress');
        expect(find.byKey(const Key('calendar-unknown-mark')), findsWidgets);
        final strings = t
            .widgetList<Text>(
              find.descendant(
                of: find.byType(ProgressCalendar),
                matching: find.byType(Text),
              ),
            )
            .map((w) => w.data ?? w.textSpan!.toPlainText());
        for (final f in Directory(
          'fonts',
        ).listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
          final cmap = TtfParser(
            f.readAsBytesSync().buffer.asByteData(),
          ).charToGlyphIndexMap;
          expect(
            cmap[0x25cb] ?? 0,
            0,
            reason: 'regression fixture detects unsupported hollow circle',
          );
          for (final s in strings) {
            for (final rune in s.runes.where((r) => r > 32)) {
              expect(
                cmap[rune] ?? 0,
                isNot(0),
                reason: '${f.path}: U+${rune.toRadixString(16)} in $s',
              );
            }
          }
        }
        expect(t.takeException(), isNull);
      },
    );
  }
}
