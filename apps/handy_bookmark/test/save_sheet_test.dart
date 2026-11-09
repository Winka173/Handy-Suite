import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/controller.dart' show saveTime, SaveController;
import 'package:handy_bookmark/settings/help_links.dart' as help;
import 'package:handy_bookmark/settings/settings_parts.dart' show SettingsGroup;
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
  testWidgets('Quick Save on Home: + until there is text, then Save; a word '
      'with no link says so in place and keeps the text; a save clears the '
      'field and offers View and Undo', (t) async {
    final store = TestStore(), c = await start(t, store: store);
    final input = find.byKey(const Key('bookmark-inline-url'));
    expect(input, findsOneWidget, reason: 'the field is on Home');
    expect(find.byKey(const Key('bookmark-inline-save')), findsNothing);
    expect(find.byKey(const Key('save-new')), findsOneWidget);

    await t.enterText(input, 'pho near the river');
    await t.pump();
    expect(find.byKey(const Key('save-new')), findsNothing);
    await tapKey(t, 'bookmark-inline-save');
    expect(find.textContaining('No link in this text'), findsOneWidget);
    expect(store.rows, isEmpty);
    expect(t.widget<TextField>(input).controller!.text, 'pho near the river');

    await t.enterText(input, 'javascript:alert(1)');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(find.textContaining('Only web links'), findsOneWidget);
    expect(store.rows, isEmpty);

    await tapKey(t, 'quick-clear');
    clipboardHolds(t, '  https://example.org/pho  ');
    await tapKey(t, 'save-paste');
    expect(
      t.widget<TextField>(input).controller!.text,
      'https://example.org/pho',
    );
    expect(find.byKey(const Key('quick-problem')), findsNothing);

    // The keyboard's Done saves, once, however fast it is pressed.
    await t.showKeyboard(input);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pumpAndSettle();
    expect(store.rows, hasLength(1));
    expect(c.library!.bookmarks.single.originalUrl, 'https://example.org/pho');
    expect(find.text('Saved to Not sorted.'), findsOneWidget);
    expect(find.byKey(const Key('quick-view')), findsOneWidget);
    expect(t.widget<TextField>(input).controller!.text, isEmpty);

    // Undo puts the new save in Trash: nothing is lost by a quick tap.
    await tapKey(t, 'quick-undo');
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    expect(c.library!.bookmarks, isEmpty);
    expect(c.library!.trash, hasLength(1));

    // The same clipboard text is not offered twice.
    await tapKey(t, 'save-paste');
    expect(find.textContaining('already offered'), findsOneWidget);
  });

  testWidgets('a link already saved offers to show it first', (t) async {
    final c = await start(
      t,
      seed: (c) => c.quickSave('https://example.com/a', title: 'Phở Hà Nội'),
    );
    await t.enterText(
      find.byKey(const Key('bookmark-inline-url')),
      'https://example.com/a',
    );
    // The Save button comes with the next frame.
    await t.pump();
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

  testWidgets('settings: Pro first, then General, Privacy, Data, Help and '
      'About; delete-all ends Data; truthful sync and privacy', (t) async {
    await start(t);
    Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/settings');
    await t.pumpAndSettle();
    expect(find.byKey(const Key('set-pro')), findsOneWidget);
    expect(find.text('Upgrade to Pro'), findsOneWidget);
    for (final group in ['General', 'Privacy', 'Data', 'Help', 'About']) {
      final heading = find.byWidgetPredicate(
        (w) => w is SettingsGroup && w.title == group,
      );
      await t.scrollUntilVisible(
        heading,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(heading, findsOneWidget, reason: group);
    }
    // Gone: a separate reset, a second guide row, storage on its own.
    expect(find.byKey(const Key('settings-reset')), findsNothing);
    expect(find.byKey(const Key('set-guide')), findsNothing);
    // Nothing claims a connection that does not exist.
    expect(find.textContaining('Connected'), findsNothing);
    await t.scrollUntilVisible(
      find.byKey(const Key('save-privacy')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.scrollUntilVisible(
      find.byKey(const Key('save-privacy')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // The published policy (the Play listing's too) opens outside the app.
    final opened = <Uri>[];
    final open = help.openExternal;
    help.openExternal = (uri) async {
      opened.add(uri);
      return true;
    };
    addTearDown(() => help.openExternal = open);
    await tapKey(t, 'save-privacy');
    // In the app's language: the English page, or its Vietnamese twin.
    expect(opened.single.host, 'winka.top');
    expect(
      opened.single.path,
      matches(RegExp(r'^/(en|vi)/apps/handy-bookmark/privacy/$')),
    );
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
        // A complete automatic copy is told by its switch instead; what
        // was left out is always told here.
        automatic: omissions.isNotEmpty,
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
