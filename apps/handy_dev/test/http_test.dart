import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:handy_dev/http_transport.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_core/handy_core.dart';

void main() {
  test(
    'HTTPS request sends prepared auth and body without following redirects',
    () async {
      late http.Request captured;
      final transport = HttpTransport(
        clientFactory: () => MockClient((r) async {
          captured = r;
          return http.Response('{"ok":true}', 200);
        }),
      );
      final request = prepareRequest(
        ApiRequest(
          id: 'x',
          name: 'x',
          url: 'https://example.com',
          method: 'POST',
          body: '{"a":1}',
          headers: {'Content-Type': 'application/json'},
          auth: const ApiAuth.bearer('secret'),
        ),
      );
      final response = await transport.send(request);
      expect(captured.headers['Authorization'], 'Bearer secret');
      expect(captured.followRedirects, false);
      expect(response.status, 200);
      expect(jsonDecode(response.body), {'ok': true});
    },
  );
  test(
    'oversized actual response is rejected independent of advertised header',
    () async {
      final client = MockClient.streaming(
        (request, body) async => http.StreamedResponse(
          Stream.fromIterable([
            List.filled(600000, 65),
            List.filled(600000, 66),
          ]),
          200,
        ),
      );
      final t = HttpTransport(clientFactory: () => client);
      await expectLater(
        t.send(
          prepareRequest(
            ApiRequest(id: 'x', name: 'x', url: 'https://example.com'),
          ),
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'timeout errors and connection errors never include credential URL',
    () async {
      final t = HttpTransport(
        clientFactory: () => MockClient((r) async {
          throw Exception('LEAK Bearer abc https://example.com/?secret=secret');
        }),
      );
      await expectLater(
        t.send(
          prepareRequest(
            ApiRequest(
              id: 'x',
              name: 'x',
              url: 'https://example.com/?secret=secret',
            ),
          ),
        ),
        throwsA(
          predicate(
            (e) =>
                !e.toString().contains('LEAK') &&
                !e.toString().contains('?secret=secret'),
          ),
        ),
      );
    },
  );
  test('timeout closes transport and permits retry', () async {
    var count = 0;
    final t = HttpTransport(
      clientFactory: () => MockClient((r) async {
        if (count++ == 0)
          await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response('ok', 200);
      }),
    );
    final p = prepareRequest(
      ApiRequest(id: 'x', name: 'x', url: 'https://example.com'),
    );
    await expectLater(
      t.send(p, timeout: const Duration(milliseconds: 1)),
      throwsA(isA<TimeoutException>()),
    );
    expect((await t.send(p)).body, 'ok');
  });
  test('explicit cancellation cannot return a successful response', () async {
    final gate = Completer<void>();
    final t = HttpTransport(
      clientFactory: () => MockClient((r) async {
        await gate.future;
        return http.Response('late', 200);
      }),
    );
    final response = t.send(
      prepareRequest(
        ApiRequest(id: 'x', name: 'x', url: 'https://example.com'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    t.cancel();
    gate.complete();
    await expectLater(response, throwsA(isA<Cancelled>()));
  });
}
