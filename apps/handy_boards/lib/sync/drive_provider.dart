import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:http/http.dart' as http;

/// Why a Google Drive sync could not finish, in terms Settings can explain.
enum DriveFailure {
  /// No network, or Drive did not answer.
  offline,

  /// The person needs to allow access again (signed out, revoked).
  authNeeded,

  /// Their Drive is full.
  quota,

  /// Anything else; nothing on the device was changed.
  other,
}

class DriveException implements Exception {
  const DriveException(this.failure, [this.detail = '']);
  final DriveFailure failure;
  final String detail;
  @override
  String toString() =>
      'DriveException($failure${detail.isEmpty ? '' : ': $detail'})';
}

/// Access tokens for Drive's app folder. [GoogleDriveAuth] asks Google;
/// tests give a fixed one.
abstract class DriveAuth {
  /// A token for [GoogleDriveAuth.scope]; [fresh] asks for a new one.
  Future<String> token({bool fresh = false});

  /// Drops a token Drive refused, so the next one is fresh.
  Future<void> forget(String token);
}

/// Google Sign-In's authorization for `drive.appdata` only: the hidden app
/// folder of the person's own Drive. Handy Boards cannot see their other
/// Drive files, and they can delete its data from Drive's settings
/// (Manage apps).
///
/// Needs Android OAuth clients for this package and its signing
/// certificates in Google Cloud (docs/HANDY_BOARDS_RELEASE.md).
class GoogleDriveAuth implements DriveAuth {
  const GoogleDriveAuth();

  static const scope = 'https://www.googleapis.com/auth/drive.appdata';
  static bool _ready = false;

  static Future<void> _init() async {
    if (_ready) return;
    await GoogleSignIn.instance.initialize();
    _ready = true;
  }

  /// Asks the person to let Handy Boards use its Drive app folder.
  /// False when they say no or this device cannot.
  static Future<bool> authorize() async {
    try {
      await _init();
      await GoogleSignIn.instance.authorizationClient.authorizeScopes([scope]);
      return true;
    } catch (e) {
      debugPrint('Drive authorization failed: $e');
      return false;
    }
  }

  /// Gives the access back (sync switched off and the person asked to).
  static Future<void> revoke() async {
    try {
      await _init();
      await GoogleSignIn.instance.disconnect();
    } catch (e) {
      debugPrint('Drive revoke failed: $e');
    }
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
    } catch (e) {
      throw DriveException(DriveFailure.authNeeded, '$e');
    }
  }

  @override
  Future<void> forget(String token) async {
    try {
      await GoogleSignIn.instance.authorizationClient.clearAuthorizationToken(
        accessToken: token,
      );
    } catch (_) {}
  }
}

/// The sync folder ([syncRoot]) kept in Google Drive's hidden app folder
/// (`appDataFolder`). Drive holds flat files, so a path is the file's name.
/// Drive v3 has no conditional write: [write] checks the file's version
/// just before writing, so a write from another device in that moment is
/// caught almost always; one that slips through is merged again by that
/// device's next sync, which still holds everything it wrote.
class DriveSyncProvider implements SyncProvider {
  DriveSyncProvider({
    http.Client? client,
    DriveAuth auth = const GoogleDriveAuth(),
  }) : _http = client ?? http.Client(),
       _auth = auth;

  static const _api = 'https://www.googleapis.com/drive/v3/files';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3/files';

