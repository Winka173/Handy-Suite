import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'kanban_app_test.dart';

void main() {
  testWidgets('the column a card is held over lights up, and dims after', (
    t,
  ) async {
    final c = await boot(t, studyState(), size: const Size(1280, 900));
    await tap(t, find.text('Semester 1').first);
    await settle(t);
    final s = c.state!;
    final columns = columnsOf(s, board);
    final card = topTasks(s, board: board).firstWhere(
      (x) =>
          x.str('status') == columns.first.id &&
          find.byKey(ValueKey('card-${x.id}')).evaluate().isNotEmpty,
    );
    final next = find.byKey(ValueKey(columns[1].id));
    // The column's own container: the first one inside it.
    bool lit() {
      final w = t
          .widgetList<AnimatedContainer>(
            find.descendant(of: next, matching: find.byType(AnimatedContainer)),
          )
          .first;
      final border = (w.foregroundDecoration as BoxDecoration?)?.border;
      return border is Border && border.top.color != Colors.transparent;
    }

    expect(lit(), isFalse);
    final from = t.getCenter(find.byKey(ValueKey('card-${card.id}')).first);
    final g = await t.startGesture(from);
    await t.pump(const Duration(milliseconds: 600));
    await g.moveTo(t.getCenter(next) + const Offset(0, 40));
    await t.pump();
    await g.moveBy(const Offset(0, 10));
    await t.pump(const Duration(milliseconds: 300));
    expect(lit(), isTrue);
    await g.up();
    await settle(t);
    expect(lit(), isFalse);
  });
}
