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
      for (final (name, sample) in [
        ('timestamp', '1730505600'),
        ('cron', '*/15 9-17 * * 1-5'),
        ('url', 'https://shop.example.vn/s?q=%C3%A1o&page=2#top'),
        ('ids', '017F22E2-79B0-7CC3-98C4-DC0C0C07398F'),
        ('bases', '-1'),
      ]) {
        await paste(tester, sample);
        await meetsAll(tester, name);
      }
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
      '1730505600',
      '*/15 9-17 * * 1-5',
      'https://ana:pw@shop.example.vn/s?q=%C3%A1o&page=2&utm_source=zalo#top',
      '017F22E2-79B0-7CC3-98C4-DC0C0C07398F\n01JBQ8Z3M2T4ABCDEF01234567',
      '0x${'f' * 64}',
    ]) {
      await paste(tester, sample);
      expect(tester.takeException(), isNull, reason: sample);
    }
    await paste(tester, 'a\nb\nc');
    await tapKey(tester, 'lens-text-diff');
    await tester.enterText(find.byKey(const Key('lens-option')), 'a\nB\nc\nd');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'diff');
    await tapKey(tester, 'lens-hmac');
    await tester.enterText(find.byKey(const Key('lens-option')), 'key');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'hmac');
    await openRequests(tester);
    await tapKey(tester, 'request-new');
    expect(tester.takeException(), isNull);
  });
}
