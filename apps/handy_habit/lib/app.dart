import 'design/identity.dart';
import 'design/theme.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_home_widget/handy_home_widget.dart';
import 'package:handy_ui/kit.dart';
import 'controller.dart';
import 'habits/habit_view.dart';
import 'habits/habit_editor.dart';
import 'habits/habits_page.dart';
import 'habits/preset_sheet.dart';
import 'insights/week_review.dart';
import 'home_widget.dart';
import 'reminders.dart';
import 'routines/routine_view.dart';
import 'routines/routine_editor.dart';
import 'routines/session_view.dart';
import 'run_notice.dart';
import 'runner.dart';
import 'scope.dart';
import 'settings/settings_page.dart';
import 'settings/trash_page.dart';
import 'settings/help_page.dart';
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
  late final c = widget.controller ?? HabitController(clock: widget.clock);
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
  Timer? _clockWatch;
  String? _clockStamp;
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
    _clockWatch = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshClock(),
    );
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
    // Keep an editor draft underneath a link instead of removing its route.
    unawaited(nav.pushNamed('/today'));
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
    _clockWatch?.cancel();
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
    if (state == AppLifecycleState.resumed) {
      _refreshClock();
      _sync();
    }
  }

  void _refreshClock() {
    if (!mounted || c.state == null) return;
    final next = '${scope.today}:${scope.hour}';
    if (_clockStamp == next) return;
    _clockStamp = next;
    scope.clockTick.value++;
    _sync();
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
    listenable: Listenable.merge([c, scope.clockTick]),
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
    final uri = Uri.tryParse(s.name ?? '/') ?? Uri(path: '/');
    final parts = uri.path.split('/');
    final Widget Function()? page = switch (parts) {
      ['', 'today'] => () => HabitShell(scope: scope),
      ['', 'routines'] => () => HabitShell(scope: scope, area: 2),
      ['', 'progress'] ||
      ['', 'insights'] => () => HabitShell(scope: scope, area: 3),
      ['', 'progress', 'week'] || ['', 'review'] => () => WeekReviewPage(
        scope: scope,
        from: uri.queryParameters['from'],
      ),
      ['', 'habits'] => () => Scaffold(
        appBar: AppBar(
          title: Text(tr(navigator.currentContext!, 'Habits', 'Thói quen')),
        ),
        body: HabitsPage(
          scope: scope,
          autofocus: uri.queryParameters['search'] == 'true',
        ),
      ),
      ['', 'habit', 'new'] => () => Builder(
        builder: (context) => buildHabitEditor(
          context,
          scope,
          null,
          s.arguments is HabitPreset ? s.arguments as HabitPreset : null,
        ),
      ),
      ['', 'habit', final id, 'edit'] => () => Builder(
        builder: (context) => switch (scope.habit(id)) {
          final h? => buildHabitEditor(context, scope, h),
          _ => _missing('/habits'),
        },
      ),
      ['', 'routine', 'new'] => () => Builder(
        builder: (context) => buildRoutineEditor(context, scope),
      ),
      ['', 'routine', final id, 'edit'] => () => Builder(
        builder: (context) => switch (scope.routine(id)) {
          final r? => buildRoutineEditor(context, scope, r),
          _ => _missing('/routines'),
        },
      ),
      ['', 'templates'] => () => HabitTemplatesPage(scope: scope),
      ['', 'templates', final id] => () => Builder(
        builder: (context) =>
            switch (habitPresets.where((p) => p.id == id).firstOrNull) {
              final p? => buildHabitEditor(context, scope, null, p),
              _ => _missing('/templates?kind=habit'),
            },
      ),
      ['', 'help'] || ['', 'help', _] => () => HabitHelpPage(),
      ['', 'settings', 'trash'] => () => HabitTrashPage(scope: scope),
      ['', 'settings'] => () => HabitSettingsPage(scope: scope),
      ['', 'settings', _] => () => HabitSettingsPage(scope: scope),
      ['', 'habit', final id] =>
        () => scope.habit(id) != null
            ? HabitPage(scope: scope, id: id)
            : _missing('/habits'),
      ['', 'routine', final id] =>
        () => scope.routine(id) != null
            ? RoutinePage(scope: scope, id: id)
            : _missing('/routines'),
      ['', 'session', final id] =>
        () => c.state!.sessions.any((v) => v.id == id)
            ? SessionPage(scope: scope, id: id)
            : _missing('/routines'),
      ['', 'run', final id] =>
        () => c.state!.sessions.any((x) => x.id == id && x.status == 'active')
            ? RoutineRunner(
                controller: c,
                sessionId: id,
                clock: scope.clock,
                notices: scope.notices,
              )
            : c.state!.sessions.any((v) => v.id == id)
            ? SessionPage(scope: scope, id: id)
            : _missing('/routines'),
      _ => () => _missing('/today'),
    };
    if (page == null) return null;
    if (parts.length >= 3 &&
            parts[1] == 'habit' &&
            (parts[2] == 'new' || parts.last == 'edit') ||
        parts.length == 3 && parts[1] == 'templates') {
      return MaterialPageRoute<bool>(settings: s, builder: (_) => _ready(page));
    }
    if (parts.length >= 3 &&
        parts[1] == 'routine' &&
        (parts[2] == 'new' || parts.last == 'edit')) {
      return MaterialPageRoute<String>(
        settings: s,
        builder: (_) => _ready(page),
      );
    }
    return MaterialPageRoute<void>(settings: s, builder: (_) => _ready(page));
  }

  Widget _missing(String parent) => Builder(
    builder: (context) => Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Page unavailable', 'Không có trang này')),
      ),
      body: HandyEmpty(
        title: tr(
          context,
          'This page is no longer available.',
          'Trang này không còn.',
        ),
        action: TextButton(
          onPressed: () => Navigator.pushReplacementNamed(context, parent),
          child: Text(tr(context, 'Go back', 'Quay lại')),
        ),
      ),
    ),
  );

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      navigator.currentState?.maybePop();
      return KeyEventResult.handled;
    }
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus?.widget is EditableText ||
        focus?.findAncestorWidgetOfExactType<EditableText>() != null)
      return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    if (!keys.isControlPressed && !keys.isMetaPressed)
      return KeyEventResult.ignored;
    final path = switch (event.logicalKey) {
      LogicalKeyboardKey.keyN =>
        routes.top == '/routines' ? '/routine/new' : '/habit/new',
      LogicalKeyboardKey.keyF => '/habits?search=true',
      LogicalKeyboardKey.comma => '/settings',
      LogicalKeyboardKey.digit1 => '/today',
      LogicalKeyboardKey.digit2 => '/routines',
      LogicalKeyboardKey.digit3 => '/progress',
      _ => null,
    };
    if (path == null) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.digit1 ||
        event.logicalKey == LogicalKeyboardKey.digit2 ||
        event.logicalKey == LogicalKeyboardKey.digit3) {
      if ([
        '/today',
        '/routines',
        '/progress',
        '/insights',
      ].contains(routes.top)) {
        navigator.currentState?.pushReplacementNamed(path);
      } else {
        navigator.currentState?.pushNamed(path);
      }
    } else {
      navigator.currentState?.pushNamed(path);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => HandyApp(
      brand: habitIdentity,
      themeOverride: habitTheme,
      app: 'habit',
      title: 'Handy Habit',
      accent: habitAccent,
      locale: c.state?.settings['locale'] as String? ?? 'system',
      theme: c.state?.settings['theme'] as String? ?? 'system',
      adsVisible: c.adsVisible,
      navigatorKey: navigator,
      navigatorObservers: [routes],
      onGenerateRoute: route,
      wrap: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations:
              MediaQuery.disableAnimationsOf(context) ||
              c.state?.settings['reducedMotion'] == true,
        ),
        child: Focus(onKeyEvent: _key, child: child),
      ),
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

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (top == oldRoute?.settings.name) top = newRoute?.settings.name;
    _set(depth);
  }
}
