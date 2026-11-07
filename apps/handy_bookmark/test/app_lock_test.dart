import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/security/app_lock.dart';
import 'package:handy_ui/kit.dart';
import 'new_flows_test.dart' show boot, settle;
import 'widget_test.dart' show tapKey;

Future<void> openSettings(WidgetTester t) async {
  Navigator.of(t.element(find.byType(Scaffold).first)).pushNamed('/settings');
  await t.pumpAndSettle();
  await t.scrollUntilVisible(
    find.byKey(const Key('set-app-lock')),
    300,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  tearDown(() => AppLock.debugAsk = null);

  testWidgets('switching the lock on asks first; a phone with no screen '
      'lock says so and stays off', (t) async {
    final asked = <String>[];
    var answer = UnlockResult.noLock;
    AppLock.debugAsk = (reason) async {
      asked.add(reason);
      return answer;
    };
    final (c, _) = await boot(t);
    await openSettings(t);
    await tapKey(t, 'set-app-lock');
    await settle(t);
    expect(asked, hasLength(1));
    expect(c.preferences[appLockKey], isNot(true));
    expect(
      find.textContaining('screen lock on this device first'),
      findsOneWidget,
    );

    answer = UnlockResult.unlocked;
    await tapKey(t, 'set-app-lock');
    await settle(t);
    expect(c.preferences[appLockKey], isTrue);
    // Switched on by its owner: not locked at once.
    expect(find.byKey(const Key('app-locked')), findsNothing);
  });

  testWidgets('with the lock on, the app opens covered until the phone '
      'says it is the owner', (t) async {
    var answer = UnlockResult.failed;
    AppLock.debugAsk = (_) async => answer;
    await boot(
      t,
      seed: (c) =>
          c.update((l) => l, prefs: {...c.preferences, appLockKey: true}),
    );
    await settle(t);
    expect(find.byKey(const Key('app-locked')), findsOneWidget);
    expect(find.textContaining('locked'), findsWidgets);
    answer = UnlockResult.unlocked;
    await tapKey(t, 'app-unlock');
    await settle(t);
    expect(find.byKey(const Key('app-locked')), findsNothing);
  });
}
