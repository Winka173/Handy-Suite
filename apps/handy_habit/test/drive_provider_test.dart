import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_habit/sync/drive_provider.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class Auth implements DriveAuth {
  int forgotten = 0;
  @override
  Future<String> token({bool fresh = false}) async =>
      fresh ? 'fresh-test-token' : 'test-token';
  @override
  Future<void> forget(String token) async {
    forgotten++;
  }
}

void main() {
  test('appdata-only complete pagination filters app-scoped paths', () async {
    var calls = 0;
    final p = DriveSyncProvider(
      auth: Auth(),
      client: MockClient((r) async {
        expect(r.url.queryParameters['spaces'], 'appDataFolder');
        expect(r.url.queryParameters['q'], 'trashed = false');
        calls++;
        return http.Response(
          jsonEncode({
            'files': [
              {
                'id': '$calls',
                'name': calls == 1
                    ? 'handy-habit/commits/a.json'
                    : 'other-app/file.json',
              },
            ],
            if (calls == 1) 'nextPageToken': 'next',
          }),
          200,
        );
      }),
    );
    addTearDown(p.close);
    expect(await p.list('$habitSyncRoot/commits'), {'a.json'});
    expect(calls, 2);
    expect(
      GoogleDriveAuth.scope,
      'https://www.googleapis.com/auth/drive.appdata',
    );
  });
  test('401 forgets refused token and retries once authorized', () async {
    final auth = Auth();
    var calls = 0;
    final p = DriveSyncProvider(
      auth: auth,
      client: MockClient((r) async {
        calls++;
        return calls == 1
            ? http.Response('', 401)
            : http.Response('{"files":[]}', 200);
      }),
    );
    addTearDown(p.close);
    expect(await p.list('$habitSyncRoot/commits'), isEmpty);
    expect(auth.forgotten, 1);
    expect(calls, 2);
  });
  test('retry transient server failures with bounded backoff', () async {
    var calls = 0;
    final pauses = <Duration>[];
    final p = DriveSyncProvider(
      auth: Auth(),
      pause: (d) async {
        pauses.add(d);
      },
      client: MockClient((r) async {
        calls++;
        return calls < 3
            ? http.Response('', 503)
            : http.Response('{"files":[]}', 200);
      }),
    );
    addTearDown(p.close);
    expect(await p.list('$habitSyncRoot/commits'), isEmpty);
    expect(calls, 3);
    expect(pauses, hasLength(2));
  });
  test(
    'quota and revoked authorization map to distinct actionable errors',
    () async {
      for (final status in [401, 403]) {
        final p = DriveSyncProvider(
          auth: Auth(),
          client: MockClient(
            (r) async => http.Response('storageQuotaExceeded', status),
          ),
        );
        addTearDown(p.close);
        await expectLater(
          p.list('$habitSyncRoot/commits'),
          throwsA(
            isA<DriveException>().having(
              (e) => e.failure,
              'failure',
              status == 401 ? DriveFailure.authNeeded : DriveFailure.quota,
            ),
          ),
        );
      }
    },
  );
  test(
    'immutable multipart upload is app-scoped, read back, never PATCHed',
    () async {
      Uint8List? stored;
      String? name;
      var posts = 0;
      final p = DriveSyncProvider(
        auth: Auth(),
        client: MockClient((r) async {
          expect(r.method, isNot('PATCH'));
          if (r.method == 'POST') {
            posts++;
            final raw = r.body;
            expect(raw, contains('"parents":["appDataFolder"]'));
            final sections = raw.split('\r\n\r\n');
            final meta = jsonDecode(sections[1].split('\r\n--').first) as Map;
            name = meta['name'] as String;
            stored = Uint8List.fromList(
              utf8.encode(sections[2].split('\r\n--').first),
            );
            return http.Response('{"id":"file","version":"1"}', 200);
          }
          if (r.url.queryParameters['alt'] == 'media')
            return http.Response.bytes(stored!, 200);
          expect(r.url.queryParameters['spaces'], 'appDataFolder');
          return http.Response(
            jsonEncode({
              'files': [
                if (stored != null)
                  {'id': 'file', 'name': name, 'size': '${stored!.length}'},
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(p.close);
      final bytes = Uint8List.fromList(utf8.encode('{"test":true}'));
      await p.put('$habitSyncRoot/commits/test.json', bytes);
      await p.put('$habitSyncRoot/commits/test.json', bytes);
      expect(posts, 1);
      expect(stored, bytes);
      await expectLater(
        p.put('$habitSyncRoot/commits/test.json', Uint8List.fromList([1])),
        throwsA(isA<DriveException>()),
      );
    },
  );
  test(
    'different duplicate Drive file bodies refuse, never select newest',
    () async {
      final p = DriveSyncProvider(
        auth: Auth(),
        client: MockClient((r) async {
          if (r.url.queryParameters['alt'] == 'media')
            return http.Response(r.url.path.endsWith('a') ? 'one' : 'two', 200);
          return http.Response('{"files":[{"id":"a"},{"id":"b"}]}', 200);
        }),
      );
      addTearDown(p.close);
      await expectLater(
        p.read('$habitSyncRoot/commits/test.json'),
        throwsA(isA<DriveException>()),
      );
    },
  );
  test(
    'partial/repeating pagination and network failures refuse safely',
    () async {
      final p = DriveSyncProvider(
        auth: Auth(),
        pause: (_) async {},
        client: MockClient(
          (r) async =>
              http.Response('{"files":[],"nextPageToken":"repeat"}', 200),
        ),
      );
      addTearDown(p.close);
      await expectLater(
        p.list('$habitSyncRoot/commits'),
        throwsA(isA<DriveException>()),
      );
      final offline = DriveSyncProvider(
        auth: Auth(),
        pause: (_) async {},
        client: MockClient((r) async => throw http.ClientException('offline')),
      );
      addTearDown(offline.close);
      await expectLater(
        offline.list('$habitSyncRoot/commits'),
        throwsA(
          isA<DriveException>().having(
            (e) => e.failure,
            'failure',
            DriveFailure.offline,
          ),
        ),
      );
    },
  );
}
