import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:path_provider/path_provider.dart';
import '../controller.dart';
import 'drive_provider.dart';

/// Builds made with `--dart-define=HANDY_DRIVE_SYNC=true` offer Google
/// Drive sync (on Android). Without the Google Cloud OAuth clients for the
/// package and its signing keys the switch could never connect, so other
/// builds do not show it (docs/HANDY_BOARDS_RELEASE.md).
const driveSyncBuild = bool.fromEnvironment('HANDY_DRIVE_SYNC');

bool get driveSyncOffered =>
    driveSyncBuild &&
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.android;

enum DriveSyncState { off, idle, syncing, offline, authNeeded, quota, failed }

/// Where this device keeps its base (fingerprints of every record as of
/// its last sync). It stays on the device: never in backups, never in
/// Drive. Tests use [MemoryBaseStore].
abstract class SyncBaseStore {
  Future<Map<String, String>> read();
  Future<void> write(Map<String, String> base);
  Future<void> clear();
}

class FileBaseStore implements SyncBaseStore {
  const FileBaseStore();
  Future<File> _file() async => File(
    '${(await getApplicationSupportDirectory()).path}/boards-drive-base.json',
  );

  @override
  Future<Map<String, String>> read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return {};
      return Map<String, String>.from(
        jsonDecode(await f.readAsString()) as Map,
      );
    } catch (_) {
      // A damaged base only makes the next sync a joining one.
      return {};
    }
  }

  @override
  Future<void> write(Map<String, String> base) async {
    final f = await _file();
    final part = File('${f.path}.part');
    await part.writeAsString(jsonEncode(base), flush: true);
    await part.rename(f.path);
  }

  @override
  Future<void> clear() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }
}

class MemoryBaseStore implements SyncBaseStore {
  Map<String, String> base = {};
  @override
  Future<Map<String, String>> read() async => {...base};
  @override
  Future<void> write(Map<String, String> value) async => base = {...value};
  @override
  Future<void> clear() async => base = {};
}

class _StateFiles implements SyncFiles {
  final BoardsState state;
  const _StateFiles(this.state);
  @override
  Future<Uint8List?> read(String path) async =>
      state.hasFile(path) ? state.file(path) : null;
}

/// Keeps this device's boards in step with the person's other Android
/// devices through their Google Drive's hidden app folder (see the
/// engine's `sync.dart` for what moves and how clashes resolve). Off unless
/// switched on; nothing else in the app needs it.
///
/// It runs while the app is open: half a minute after the last change,
/// when the app comes back, when it goes to the background with a change
/// waiting, at launch, and from Sync now.
class BoardsDriveSync extends ChangeNotifier {
  BoardsDriveSync(
    this.c, {
    SyncProvider Function()? provider,
    Future<bool> Function()? authorize,
    Future<void> Function()? revoke,
    SyncBaseStore? base,
    this.delay = const Duration(seconds: 30),
  }) : _provider = provider ?? (() => DriveSyncProvider()),
       _authorize = authorize ?? GoogleDriveAuth.authorize,
       _revoke = revoke ?? GoogleDriveAuth.revoke,
       _base = base ?? const FileBaseStore();

  final BoardsController c;
  final SyncProvider Function() _provider;
  final Future<bool> Function() _authorize;
  final Future<void> Function() _revoke;
  final SyncBaseStore _base;
  final Duration delay;

  static const _on = 'driveSync', _at = 'driveSyncedAt';

  SyncProvider? _remote;
  DriveSyncState _state = DriveSyncState.off;
  DriveSyncState get state =>
      enabled && _state == DriveSyncState.off ? DriveSyncState.idle : _state;

  /// Attachments sent and received by the last sync.
  int sent = 0, received = 0;

  bool get enabled => c.state?.preferences[_on] == true;
  DateTime? get lastSync =>
      DateTime.tryParse(c.state?.preferences[_at] as String? ?? '')?.toLocal();

  Timer? _pending;
  Future<void>? _running;
  Object? _seen;
  bool _disposed = false;

  Future<void> _prefs(Map<String, Object?> values) => c.change(
    (s) => s.copy(
      preferences: {
        ...s.preferences,
        for (final e in values.entries)
          if (e.value != null) e.key: e.value,
      }..removeWhere((k, _) => values.containsKey(k) && values[k] == null),
    ),
    history: false,
  );

  /// Asks for access to the app folder, then switches sync on and syncs.
  /// False when the person did not allow it.
  Future<bool> enable() async {
    if (!await _authorize()) return false;
    _remote = _provider();
    await _prefs({_on: true});
    _state = DriveSyncState.idle;
    notifyListeners();
    await syncNow();
    return true;
  }

  /// Switches sync off. Nothing on this device or in Drive is deleted; the
  /// base is dropped so turning it on again joins both sides (it never
  /// deletes anything on the strength of an old base). [forget] also gives
  /// the access back.
  Future<void> disable({bool forget = false}) async {
    _pending?.cancel();
    await _prefs({_on: null, _at: null});
    await _base.clear();
    _remote = null;
    _state = DriveSyncState.off;
    notifyListeners();
    if (forget) await _revoke();
  }

  /// The boards changed: sync [delay] after the last change. The sync's
  /// own result and settings-only changes do not count.
  void changed() {
    if (!enabled || _running != null) return;
    final now = c.state;
    if (now == null || identical(now, _seen)) return;
    _seen = now;
    _pending?.cancel();
    _pending = Timer(delay, () => unawaited(syncNow()));
  }

  void resumed() {
    if (enabled) unawaited(syncNow());
  }

  void paused() {
    if (_pending?.isActive ?? false) {
      _pending!.cancel();
      unawaited(syncNow());
    }
  }

  /// One sync. Calls while one runs share it.
  Future<void> syncNow() {
    if (!enabled || c.state == null || _disposed) return Future.value();
    _pending?.cancel();
    return _running ??= _sync().whenComplete(() {
      _running = null;
      _seen = c.state;
    });
  }

  Future<void> _sync() async {
    _state = DriveSyncState.syncing;
    notifyListeners();
    try {
      final now = c.state!;
      final snap = syncRecordsOf(now);
      final result = await syncBoardsOnce(
        local: snap,
        base: await _base.read(),
        remote: _remote ??= _provider(),
        files: _StateFiles(now),
      );
      // Applied onto the boards as they are now: edits made meanwhile stay.
      await c.change((s) => applySyncResult(s, snap, result), history: false);
      await _base.write(result.base);
      sent = result.sent;
      received = result.files.length;
      _state = DriveSyncState.idle;
      await _prefs({_at: DateTime.now().toUtc().toIso8601String()});
    } on DriveException catch (e) {
      debugPrint('Drive sync stopped: $e');
      _state = switch (e.failure) {
        DriveFailure.offline => DriveSyncState.offline,
        DriveFailure.authNeeded => DriveSyncState.authNeeded,
        DriveFailure.quota => DriveSyncState.quota,
        DriveFailure.other => DriveSyncState.failed,
      };
    } catch (e) {
      debugPrint('Drive sync failed: $e');
      _state = DriveSyncState.failed;
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pending?.cancel();
    super.dispose();
  }
}
