import 'dart:async';
import 'package:handy_files/handy_files.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_home_widget/handy_home_widget.dart';
import 'package:handy_ui/kit.dart';
import 'controller.dart';
import 'habits/habit_view.dart';
import 'home_widget.dart';
import 'reminders.dart';
import 'routines/routine_view.dart';
import 'routines/session_view.dart';
import 'run_notice.dart';
import 'runner.dart';
import 'scope.dart';
import 'settings/settings_page.dart';
import 'shell/habit_shell.dart';
import 'today/check_in.dart';

export 'scope.dart' show HabitScope;

/// Habit's hue in the suite palette (docs/UX_REDESIGN.md): vermilion.
const habitAccent = Color(0xFFB42318);

class HabitApp extends StatefulWidget {
  final HabitController? controller;
  final HandyFiles files;
  final DateTime Function()? clock;
  final HabitReminders? reminders;
  final HabitRunNotices? notices;

  /// Off in host tests: no folder backups, no home-screen widget.
  final bool device;
  const HabitApp({
    super.key,
    this.controller,
    this.files = const SystemHandyFiles(),
    this.clock,
    this.reminders,
    this.notices,
    this.device = true,
  });
  @override
  State<HabitApp> createState() => _HabitAppState();
}

class _HabitAppState extends State<HabitApp> with WidgetsBindingObserver {
  late final c = widget.controller ?? HabitController();
  late final reminders = widget.reminders ?? HabitReminders();
  late final scope = HabitScope(
    controller: c,
    files: widget.files,
    reminders: reminders,
    // One plugin set-up for both, so the tap handler is not reset.
    notices:
        widget.notices ??
        HabitRunNotices(port: DeviceRunNoticePort(reminders.port)),
    clock: widget.clock ?? DateTime.now,
    autoBackup: widget.device
        ? HandyAutoBackup.local(
            app: 'habit',
            extension: 'zip',
            build: () async => backup(c.state!, zip: true),
            revision: () => c.state?.revision.toString(),
          )
        : null,
  );
  final widgetFeed = HomeWidgetFeed(habitWidgetClass);
  StreamSubscription<Uri>? _links;
  late final routes = _Depth(_ads);
  final navigator = GlobalKey<NavigatorState>();
  String? _launched;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_changed);
    scope.area.addListener(_ads);
    if (c.state == null) unawaited(c.load());
    _ads();
    if (widget.device) _links = widgetFeed.links().listen(_widgetLink);
    unawaited(
      scope.notices.start(_openRun).then((id) {
        if (id == null || !mounted) return;
        _launched = id;
        _changed();
      }),
    );
  }

  /// A tap on the paused-run notice: back to that run, unless it is
  /// already on screen or is over.
  void _openRun(String id) {
    final s = c.state;
    if (s == null) {
      _launched = id;
      return;
    }
    if (routes.top == '/run/$id' ||
        !s.sessions.any((x) => x.id == id && x.status == 'active'))
      return;
    unawaited(navigator.currentState?.pushNamed('/run/$id'));
  }

  /// A tap on the home-screen widget: today, a habit, or a one-tap
  /// check-in that leaves the usual Undo.
  Uri? _pendingLink;
  void _widgetLink(Uri uri) {
    final s = c.state, nav = navigator.currentState;
    if (s == null || nav == null) {
      _pendingLink = uri;
      return;
    }
    final id = uri.pathSegments.firstOrNull;
    final habit = s.habits.where((h) => h.id == id).firstOrNull;
    nav.popUntil((r) => r.isFirst);
    scope.area.value = 0;
    if (habit == null) return;
    if (uri.host == 'habit') {
      unawaited(nav.pushNamed('/habit/${habit.id}'));
    } else if (uri.host == 'checkin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = navigator.currentContext;
        if (context != null && mounted)
          unawaited(checkIn(context, scope, habit));
      });
    }
  }

  @override
  void dispose() {
    unawaited(_links?.cancel());
    scope.autoBackup?.dispose();
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
    final launched = _launched;
    if (launched != null && c.state != null) {
      _launched = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openRun(launched));
    }
    if (c.state?.revision != _synced) {
      _synced = c.state?.revision;
      _sync();
    }
    if (c.state != null) {
      scope.autoBackup?.attach();
      final link = _pendingLink;
      if (link != null && navigator.currentState != null) {
        _pendingLink = null;
        WidgetsBinding.instance.addPostFrameCallback((_) => _widgetLink(link));
      }
    }
    _ads();
  }

  void _sync() {
    final s = c.state;
    if (s == null) return;
    // Today still lists the next reminder if the system refuses.
    unawaited(scope.reminders.sync(s).catchError((Object _) {}));
    if (widget.device) {
      final locale = s.settings['locale'] as String? ?? 'system';
      final vi =
          locale == 'vi' ||
          locale == 'system' &&
              WidgetsBinding.instance.platformDispatcher.locale.languageCode ==
                  'vi';
      unawaited(widgetFeed.publish(habitWidgetView(s, scope.today, vi: vi)));
    }
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
            ? RoutineRunner(
                controller: c,
                sessionId: id,
                clock: scope.clock,
                notices: scope.notices,
              )
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
      brand: HandyBrand.habit,
      app: 'habit',
      title: 'Handy Habit',
      accent: habitAccent,
      locale: c.state?.settings['locale'] as String? ?? 'system',
      theme: c.state?.settings['theme'] as String? ?? 'system',
      adsVisible: c.adsVisible,
      navigatorKey: navigator,
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

  /// The name of the route on top, for the notice tap.
  String? top;
  _Depth(this.changed);
  void _set(int next) {
    depth = next < 0 ? 0 : next;
    WidgetsBinding.instance.addPostFrameCallback((_) => changed());
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    top = route.settings.name;
    _set(depth + 1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    top = previousRoute?.settings.name;
    _set(depth - 1);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (top == route.settings.name) top = previousRoute?.settings.name;
    _set(depth - 1);
  }
}
