import 'package:flutter_test/flutter_test.dart';
import 'package:handy_dev/http_transport.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'helpers.dart';

void main() {
  testWidgets(
    'a collection name survives a failed save; retry commits before the dialog closes',
    (tester) async {
      final store = Store()..fail = true;
      await start(tester, store: store);
      await openRequests(tester);
      await tapKey(tester, 'more-menu');
      await tapKey(tester, 'api-create-collection');
      await tester.enterText(
        find.byKey(const Key('collection-name')),
        'My requests',
      );
      await tapKey(tester, 'collection-save');
      expect(find.byKey(const Key('collection-name')), findsOneWidget);
      expect(store.text, isNull);
      store.fail = false;
      await tapKey(tester, 'collection-save');
      expect(find.byKey(const Key('collection-name')), findsNothing);
      expect(
        parseWorkspace(store.text!).collections.map((c) => c.name),
        contains('My requests'),
      );
    },
  );

  testWidgets('saving a request writes a template without secrets', (
    tester,
  ) async {
    final store = Store();
    await start(tester, store: store);
    await openRequests(tester);
    await tapKey(tester, 'request-new');
    await tester.enterText(find.byKey(const Key('request-name')), 'Example');
    await tester.enterText(
      find.byKey(const Key('request-url')),
      'https://example.com/?token=private',
    );
    await tapKey(tester, 'request-save');
    expect(store.text, isNotNull);
    expect(store.text, isNot(contains('private')));
    expect(parseWorkspace(store.text!).requests.single.name, 'Example');
  });

  testWidgets('send shows the status line and the JSON body as a tree', (
    tester,
  ) async {
    final transport = HttpTransport(
      clientFactory: () =>
          MockClient((_) async => http.Response('{"id": 7, "ok": true}', 200)),
    );
    await start(tester, transport: transport);
    await openRequests(tester);
    await tapKey(tester, 'request-new');
    await tester.enterText(
      find.byKey(const Key('request-url')),
      'https://api.example.com/items/7',
    );
    await tapKey(tester, 'send');
    expect(find.byKey(const Key('response')), findsOneWidget);
    expect(find.text('200 OK'), findsOneWidget);
    expect(find.byKey(const Key(r'tree-row-$.id')), findsOneWidget);
  });

  testWidgets('plain HTTP is refused before anything is sent', (tester) async {
    var sent = false;
    final transport = HttpTransport(
      clientFactory: () => MockClient((_) async {
        sent = true;
        return http.Response('', 200);
      }),
    );
    await start(tester, transport: transport);
    await openRequests(tester);
    await tapKey(tester, 'request-new');
    await tester.enterText(
      find.byKey(const Key('request-url')),
      'http://insecure.example.com',
    );
    await tapKey(tester, 'send');
    expect(find.byKey(const Key('send-error')), findsOneWidget);
    expect(sent, isFalse);
  });
}
