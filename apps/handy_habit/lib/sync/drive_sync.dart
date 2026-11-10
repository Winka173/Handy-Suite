import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import '../controller.dart';
import 'drive_provider.dart';
import 'metadata.dart';
export 'metadata.dart';

const driveSyncBuild = bool.fromEnvironment('HANDY_DRIVE_SYNC');
bool get driveSyncOffered =>
    driveSyncBuild &&
    !kIsWeb &&
    defaultTargetPlatform == TargetPlatform.android;

enum DriveSyncState {
  off,
  connecting,
  synced,
  pending,
  syncing,
  error,
  newerRemote,
}

class HabitDriveSync extends ChangeNotifier {
  HabitDriveSync(
    this.c, {
    HabitSyncProvider Function()? provider,
    Future<bool> Function()? authorize,
    Future<void> Function()? revoke,
    String? Function()? account,
    SyncMetadataStore? metadata,
    this.delay = const Duration(seconds: 30),
  }) : _provider = provider,
       _authorize = authorize ?? GoogleDriveAuth.authorize,
       _revoke = revoke ?? GoogleDriveAuth.revoke,
       _account = account ?? (() => GoogleDriveAuth.account),
       _store = metadata ?? FileSyncMetadata() {
    c.addListener(changed);
    c.beforeReplace = disable;
  }
  final HabitController c;
  final HabitSyncProvider Function()? _provider;
  final Future<bool> Function() _authorize;
  final Future<void> Function() _revoke;
  final String? Function() _account;
  final SyncMetadataStore _store;
  final Duration delay;
  HabitSyncProvider? _remote;
  Map<String, dynamic> _data = {};
  Future<void>? _loading, _running;
  Timer? _timer;
  bool _disposed = false, _applying = false, _loaded = false;
  Object? _seen;
  int _epoch = 0;
  DriveSyncState state = DriveSyncState.off;
  String? errorCode;
  bool get enabled => _data['enabled'] == true;
  String? get account => _data['account'] as String?;
  String? get lastError => errorCode ?? _data['lastError'] as String?;
  DateTime? get lastSync =>
      DateTime.tryParse(_data['lastSync'] as String? ?? '');
  List<String> get activity =>
      List<String>.from(_data['activity'] as List? ?? []);
  List<HabitOperation> get base =>
      objects(_data['base'] ?? []).map(HabitOperation.fromJson).toList();
  int get pending {
    final s = c.state;
    if (s == null) return 0;
    final known = {for (final o in base) o.id: o.toJson()};
    return prepareHabitSync(s).operations
        .where(
          (o) =>
              !['settings', 'clockPolicies'].contains(o.kind) &&
              (known[o.id] == null || known[o.id]!['redacted'] != o.redacted),
        )
        .length;
  }

  bool get busy =>
      state == DriveSyncState.connecting || state == DriveSyncState.syncing;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _save(Map<String, dynamic> changes) async {
    final next = {..._data, ...changes};
    await _store.write(next);
    _data = next;
  }

  Future<void> initialize() => _loading ??= _initialize();
  Future<void> _initialize() async {
    try {
      _data = await _store.read();
      _data['device'] ??= uid();
      if (!RegExp(
            r'^[a-zA-Z0-9-]{1,200}$',
          ).hasMatch(_data['device'] as String) ||
          _data['enabled'] != null && _data['enabled'] is! bool ||
          _data['account'] != null && _data['account'] is! String ||
          _data['lastError'] != null && _data['lastError'] is! String)
        throw const FormatException('Invalid sync metadata');
      validateOperations(base);
      if (_data['lastSync'] != null) timestamp(_data['lastSync']);
      if (activity.length > 5)
        throw const FormatException('Invalid sync activity');
      for (final value in activity) {
        timestamp(value);
      }
      _loaded = true;
      state = enabled ? DriveSyncState.pending : DriveSyncState.off;
    } catch (_) {
      _data = {};
      state = DriveSyncState.error;
      errorCode = 'metadata';
    }
    _notify();
  }

  Future<void> start() async {
    await initialize();
    if (enabled && c.state != null) await syncNow();
  }

  HabitSyncProvider _newProvider() =>
      _provider?.call() ??
      DriveSyncProvider(auth: GoogleDriveAuth(expectedAccount: account));

