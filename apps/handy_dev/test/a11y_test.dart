import 'package:flutter_test/flutter_test.dart';
import 'package:handy_dev/http_transport.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'helpers.dart';

Future<void> meetsAll(WidgetTester tester, String state) async {
  for (final g in [
    textContrastGuideline,
    androidTapTargetGuideline,
    iOSTapTargetGuideline,
    labeledTapTargetGuideline,
  ]) {
    await expectLater(tester, meetsGuideline(g), reason: state);
  }
}

void main() {
  for (final theme in ['light', 'dark']) {
    testWidgets('inspect and requests meet accessibility guidelines ($theme)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final prefs = DevPreferences()
        ..value = HandyPreferences(theme: theme, favorites: ['jwt']);
      final transport = HttpTransport(
        clientFactory: () =>
            MockClient((_) async => http.Response('{"id": 7}', 200)),
      );
      await start(tester, prefs: prefs, transport: transport);
      await meetsAll(tester, 'empty');
      await paste(tester, '{"order": {"items": [1, 2]}}');
      await meetsAll(tester, 'json tree');
      await paste(tester, 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.');
      await meetsAll(tester, 'jwt');
      await openRequests(tester);
      await tapKey(tester, 'request-new');
      await tester.enterText(
        find.byKey(const Key('request-url')),
        'https://api.example.com/items/7',
      );
      await tapKey(tester, 'send');
      await meetsAll(tester, 'response');
      handle.dispose();
    });
  }

  testWidgets('inspect and requests lay out at 320px without overflow', (
    tester,
  ) async {
    await start(tester, size: const Size(320, 720));
    for (final sample in [
      '{"a": [1, {"b": "x"}]}',
      'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.',
      'name: An\nage: 3',
      'id,name\n1,An',
    ]) {
      await paste(tester, sample);
      expect(tester.takeException(), isNull, reason: sample);
    }
    await openRequests(tester);
    await tapKey(tester, 'request-new');
    expect(tester.takeException(), isNull);
  });
}
