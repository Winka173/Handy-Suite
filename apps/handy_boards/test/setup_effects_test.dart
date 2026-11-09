import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/board/board_page.dart';
import 'package:handy_boards/create/setup_page.dart';
import 'package:handy_boards/pro/pro.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'kanban_app_test.dart';

void main() {
  testWidgets('every field of every template says what it puts on the board', (
    t,
  ) async {
    debugProOverride = true;
    addTearDown(() => debugProOverride = null);
    await boot(t, studyState());
    await tap(t, find.text('Semester 1').first);
    await settle(t);
    final scope = (t.widget(find.byType(BoardPage)) as BoardPage).scope;
    final nav = Navigator.of(t.element(find.byType(BoardPage)));
    for (final template in boardTemplates) {
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => SetupPage(scope: scope, template: template),
        ),
      );
      await settle(t);
      for (final f in template.fields) {
        final effect = find.byKey(Key('setup-effect-${f.id}'));
        await t.scrollUntilVisible(
          effect,
          200,
          scrollable: find.byType(Scrollable).last,
        );
        expect(effect, findsOneWidget, reason: '${template.id}/${f.id}');
      }
      expect(t.takeException(), isNull, reason: template.id);
      nav.pop();
      await settle(t);
    }
  });
}
