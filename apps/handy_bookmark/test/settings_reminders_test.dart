import 'package:flutter_test/flutter_test.dart';
import 'package:handy_ui/kit.dart';
import 'new_flows_test.dart' show boot, settle, idOf;
import 'widget_test.dart' show tapKey;

Future<void> openSettings(WidgetTester t) async {
  Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/settings');
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Existing reminders hides itself while no item has one', (
    t,
  ) async {
    await boot(t);
    await openSettings(t);
    await t.scrollUntilVisible(
      find.text('Backup and restore'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('existing-reminders')), findsNothing);
  });

  testWidgets('a reminder can be cancelled one by one, with Undo, or all '
      'at once after a confirmation; the items stay', (t) async {
    final soon = DateTime.now().toUtc().add(const Duration(days: 2));
    final (c, _) = await boot(
      t,
      seed: (c) => c.update(
        (l) => l.copyWith(
          bookmarks: [
            for (final b in l.bookmarks)
              b.copyWith(reminderAt: soon.toIso8601String()),
          ],
        ),
      ),
    );
    final one = idOf(c, 'https://a.com/one');
    await openSettings(t);
    await t.scrollUntilVisible(
      find.byKey(const Key('existing-reminders')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Reminders set'), findsOneWidget);

    await tapKey(t, 'reminder-cancel-$one');
    await settle(t);
    expect(
      c.library!.bookmarks.firstWhere((b) => b.id == one).reminderAt,
      isNull,
    );
    expect(find.byKey(Key('reminder-$one')), findsNothing);
    await t.tap(find.text('Undo'));
    await settle(t);
    expect(
      c.library!.bookmarks.firstWhere((b) => b.id == one).reminderAt,
      isNotNull,
    );

    await tapKey(t, 'reminders-cancel-all');
    expect(find.text('Cancel 3 reminders?'), findsOneWidget);
    await tapKey(t, 'confirm-cancel');
    expect(
      c.library!.bookmarks.where((b) => b.reminderAt != null),
      hasLength(3),
    );
    await tapKey(t, 'reminders-cancel-all');
    await tapKey(t, 'confirm-action');
    await settle(t);
    expect(c.library!.bookmarks, hasLength(3), reason: 'items stay');
    expect(c.library!.bookmarks.where((b) => b.reminderAt != null), isEmpty);
    expect(find.byKey(const Key('existing-reminders')), findsNothing);
  });

  testWidgets('Back up is one tap and Settings then says what it held', (
    t,
  ) async {
    final (c, _) = await boot(t);
    await openSettings(t);
    expect(find.byKey(const Key('backup-report')), findsNothing);
    await tapKey(t, 'save-backup');
    await settle(t, 300);
    expect(c.lastBackup, isNotNull);
    expect(c.lastBackup!.automatic, isFalse);
    expect(c.lastBackup!.links, 3);
    expect(find.byKey(const Key('backup-report')), findsOneWidget);
    expect(find.textContaining('Last backup'), findsOneWidget);
  });
}
