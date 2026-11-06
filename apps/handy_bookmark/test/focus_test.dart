import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'new_flows_test.dart' show boot, settle;
import 'widget_test.dart' show tapKey;

Future<void> openFocus(WidgetTester t) async {
  Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/focus');
  await settle(t);
}

void main() {
  testWidgets('swiping right marks the oldest read; Undo brings it back', (
    t,
  ) async {
    final (c, _) = await boot(t);
    await openFocus(t);
    expect(find.text('3 to go'), findsOneWidget);
    final oldest = c.library!.bookmarks.reduce(
      (a, b) => a.savedAt.compareTo(b.savedAt) <= 0 ? a : b,
    );
    await t.drag(find.byKey(const Key('focus-card')), const Offset(300, 0));
    await settle(t);
    expect(
      c.library!.bookmarks.firstWhere((b) => b.id == oldest.id).isRead,
      isTrue,
    );
    expect(find.text('2 to go'), findsOneWidget);
    await t.tap(find.byKey(const Key('focus-undo')));
    await settle(t);
    expect(
      c.library!.bookmarks.firstWhere((b) => b.id == oldest.id).isRead,
      isFalse,
    );
    expect(find.text('3 to go'), findsOneWidget);
  });

  testWidgets('swiping left keeps it for later without changing it', (t) async {
    final (c, _) = await boot(t);
    await openFocus(t);
    await t.drag(find.byKey(const Key('focus-card')), const Offset(-300, 0));
    await settle(t);
    expect(find.text('2 to go'), findsOneWidget);
    expect(c.library!.bookmarks.every((b) => !b.isRead), isTrue);
  });

  testWidgets('a short drag springs back and does nothing', (t) async {
    final (c, _) = await boot(t);
    await openFocus(t);
    await t.timedDrag(
      find.byKey(const Key('focus-card')),
      const Offset(40, 0),
      const Duration(milliseconds: 800),
    );
    await settle(t);
    expect(find.text('3 to go'), findsOneWidget);
    expect(c.library!.bookmarks.every((b) => !b.isRead), isTrue);
  });

  testWidgets('buttons and keys do the same; the end offers the later ones', (
    t,
  ) async {
    final (c, _) = await boot(t);
    await openFocus(t);
    await tapKey(t, 'focus-archive');
    await settle(t);
    expect(c.library!.bookmarks.where((b) => b.isArchived), hasLength(1));
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await settle(t);
    expect(c.library!.bookmarks.where((b) => b.isRead), hasLength(1));
    await tapKey(t, 'focus-later');
    await settle(t);
    expect(find.text('Done: 3 went through'), findsOneWidget);
    await tapKey(t, 'focus-again');
    await settle(t);
    expect(find.text('1 to go'), findsOneWidget);
  });
}
