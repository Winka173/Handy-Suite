import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';

final now = DateTime(2026, 11, 9, 9);
const board = 'b0000000-0000-4000-8000-000000000011';

BoardsState make(String id, [TemplateAnswers extra = const {}]) {
  final t = templateById(id)!;
  return createFromTemplate(
    BoardsState(preferences: {'locale': 'vi'}),
    t,
    vi: true,
    answers: {
      ...defaultAnswers(t, vi: true, now: now),
      ...extra,
    },
    now: now,
    boardId: board,
  );
}

void main() {
  test('every suggested field is a valid field of a real template', () {
    for (final t in boardTemplates) {
      for (final f in templateCardFields(t.id)) {
        expect(fieldTypes, contains(f.type), reason: t.id);
        if (f.type == 'single') expect(f.options, isNotEmpty, reason: t.id);
      }
    }
  });

  test('a board from a template starts with its suggested fields, in the '
      "person's language, marked as the template's", () {
    final s = make('trip');
    final fields = fieldsOf(s, board);
    expect(fields.map((f) => f.str('title')), [
      'Chi phí',
      'Link đặt chỗ',
      'Đã đặt',
      'Địa chỉ',
    ]);
    expect(fields.every((f) => f.flag('template')), isTrue);
    expect(fields.first.flag('onCard'), isTrue);
    s.validate();
  });

  test('fields unticked in the Smart Setup are left out', () {
    final s = make('trip', {
      cardFieldsKey: [0, 2],
    });
    expect(fieldsOf(s, board).map((f) => f.str('title')), [
      'Chi phí',
      'Đã đặt',
    ]);
  });

  test('a template with no suggestions starts with no fields', () {
    expect(templateCardFields('daily'), isEmpty);
    expect(fieldsOf(make('daily'), board), isEmpty);
  });
}
