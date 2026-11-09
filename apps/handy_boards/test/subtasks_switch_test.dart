import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'kanban_app_test.dart';

void main() {
  testWidgets('one switch shows subtasks on cards, and says so', (t) async {
    final c = await boot(t, studyState());
    await tap(t, find.text('Semester 1').first);
    await settle(t);
    String look() => c.state!.get('boards', board).str('presentation');
    final before = look();
    await tap(t, find.byKey(const Key('board-more')));
    await menuTap(t, 'menu-presentation');
    await settle(t);
    expect(look(), before == 'detailed' ? 'compact' : 'detailed');
    await tap(t, find.byKey(const Key('board-more')));
    await t.scrollUntilVisible(
      find.byKey(const Key('menu-presentation')),
      120,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Show subtasks on cards'), findsOneWidget);
    expect(find.text('Show compact cards'), findsNothing);
  });
}
