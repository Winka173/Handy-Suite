import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/ui/form.dart';
import 'package:handy_ui/kit.dart';

void main() {
  testWidgets(
    'collapsed settings keep legacy choice and edited text through a failed save',
    (t) async {
      Map<String, dynamic>? saved;
      var fail = true;
      await t.pumpWidget(
        MaterialApp(
          theme: buildHandyTheme(const Color(0xffb42318), Brightness.light),
          home: Scaffold(
            body: HabitForm(
              title: 'Habit',
              fields: const [
                HabitField(
                  'schedule',
                  'How often',
                  'Lịch',
                  kind: FieldKind.choice,
                  options: {'daily': 'Daily', 'interval': 'Interval'},
                  advancedOptions: {'interval'},
                ),
                HabitField(
                  'note',
                  'Note',
                  'Ghi chú',
                  advanced: true,
                  required: false,
                ),
              ],
              initial: {'schedule': 'interval', 'note': 'Existing note'},
              save: (value) async {
                if (fail) throw StateError('full');
                saved = value;
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const Key('field-schedule-interval')), findsOneWidget);
      expect(find.byKey(const Key('field-note')), findsNothing);
      await t.tap(find.byKey(const Key('habit-form-advanced')));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const Key('field-note')),
        'Retained after collapse',
      );
      await t.tap(find.byKey(const Key('habit-form-advanced')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('editor-save')));
      await t.pumpAndSettle();
      expect(saved, isNull);
      expect(find.textContaining('Nothing changed.'), findsOneWidget);
      fail = false;
      await t.tap(find.byKey(const Key('editor-save')));
      await t.pumpAndSettle();
      expect(saved, {
        'schedule': 'interval',
        'note': 'Retained after collapse',
      });
    },
  );
}