  final http.Client _http;
  final DriveAuth _auth;
  String? _token;

  Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String> headers) call,
  ) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (_token == null || attempt > 0) {
        _token = await _auth.token(fresh: attempt > 0);
      }
      final token = _token!;
      final http.Response res;
      try {
        res = await call({'Authorization': 'Bearer $token'});
      } on http.ClientException catch (e) {
        // No network (package:http reports socket errors this way).
        throw DriveException(DriveFailure.offline, '$e');
      }
      if (res.statusCode == 401 && attempt == 0) {
        // A stale token: drop it and ask for a fresh one, once.
        await _auth.forget(token);
        _token = null;
        continue;
      }
      if (res.statusCode >= 200 && res.statusCode < 300) return res;
      if (res.statusCode == 401) {
        throw const DriveException(DriveFailure.authNeeded);
      }
      if (res.statusCode == 403 && res.body.contains('storageQuotaExceeded')) {
        throw const DriveException(DriveFailure.quota);
      }
      if (res.statusCode >= 500 || res.statusCode == 429) {
        throw DriveException(DriveFailure.offline, 'HTTP ${res.statusCode}');
      }
      throw DriveException(DriveFailure.other, 'HTTP ${res.statusCode}');
    }
    throw const DriveException(DriveFailure.authNeeded);
  }

  /// The app folder's files named [name], newest first.
  Future<List<({String id, String version})>> _find(String name) async {
    final uri = Uri.parse(_api).replace(
      queryParameters: {
        'spaces': 'appDataFolder',
        'q': "name = '${name.replaceAll("'", r"\'")}' and trashed = false",
        'fields': 'files(id, version, modifiedTime)',
        'orderBy': 'modifiedTime desc',
        'pageSize': '10',
      },
    );
    final res = await _send((h) => _http.get(uri, headers: h));
    final files = (jsonDecode(res.body) as Map)['files'] as List? ?? const [];
    return [
      for (final f in files.cast<Map>())
        (id: f['id'] as String, version: '${f['version']}'),
    ];
  }

  @override
  Future<RemoteFile?> read(String path) async {
    final found = await _find(path);
    if (found.isEmpty) return null;
    final file = found.first;
    final res = await _send(
      (h) => _http.get(Uri.parse('$_api/${file.id}?alt=media'), headers: h),
    );
    return RemoteFile(res.bodyBytes, file.version);
  }

  @override
  Future<String> write(
    String path,
    Uint8List bytes, {
    String? ifMatch,
    bool ifAbsent = false,
  }) async {
    final current = (await _find(path)).firstOrNull;
    if (ifAbsent && current != null) throw const SyncConflict();
    if (ifMatch != null && current?.version != ifMatch) {
      throw const SyncConflict();
    }
    final type = path.endsWith('.json')
        ? 'application/json'
        : 'application/octet-stream';
    if (current != null) {
      final res = await _send(
        (h) => _http.patch(
          Uri.parse('$_upload/${current.id}?uploadType=media&fields=version'),
          headers: {...h, 'Content-Type': type},
          body: bytes,
        ),
      );
      return '${(jsonDecode(res.body) as Map)['version']}';
    }
    const boundary = 'handy-boards-sync-boundary';
    final meta = jsonEncode({
      'name': path,
      'parents': ['appDataFolder'],
    });
    final body = BytesBuilder()
      ..add(
        utf8.encode(
          '--$boundary\r\n'
          'Content-Type: application/json; charset=UTF-8\r\n\r\n'
          '$meta\r\n'
          '--$boundary\r\n'
          'Content-Type: $type\r\n\r\n',
        ),
      )
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--\r\n'));
    final res = await _send(
      (h) => _http.post(
        Uri.parse('$_upload?uploadType=multipart&fields=id,version'),
        headers: {
          ...h,
          'Content-Type': 'multipart/related; boundary=$boundary',
        },
        body: body.takeBytes(),
      ),
    );
    return '${(jsonDecode(res.body) as Map)['version']}';
  }

  @override
  Future<Set<String>> list(String folder) async {
    // Only this app's files live in its app folder: list them all and keep
    // the ones under [folder].
    final prefix = '$folder/';
    final out = <String>{};
    String? page;
    do {
      final uri = Uri.parse(_api).replace(
        queryParameters: {
          'spaces': 'appDataFolder',
          'q': 'trashed = false',
          'fields': 'nextPageToken, files(name)',
          'pageSize': '1000',
          'pageToken': ?page,
        },
      );
      final res = await _send((h) => _http.get(uri, headers: h));
      final json = jsonDecode(res.body) as Map;
      for (final f in (json['files'] as List? ?? const []).cast<Map>()) {
        final name = f['name'] as String;
        if (name.startsWith(prefix) &&
            !name.substring(prefix.length).contains('/')) {
          out.add(name.substring(prefix.length));
        }
      }
      page = json['nextPageToken'] as String?;
    } while (page != null);
    return out;
  }
}
