import 'dart:convert';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';

DevTool tool(String id) => devTools.singleWhere((t) => t.id == id);

final _utc = const ZoneChoice.utc(), _vn = const ZoneChoice.fixed(7 * 60);

void main() {
  group('timestamp', () {
    final now = DateTime.utc(2024, 11, 5);
    test('unit is guessed from the size of the number', () {
      final s = readTimestamp('1730505600', now: now);
      expect(s.source, TimeSource.seconds);
      expect(s.instant, DateTime.utc(2024, 11, 2));
      expect(
        readTimestamp('1730505600123', now: now).source,
        TimeSource.milliseconds,
      );
      expect(readTimestamp('1730505600123', now: now).instant.millisecond, 123);
      final ns = readTimestamp('1730505600123456789', now: now);
      expect(ns.source, TimeSource.nanoseconds);
      expect(ns.toJson()['utc'], '2024-11-02T00:00:00.123456Z');
      expect(
        readTimestamp('1730505600123456', now: now).source,
        TimeSource.microseconds,
      );
      expect(
        readTimestamp('1730505600.5', now: now).unixMilliseconds,
        1730505600500,
      );
      expect(
        readTimestamp('-86400', now: now).instant,
        DateTime.utc(1969, 12, 31),
      );
      expect(
        readTimestamp('1730505600', unit: 'ms', now: now).instant,
        DateTime.utc(1970, 1, 21, 0, 41, 45, 600),
      );
    });
    test('zones: UTC, fixed offsets, and ISO input both ways', () {
      final s = readTimestamp('1730505600', zone: _vn, now: now).toJson();
      expect(s['inZone'], '2024-11-02T07:00:00.000+07:00');
      expect(s['utc'], '2024-11-02T00:00:00.000Z');
      expect(s['zone'], 'UTC+07:00');
      expect(s['unixMilliseconds'], 1730505600000);
      expect(
        readTimestamp('2024-11-02T07:00:00+07:00', now: now).unixSeconds,
        1730505600,
      );
      // No offset: the wall time is read in the chosen zone.
      expect(
        readTimestamp('2024-11-02 07:00', zone: _vn, now: now).unixSeconds,
        1730505600,
      );
      expect(readTimestamp('2024-11-02', now: now).unixSeconds, 1730505600);
      expect(ZoneChoice.parse('UTC-5:30').offsetMinutes, -330);
      expect(ZoneChoice.parse('+0545').offsetMinutes, 345);
      expect(ZoneChoice.parse('local').local, isTrue);
      for (final bad in ['+15:00', 'Asia/Ho_Chi_Minh', '+07:75']) {
        expect(() => ZoneChoice.parse(bad), throwsFormatException);
      }
    });
    test('relative time in English and Vietnamese', () {
      final s = readTimestamp('1730505600', now: now);
      expect(s.relative, (en: '3 days ago', vi: '3 ngày trước'));
      expect(relativeTime(now.add(const Duration(hours: 2)), now), (
        en: 'in 2 hours',
        vi: '2 giờ nữa',
      ));
      expect(relativeTime(now, now).en, 'just now');
      expect(relativeTime(DateTime.utc(2023, 11, 5), now), (
        en: '1 year ago',
        vi: '1 năm trước',
      ));
    });
    test('bad input is refused, not guessed', () {
      for (final bad in ['abc', '2024-13-45', '12:00', '1.2.3', '']) {
        expect(
          () => readTimestamp(bad, now: now),
          throwsFormatException,
          reason: bad,
        );
      }
      expect(
        () => readTimestamp('9999999999999999999', unit: 's', now: now),
        throwsFormatException,
      );
      expect(() => timestampOptions('+07:00 hours'), throwsFormatException);
    });
    test('the tool reads zone and unit options', () {
      final out = jsonDecode(tool('timestamp').run('1730505600000', 'utc ms'));
      expect(out['readAs'], 'milliseconds');
      expect(out['utc'], '2024-11-02T00:00:00.000Z');
      expect(out['relativeVi'], isA<String>());
    });
  });

  group('uuid and ulid', () {
    final at = DateTime.utc(2026, 11, 2, 7, 30);
    test('v4 has its version and variant bits', () {
      final ids = generateIds(IdKind.v4, 50, random: Random(1));
      for (final id in ids) {
        expect(
          id,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
        expect(inspectId(id)['version'], 4);
        expect(inspectId(id)['variant'], 'RFC 9562');
      }
      expect(ids.toSet().length, 50);
    });
    test('v7 and ULID carry the time and sort in creation order', () {
      final v7 = generateIds(IdKind.v7, 20, now: at);
      expect(v7, [...v7]..sort());
      expect(inspectId(v7.first)['version'], 7);
      expect(inspectId(v7.first)['timestamp'], '2026-11-02T07:30:00.000Z');
      final ulid = generateIds(IdKind.ulid, 20, now: at);
      expect(ulid.first, matches(RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$')));
      expect(ulid, [...ulid]..sort());
      final r = inspectId(ulid.first.toLowerCase());
      expect(r['kind'], 'ULID');
      expect(r['timestamp'], '2026-11-02T07:30:00.000Z');
    });
    test('counts are bounded', () {
      expect(() => generateIds(IdKind.v4, 0), throwsFormatException);
      expect(() => generateIds(IdKind.v4, maxIds + 1), throwsFormatException);
      expect(generateIds(IdKind.v4, maxIds).length, maxIds);
    });
    test('RFC 9562 examples decode to their times', () {
      for (final id in [
        'C232AB00-9414-11EC-B3C8-9F6BDECED846',
        '1EC9414C-232A-6B00-B3C8-9F6BDECED846',
        '017F22E2-79B0-7CC3-98C4-DC0C0C07398F',
      ]) {
        final r = inspectId(id);
        expect(r['canonical'], id.toLowerCase());
        expect(r['timestamp'], startsWith('2022-02-22T19:22:22'), reason: id);
      }
      expect(inspectId('{550e8400e29b41d4a716446655440000}')['version'], 4);
      expect(
        inspectId('urn:uuid:550e8400-e29b-41d4-a716-446655440000')['canonical'],
        '550e8400-e29b-41d4-a716-446655440000',
      );
      expect(
        inspectId('00000000-0000-0000-0000-000000000000')['special'],
        'nil',
      );
      expect(
        inspectId('550e8400-e29b-41d4-c716-446655440000')['variant'],
        'Microsoft (reserved)',
      );
    });
    test('bad IDs say why; a list keeps going', () {
      expect(() => inspectId('not-a-uuid'), throwsFormatException);
      expect(
        () => inspectId('8ZZZZZZZZZZZZZZZZZZZZZZZZZ'),
        throwsFormatException,
      );
      final r = inspectIds('550e8400-e29b-41d4-a716-446655440000\n\nnope');
      expect(r.map((x) => x['valid']), [true, false]);
      expect(() => tool('uuid').run('nope'), throwsFormatException);
    });
    test('the tool makes IDs from empty input', () {
      final out = tool('uuid').run('', 'v7 3').split('\n');
      expect(out.length, 3);
      expect(inspectId(out.first)['version'], 7);
      expect(() => tool('uuid').run('', 'v9'), throwsFormatException);
    });
  });

  group('text diff', () {
    test('changes, line numbers, unified and side by side', () {
      final d = diffText('a\nb\nc', 'a\nB\nc\nd\n');
      expect(d.lines.map((l) => (l.op, l.text)).toList(), [
        (DiffOp.same, 'a'),
        (DiffOp.removed, 'b'),
        (DiffOp.added, 'B'),
        (DiffOp.same, 'c'),
        (DiffOp.added, 'd'),
      ]);
      expect((d.added, d.removed), (2, 1));
      expect(d.lines[3].before, 3);
      expect(d.lines[4].after, 4);
      expect(
        d.unified(),
        '--- before\n+++ after\n@@ -1,3 +1,4 @@\n a\n-b\n+B\n c\n+d\n',
      );
      expect(d.sideBySide().map((r) => (r.$1?.text, r.$2?.text)).toList(), [
        ('a', 'a'),
        ('b', 'B'),
        ('c', 'c'),
        (null, 'd'),
      ]);
    });
    test('identical texts and line endings', () {
      final d = diffText('x\r\ny\n', 'x\ny');
      expect(d.identical, isTrue);
      expect(d.unified(), '');
      expect(
        diffText('', 'a').unified(),
        '--- before\n+++ after\n@@ -0,0 +1 @@\n+a\n',
      );
    });
    test('far-apart changes get their own hunks', () {
      final a = [for (var i = 1; i <= 30; i++) 'line $i'];
      final b = [...a]
        ..[1] = 'two'
        ..[25] = 'twenty-six';
      final u = diffText(a.join('\n'), b.join('\n')).unified();
      expect('@@'.allMatches(u).length, 4);
      expect(u, contains('@@ -1,5 +1,5 @@'));
      expect(u, contains('@@ -23,7 +23,7 @@'));
    });
    test('random edits rebuild both texts with a minimal script', () {
      final r = Random(7);
      for (var round = 0; round < 60; round++) {
        final a = [for (var i = 0; i < r.nextInt(40); i++) '${r.nextInt(6)}'];
        final b = [for (var i = 0; i < r.nextInt(40); i++) '${r.nextInt(6)}'];
        final d = diffText(a.join('\n'), b.join('\n'));
        expect([
          for (final l in d.lines)
            if (l.op != DiffOp.added) l.text,
        ], a);
        expect([
          for (final l in d.lines)
            if (l.op != DiffOp.removed) l.text,
        ], b);
        // Myers is minimal: edits = |a| + |b| − 2·LCS.
        final lcs = List.generate(
          a.length + 1,
          (_) => List.filled(b.length + 1, 0),
        );
        for (var i = a.length - 1; i >= 0; i--) {
          for (var j = b.length - 1; j >= 0; j--) {
            lcs[i][j] = a[i] == b[j]
                ? lcs[i + 1][j + 1] + 1
                : max(lcs[i + 1][j], lcs[i][j + 1]);
          }
        }
        expect(d.added + d.removed, a.length + b.length - 2 * lcs[0][0]);
      }
    });
    test('size and change limits', () {
      expect(
        () => diffText(List.filled(maxDiffLines + 1, 'x').join('\n'), ''),
        throwsFormatException,
      );
      final a = [for (var i = 0; i < 1500; i++) 'a$i'].join('\n');
      final b = [for (var i = 0; i < 1500; i++) 'b$i'].join('\n');
      expect(() => diffText(a, b), throwsFormatException);
      expect(tool('text-diff').run('a\nb', 'a\nc'), contains('-b\n+c'));
    });
  });

  group('cron', () {
    // Monday 2 November 2026, 08:50 UTC.
    final from = DateTime.utc(2026, 11, 2, 8, 50);
    test('explains in English and Vietnamese', () {
      String en(String s) => parseCron(s).describe();
      String vi(String s) => parseCron(s).describe(vi: true);
      expect(en('*/5 * * * *'), 'Every 5 minutes');
      expect(vi('*/5 * * * *'), 'Cứ 5 phút');
      expect(en('* * * * *'), 'Every minute');
      expect(en('0 9 * * 1-5'), 'At 09:00, on Monday through Friday');
      expect(vi('0 9 * * 1-5'), 'Lúc 09:00, vào thứ Hai đến thứ Sáu');
      expect(en('30 * * * *'), 'At minute 30 of every hour');
      expect(vi('30 * * * *'), 'Vào phút 30 mỗi giờ');
      expect(en('0 9,17 * * *'), 'At 09:00 and 17:00, every day');
      expect(en('@daily'), 'At 00:00, every day');
      expect(
        en('*/15 9-17 * * 1-5'),
        'Every 15 minutes, past hours 9 through 17, on Monday through Friday',
      );
      expect(
        en('0 0 * JAN,JUL SUN'),
        'At 00:00, on Sunday, in January and July',
      );
      expect(vi('0 0 1 * *'), 'Lúc 00:00, ngày 1 trong tháng');
      expect(en('0 0 13 * 5'), 'At 00:00, on day 13 of the month or on Friday');
      expect(en('*/10 * * * * *'), 'Every 10 seconds');
      expect(en('0 */2 * * *'), 'At minute 0, every 2 hours');
      expect(en('15 30 8 * * *'), 'At 08:30:15, every day');
    });
    test('next runs in a zone', () {
      final c = parseCron('*/15 9-17 * * 1-5');
      expect(c.next(3, _utc, from: from), [
        DateTime.utc(2026, 11, 2, 9),
        DateTime.utc(2026, 11, 2, 9, 15),
        DateTime.utc(2026, 11, 2, 9, 30),
      ]);
      // 09:00 in UTC+7 is 02:00 UTC; from 08:50 UTC it is tomorrow's.
      expect(parseCron('0 9 * * *').next(1, _vn, from: from), [
        DateTime.utc(2026, 11, 3, 2),
      ]);
      // Friday the 13th rule: either the 13th or a Friday.
      expect(parseCron('0 0 13 * 5').next(3, _utc, from: from), [
        DateTime.utc(2026, 11, 6),
        DateTime.utc(2026, 11, 13),
        DateTime.utc(2026, 11, 20),
      ]);
      expect(
        parseCron(
          '*/20 * * * * *',
        ).next(2, _utc, from: from.add(const Duration(seconds: 5))),
        [
          DateTime.utc(2026, 11, 2, 8, 50, 20),
          DateTime.utc(2026, 11, 2, 8, 50, 40),
        ],
      );
      expect(parseCron('0 0 29 2 *').next(1, _utc, from: from), [
        DateTime.utc(2028, 2, 29),
      ]);
      expect(parseCron('0 0 30 2 *').next(1, _utc, from: from), isEmpty);
      expect(parseCron('0 0 * * 7').next(1, _utc, from: from), [
        DateTime.utc(2026, 11, 8),
      ]);
    });
    test('clear errors per field', () {
      String message(String s) {
        try {
          parseCron(s);
        } on FormatException catch (e) {
          return e.message;
        }
        fail('$s parsed');
      }

      expect(message('60 * * * *'), contains('Minute: 60 is outside 0–59'));
      expect(message('* 24 * * *'), contains('Hour'));
      expect(message('* * 0 * *'), contains('Day of month'));
      expect(message('* * * 13 *'), contains('Month'));
      expect(message('* * * * 8'), contains('Day of week'));
      expect(message('5-1 * * * *'), contains('backwards'));
      expect(message('*/0 * * * *'), contains('step'));
      expect(message('MON * * * *'), contains('not a number or a name'));
      expect(message('? * * * *'), contains('"?"'));
      expect(message('1,,2 * * * *'), contains('empty'));
      expect(message('* * *'), contains('found 3'));
      expect(message('@reboot'), contains('startup'));
      expect(message('@often'), contains('Unknown macro'));
      expect(message('60 * * * *'), contains('Phút'));
    });
    test('the tool reports explanation and runs', () {
      final r = jsonDecode(tool('cron').run('@hourly', 'UTC 2'));
      expect(r['en'], 'At minute 0 of every hour');
      expect((r['next'] as List).length, 2);
      expect(r['fields']['Minute'], '0');
      expect(() => tool('cron').run('* * * * *', '0'), throwsFormatException);
      expect(cronReport(parseCron('0 9 * * *'), _vn, 1, from: from)['next'], [
        '2026-11-03T09:00:00.000+07:00',
      ]);
    });
  });

  group('number bases', () {
    test('2, 8, 10, 16 and any base', () {
      final c = convertBase('255');
      expect((c.hex, c.octal, c.binary), ('0xff', '0o377', '0b11111111'));
      expect(convertBase('0xFF_FF').decimal, '65535');
      expect(convertBase('0b1010').decimal, '10');
      expect(convertBase('0o755').decimal, '493');
      expect(convertBase('-42').hex, '-0x2a');
      expect(convertBase('255', base: 36).inBase, '73');
      expect(convertBase('zz', base: 36).decimal, '1295');
      expect(
        convertBase('0x${'f' * 64}').decimal,
        (BigInt.two.pow(256) - BigInt.one).toString(),
      );
    });
    test('two\'s complement at a width', () {
      final t = convertBase('-1', bits: 8).twos!;
      expect(
        (t.unsigned, t.signed, t.hex, t.binary),
        ('255', '-1', '0xff', '0b11111111'),
      );
      expect(convertBase('0xff', bits: 8).twos!.signed, '-1');
      expect(convertBase('5', bits: 8).twos!.binary, '0b00000101');
      expect(convertBase('-1', bits: 64).twos!.hex, '0xffffffffffffffff');
      expect(convertBase('-128', bits: 8).twos!.unsigned, '128');
      expect(() => convertBase('256', bits: 8), throwsFormatException);
      expect(() => convertBase('-129', bits: 8), throwsFormatException);
    });
    test('bad input', () {
      for (final bad in ['ff', '0x', '0b102', '1.5', '', '0xg']) {
        expect(() => convertBase(bad), throwsFormatException, reason: bad);
      }
      expect(() => convertBase('1', base: 37), throwsFormatException);
      expect(
        () => convertBase('1' * (maxBaseDigits + 1)),
        throwsFormatException,
      );
      expect(() => baseOptions('radix=2'), throwsFormatException);
    });
    test('the tool', () {
      final r = jsonDecode(tool('base-convert').run('-1', 'bits=16 base=2'));
      expect(r['twosComplementHex'], '0xffff');
      expect(r['base2'], '-1');
      expect(r['signed'], '-1');
    });
  });

  group('url parts', () {
    const url =
        'https://ana:pw@Example.com:8443/a%20b/c?q=caf%C3%A9&x=1&x=2&flag&sp=a+b#top%20part';
    test('splits and decodes every part', () {
      final p = parseUrl(url);
      expect(p.scheme, 'https');
      expect(p.user, 'ana');
      expect(p.hasPassword, isTrue);
      expect(p.host, 'example.com');
      expect(p.port, 8443);
      expect(p.path, '/a b/c');
      expect(p.query, [
        ('q', 'café'),
        ('x', '1'),
        ('x', '2'),
        ('flag', ''),
        ('sp', 'a b'),
      ]);
      expect(p.fragment, 'top part');
      final json = jsonEncode(p.toJson());
      expect(json, isNot(contains('pw')));
      expect(parseUrl('https://example.com').port, isNull);
    });
    test('rebuilds with edited parameters, other parts untouched', () {
      final p = parseUrl(url);
      expect(
        p.rebuild([('q', 'trà đá'), ('new', 'a&b=c')]),
        'https://ana:pw@example.com:8443/a%20b/c?q=tr%C3%A0+%C4%91%C3%A1&new=a%26b%3Dc#top%20part',
      );
      expect(
        p.rebuild([]),
        'https://ana:pw@example.com:8443/a%20b/c#top%20part',
      );
      final again = parseUrl(p.rebuild(p.query));
      expect(
        again.query.where((q) => q.$1 != 'flag'),
        p.query.where((q) => q.$1 != 'flag'),
      );
    });
    test('bad URLs are refused', () {
      for (final bad in [
        'example.com/x',
        'https://a b',
        '',
        'https://x/?a=%E0%A4%A',
      ]) {
        expect(() => parseUrl(bad), throwsFormatException, reason: bad);
      }
    });
    test('the tool rebuilds from a JSON query', () {
      final r = jsonDecode(
        tool('url-parse').run('https://x.dev/p?a=1', '[["a","2"],["b","3"]]'),
      );
      expect(r['url'], 'https://x.dev/p?a=2&b=3');
      expect(r['query'], [
        {'name': 'a', 'value': '1'},
      ]);
      expect(
        () => tool('url-parse').run('https://x.dev', '{"a":1}'),
        throwsFormatException,
      );
    });
  });

  group('hmac', () {
    // RFC 4231 test case 2.
    const msg = 'what do ya want for nothing?';
    test('SHA-256 and SHA-512, hex and Base64, key as text or hex', () {
      const sha256 =
          '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843';
      expect(hmacSign(msg, 'Jefe'), sha256);
      expect(hmacSign(msg, '4a656665', keyFormat: 'hex'), sha256);
      expect(hmacSign(msg, 'SmVmZQ==', keyFormat: 'base64'), sha256);
      expect(
        hmacSign(msg, 'Jefe', output: 'base64'),
        base64.encode([
          for (var i = 0; i < sha256.length; i += 2)
            int.parse(sha256.substring(i, i + 2), radix: 16),
        ]),
      );
      expect(
        hmacSign(msg, 'Jefe', hash: 'sha512'),
        '164b7a7bfcf819e2e395fbe73b56e0a387bd64222e831fd610270cd7ea250554'
        '9758bf75c05a994a6d034f65f8f0e6fdcaeab1a34d4a6b4b636e070a38bce737',
      );
    });
    test('errors never repeat the key', () {
      for (final (opts, why) in [
        ('{"key":"SECRETKEY","keyFormat":"hex"}', 'bad hex'),
        ('{"key":"SECRETKEY","hash":"md5"}', 'bad hash'),
        ('{"key":"SECRETKEY"', 'bad JSON'),
        ('{"key":""}', 'empty'),
      ]) {
        try {
          tool('hmac').run(msg, opts);
          fail(why);
        } on FormatException catch (e) {
          expect(e.message, isNot(contains('SECRET')), reason: why);
          expect('${e.source}', isNot(contains('SECRET')), reason: why);
        }
      }
      expect(tool('hmac').sensitive, isTrue);
      expect(
        tool('hmac').run(msg, jsonEncode({'key': 'Jefe', 'output': 'hex'})),
        startsWith('5bdcc1'),
      );
    });
  });
}
