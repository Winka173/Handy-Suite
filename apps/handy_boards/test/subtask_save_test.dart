import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/board/board_page.dart';
import 'package:handy_boards/card/card_sheet.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'kanban_app_test.dart';

Future<BoardRecord> openOne(WidgetTester t, dynamic c) async {
  await tap(t, find.text('Semester 1').first);
  await settle(t);
  final card = topTasks(c.state!, board: board).first;
  final ctx = t.element(find.byType(BoardPage));
  final scope = (t.widget(find.byType(BoardPage)) as BoardPage).scope;
  openCard(ctx, scope, card.id, addSubtask: true);
  await settle(t);
  return card;
}

List<String> titles(dynamic c, String card) => [
  for (final x in subtasksOf(c.state!, card)) x.str('title'),
];

void main() {
  testWidgets('a typed subtask has an Add button', (t) async {
    final c = await boot(t, studyState());
    final card = await openOne(t, c);
    final field = find.byKey(const Key('card-add-subtask'));
    await t.ensureVisible(field);
    expect(find.byKey(const Key('card-add-subtask-save')), findsNothing);
    await t.enterText(field, 'Buy paper');
    await t.pump();
    await tap(t, find.byKey(const Key('card-add-subtask-save')));
    expect(titles(c, card.id), contains('Buy paper'));
  });

  testWidgets('Back with a subtask typed asks; Add keeps it and closes', (
    t,
  ) async {
    final c = await boot(t, studyState());
    final card = await openOne(t, c);
    final field = find.byKey(const Key('card-add-subtask'));
    await t.ensureVisible(field);
    await t.enterText(field, 'Print it');
    await t.pump();
    await t.binding.handlePopRoute();
    await settle(t);
    expect(find.byKey(const Key('subtask-leave-add')), findsOneWidget);
    await tap(t, find.byKey(const Key('subtask-leave-add')));
    await settle(t);
    expect(titles(c, card.id), contains('Print it'));
    expect(find.byKey(const Key('card-add-subtask')), findsNothing);
  });

  testWidgets('a sheet closed with a subtask typed keeps it and says so', (
    t,
  ) async {
    final c = await boot(t, studyState());
    final card = await openOne(t, c);
    final field = find.byKey(const Key('card-add-subtask'));
    await t.ensureVisible(field);
    await t.enterText(field, 'Bind it');
    await t.pump();
    // As a drag down does: the route goes without asking.
    Navigator.of(t.element(field)).pop();
    await settle(t);
    expect(titles(c, card.id), contains('Bind it'));
    expect(find.textContaining('Bind it'), findsOneWidget);
  });
}
