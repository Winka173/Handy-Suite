import 'dart:convert';
import 'dart:typed_data';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:test/test.dart';

Routine routine() => Routine(
  id: 'mine',
  title: 'Morning <easy>',
  note: 'Before work',
  steps: [
    RoutineStep(id: 'a', title: 'Water', seconds: 60, habit: 'h1'),
    RoutineStep(id: 'b', title: 'Stretch', seconds: 300),
  ],
);

void main() {
  test(
    'a shared page reads in a browser and comes back without habit links',
    () {
      final page = sharedRoutinePage(routine(), vietnamese: false);
      expect(page, contains('<h1>Morning &lt;easy&gt;</h1>'));
      expect(page, contains('Stretch'));
      final bytes = Uint8List.fromList(utf8.encode(page));
      expect(isSharedRoutine(bytes), isTrue);
      final back = readSharedRoutine(bytes);
      expect(back.id, isNot('mine'));
      expect(back.title, 'Morning <easy>');
      expect(back.steps.map((s) => s.title), ['Water', 'Stretch']);
      expect(back.steps.every((s) => s.habit == null), isTrue);
      expect(back.planned, 360);
    },
  );

  test('pages that are not a routine, or are broken, are refused', () {
    expect(
      () => readSharedRoutine(Uint8List.fromList(utf8.encode('<html></html>'))),
      throwsFormatException,
    );
    final broken = '<!-- ${sharedRoutineMarker}e30 -->';
    expect(
      () => readSharedRoutine(Uint8List.fromList(utf8.encode(broken))),
      throwsFormatException,
    );
  });
}
