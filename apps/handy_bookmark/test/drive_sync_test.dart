import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:handy_bookmark/controller.dart';
import 'package:handy_bookmark/sync/drive_provider.dart';
import 'package:handy_bookmark/sync/drive_sync.dart';
import 'package:handy_bookmark/sync/sync_service.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'controller_test.dart' show TestStore, TestInbox;

/// Google Drive's app folder, in memory, answering the calls the provider
/// makes (list by name, download, create, update).
class FakeDrive {
  final files = <String, ({String name, Uint8List bytes, int version})>{};
  var _ids = 0;
  var tokens = <String>[];

  /// Answers every call with this status (and body) instead.
  int? failWith;
  String failBody = '';

  /// The next call answers 401 once (a stale token).
  bool expireOnce = false;

  late final client = MockClient((req) async {
    tokens.add(req.headers['Authorization'] ?? '');
    if (expireOnce) {
      expireOnce = false;
      return http.Response('', 401);
    }
    if (failWith != null) return http.Response(failBody, failWith!);
    final u = req.url;
    if (req.method == 'GET' && u.path == '/drive/v3/files') {
      final q = u.queryParameters['q']!;
      final name = RegExp(r"name = '(.*)' and").firstMatch(q)?.group(1);
      final list = [
        for (final e in files.entries)
          if (name == null || e.value.name == name)
            {
              'id': e.key,
              'name': e.value.name,
              'version': '${e.value.version}',
            },
      ];
      return http.Response(jsonEncode({'files': list}), 200);
    }
    if (req.method == 'GET' && u.queryParameters['alt'] == 'media') {
      final f = files[u.pathSegments.last];
      return f == null
          ? http.Response('', 404)
          : http.Response.bytes(f.bytes, 200);
    }
    if (req.method == 'PATCH') {
      final id = u.pathSegments.last;
      final f = files[id]!;
      files[id] = (name: f.name, bytes: req.bodyBytes, version: f.version + 1);
      return http.Response(jsonEncode({'version': '${f.version + 1}'}), 200);
    }
    if (req.method == 'POST') {
      // multipart/related: --b, headers, the JSON metadata, --b, headers,
      // the bytes, --b--.
      final raw = latin1.decode(req.bodyBytes);
      final metaStart = raw.indexOf('\r\n\r\n') + 4;
      final metaEnd = raw.indexOf('\r\n--', metaStart);
      final meta = jsonDecode(raw.substring(metaStart, metaEnd)) as Map;
      final bodyStart = raw.indexOf('\r\n\r\n', metaEnd) + 4;
      final body = raw.substring(bodyStart, raw.lastIndexOf('\r\n--'));
      final id = 'f${++_ids}';
      files[id] = (
        name: meta['name'] as String,
        bytes: Uint8List.fromList(latin1.encode(body)),
        version: 1,
      );
      return http.Response(jsonEncode({'id': id, 'version': '1'}), 200);
    }
    return http.Response('', 400);
  });
}

class FixedAuth implements DriveAuth {
  var n = 0;
  final forgotten = <String>[];
  @override
  Future<String> token({bool fresh = false}) async => 'token-${++n}';
  @override
  Future<void> forget(String token) async => forgotten.add(token);
}

Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