  Future<bool> enable() async {
    await initialize();
    if (busy || !_loaded) return false;
    state = DriveSyncState.connecting;
    errorCode = null;
    _notify();
    try {
      if (!await _authorize()) {
        state = enabled ? DriveSyncState.pending : DriveSyncState.off;
        _notify();
        return false;
      }
      final selected = _account();
      // An account change starts a fresh base. Local data joins the selected
      // account only after this explicit Turn on / Allow access action.
      await _save({
        'enabled': true,
        'account': selected,
        if (account != selected) 'base': <dynamic>[],
      });
      if (_remote case final DriveSyncProvider p) p.close();
      _remote = _newProvider();
      state = DriveSyncState.pending;
      await syncNow();
      return true;
    } on DriveException catch (e) {
      state = DriveSyncState.error;
      errorCode = e.failure.name;
      _notify();
      return false;
    } catch (_) {
      state = DriveSyncState.error;
      errorCode = 'connect';
      _notify();
      return false;
    }
  }

  Future<void> disable({bool disconnect = false}) async {
    await initialize();
    ++_epoch;
    _timer?.cancel();
    if (!_loaded) {
      state = DriveSyncState.off;
      _notify();
      return;
    }
    // Prevent applying a result already in flight, then wait for it to settle.
    await _save({'enabled': false});
    await _running;
    state = DriveSyncState.off;
    if (disconnect) {
      try {
        await _revoke();
        await _save({'account': null});
      } catch (_) {
        errorCode = 'disconnect';
        state = DriveSyncState.error;
      }
    }
    if (_remote case final DriveSyncProvider p) p.close();
    _remote = null;
    _notify();
  }

  void changed() {
    final ops = c.state?.operations;
    if (_disposed || _applying || identical(ops, _seen)) return;
    _seen = ops;
    if (!_loaded || !enabled || c.state == null) return;
    if (state != DriveSyncState.newerRemote && !busy)
      state = DriveSyncState.pending;
    _notify();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(syncNow()));
  }

  void resumed() {
    if (enabled) unawaited(syncNow());
  }

  Future<void> syncNow() async {
    await initialize();
    if (!enabled || c.state == null || _disposed) return;
    _timer?.cancel();
    return _running ??= _sync().whenComplete(() {
      _running = null;
      if (enabled &&
          !_disposed &&
          pending > 0 &&
          state == DriveSyncState.synced) {
        state = DriveSyncState.pending;
        _notify();
        _schedule();
      }
    });
  }

  Future<void> _sync() async {
    final epoch = _epoch, snapshot = c.state!;
    state = DriveSyncState.syncing;
    errorCode = null;
    _notify();
    try {
      final result = await syncHabitOnce(
        local: snapshot,
        base: base,
        device: _data['device'] as String,
        remote: _remote ??= _newProvider(),
      );
      if (epoch != _epoch || !enabled || _disposed) return;
      _applying = true;
      try {
        await c.change(
          (current) => mergeHabitStates(current, result.state, base: base),
          remember: false,
          recorded: true,
        );
        _seen = c.state?.operations;
      } finally {
        _applying = false;
      }
      if (epoch != _epoch || !enabled || _disposed) return;
      final stamp = c.clock().toUtc().toIso8601String();
      await _save({
        'base': result.base.map((o) => o.toJson()).toList(),
        'lastSync': stamp,
        'activity': [stamp, ...activity].take(5).toList(),
      });
      state = pending > 0 ? DriveSyncState.pending : DriveSyncState.synced;
      if (pending > 0) _schedule();
    } on NewerHabitSync {
      state = DriveSyncState.newerRemote;
      errorCode = 'newer';
    } on DriveException catch (e) {
      state = DriveSyncState.error;
      errorCode = e.failure.name;
    } on FormatException {
      state = DriveSyncState.error;
      errorCode = 'damaged';
    } catch (_) {
      state = DriveSyncState.error;
      errorCode = 'offline';
    }
    if (errorCode != null &&
        errorCode != 'metadata' &&
        epoch == _epoch &&
        enabled) {
      try {
        await _save({'lastError': errorCode});
      } catch (_) {
        /* Preserve local data when metadata storage fails. */
      }
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_epoch;
    _timer?.cancel();
    c.removeListener(changed);
    c.beforeReplace = null;
    if (_remote case final DriveSyncProvider p) p.close();
    super.dispose();
  }
}
