import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/card/card_sheet.dart';
import 'package:handy_boards/board/board_page.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'kanban_app_test.dart';

void main() {
  testWidgets('a card opened to add a subtask is ready to type', (t) async {
    final c = await boot(t, studyState());
    await tap(t, find.text('Semester 1').first);
    await settle(t);
    final card = topTasks(c.state!, board: board).first;
    final ctx = t.element(find.byType(BoardPage));
    final scope = (t.widget(find.byType(BoardPage)) as BoardPage).scope;
    openCard(ctx, scope, card.id, addSubtask: true);
    await settle(t);
    final field = t.widget<TextField>(
      find.byKey(const Key('card-add-subtask')),
    );
    expect(field.focusNode!.hasFocus, isTrue);
    expect(find.byKey(const Key('card-subtasks')), findsOneWidget);
    await t.enterText(
      find.byKey(const Key('card-add-subtask')),
      'Read chapter 4',
    );
    await t.testTextInput.receiveAction(TextInputAction.done);
    await settle(t);
    expect(
      subtasksOf(c.state!, card.id).map((x) => x.str('title')),
      contains('Read chapter 4'),
    );
  });
}
