import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_dev/inspect/detect.dart';
import 'package:handy_dev/inspect/inspection.dart';
import 'package:handy_dev/inspect/lenses.dart';
import 'package:handy_dev/inspect/query_editor.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'helpers.dart';

Lens lens(DataKind k, String id) => lensesFor(k).firstWhere((l) => l.id == id);

String _field(WidgetTester t, String key) =>
    t.widget<TextField>(find.byKey(Key(key))).controller!.text;

void main() {
  group('detection and core', () {
    test('new kinds are recognised, best guess first', () {
      expect(detect('1730505600').take(2), [
        DataKind.timestamp,
        DataKind.number,
      ]);
      expect(detect('2026-11-02T07:00:00+07:00').first, DataKind.timestamp);
      expect(detect('0xff').first, DataKind.number);
      expect(detect('42').first, DataKind.number);
      expect(
        detect('0192f0a4-9b2e-7c3d-8e4f-0123456789ab').first,
        DataKind.ids,
      );
      expect(
        detect('01JBQ8Z3M2T4ABCDEF01234567\n01JBQ8Z3M2T4ABCDEF01234568').first,
        DataKind.ids,
      );
      expect(detect('*/5 * * * *').first, DataKind.cron);
      expect(detect('@daily').first, DataKind.cron);
      expect(detect('https://example.com/a?b=1').first, DataKind.link);
      // Unchanged: encoded text, words, YAML.
      expect(detect('https%3A%2F%2Fexample.com%2F').first, DataKind.url);
      expect(detect('one two three four five'), [DataKind.text]);
      // Text diff is offered for documents, not for a single value.
      bool diffs(DataKind k) => lensesFor(k).any((l) => l.id == 'text-diff');
      expect(diffs(DataKind.yaml) && diffs(DataKind.text), isTrue);
      expect(diffs(DataKind.number) || diffs(DataKind.cron), isFalse);
      expect(detect('name: An\nage: 3').first, DataKind.yaml);
    });

    test('utility lenses give typed answers and facts', () {
      final now = DateTime.utc(2024, 11, 5);
      final t = inspect(
        '1730505600',
        DataKind.timestamp,
        timestampLens,
        picks: {'zone': 'utc'},
        now: now,
      );
      expect((t.detail as TimestampReading).unixSeconds, 1730505600);
      expect(facts(t).map((f) => f.$1), ['unit:seconds']);
      expect(jsonDecode(t.copy)['relativeEn'], '3 days ago');
      final vn = inspect(
        '1730505600',
        DataKind.timestamp,
        timestampLens,
        option: '+07:00',
        now: now,
      );
      expect(jsonDecode(vn.copy)['inZone'], '2024-11-02T07:00:00.000+07:00');

      final d = inspect('a\nb', DataKind.text, textDiffLens);
      expect(d.needsOption, isTrue);
      final d2 = inspect('a\nb', DataKind.text, textDiffLens, option: 'a\nc');
      expect(facts(d2).map((f) => f.$1), ['diff:1:1']);
      expect(d2.copy, contains('-b\n+c'));
      expect(
        facts(inspect('a', DataKind.text, textDiffLens, option: 'a')).single,
        ('identical', true),
      );

      final c = inspect(
        '0 9 * * 1-5',
        DataKind.cron,
        cronLens,
        picks: {'zone': 'utc', 'count': '10'},
        now: DateTime.utc(2026, 11, 2, 8, 50),
      );
      final a = c.detail as CronAnswer;
      expect(a.runs.length, 10);
      expect(a.runs.first, DateTime.utc(2026, 11, 2, 9));
      expect(facts(c).single.$1, startsWith('next:2026-11-02T09:00'));
      expect(facts(inspect('0 0 30 2 *', DataKind.cron, cronLens)).single, (
        'never',
        false,
      ));

      final b = inspect(
        '-1',
        DataKind.number,
        baseLens,
        picks: {'bits': '16'},
        option: '2',
      );
      expect((b.detail as BaseConversion).twos!.hex, '0xffff');
      expect(facts(b).single.$1, 'bits:16');
      expect(
        inspect('1', DataKind.number, baseLens, option: 'x').error,
        contains('Base must be'),
      );

      final ids = inspect(
        '017F22E2-79B0-7CC3-98C4-DC0C0C07398F\nbad',
        DataKind.ids,
        idsLens,
      );
      expect(facts(ids).map((f) => f.$1), ['ids:1', 'bad-ids:1']);
      expect(ids.copy, '017f22e2-79b0-7cc3-98c4-dc0c0c07398f');
      expect(inspect('nope', DataKind.ids, idsLens).error, isNotEmpty);

      final u = inspect('https://x.dev/p?a=1&b=2', DataKind.link, urlLens);
      expect(facts(u).single.$1, 'params:2');
    });

    test('HMAC builds its options from the key and the picks', () {
      final r = inspect(
        'what do ya want for nothing?',
        DataKind.text,
        hmacLens,
        option: 'Jefe',
        picks: {'output': 'hex'},
      );
      expect(r.text, startsWith('5bdcc146'));
      expect(r.copy, isNot(contains('Jefe')));
      final b64 = inspect(
        'what do ya want for nothing?',
        DataKind.text,
        hmacLens,
        option: '4a656665',
        picks: {'output': 'base64', 'keyFormat': 'hex'},
      );
      expect(b64.text, base64.encode(hexBytes(r.text!)));
      expect(
        inspect('x', DataKind.text, hmacLens).needsOption,
        isTrue,
        reason: 'no key, no answer',
      );
      expect(hmacLens.sensitive, isTrue);
      expect(chainable.contains('hmac'), isFalse);
    });

    test('the query editor keeps rows and rebuilds through the engine', () {
      final e = QueryEditor(parseUrl('https://x.dev/p?a=1&a=2#f'));
      expect(e.rows.length, 2);
      expect(e.edited, isFalse);
      e.rows.first.$2.text = 'one';
      e.add();
      e.rows.last.$1.text = 'q';
      e.rows.last.$2.text = 'á b';
      expect(e.edited, isTrue);
      expect(e.url, 'https://x.dev/p?a=one&a=2&q=%C3%A1+b#f');
      e.remove(1);
      expect(e.url, 'https://x.dev/p?a=one&q=%C3%A1+b#f');
      e.reset();
      expect(e.url, 'https://x.dev/p?a=1&a=2#f');
      e.dispose();
    });
  });

  group('screens', () {
    testWidgets('a timestamp reads in the chosen zone', (tester) async {
      await start(
        tester,
        prefs: DevPreferences()..value = HandyPreferences(locale: 'en'),
      );
      await paste(tester, '1730505600');
      expect(find.byKey(const Key('kind-timestamp')), findsOneWidget);
      expect(find.byKey(const Key('kind-number')), findsOneWidget);
      await tapKey(tester, 'pick-zone-utc');
      expect(find.text('2024-11-02 00:00:00'), findsOneWidget);
      expect(find.text('seconds'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('lens-option')), '+07:00');
      await tester.pumpAndSettle();
      expect(find.text('2024-11-02 07:00:00'), findsOneWidget);
      await tapKey(tester, 'kind-number');
      await reveal(tester, find.text('0x6725 6b80'));
      expect(find.text('0x6725 6b80'), findsOneWidget);
    });

    testWidgets('IDs are made, inspected and copied', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await start(tester);
      await tapKey(tester, 'make-v7');
      expect(
        tester.widget<Text>(find.byKey(const Key('utility-headline'))).data,
        'UUID v7',
      );
      await tapKey(tester, 'id-kind');
      await tester.tap(find.text('ULID'));
      await tester.enterText(find.byKey(const Key('id-count')), '3');
      await tapKey(tester, 'id-generate');
      final lines = _field(tester, 'dev-input').split('\n');
      expect(lines.length, 3);
      expect(lines.every((l) => l.length == 26), isTrue);
      await tapKey(tester, 'dev-copy');
      expect(copied, lines.join('\n'));
      await tester.enterText(find.byKey(const Key('id-count')), '5000');
      await tapKey(tester, 'id-generate');
      expect(find.text('Enter 1 to 1000'), findsOneWidget);
      expect(_field(tester, 'dev-input').split('\n').length, 3);
    });

    testWidgets('text diff shows side by side and unified', (tester) async {
      await start(tester, size: const Size(1280, 1000));
      await paste(tester, 'host = a\nport = 80\nmode = dev');
      await tapKey(tester, 'lens-text-diff');
      expect(find.text('Fill in compare with above.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('lens-option')),
        'host = a\nport = 443\nmode = dev\ntls = on',
      );
      await tester.pumpAndSettle();
      expect(find.text('+2 −1 lines'), findsOneWidget);
      expect(find.text('port = 80'), findsOneWidget);
      expect(find.text('port = 443'), findsOneWidget);
      // Side by side: unchanged lines appear in both columns.
      expect(find.text('host = a'), findsNWidgets(2));
      await tester.tap(find.text('Unified'));
      await tester.pumpAndSettle();
      expect(find.text('host = a'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('lens-option')),
        'host = a\nport = 80\nmode = dev',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('diff-identical')), findsOneWidget);
    });

    testWidgets('cron explains itself and lists runs; errors name the field', (
      tester,
    ) async {
      await start(
        tester,
        prefs: DevPreferences()..value = HandyPreferences(locale: 'vi'),
      );
      await paste(tester, '0 9 * * 1-5');
      expect(find.text('Lúc 09:00, vào thứ Hai đến thứ Sáu'), findsOneWidget);
      await tapKey(tester, 'pick-count-10');
      expect(find.byKey(const Key('dev-row-9')), findsWidgets);
      await tapKey(tester, 'lens-cron');
      await paste(tester, '0 0 30 2 *');
      expect(find.byKey(const Key('cron-never')), findsOneWidget);
    });

    testWidgets('a URL is split, edited and rebuilt', (tester) async {
      await start(
        tester,
        prefs: DevPreferences()..value = HandyPreferences(locale: 'en'),
      );
      await paste(
        tester,
        'https://ana:pw@shop.example.vn/s?q=%C3%A1o&page=2#top',
      );
      expect(find.text('shop.example.vn'), findsOneWidget);
      expect(find.text('hidden'), findsOneWidget);
      expect(find.text('pw'), findsNothing);
      expect(find.text('ana:pw'), findsNothing);
      expect(_field(tester, 'query-value-0'), 'áo');
      await tester.enterText(find.byKey(const Key('query-value-1')), '3');
      await tapKey(tester, 'query-add');
      await tester.enterText(find.byKey(const Key('query-name-2')), 'sort');
      await tester.enterText(find.byKey(const Key('query-value-2')), 'giá');
      await tester.pumpAndSettle();
      const rebuilt =
          'https://ana:pw@shop.example.vn/s?q=%C3%A1o&page=3&sort=gi%C3%A1#top';
      expect(find.text(rebuilt), findsOneWidget);
      await tapKey(tester, 'url-use');
      expect(_field(tester, 'dev-input'), rebuilt);
    });

    testWidgets(
      'an HMAC key is hidden, never a draft, and gone when the lens changes',
      (tester) async {
        final prefs = DevPreferences()
          ..value = HandyPreferences(
            locale: 'en',
            drafts: {'hmac': 'old message', 'base64-encode': 'hi'},
          );
        await start(tester, prefs: prefs);
        expect(find.byKey(const Key('draft-hmac')), findsNothing);
        await paste(tester, 'what do ya want for nothing?');
        await tapKey(tester, 'lens-hmac');
        expect(find.text('Fill in key above.'), findsOneWidget);
        final field = tester.widget<TextField>(
          find.byKey(const Key('lens-option')),
        );
        expect(field.obscureText, isTrue);
        expect(field.enableSuggestions, isFalse);
        await tester.enterText(find.byKey(const Key('lens-option')), 'Jefe');
        await tester.pumpAndSettle();
        expect(
          find.text(
            '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843',
          ),
          findsOneWidget,
        );
        // Editing the message keeps the lens and the key.
        await tester.enterText(
          find.byKey(const Key('dev-input')),
          'what do ya want for nothing??',
        );
        await tester.pumpAndSettle();
        expect(_field(tester, 'lens-option'), 'Jefe');
        expect(find.textContaining('5bdcc146'), findsNothing);
        await tester.enterText(
          find.byKey(const Key('dev-input')),
          'what do ya want for nothing?',
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('dev-save-draft')), findsNothing);
        expect(find.byKey(const Key('chain-save')), findsNothing);
        await tapKey(tester, 'pick-output-base64');
        expect(
          find.textContaining('W9zBRr9gdU5qBCQmCJV1x1oAPwidJzmDnexYuWTsOEM='),
          findsOneWidget,
        );
        await tapKey(tester, 'lens-sha256');
        await tapKey(tester, 'lens-hmac');
        expect(_field(tester, 'lens-option'), isEmpty);
        expect(jsonEncode(prefs.value.toJson()), isNot(contains('Jefe')));
      },
    );
  });
}

List<int> hexBytes(String h) => [
  for (var i = 0; i < h.length; i += 2)
    int.parse(h.substring(i, i + 2), radix: 16),
];
