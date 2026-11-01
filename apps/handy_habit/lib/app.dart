import 'dart:async';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'controller.dart';
import 'habits/habit_view.dart';
import 'reminders.dart';
import 'routines/routine_view.dart';
import 'routines/session_view.dart';
import 'runner.dart';
import 'scope.dart';
import 'settings/settings_page.dart';
import 'shell/habit_shell.dart';

export 'scope.dart' show HabitScope;

/// Habit's hue in the suite palette (docs/UX_REDESIGN.md): vermilion.
const habitAccent = Color(0xFFB42318);

class HabitApp extends StatefulWidget {
  final HabitController? controller;
  final HandyFiles files;
  final DateTime Function()? clock;
  final HabitReminders? reminders;
  const HabitApp({
    super.key,
    this.controller,
    this.files = const SystemHandyFiles(),
    this.clock,
    this.reminders,
  });
  @override
  State<HabitApp> createState() => _HabitAppState();
}

class _HabitAppState extends State<HabitApp> with WidgetsBindingObserver {
  late final c = widget.controller ?? HabitController();
  late final scope = HabitScope(
    controller: c,
    files: widget.files,
    reminders: widget.reminders ?? HabitReminders(),
    clock: widget.clock ?? DateTime.now,
  );
  late final routes = _Depth(_ads);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_changed);
    scope.area.addListener(_ads);
    if (c.state == null) unawaited(c.load());
    _ads();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_changed);
    scope.area.removeListener(_ads);
    scope.dispose();
    if (widget.controller == null) c.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  int? _synced;
  void _changed() {
    if (c.state?.revision != _synced) {
      _synced = c.state?.revision;
      _sync();
    }
    _ads();
  }

  void _sync() {
    final s = c.state;
    if (s == null) return;
    // Today still lists the next reminder if the system refuses.
    unawaited(scope.reminders.sync(s).catchError((Object _) {}));
  }

  /// Ads only on the home once set up; never over a form, the runner or
  /// any page above the home.
  void _ads() {
    if (c.disposed) return;
    c.adsVisible.value =
        c.state?.settings['onboarded'] == true && routes.depth <= 1;
  }

  Widget _ready(Widget Function() page) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      if (c.state == null && c.error != null)
        return HandyLoadError(
          title: tr(
            context,
            'Habit could not open your data',
            'Habit chưa mở được dữ liệu',
          ),
          error: c.error!,
          onRetry: c.load,
        );
      if (c.state == null) return const HandyLoading();
      return page();
    },
  );

  Route<dynamic>? route(RouteSettings s) {
    final Widget Function()? page = switch ((s.name ?? '/').split('/')) {
      ['', 'settings'] => () => HabitSettingsPage(scope: scope),
      ['', 'habit', final id] => () => HabitPage(scope: scope, id: id),
      ['', 'routine', final id] => () => RoutinePage(scope: scope, id: id),
      ['', 'session', final id] => () => SessionPage(scope: scope, id: id),
      ['', 'run', final id] =>
        () => c.state!.sessions.any((x) => x.id == id && x.status == 'active')
            ? RoutineRunner(controller: c, sessionId: id, clock: scope.clock)
            : SessionPage(scope: scope, id: id),
      _ => null,
    };
    if (page == null) return null;
    return MaterialPageRoute<void>(settings: s, builder: (_) => _ready(page));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => HandyApp(
      app: 'habit',
      title: 'Handy Habit',
      accent: habitAccent,
      locale: c.state?.settings['locale'] as String? ?? 'system',
      theme: c.state?.settings['theme'] as String? ?? 'system',
      adsVisible: c.adsVisible,
      navigatorObservers: [routes],
      onGenerateRoute: route,
      home: _ready(() => HabitShell(scope: scope)),
    ),
  );
}

/// Counts the routes above the home so ads know when something is up.
class _Depth extends NavigatorObserver {
  final VoidCallback changed;
  int depth = 0;
  _Depth(this.changed);
  void _set(int next) {
    depth = next < 0 ? 0 : next;
    WidgetsBinding.instance.addPostFrameCallback((_) => changed());
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(depth + 1);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(depth - 1);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _set(depth - 1);
}
