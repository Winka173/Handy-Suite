import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:http/http.dart' as http;

enum DriveFailure { offline, authNeeded, quota, damaged, other }

class DriveException implements Exception {
  final DriveFailure failure;
  const DriveException(this.failure);
  @override
  String toString() => 'Drive sync: ${failure.name}';
}

abstract interface class DriveAuth {
  Future<String> token({bool fresh = false});
  Future<void> forget(String token);
}

/// Same SDK and appdata scope as Boards/Bookmark; tokens never enter storage,
/// logs, backups or URLs. Google owns account selection; no email is exposed.
class GoogleDriveAuth implements DriveAuth {
  const GoogleDriveAuth();
  static const scope = 'https://www.googleapis.com/auth/drive.appdata';
  static Future<void>? _ready;
  // Authorization-only Google Sign-In does not expose account identity.
  static String? get account => null;
  static Future<void> _init() async {
    try {
      await (_ready ??= GoogleSignIn.instance.initialize());
    } catch (_) {
      _ready = null;
      rethrow;
    }
  }

  static Future<bool> authorize() async {
    try {
      await _init();
      await GoogleSignIn.instance.authorizationClient.authorizeScopes([scope]);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> revoke() async {
    await _init();
    await GoogleSignIn.instance.disconnect();
  }

  @override
  Future<String> token({bool fresh = false}) async {
    try {
      await _init();
      final auth = await GoogleSignIn.instance.authorizationClient
          .authorizationForScopes([scope]);
      if (auth == null) throw const DriveException(DriveFailure.authNeeded);
      return auth.accessToken;
    } on DriveException {
      rethrow;
    } catch (_) {
      throw const DriveException(DriveFailure.authNeeded);
    }
  }

  @override
  Future<void> forget(String token) async => GoogleSignIn
      .instance
      .authorizationClient
      .clearAuthorizationToken(accessToken: token);
}

/// Flat app-scoped files in appDataFolder. Data is immutable and named by
/// device + content hash. Duplicate creates after a timeout are harmless only
/// when every copy has exactly the same bytes. Never PATCH a shared data file.
class DriveSyncProvider implements HabitSyncProvider {
  DriveSyncProvider({
    http.Client? client,
    DriveAuth auth = const GoogleDriveAuth(),
    Future<void> Function(Duration)? pause,
  }) : _http = client ?? http.Client(),
       _auth = auth,
       _pause = pause ?? Future<void>.delayed;
  static const _api = 'https://www.googleapis.com/drive/v3/files';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3/files';
  final http.Client _http;
  final DriveAuth _auth;
  final Future<void> Function(Duration) _pause;
  String? _token;
  void close() => _http.close();

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String>) call,
  ) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      _token ??= await _auth.token(fresh: attempt > 0);
      try {
        final res = await call({
          'Authorization': 'Bearer $_token',
        }).timeout(const Duration(seconds: 45));
        if (res.statusCode >= 200 && res.statusCode < 300) return res;
        if (res.statusCode == 401) {
          await _auth.forget(_token!);
          _token = null;
          if (attempt == 2) throw const DriveException(DriveFailure.authNeeded);
          continue;
        }
        if (res.statusCode == 403 && res.body.contains('storageQuotaExceeded'))
          throw const DriveException(DriveFailure.quota);
        if (res.statusCode == 429 || res.statusCode >= 500) {
          if (attempt == 2) throw const DriveException(DriveFailure.offline);
        } else {
          throw const DriveException(DriveFailure.other);
        }
      } on http.ClientException {
        if (attempt == 2) throw const DriveException(DriveFailure.offline);
      } on TimeoutException {
        if (attempt == 2) throw const DriveException(DriveFailure.offline);
      }
      await _pause(Duration(milliseconds: 250 * (1 << attempt)));
    }
    throw const DriveException(DriveFailure.offline);
  }

  Future<List<Map<String, dynamic>>> _files({String? name}) async {
    final out = <Map<String, dynamic>>[];
    String? page;
    final seen = <String>{};
    do {
      final uri = Uri.parse(_api).replace(
        queryParameters: {
          'spaces': 'appDataFolder',
          'q': name == null
              ? 'trashed = false'
              : "name = '${name.replaceAll("'", r"\'")}' and trashed = false",
          'fields': 'nextPageToken,files(id,name,version,size)',
          'pageSize': '1000',
          'pageToken': ?page,
        },
      );
      final res = await _send((h) => _http.get(uri, headers: h));
      final j = jsonDecode(res.body) as Map;
      if (j['files'] is! List) throw const DriveException(DriveFailure.damaged);
      out.addAll(
        (j['files'] as List).map((v) => Map<String, dynamic>.from(v as Map)),
      );
      page = j['nextPageToken'] as String?;
      if (page != null && !seen.add(page))
        throw const DriveException(DriveFailure.damaged);
      if (out.length > 10000)
        throw const FormatException('Drive history exceeds 10000 generations');
    } while (page != null);
    return out;
  }

  @override
  Future<Uint8List?> read(String path) async {
    final files = await _files(name: path);
    Uint8List? bytes;
    for (final f in files) {
      if (int.tryParse('${f['size']}') case final size? when size > backupLimit)
        throw const DriveException(DriveFailure.damaged);
      final res = await _send(
        (h) => _http.get(
          Uri.parse(
            '$_api/${Uri.encodeComponent(f['id'] as String)}?alt=media',
          ),
          headers: h,
        ),
      );
      if (res.bodyBytes.length > backupLimit ||
          bytes != null && !_equal(bytes, res.bodyBytes))
        throw const DriveException(DriveFailure.damaged);
      bytes = res.bodyBytes;
    }
    return bytes;
  }

  static bool _equal(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Future<void> put(String path, Uint8List bytes) async {
    if (!path.startsWith('$habitSyncRoot/') || bytes.length > backupLimit)
      throw const FormatException('Invalid Habit sync upload');
    final old = await read(path);
    if (old != null) {
      if (!_equal(old, bytes)) throw const DriveException(DriveFailure.damaged);
      return;
    }
    final metadata = jsonEncode({
      'name': path,
      'parents': ['appDataFolder'],
    });
    if (bytes.length > 5 * 1024 * 1024) {
      final start = await _send(
        (h) => _http.post(
          Uri.parse('$_upload?uploadType=resumable&fields=id,version'),
          headers: {
            ...h,
            'Content-Type': 'application/json',
            'X-Upload-Content-Type': 'application/json',
            'X-Upload-Content-Length': '${bytes.length}',
          },
          body: metadata,
        ),
      );
      final location = Uri.tryParse(start.headers['location'] ?? '');
      if (location == null ||
          location.scheme != 'https' ||
          location.host != 'www.googleapis.com')
        throw const DriveException(DriveFailure.damaged);
      await _send(
        (h) => _http.put(
          location,
          headers: {...h, 'Content-Type': 'application/json'},
          body: bytes,
        ),
      );
    } else {
      const boundary = 'handy-habit-sync-boundary';
      final body = BytesBuilder()
        ..add(
          utf8.encode(
            '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n--$boundary\r\nContent-Type: application/json\r\n\r\n',
          ),
        )
        ..add(bytes)
        ..add(utf8.encode('\r\n--$boundary--\r\n'));
      final payload = body.takeBytes();
      await _send(
        (h) => _http.post(
          Uri.parse('$_upload?uploadType=multipart&fields=id,version'),
          headers: {
            ...h,
            'Content-Type': 'multipart/related; boundary=$boundary',
          },
          body: payload,
        ),
      );
    }
    // Read-back catches incomplete uploads before a successful sync is recorded.
    final stored = await read(path);
    if (stored == null || !_equal(stored, bytes))
      throw const DriveException(DriveFailure.damaged);
  }

  @override
  Future<Set<String>> list(String folder) async => {
    for (final f in await _files())
      if ((f['name'] as String).startsWith('$folder/') &&
          !(f['name'] as String).substring(folder.length + 1).contains('/'))
        (f['name'] as String).substring(folder.length + 1),
  };
}
