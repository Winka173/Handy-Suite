import 'package:flutter_test/flutter_test.dart';
import 'package:handy_dev/http_transport.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'helpers.dart';

void main() {
  testWidgets('history is off until turned on, keeps no secrets, and '
      'forgets everything when turned off', (tester) async {
    final history = Store(), store = Store();
    final transport = HttpTransport(
      clientFactory: () =>
          MockClient((_) async => http.Response('{"ok": true}', 201)),
    );
    await start(tester, transport: transport, history: history, store: store);
    await openRequests(tester);
    expect(find.byKey(const Key('history-off')), findsOneWidget);

    // Off: a send leaves nothing behind.
    await tapKey(tester, 'request-new');
    await tester.enterText(
      find.byKey(const Key('request-url')),
      'https://api.example.com/orders?token=s3cret',
    );
    await tapKey(tester, 'request-save');
    await tapKey(tester, 'send');
    expect(history.text, isNull);

    await tapKey(tester, 'request-back');
    await tapKey(tester, 'history-keep');
    await tapKey(
      tester,
      'request-${parseWorkspace(store.text!).requests.single.id}',
    );
    await tapKey(tester, 'send');
    expect(history.text, isNot(contains('s3cret')));
    final kept = parseSendHistory(history.text!);
    expect(kept.items.single.url, 'https://api.example.com/orders?token');
    expect(kept.items.single.status, 201);

    // The list shows it and opens the request it came from.
    await tapKey(tester, 'request-back');
    expect(find.byKey(const Key('sent-0')), findsOneWidget);
    expect(find.textContaining('201 · '), findsOneWidget);
    await tapKey(tester, 'sent-0');
    expect(find.byKey(const Key('request-url')), findsOneWidget);
    await tapKey(tester, 'request-back');

    // Off again, after saying how many go.
    await tapKey(tester, 'history-keep');
    expect(find.text('Stop and forget 1 sends?'), findsOneWidget);
    await tapKey(tester, 'confirm-action');
    expect(parseSendHistory(history.text!).items, isEmpty);
    expect(parseSendHistory(history.text!).on, isFalse);
    expect(find.byKey(const Key('sent-0')), findsNothing);
  });

  testWidgets('a broken history file starts again, off', (tester) async {
    final history = Store()..text = '{"version": 1, "on": true, "items": 7}';
    await start(tester, history: history);
    await openRequests(tester);
    expect(find.byKey(const Key('history-off')), findsOneWidget);
  });
}
