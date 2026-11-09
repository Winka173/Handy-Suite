import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'kanban_app_test.dart';

void main() {
  testWidgets(
    'key dates save while the keyboard closes (no disposed field is read)',
    (t) async {
      var s = studyState();
      s = setMilestones(s, board, [
        (label: 'Key date', day: DateTime(2026, 11, 9), minute: null),
        (label: 'Key date', day: DateTime(2026, 11, 28), minute: null),
      ]);
      await boot(t, s);
      await tap(t, find.text('Semester 1').first);
      await settle(t);
      await tap(t, find.byKey(const Key('key-date-Key date')));
      await settle(t);
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      await t.pump();
      await t.tap(find.byKey(const Key('key-date-save')));
      await t.pump();
      t.view.viewInsets = FakeViewPadding.zero;
      await t.pump(const Duration(milliseconds: 16));
      await t.pump(const Duration(milliseconds: 100));
      await settle(t);
      expect(t.takeException(), isNull);
    },
  );
}