Future<SaveController> device() async {
  final c = SaveController(open: () async => TestStore(), shares: TestInbox());
  await c.initialize();
  c.preferences['automaticMetadata'] = false;
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('DriveSyncProvider', () {
    late FakeDrive drive;
    late FixedAuth auth;
    late DriveSyncProvider p;
    setUp(() {
      drive = FakeDrive();
      auth = FixedAuth();
      p = DriveSyncProvider(client: drive.client, auth: auth);
    });

    test('reads, creates, and writes against the version read', () async {
      expect(await p.read('handy-bookmark/library.json'), isNull);
      final v1 = await p.write(
        'handy-bookmark/library.json',
        bytes('{"a":1}'),
        ifAbsent: true,
      );
      final file = (await p.read('handy-bookmark/library.json'))!;
      expect(utf8.decode(file.bytes), '{"a":1}');
      expect(file.etag, v1);
      // Created once only: another device creating it too is a conflict.
      expect(
        () =>
            p.write('handy-bookmark/library.json', bytes('x'), ifAbsent: true),
        throwsA(isA<SyncConflict>()),
      );
      final v2 = await p.write(
        'handy-bookmark/library.json',
        bytes('{"a":2}'),
        ifMatch: v1,
      );
      expect(v2, isNot(v1));
      // Written by someone else since: refused.
      expect(
        () => p.write('handy-bookmark/library.json', bytes('x'), ifMatch: v1),
        throwsA(isA<SyncConflict>()),
      );
      expect(drive.files, hasLength(1), reason: 'never a second copy');
    });

    test('lists the pictures under a folder, binary bytes intact', () async {
      final picture = Uint8List.fromList(List.generate(256, (i) => i));
      await p.write('handy-bookmark/media/abc', picture);
      await p.write('handy-bookmark/library.json', bytes('{}'));
      expect(await p.list('handy-bookmark/media'), {'abc'});
      expect((await p.read('handy-bookmark/media/abc'))!.bytes, picture);
    });

    test('a stale token is dropped and a fresh one asked for once', () async {
      await p.write('handy-bookmark/library.json', bytes('{}'));
      drive.expireOnce = true;
      expect(await p.read('handy-bookmark/library.json'), isNotNull);
      expect(auth.forgotten, ['token-1']);
      expect(drive.tokens.last, 'Bearer token-2');
    });

    test('Drive full, no network and refused access say so', () async {
      drive
        ..failWith = 403
        ..failBody = '{"error":{"errors":[{"reason":"storageQuotaExceeded"}]}}';
      await expectLater(
        p.read('handy-bookmark/library.json'),
        throwsA(
          isA<DriveException>().having(
            (e) => e.failure,
            'f',
            DriveFailure.quota,
          ),
        ),
      );
      drive.failWith = 503;
      await expectLater(
        p.read('x'),
        throwsA(
          isA<DriveException>().having(
            (e) => e.failure,
            'f',
            DriveFailure.offline,
          ),
        ),
      );
      final offline = DriveSyncProvider(
        client: MockClient((_) => throw http.ClientException('no route')),
        auth: auth,
      );
      await expectLater(
        offline.read('x'),
        throwsA(
          isA<DriveException>().having(
            (e) => e.failure,
            'f',
            DriveFailure.offline,
          ),
        ),
      );
      drive
        ..failWith = 401
        ..failBody = '';
      await expectLater(
        p.read('x'),
        throwsA(
          isA<DriveException>().having(
            (e) => e.failure,
            'f',
            DriveFailure.authNeeded,
          ),
        ),
      );
    });

    test('two devices end up with each other’s links through it', () async {
      final a = await device(), b = await device();
      await a.quickSave('https://a.example/one');
      await b.quickSave('https://b.example/two');
      final pa = DriveSyncProvider(client: drive.client, auth: FixedAuth());
      final pb = DriveSyncProvider(client: drive.client, auth: FixedAuth());
      await syncLibrary(a, pa);
      await syncLibrary(b, pb);
      await syncLibrary(a, pa);
      for (final c in [a, b]) {
        expect(c.library!.bookmarks.map((x) => x.originalUrl).toSet(), {
          'https://a.example/one',
          'https://b.example/two',
        });
      }
    });
  });

  group('DriveSync', () {
    test('switching on asks for access first; a no changes nothing', () async {
      final c = await device();
      final d = DriveSync(
        c,
        provider: MemorySyncProvider.new,
        authorize: () async => false,
      );
      addTearDown(d.dispose);
      expect(await d.enable(), isFalse);
      expect(d.enabled, isFalse);
      expect(d.state, DriveSyncState.off);
    });

    test('a change syncs a while after the last one; settings alone do '
        'not', () async {
      final remote = MemorySyncProvider();
      final c = await device();
      // Half a minute in the app; a quarter second here.
      final d = DriveSync(
        c,
        provider: () => remote,
        authorize: () async => true,
        revoke: () async {},
        delay: const Duration(milliseconds: 250),
      );
      addTearDown(d.dispose);
      c.addListener(d.changed);
      expect(await d.enable(), isTrue);
      expect(d.enabled, isTrue);
      expect(d.state, DriveSyncState.idle);
      expect(d.lastSync, isNotNull);
      Future<void> settled() async {
        while (d.state == DriveSyncState.syncing) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }

      final writes = remote.writes;
      await c.quickSave('https://a.example/new');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(remote.writes, writes, reason: 'not yet');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await settled();
      expect(remote.writes, writes + 1);

      // A settings change is not a library change.
      await c.update((l) => l, prefs: {...c.preferences, 'theme': 'dark'});
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await settled();
      expect(remote.writes, writes + 1);

      await d.disable(forget: true);
      expect(d.enabled, isFalse);
      expect(d.state, DriveSyncState.off);
      expect(c.library!.bookmarks, isNotEmpty, reason: 'nothing deleted');
    });

    test('Drive trouble becomes a state; the library is untouched', () async {
      final c = await device();
      await c.quickSave('https://a.example/one');
      final d = DriveSync(
        c,
        provider: _Failing.new,
        authorize: () async => true,
      );
      addTearDown(d.dispose);
      await d.enable();
      expect(d.state, DriveSyncState.authNeeded);
      expect(c.library!.bookmarks, hasLength(1));
    });
  });
}

class _Failing implements SyncProvider {
  @override
  Future<RemoteFile?> read(String path) =>
      throw const DriveException(DriveFailure.authNeeded);
  @override
  Future<String> write(
    String path,
    Uint8List bytes, {
    String? ifMatch,
    bool ifAbsent = false,
  }) => throw const DriveException(DriveFailure.authNeeded);
  @override
  Future<Set<String>> list(String folder) =>
      throw const DriveException(DriveFailure.authNeeded);
}
