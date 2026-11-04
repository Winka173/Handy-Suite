import 'package:flutter_test/flutter_test.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';

final secretRequest = ApiRequest(
  id: 'r1',
  name: 'Orders',
  method: 'POST',
  url: 'https://me:pw@api.example.com/orders?token=abc&page=2#frag',
  headers: const {'Authorization': 'Bearer s3cret', 'X-Key': 'k-123'},
  body: '{"card": "4111"}',
  auth: const ApiAuth.basic(username: 'me', password: 'pw'),
);

void main() {
  final at = DateTime.utc(2026, 11, 4, 9);

  test('off keeps nothing', () {
    final h = recordSend(SendHistory(), secretRequest, at: at, status: 200);
    expect(h.items, isEmpty);
  });

  test('a send is kept without secrets, values or bodies', () {
    final h = recordSend(
      SendHistory(on: true),
      secretRequest,
      at: at,
      status: 201,
      elapsedMs: 120,
      bytes: 512,
    );
    final stored = exportSendHistory(h);
    for (final secret in ['s3cret', 'k-123', '4111', 'abc', 'pw', 'frag']) {
      expect(stored, isNot(contains(secret)), reason: secret);
    }
    final back = parseSendHistory(stored);
    expect(back.on, isTrue);
    final i = back.items.single;
    expect(i.method, 'POST');
    expect(i.status, 201);
    expect(i.url, 'https://api.example.com/orders?token&page');
    expect(i.at, '2026-11-04T09:00:00.000Z');
  });

  test('environment templates stay templates', () {
    final r = ApiRequest(
      id: 'r2',
      name: 'Me',
      url: '{{base}}/me?key={{apiKey}}',
    );
    final h = recordSend(SendHistory(on: true), r, at: at);
    expect(h.items.single.url, '{{base}}/me');
    expect(h.items.single.status, isNull);
  });

  test('newest first, capped, and turning off empties it', () {
    var h = SendHistory(on: true);
    for (var i = 0; i < sendHistoryLimit + 5; i++) {
      h = recordSend(
        h,
        ApiRequest(id: 'r$i', name: 'n$i', url: 'https://a.example/$i'),
        at: at.add(Duration(seconds: i)),
        status: 200,
      );
    }
    expect(h.items, hasLength(sendHistoryLimit));
    expect(h.items.first.requestId, 'r${sendHistoryLimit + 4}');
    final off = switchSendHistory(h, false);
    expect(off.on, isFalse);
    expect(off.items, isEmpty);
  });

  test('malformed history fails whole', () {
    expect(() => parseSendHistory('{"version":2}'), throwsFormatException);
    expect(
      () => parseSendHistory(
        '{"version":1,"on":true,"items":[{"at":"x","requestId":"a","name":"","method":"GET","url":"u","elapsedMs":0,"bytes":0}]}',
      ),
      throwsFormatException,
    );
  });
}
