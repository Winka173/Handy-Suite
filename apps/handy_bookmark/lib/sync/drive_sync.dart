import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import '../controller.dart';
import 'drive_provider.dart';
import 'sync_service.dart' show syncLibrary;

/// Builds made with `--dart-define=HANDY_DRIVE_SYNC=true` offer Google Drive
/// sync (on Android). Without the Google OAuth clients set up, the switch
/// could never connect, so other builds do not show it.
const driveSyncBuild = bool.fromEnvironment('HANDY_DRIVE_SYNC');

/// Whether this device offers Google Drive sync.
bool get driveSyncOffered =>
    driveSyncBuild &&
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.android;

enum DriveSyncState { off, idle, syncing, offline, authNeeded, quota, failed }

/// Keeps this device's library in step with the person's other Android
/// devices through their Google Drive's hidden app folder, using the same
/// merge as folder sync (items, Recently Deleted, deletions, collections,
/// pictures; device settings stay here). Off unless switched on; nothing
/// in the app needs it.
///
/// It runs while the app is open: half a minute after the last change, when
/// the app comes back, when it goes to the background with a change
/// waiting, at launch, and from Sync now.
class DriveSync extends ChangeNotifier {
  DriveSync(
    this.c, {
    SyncProvider Function()? provider,
    Future<bool> Function()? authorize,
    Future<void> Function()? revoke,
    this.delay = const Duration(seconds: 30),
  }) : _provider = provider ?? (() => DriveSyncProvider()),
       _authorize = authorize ?? GoogleDriveAuth.authorize,
       _revoke = revoke ?? GoogleDriveAuth.revoke;

  final SaveController c;
  final SyncProvider Function() _provider;
  final Future<bool> Function() _authorize;
  final Future<void> Function() _revoke;
  final Duration delay;

  static const _on = 'driveSync', _at = 'driveSyncedAt';

  SyncProvider? _remote;
  DriveSyncState _state = DriveSyncState.off;
  DriveSyncState get state =>
      enabled && _state == DriveSyncState.off ? DriveSyncState.idle : _state;

  /// Pictures sent and received by the last sync.
  int sent = 0, received = 0;

  bool get enabled => c.preferences[_on] == true;
  DateTime? get lastSync =>
      DateTime.tryParse(c.preferences[_at] as String? ?? '')?.toLocal();

  Timer? _pending;
  Future<void>? _running;
  Object? _seen;
  bool _disposed = false;

  Future<void> _prefs(Map<String, Object?> values) => c.update(
    (l) => l,
    prefs: {
      ...c.preferences,
      for (final e in values.entries)
        if (e.value != null) e.key: e.value,
    }..removeWhere((k, _) => values.containsKey(k) && values[k] == null),
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

  /// Switches sync off. Nothing on this device is deleted, and the copy in
  /// Drive stays for the other devices; [forget] also gives the access
  /// back.
  Future<void> disable({bool forget = false}) async {
    _pending?.cancel();
    await _prefs({_on: null, _at: null});
    _remote = null;
    _state = DriveSyncState.off;
    notifyListeners();
    if (forget) await _revoke();
  }

  /// The library changed: sync [delay] after the last change. Settings
  /// alone (the library unchanged) and the sync's own result do not count.
  void changed() {
    if (!enabled || _running != null) return;
    final now = c.library;
    if (now == null || identical(now, _seen)) return;
    _seen = now;
    _pending?.cancel();
    _pending = Timer(delay, () => unawaited(syncNow()));
  }

  /// The app came back to the front.
  void resumed() {
    if (enabled) unawaited(syncNow());
  }

  /// The app went to the background: a change still waiting goes now.
  void paused() {
    if (_pending?.isActive ?? false) {
      _pending!.cancel();
      unawaited(syncNow());
    }
  }

  /// One sync. Calls while one runs share it.
  Future<void> syncNow() {
    if (!enabled || c.library == null || _disposed) return Future.value();
    _pending?.cancel();
    return _running ??= _sync().whenComplete(() {
      _running = null;
      _seen = c.library;
    });
  }

  Future<void> _sync() async {
    _state = DriveSyncState.syncing;
    notifyListeners();
    try {
      final r = await syncLibrary(c, _remote ??= _provider());
      sent = r.picturesSent;
      received = r.picturesReceived;
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
