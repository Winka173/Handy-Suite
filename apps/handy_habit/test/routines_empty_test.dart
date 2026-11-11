import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'run3_ui_test.dart' as host;
import 'run4_routines_test.dart' show tap;

void main() {
  testWidgets('empty Routines shows the starters it points to', (t) async {
    await host.boot(t, state: HabitState(settings: {'onboarded': true}));
    await host.go(t, '/routines');
    final first = routineTemplateCatalog.first;
    expect(find.byKey(Key('routine-starter-${first.id}')), findsOneWidget);
    expect(find.byKey(const Key('routine-starters-all')), findsOneWidget);
    await tap(t, 'routine-starter-${first.id}');
    expect(host.route(t), '/templates/${first.id}');
  });
}
