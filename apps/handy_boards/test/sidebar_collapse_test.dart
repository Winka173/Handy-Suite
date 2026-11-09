import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'kanban_app_test.dart';

void main() {
  testWidgets('the wide sidebar folds away and comes back, remembered', (
    t,
  ) async {
    final c = await boot(t, studyState(), size: const Size(1280, 900));
    expect(find.byKey(const Key('boards-sidebar')), findsOneWidget);
    await tap(t, find.byKey(const Key('side-collapse')));
    await settle(t);
    expect(find.byKey(const Key('boards-sidebar')), findsNothing);
    expect(c.state!.preferences['sidebarCollapsed'], isTrue);
    await tap(t, find.byKey(const Key('side-open')));
    await settle(t);
    expect(find.byKey(const Key('boards-sidebar')), findsOneWidget);
    expect(c.state!.preferences['sidebarCollapsed'], isFalse);
  });
}
