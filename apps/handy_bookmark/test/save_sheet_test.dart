import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/controller.dart' show saveTime, SaveController;
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'controller_test.dart' show TestStore;
import 'widget_test.dart' show start, tapKey;

/// Answers the platform clipboard with [text].
void clipboardHolds(WidgetTester t, String text) {
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => call.method == 'Clipboard.getData' ? {'text': text} : null,
  );
  addTearDown(
    () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

void main() {
  testWidgets('the save sheet: Paste fills the field, a word with no link '
      'says so in place, and a save keeps the sheet open for the next', (
    t,
  ) async {
    final store = TestStore(), c = await start(t, store: store);
    await tapKey(t, 'save-new');
    final input = find.byKey(const Key('bookmark-inline-url'));

    // Save stays off until there is something to save.
    expect(
      t
          .widget<FilledButton>(find.byKey(const Key('bookmark-inline-save')))
          .onPressed,
      isNull,
    );

    await t.enterText(input, 'pho near the river');
    await tapKey(t, 'bookmark-inline-save');
    expect(find.textContaining('No link here yet'), findsOneWidget);
    expect(store.rows, isEmpty);
    expect(t.widget<TextField>(input).controller!.text, 'pho near the river');

    clipboardHolds(t, '  https://example.org/pho  ');
    await tapKey(t, 'save-paste');
    expect(
      t.widget<TextField>(input).controller!.text,
      'https://example.org/pho',
    );
    expect(find.textContaining('No link here yet'), findsNothing);

    await tapKey(t, 'bookmark-inline-save');
    expect(store.rows, hasLength(1));
    expect(c.library!.bookmarks.single.originalUrl, 'https://example.org/pho');
    expect(find.textContaining('Saved to Not sorted'), findsOneWidget);
    expect(find.byKey(const Key('save-sheet')), findsOneWidget);
    expect(t.widget<TextField>(input).controller!.text, isEmpty);

    // The same clipboard text is not offered twice.
    await tapKey(t, 'save-paste');
    expect(find.textContaining('already offered'), findsOneWidget);
  });

  testWidgets('a link already saved offers to show it first', (t) async {
    final c = await start(
      t,
      seed: (c) => c.quickSave('https://example.com/a', title: 'Phở Hà Nội'),
    );
    await tapKey(t, 'save-new');
    await t.enterText(
      find.byKey(const Key('bookmark-inline-url')),
      'https://example.com/a',
    );
    await tapKey(t, 'bookmark-inline-save');
    expect(find.text('Already saved'), findsOneWidget);
    expect(find.text('Phở Hà Nội'), findsWidgets);
    await tapKey(t, 'dup-open');
    expect(find.byKey(const Key('save-open-original')), findsOneWidget);
    expect(c.library!.bookmarks, hasLength(1));
  });

  testWidgets('the save sheet and several-links sheet fit 320 px at 200% '
      'text', (t) async {
    await start(t, size: const Size(320, 640), textScale: 2);
    await tapKey(t, 'save-new');
    expect(t.takeException(), isNull, reason: 'save sheet');
    await tapKey(t, 'save-add');
    expect(t.takeException(), isNull, reason: 'several links');
    await t.enterText(
      find.byKey(const Key('save-text-input')),
      'https://a.com/1 and https://b.com/2',
    );
    await t.pump();
    expect(find.text('Save 2 links'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('settings: four groups, truthful sync and privacy, and the '
      'irreversible actions last', (t) async {
    await start(t);
    Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/settings');
    await t.pumpAndSettle();
    for (final group in [
      'Personalise',
      'Reminders',
      'Your data',
      'Help and advanced',
    ]) {
      await t.scrollUntilVisible(
        find.text(group),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(group), findsOneWidget);
    }
    // Nothing claims a connection that does not exist.
    expect(find.textContaining('Connected'), findsNothing);
    await t.scrollUntilVisible(
      find.byKey(const Key('save-reset')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // Delete-all is the last row of the page, under its own heading.
    expect(find.text('Reset and delete'), findsOneWidget);
    await t.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await t.pumpAndSettle();
    expect(
      t.getRect(find.byKey(const Key('save-reset'))).bottom,
      greaterThan(900 - 120),
      reason: 'at the end of the page, nothing comes after it',
    );
    await t.scrollUntilVisible(
      find.byKey(const Key('save-privacy')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tapKey(t, 'save-privacy');
    expect(find.textContaining('Only when you start it'), findsOneWidget);
    expect(find.textContaining('never leaves'), findsNothing);
  });

  testWidgets('Recently Deleted: restore is the prominent action; delete '
      'forever asks first; an empty bin says how it works', (t) async {
    final c = await start(
      t,
      seed: (c) async {
        await c.quickSave('https://a.com/one');
        await c.quickSave('https://b.com/two');
      },
    );
    await c.update(
      (l) => moveToTrash(l, [for (final b in l.bookmarks) b.id], saveTime()),
    );
    await t.pumpAndSettle();
    Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/trash');
    await t.pumpAndSettle();
    final one = c.library!.trash.first.id;
    expect(find.byKey(Key('trash-restore-$one')), findsOneWidget);
    await tapKey(t, 'trash-empty-all');
    expect(find.text('Empty Recently Deleted?'), findsOneWidget);
    await tapKey(t, 'confirm-cancel');
    expect(c.library!.trash, hasLength(2), reason: 'cancel keeps both');
    await tapKey(t, 'trash-empty-all');
    await tapKey(t, 'confirm-action');
    expect(c.library!.trash, isEmpty);
    expect(find.byKey(const Key('trash-empty')), findsOneWidget);
    expect(find.textContaining('30 days'), findsOneWidget);
  });

  for (final (omissions, says) in [
    (const <BackupOmission>[], 'complete. 2 links, 1 pictures'),
    (
      const [BackupOmission('pictures', OmissionReason.tooLarge, 3, 900)],
      'left out 3 pictures (too large). They are still on this device.',
    ),
  ]) {
    testWidgets('settings shows what the last backup holds: $says', (t) async {
      final c = await start(t);
      final report = BackupReport(
        at: '2026-11-05T08:00:00Z',
        automatic: true,
        links: 2,
        picturesIncluded: 1,
        omissions: omissions,
      );
      await c.update(
        (l) => l,
        prefs: {
          ...c.preferences,
          SaveController.lastBackupKey: report.toJson(),
        },
      );
      Navigator.of(
        t.element(find.byType(Scaffold).first),
      ).pushNamed('/settings');
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byKey(const Key('backup-report')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining(says), findsOneWidget);
      expect(
        find.textContaining('complete'),
        omissions.isEmpty ? findsOneWidget : findsNothing,
        reason: 'complete only when nothing was left out',
      );
    });
  }

  testWidgets('settings and Recently Deleted fit 320 px at 200% text', (
    t,
  ) async {
    final c = await start(
      t,
      size: const Size(320, 640),
      textScale: 2,
      seed: (c) => c.quickSave('https://a.com/a-rather-long-address/to-wrap'),
    );
    await c.update(
      (l) => moveToTrash(l, [for (final b in l.bookmarks) b.id], saveTime()),
    );
    await t.pumpAndSettle();
    final nav = Navigator.of(t.element(find.byType(Scaffold).first));
    nav.pushNamed('/trash');
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: 'trash');
    nav.pop();
    nav.pushNamed('/settings');
    await t.pumpAndSettle();
    for (var i = 0; i < 40; i++) {
      await t.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await t.pump();
      expect(t.takeException(), isNull, reason: 'settings, page $i');
    }
  });
}
