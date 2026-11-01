import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';

ApiRequest request({
  String url = 'https://example.com/path',
  String body = '',
  Map<String, String> headers = const {},
  ApiAuth auth = const ApiAuth.none(),
}) => ApiRequest(
  id: 'r1',
  name: 'Example',
  url: url,
  body: body,
  headers: headers,
  auth: auth,
);
void main() {
  test(
    'Basic Unicode credentials encoded UTF8; bearer/key auth preparation',
    () {
      expect(
        prepareRequest(
          request(
            auth: const ApiAuth.basic(username: 'máy', password: 'secret'),
          ),
        ).headers['Authorization'],
        'Basic ${base64.encode(utf8.encode('máy:secret'))}',
      );
      expect(
        prepareRequest(
          request(auth: const ApiAuth.bearer('secret')),
        ).headers['Authorization'],
        'Bearer secret',
      );
      expect(
        prepareRequest(
          request(
            auth: const ApiAuth.apiKey(name: 'X-Key', value: 'secret'),
          ),
        ).headers['X-Key'],
        'secret',
      );
      expect(
        Uri.parse(
          prepareRequest(
            request(
              url: 'https://example.com/?a=1&a=2',
              auth: const ApiAuth.apiKey(
                name: 'key',
                value: 'secret',
                location: 'query',
              ),
            ),
          ).url,
        ).queryParametersAll,
        {
          'a': ['1', '2'],
          'key': ['secret'],
        },
      );
    },
  );
  for (final url in [
    'http://example.com',
    'file:///secret',
    'https://u:p@example.com',
    'https://example.com/#token',
    'javascript:alert(1)',
    'https://',
  ]) {
    test(
      'reject unsafe URL $url',
      () => expect(
        () => prepareRequest(request(url: url)),
        throwsFormatException,
      ),
    );
  }
  test(
    'header validation rejects injection, managed, duplicate and excess',
    () {
      for (final h in [
        {'X': 'a\r\nb'},
        {'Host': 'x'},
        {'Content-Length': '1'},
        {'bad key': 'x'},
        {'X': 'a', 'x': 'b'},
        {for (var i = 0; i < 101; i++) 'X-$i': 'v'},
      ]) {
        expect(() => validateHeaders(h), throwsFormatException);
      }
    },
  );
  test('auth conflicts and invalid fields reject without echoing secrets', () {
    for (final r in [
      request(
        auth: const ApiAuth.basic(username: 'u:p', password: 'VERY_SECRET'),
      ),
      request(auth: const ApiAuth.bearer('')),
      request(
        auth: const ApiAuth.apiKey(name: '', value: 'VERY_SECRET'),
      ),
      request(
        auth: const ApiAuth.apiKey(name: 'X', value: 'x'),
        headers: {'x': 'y'},
      ),
      request(
        auth: const ApiAuth.bearer('VERY_SECRET'),
        headers: {'authorization': 'other'},
      ),
      request(auth: const ApiAuth.bearer('VERY_SECRET\n')),
    ]) {
      try {
        prepareRequest(r);
        fail('must reject');
      } catch (e) {
        expect(e, isA<FormatException>());
        expect('$e', isNot(contains('VERY_SECRET')));
      }
    }
  });
  test('environment substitution scalar-only including auth and body', () {
    final r = request(
      url: '{{BASE}}/x',
      headers: {'X-Test': '{{VALUE}}'},
      body: '{"v":"{{VALUE}}"}',
      auth: const ApiAuth.bearer('{{TOKEN}}'),
    );
    final prepared = prepareRequest(r, {
      'BASE': 'https://example.com',
      'VALUE': 'literal',
      'TOKEN': 'secret',
    });
    expect(prepared.url, 'https://example.com/x');
    expect(prepared.body, '{"v":"literal"}');
    expect(prepared.headers, {
      'X-Test': 'literal',
      'Authorization': 'Bearer secret',
    });
    expect(r.url, '{{BASE}}/x');
    expect(
      () => prepareRequest(r, {'BASE': 'https://example.com'}),
      throwsFormatException,
    );
    expect(
      () => prepareRequest(r, {
        'BASE': 'https://example.com',
        'VALUE': '\r\ninjected',
        'TOKEN': 's',
      }),
      throwsFormatException,
    );
  });
  test(
    'workspace default export removes ALL values and body, credentials and URL query',
    () {
      final r = request(
        url:
            'https://user:pass@example.com/x?session=QUERY_SECRET#FRAGMENT_SECRET',
        body: 'BODY_SECRET',
        headers: {'Content-Type': 'HEADER_SECRET', 'X-Custom': 'HEADER_SECRET'},
        auth: const ApiAuth.basic(
          username: 'USER_SECRET',
          password: 'PASSWORD_SECRET',
        ),
      );
      final w = ApiWorkspace(
        requests: [r],
        environments: [
          ApiEnvironment(
            id: 'e',
            name: 'Local',
            values: {'TOKEN': 'ENV_SECRET'},
          ),
        ],
      );
      final exported = exportWorkspace(w);
      for (final secret in [
        'QUERY_SECRET',
        'FRAGMENT_SECRET',
        'BODY_SECRET',
        'HEADER_SECRET',
        'USER_SECRET',
        'PASSWORD_SECRET',
        'ENV_SECRET',
        'user:pass',
      ]) {
        expect(exported, isNot(contains(secret)));
      }
      final parsed = parseWorkspace(exported);
      expect(parsed.requests.single.body, '');
      expect(
        parsed.requests.single.headers.values.every((v) => v.isEmpty),
        true,
      );
      expect(parsed.environments.single.values, {'TOKEN': ''});
      expect(exportWorkspace(parsed), exported);
      expect(w.requests.single.body, 'BODY_SECRET');
    },
  );
  test(
    'workspace session JSON legacy exact roundtrip then safe persistent CRUD',
    () {
      final w = saveEnvironment(
        saveRequest(
          emptyWorkspace(),
          request(auth: const ApiAuth.bearer('session-secret')),
        ),
        ApiEnvironment(
          id: 'env',
          name: 'Env',
          values: {'BASE': 'https://example.com'},
        ),
      );
      final same = parseWorkspace(jsonEncode(w.toJson()));
      expect(same.requests.single.auth.token, 'session-secret');
      expect(same.environments.single.values['BASE'], 'https://example.com');
      expect(removeRequest(w, 'r1').requests, isEmpty);
      expect(removeEnvironment(w, 'env').environments, isEmpty);
      expect(w.requests, hasLength(1));
      expect(() => w.requests.clear(), throwsUnsupportedError);
      expect(
        () => w.environments.single.values.clear(),
        throwsUnsupportedError,
      );
    },
  );
  test('workspace duplicate and invalid env names limits reject', () {
    final w = ApiWorkspace(requests: [request(), request()]);
    expect(() => parseWorkspace(jsonEncode(w.toJson())), throwsFormatException);
    expect(
      () => saveEnvironment(
        emptyWorkspace(),
        ApiEnvironment(id: 'e', name: 'Env', values: {'bad-key': 'x'}),
      ),
      throwsFormatException,
    );
    expect(
      () => parseWorkspace('{"version":2,"requests":[],"environments":[]}'),
      throwsFormatException,
    );
    expect(() => parseWorkspace('🧪' * 500001), throwsFormatException);
    expect(
      () => saveRequest(emptyWorkspace(), request().copyWith(id: 'bad id')),
      throwsFormatException,
    );
  });
  test(
    'common cURL JSON quoted apostrophe and multiline continuation import',
    () {
      final r = importCurl(
        "curl -s -S -X POST 'https://example.com/x' \\\n -H 'X-Test: hello' --json '{\"name\":\"O'\\''Brien\"}'",
      );
      expect(r.method, 'POST');
      expect(jsonDecode(r.body), {'name': "O'Brien"});
      expect(r.headers, {
        'X-Test': 'hello',
        'Content-Type': 'application/json',
      });
      expect(
        importCurl("curl --user 'u:p:more' https://example.com").auth.password,
        'p:more',
      );
      expect(importCurl('curl -I --url https://example.com').method, 'HEAD');
    },
  );
  test('cURL sanitized export reimports structure without session secrets', () {
    final r = request(
      url: 'https://example.com/?key=URL_SECRET',
      body: 'BODY_SECRET',
      headers: {'Authorization': 'HEADER_SECRET', 'X-Key': 'KEY_SECRET'},
      auth: const ApiAuth.none(),
    ).copyWith(method: 'POST');
    final out = exportCurl(r);
    expect(out, startsWith('curl -X POST'));
    for (final s in [
      'URL_SECRET',
      'BODY_SECRET',
      'HEADER_SECRET',
      'KEY_SECRET',
    ]) {
      expect(out, isNot(contains(s)));
    }
    final imported = importCurl(out);
    expect(imported.method, 'POST');
    expect(imported.body, '');
    expect(imported.headers, {'Authorization': '', 'X-Key': ''});
    expect(exportCurl(imported), out);
  });
  for (final bad in [
    "curl https://example.com; echo secret",
    'curl "https://example.com/\$(whoami)"',
    'curl https://example.com | sh',
    'curl -L https://example.com',
    'curl --output file https://example.com',
    "curl --data '@secret' https://example.com",
    'curl https://example.com https://second.com',
    'curl https://example.com --url https://second.com',
    "curl -d '' -d second https://example.com",
    'curl -H "X: a" -H "x: b" https://example.com',
    'curl "unclosed',
    'curl https://example.com\necho hi',
    'wget https://example.com',
  ]) {
    test(
      'cURL rejects shell/file/unsupported $bad',
      () => expect(() => importCurl(bad), throwsFormatException),
    );
  }
  test('sanitized URLs keep their shape: no stray ?# and no query values', () {
    String clean(String url) =>
        sanitizeRequest(ApiRequest(id: 'r1', name: 'n', url: url)).url;
    expect(
      clean('https://api.example.com/v1/orders/1042'),
      'https://api.example.com/v1/orders/1042',
    );
    expect(
      clean('https://api.example.com/a?token=secret#frag'),
      'https://api.example.com/a?token',
    );
    expect(
      prepareRequest(
        sanitizeRequest(
          ApiRequest(id: 'r1', name: 'n', url: 'https://api.example.com/v1'),
        ),
      ).url,
      'https://api.example.com/v1',
    );
  });
}
