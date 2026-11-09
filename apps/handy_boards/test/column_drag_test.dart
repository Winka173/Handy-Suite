import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'kanban_app_test.dart';

void main() {
  testWidgets('a column held by its header moves to where it is dropped', (
    t,
  ) async {
    final c = await boot(t, studyState(), size: const Size(1280, 900));
    await tap(t, find.text('Semester 1').first);
    await settle(t);
    final before = columnsOf(c.state!, board);
    final first = before.first, last = before.last;
    final header = find.descendant(
      of: find.byKey(ValueKey(first.id)),
      matching: find.text(first.str('title')),
    );
    final g = await t.startGesture(t.getCenter(header.first));
    await t.pump(const Duration(milliseconds: 600));
    await g.moveTo(t.getCenter(find.byKey(ValueKey(last.id))));
    await t.pump();
    await g.moveBy(const Offset(0, 10));
    await t.pump(const Duration(milliseconds: 200));
    await g.up();
    await settle(t);
    final after = columnsOf(c.state!, board).map((x) => x.id).toList();
    expect(after.last, first.id);
    expect(after.length, before.length);
    expect(after.first, before[1].id);
  });
}
