import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import 'package:local_auth/local_auth.dart';
import '../design/clipping.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../settings/settings_parts.dart';

/// The preference that keeps the library behind the phone's own lock.
const appLockKey = 'appLock';

/// How asking for the phone's lock went.
enum UnlockResult {
  /// The owner proved it is them.
  unlocked,

  /// Cancelled, too many tries, or interrupted: worth offering again.
  failed,

  /// The phone has no screen lock, fingerprint or face to ask for.
  noLock,
}

/// Asks for the phone's own fingerprint, face, PIN, pattern or password.
/// The app keeps no secret of its own, so there is nothing to forget or to
/// leak. Where there is no such thing (the web, tests) it reports
/// [UnlockResult.noLock].
class AppLock {
  const AppLock();
  static final _auth = LocalAuthentication();

  /// Replaced in tests.
  @visibleForTesting
  static Future<UnlockResult> Function(String reason)? debugAsk;

  /// Where a lock can be set at all.
  static bool get supported =>
      debugAsk != null ||
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.windows));

  Future<UnlockResult> authenticate(String reason) async {
    if (debugAsk case final ask?) return ask(reason);
    if (kIsWeb) return UnlockResult.noLock;
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        sensitiveTransaction: false,
        persistAcrossBackgrounding: true,
      );
      return ok ? UnlockResult.unlocked : UnlockResult.failed;
    } on LocalAuthException catch (e) {
      // Only a phone with no screen lock at all has nothing to ask for; any
      // other trouble keeps things shut (Unlock can be tried again).
      return e.code == LocalAuthExceptionCode.noCredentialsSet
          ? UnlockResult.noLock
          : UnlockResult.failed;
    } on MissingPluginException {
      return UnlockResult.noLock;
    } catch (_) {
      return UnlockResult.failed;
    }
  }
}

/// Covers the whole app (dialogs and sheets too, as it sits above the
/// navigator) until the phone's lock is given. Locks when the app starts
/// and when it comes back after [awayLimit] away, so stepping out to share
/// a link or pick a photo does not ask again.
class LockGate extends StatefulWidget {
  final bool enabled;

  /// Whether the library (and so this setting) has been read yet; the
  /// lock closes the moment it is known to be on.
  final bool loaded;
  final Widget child;
  final AppLock lock;
  final Duration awayLimit;
  const LockGate({
    super.key,
    required this.enabled,
    this.loaded = true,
    required this.child,
    this.lock = const AppLock(),
    this.awayLimit = const Duration(minutes: 1),
  });
  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  late bool _locked = widget.loaded && widget.enabled;
  bool _asking = false;
  DateTime? _awayAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
  }

  @override
  void didUpdateWidget(LockGate old) {
    super.didUpdateWidget(old);
    // Switching the lock on does not lock at once (the owner just proved
    // who they are); switching it off opens up straight away.
    if (!widget.enabled && _locked) _locked = false;
    // Read after the first frame: on means locked from the start.
    if (!old.loaded && widget.loaded && widget.enabled) {
      _locked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled) return;
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // The lock prompt itself can send the app to the background.
        if (!_asking) _awayAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final away = _awayAt;
        _awayAt = null;
        if (away == null) break;
        if (!_locked && DateTime.now().difference(away) >= widget.awayLimit) {
          setState(() => _locked = true);
        }
        if (_locked) unawaited(_ask());
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _ask() async {
    if (_asking || !_locked || !mounted) return;
    _asking = true;
    final result = await widget.lock.authenticate(
      tr(context, 'Unlock Handy Bookmark', 'Mở khóa Handy Bookmark'),
    );
    _asking = false;
    if (!mounted) return;
    // A phone whose screen lock was removed since cannot be asked any more;
    // locking its owner out of their own library would help no one.
    if (result != UnlockResult.failed) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      // Kept in the tree (so nothing is lost) but out of reach and sight.
      ExcludeFocus(
        excluding: _locked,
        child: ExcludeSemantics(
          excluding: _locked,
          child: IgnorePointer(ignoring: _locked, child: widget.child),
        ),
      ),
      if (_locked) _LockedCover(onUnlock: _ask),
    ],
  );
}

class _LockedCover extends StatelessWidget {
  final VoidCallback onUnlock;
  const _LockedCover({required this.onUnlock});
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    return Material(
      key: const Key('app-locked'),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(HandySpace.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_outline, size: 40, color: p.ink),
                  const SizedBox(height: HandySpace.l),
                  Center(
                    child: SheetTitle(
                      before: tr(context, 'Your library is ', 'Thư viện đang '),
                      words: tr(context, 'locked', 'khóa'),
                    ),
                  ),
                  const SizedBox(height: HandySpace.s),
                  Text(
                    tr(
                      context,
                      'Open it with your phone’s own lock.',
                      'Mở bằng khóa màn hình của máy.',
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: p.muted),
                  ),
                  const SizedBox(height: HandySpace.xl),
                  FilledButton.icon(
                    key: const Key('app-unlock'),
                    autofocus: true,
                    style: sheetButtonStyle(context),
                    onPressed: onUnlock,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(tr(context, 'Unlock', 'Mở khóa')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Settings › Privacy › App lock. Switching it on asks for the phone's lock
/// first: that proves there is one, and that whoever holds the phone may
/// set it.
class AppLockSwitch extends StatelessWidget {
  final SaveScope scope;
  const AppLockSwitch({super.key, required this.scope});

  Future<void> _set(BuildContext context, bool on) async {
    final c = scope.c;
    Future<void> store(bool v) => scope.run(
      context,
      () => c.update((l) => l, prefs: {...c.preferences, appLockKey: v}),
    );
    if (!on) return store(false);
    final result = await const AppLock().authenticate(
      tr(context, 'Confirm it is you', 'Xác nhận là bạn'),
    );
    if (!context.mounted) return;
    switch (result) {
      case UnlockResult.unlocked:
        await store(true);
      case UnlockResult.noLock:
        showHandyMessage(
          context,
          tr(
            context,
            'Set a screen lock on this device first.',
            'Hãy đặt khóa màn hình cho máy trước.',
          ),
        );
      case UnlockResult.failed:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppLock.supported) {
      return SettingsRow(
        key: const Key('set-app-lock'),
        icon: Icons.lock_outline,
        title: tr(context, 'App lock', 'Khóa app'),
        subtitle: tr(
          context,
          'Works in the Android, iOS and Windows apps.',
          'Có trong app Android, iOS và Windows.',
        ),
      );
    }
    return SettingsSwitch(
      key: const Key('set-app-lock'),
      icon: Icons.lock_outline,
      title: tr(context, 'App lock', 'Khóa app'),
      subtitle: tr(
        context,
        'Asks for your fingerprint, face or screen lock when the app opens, and after a minute away.',
        'Hỏi vân tay, khuôn mặt hoặc khóa màn hình khi mở app, và khi rời app quá một phút.',
      ),
      value: scope.c.preferences[appLockKey] == true,
      onChanged: (v) => _set(context, v),
    );
  }
}
