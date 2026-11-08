import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_boards/pro/pro.dart';
import 'package:handy_boards/settings/help_links.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import 'kanban_app_test.dart' show boot, board, studyState, tap;

/// Settings is a lazy list: tall enough to hold all of it.
const tall = Size(400, 3200);

Future<void> openSettings(WidgetTester t) =>
    tap(t, find.byKey(const Key('home-settings')));

void main() {
  setUp(() {
    debugProOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('handy.boards/share'),
          (call) async => call.method == 'drain' ? [] : true,
        );
  });

  testWidgets('Settings run like the other Handy apps: Pro first, then '
      'General, Automations, Data, Help and About', (t) async {
    await boot(t, studyState(), size: tall);
    await openSettings(t);
    final top = <String, double>{
      for (final label in [
        'Upgrade to Pro',
        'General',
        'Automations',
        'Data',
        'Help',
        'About',
      ])
        label: t.getTopLeft(find.text(label).first).dy,
    };
    final order = top.values.toList();
    expect(order, [...order]..sort());
    for (final key in [
      'settings-backup',
      'settings-restore',
      'settings-archived-cards',
      'settings-trash',
      'settings-delete-all',
      'settings-howto',
      'settings-feedback',
      'settings-privacy',
      'settings-terms',
      'settings-licenses',
    ])
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    // The old "30-second tour" line is gone.
    expect(find.textContaining('30'), findsNothing);
  });

  testWidgets('How to use: topics open as step sheets; the welcome replays '
      'without touching the boards', (t) async {
    final c = await boot(t, studyState(), size: tall);
    final before = c.state!.revision;
    await openSettings(t);
    await tap(t, find.byKey(const Key('settings-howto')));
    expect(find.byKey(const Key('howto-replay')), findsOneWidget);
    await tap(t, find.byKey(const Key('howto-topic-cards')));
    expect(find.byKey(const Key('howto-sheet-cards')), findsOneWidget);
    expect(find.byKey(const Key('howto-step-0')), findsOneWidget);
    await tap(t, find.byKey(const Key('howto-next')));
    expect(find.byKey(const Key('howto-sheet-categories')), findsOneWidget);
    await tap(t, find.byKey(const Key('howto-previous')));
    expect(find.byKey(const Key('howto-sheet-cards')), findsOneWidget);
    await tap(t, find.byKey(const Key('howto-done')));
    expect(find.byKey(const Key('howto-sheet-cards')), findsNothing);
    await tap(t, find.byKey(const Key('howto-replay')));
    expect(find.byKey(const Key('welcome-skip')), findsOneWidget);
    expect(c.state!.revision, before);
  });

  testWidgets('an archived card waits in Data and comes back with Restore', (
    t,
  ) async {
    var s = studyState();
    final card = topTasks(s, board: board).first;
    s = s.put('tasks', card.copy({'archived': true}));
    final c = await boot(t, s, size: tall);
    await openSettings(t);
    expect(find.text('1 card'), findsWidgets);
    await tap(t, find.byKey(const Key('settings-archived-cards')));
    await tap(t, find.byKey(Key('restore-${card.id}')));
    expect(c.state!.get('tasks', card.id).flag('archived'), isFalse);
  });

  testWidgets('Delete all data asks first, keeps language and theme, and '
      'starts over with the welcome', (t) async {
    final c = await boot(t, studyState(), size: tall);
    await openSettings(t);
    await tap(t, find.byKey(const Key('settings-delete-all')));
    await tap(t, find.text('Cancel').last);
    expect(c.state!.rows('boards'), isNotEmpty);
    await tap(t, find.byKey(const Key('settings-delete-all')));
    await tap(t, find.text('Delete all data').last);
    expect(c.state!.rows('boards'), isEmpty);
    expect(c.state!.rows('tasks'), isEmpty);
    expect(c.state!.preferences['locale'], 'en');
    expect(c.canUndo, isFalse);
    expect(find.byKey(const Key('welcome-skip')), findsOneWidget);
  });

  testWidgets('Send feedback writes to the studio, naming only the app', (
    t,
  ) async {
    final opened = <Uri>[];
    final was = openExternal;
    openExternal = (uri) async {
      opened.add(uri);
      return true;
    };
    addTearDown(() => openExternal = was);
    await boot(t, studyState(), size: tall);
    await openSettings(t);
    await tap(t, find.byKey(const Key('settings-feedback')));
    expect(opened.single.scheme, 'mailto');
    expect(opened.single.path, feedbackEmail);
    expect(opened.single.query, contains('Handy%20Boards'));
    await tap(t, find.byKey(const Key('settings-privacy')));
    expect(opened.last.toString(), privacyPolicyUrl);
  });

  testWidgets('on Android the home-screen widget shows card names only once '
      'it is switched on', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final c = await boot(t, studyState(), size: tall);
    await openSettings(t);
    expect(c.state!.preferences['homeWidget'], isNull);
    await tap(t, find.byKey(const Key('settings-home-widget')));
    expect(c.state!.preferences['homeWidget'], isTrue);
    debugDefaultTargetPlatformOverride = null;
  });
}
