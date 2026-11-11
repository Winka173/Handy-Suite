import 'convenience/batch_page.dart';
import 'convenience/rules_page.dart';
import 'design/identity.dart';
import 'design/theme.dart';
import 'design/studio_style.dart';
import 'design/studio_page.dart';
import 'insights/smart_page.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:handy_files/backup_folder.dart' show privateBackupFolders;
import 'package:handy_files/handy_files.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_home_widget/handy_home_widget.dart';
import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_ui/kit.dart';
import 'controller.dart';
import 'mood/mood_sheet.dart';
import 'habits/habit_view.dart';
import 'habits/habit_editor.dart';
import 'habits/habits_page.dart';
import 'habits/preset_sheet.dart';
import 'habits/template_preview.dart';
import 'insights/week_review.dart';
import 'home_widget.dart';
import 'reminders.dart';
import 'routines/routine_view.dart';
import 'routines/routine_editor.dart';
import 'routines/session_view.dart';
import 'run_notice.dart';
import 'runner.dart';
import 'scope.dart';
import 'settings/preferences_page.dart';
import 'settings/settings_page.dart';
import 'settings/trash_page.dart';
import 'settings/help_page.dart';
import 'settings/reminder_diagnostics.dart';
import 'settings/widgets_page.dart';
import 'welcome/welcome_page.dart';
import 'shell/habit_shell.dart';
import 'today/check_in.dart';
import 'sync/drive_sync.dart';
import 'sync/folder_sync.dart';
import 'sync/folder_page.dart';
import 'sync/sync_page.dart';
import 'pro/entitlements.dart';
import 'pro/pro_page.dart';

export 'scope.dart' show HabitScope;

/// Habit's hue in the suite palette (docs/UX_REDESIGN.md): vermilion.
const habitAccent = Color(0xFFB42318);

class HabitApp extends StatefulWidget {
  final HabitController? controller;
  final HandyFiles files;
  final DateTime Function()? clock;
  final HabitReminders? reminders;
  final HabitRunNotices? notices;
  final HabitDriveSync? driveSync;

  /// Host tests inject a fake store here; production uses HandyApp's native host.
  @visibleForTesting
  final LifetimeController? lifetime;

  /// Off in host tests: no folder backups, no home-screen widget.
  final bool device;
  const HabitApp({
    super.key,
    this.controller,
    this.files = const SystemHandyFiles(),
    this.clock,
    this.reminders,
    this.notices,
    this.driveSync,
    this.lifetime,
    this.device = true,
  });
  @override
  State<HabitApp> createState() => _HabitAppState();
}

class _HabitAppState extends State<HabitApp> with WidgetsBindingObserver {
  late final c = widget.controller ?? HabitController(clock: widget.clock);
  late final reminders = widget.reminders ?? HabitReminders();
  late final drive =
      widget.driveSync ??
      (driveSyncOffered && widget.device ? HabitDriveSync(c) : null);
  late final folder = folderSyncOffered && widget.device
      ? HabitFolderSync(c)
      : null;
  late final scope = HabitScope(
    controller: c,
    files: widget.files,
    reminders: reminders,
    drive: drive,
    folder: folder,
    // One plugin set-up for both, so the tap handler is not reset.
    notices:
        widget.notices ??
        HabitRunNotices(port: DeviceRunNoticePort(reminders.port)),
    clock: widget.clock ?? DateTime.now,
    // On a device only: a copy a day when something changed, kept in the
    // app's own storage (as Handy Boards); nothing to choose.
    autoBackup: widget.device && !kIsWeb
        ? HandyAutoBackup.local(
            app: 'habit',
            extension: 'zip',
            folders: privateBackupFolders(),
            build: () async => backup(c.state!, zip: true),
            revision: () => c.state?.revision.toString(),
          )
        : null,
  );
  final widgetFeed = HomeWidgetFeed(habitWidgetClass);
  final singleWidgetFeed = HomeWidgetFeed(
    singleHabitWidgetClass,
    prefix: 'habit_',
  );
  final routineWidgetFeed = HomeWidgetFeed(
    routineWidgetClass,
    prefix: 'routine_',
  );
  Future<void> _widgetQueue = Future.value();
  bool _widgetPro = false;
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
    if (folder != null) unawaited(folder!.start());
    if (c.state == null) unawaited(c.load());
    if (drive != null && c.state != null) {
      _driveStarted = true;
      unawaited(drive!.start());
    }
    _clockWatch = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshClock(),
    );
    _ads();
    if (widget.device) _links = widgetFeed.links().listen(_widgetLink);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync();
    });
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
    if (uri.scheme != 'handy-habit' ||
        !const {
          'today',
          'habit',
          'checkin',
          'routine',
          'widgets',
        }.contains(uri.host))
      return;
    final s = c.state, nav = navigator.currentState;
    if (s == null || nav == null) {
      _pendingLink = uri;
      return;
    }
    final id = uri.pathSegments.firstOrNull;
    final habit = s.liveHabits
        .where((h) => h.id == id && !h.archived)
        .firstOrNull;
    // Keep an editor draft underneath a link instead of removing its route.
    unawaited(nav.pushNamed('/today'));
    scope.area.value = 0;
    if (uri.host == 'widgets') {
      unawaited(nav.pushNamed('/settings/widgets'));
      return;
    }
    if (uri.host == 'routine') {
      final routine = s.liveRoutines
          .where((r) => r.id == id && !r.archived)
          .firstOrNull;
      if (routine != null) unawaited(nav.pushNamed('/routine/${routine.id}'));
      return;
    }
    if (habit == null) return;
    if (uri.host == 'habit') {
      unawaited(nav.pushNamed('/habit/${habit.id}'));
    } else if (uri.host == 'checkin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = navigator.currentContext;
        final current = scope.habit(habit.id);
        if (context != null &&
            mounted &&
            current != null &&
            !current.archived) {
          if (isScheduledOn(current, scope.today) &&
              !scope.index.paused(current.id, scope.today) &&
              !current.isNegative) {
            unawaited(checkIn(context, scope, current));
          } else {
            unawaited(nav.pushNamed('/habit/${current.id}'));
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _clockWatch?.cancel();
    unawaited(_links?.cancel());
    scope.autoBackup?.dispose();
    if (widget.driveSync == null) drive?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_changed);
    scope.area.removeListener(_ads);
    folder?.dispose();
    scope.dispose();
    if (widget.controller == null) c.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    c.automationForeground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      _refreshClock();
      _sync();
      drive?.resumed();
      folder?.driver.resumed();
      _evaluateRules();
    }
  }

  @override
  void didChangePlatformBrightness() => _sync();
  void _evaluateRules() {
    if (!c.automationAllowed || c.state == null) return;
    unawaited(
      c.change((s) => s).catchError((Object _) {
        final context = navigator.currentContext;
        if (mounted && context != null && context.mounted) {
          showHandyMessage(
            context,
            tr(
              context,
              'Automatic change not saved. Nothing changed. Review Local rules in Settings.',
              'Chưa lưu thay đổi tự động. Không có gì thay đổi. Xem Quy tắc cục bộ trong Cài đặt.',
            ),
          );
        }
      }),
    );
  }

  @override
  void didChangeLocales(List<Locale>? locales) => _sync();

  void _refreshClock() {
    if (!mounted || c.state == null) return;
    final next = '${scope.today}:${scope.hour}';
    if (_clockStamp == next) return;
    _clockStamp = next;
    scope.clockTick.value++;
    _sync();
    _evaluateRules();
  }

  bool _driveStarted = false;
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
      if (drive != null && !_driveStarted) {
        _driveStarted = true;
        unawaited(drive!.start());
      }
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
    unawaited(
      scope.reminders
          .sync(s)
          .then(
            (_) {
              if (mounted) scope.reminderError.value = null;
            },
            onError: (Object e) {
              if (mounted) scope.reminderError.value = e;
            },
          ),
    );
    if (widget.device) {
      final locale = s.settings['locale'] as String? ?? 'system';
      final vi =
          locale == 'vi' ||
          locale == 'system' &&
              WidgetsBinding.instance.platformDispatcher.locale.languageCode ==
                  'vi';
      final views = habitWidgetViews(
        s,
        scope.today,
        vi: vi,
        pro: _widgetPro,
        dark:
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
      );
      _widgetQueue = _widgetQueue.catchError((Object _) {}).then((_) async {
        if (!mounted) return;
        await widgetFeed.publish(views['today']!);
        await singleWidgetFeed.publish(views['habit']!);
        await routineWidgetFeed.publish(views['routine']!);
      });
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
      ['', 'progress', 'smart'] => () => HabitSmartPage(scope: scope),
      ['', 'settings', 'folder-sync'] => () => HabitFolderPage(scope: scope),
      ['', 'settings', 'rules'] => () => HabitRulesPage(scope: scope),
      ['', 'habits', 'batch'] => () => HabitBatchPage(scope: scope),
      ['', 'settings', 'studio'] => () => HabitStudioPage(scope: scope),
      ['', 'settings', 'widgets'] => () => HabitWidgetsPage(scope: scope),
      ['', 'settings', 'notifications'] => () => HabitNotificationSettingsPage(
        scope: scope,
      ),
      ['', 'settings', 'notifications', 'diagnostics'] =>
        () => HabitReminderDiagnosticsPage(scope: scope),
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
          s.arguments is String ? s.arguments as String : null,
        ),
      ),
      ['', 'habit', final id, 'edit'] => () => Builder(
        builder: (context) => switch (scope.habit(id)) {
          final h? => buildHabitEditor(context, scope, h),
          _ => _missing('/habits'),
        },
      ),
      ['', 'routine', 'new'] => () => Builder(
        builder: (context) => buildRoutineEditor(
          context,
          scope,
          null,
          s.arguments is Routine ? s.arguments as Routine : null,
        ),
      ),
      ['', 'routine', final id, 'edit'] => () => Builder(
        builder: (context) => switch (scope.routine(id)) {
          final r? => buildRoutineEditor(context, scope, r),
          _ => _missing('/routines'),
        },
      ),
      ['', 'templates'] => () => HabitTemplatesPage(
        scope: scope,
        collection: uri.queryParameters['collection'],
        routines: uri.queryParameters['kind'] == 'routine',
      ),
      ['', 'templates', final id] => () {
        final h = habitPresets.where((p) => p.id == id).firstOrNull;
        final r = routineTemplateCatalog.where((p) => p.id == id).firstOrNull;
        return h == null && r == null
            ? _missing('/templates')
            : TemplatePreviewPage(scope: scope, habit: h, routine: r);
      },
      ['', 'welcome'] => () => HabitWelcomePage(
        replay: true,
        onDone: () async {
          navigator.currentState?.pop();
        },
      ),
      ['', 'help'] => () => HabitHelpPage(
        query: uri.queryParameters['q'] ?? '',
      ),
      ['', 'help', final topic] => () => HabitHelpPage(
        topic: topic,
        query: uri.queryParameters['q'] ?? '',
      ),
      ['', 'settings', 'preferences'] => () => HabitPreferencesPage(
        scope: scope,
      ),
      ['', 'settings', 'pauses'] => () => HabitPausesPage(scope: scope),
      ['', 'settings', 'data-tools'] => () => HabitDataToolsPage(scope: scope),
      ['', 'settings', 'trash'] => () => HabitTrashPage(scope: scope),
      ['', 'settings', 'sync'] =>
        () =>
            drive == null ? _missing('/settings') : HabitSyncPage(scope: scope),
      ['', 'settings'] => () => HabitSettingsPage(scope: scope),
      ['', 'pro'] => () => HabitProPage(
        // Opened from a locked feature: that feature leads the page.
        focused: uri.queryParameters.containsKey('feature'),
        feature:
            HabitProFeature.values
                .where((f) => f.name == uri.queryParameters['feature'])
                .firstOrNull ??
            HabitProFeature.days,
      ),
      ['', 'mood', final day] =>
        () => _validMoodDay(day)
            ? MoodSheet(scope: scope, day: day)
            : _missing('/progress'),
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
        parts.length >= 2 && parts[1] == 'templates') {
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
    if (parts.length == 3 && parts[1] == 'mood') {
      final context = navigator.currentContext;
      if (context != null &&
          MediaQuery.sizeOf(context).width >= HandySpace.wide) {
        return DialogRoute<bool>(
          context: context,
          settings: s,
          barrierDismissible: false,
          builder: (context) => Dialog(
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: MediaQuery.sizeOf(context).height * .88,
              ),
              child: _ready(page),
            ),
          ),
        );
      }
      return MaterialPageRoute<bool>(settings: s, builder: (_) => _ready(page));
    }
    return MaterialPageRoute<void>(settings: s, builder: (_) => _ready(page));
  }

  bool _validMoodDay(String value) {
    try {
      date(value);
      return value.compareTo(scope.today) <= 0;
    } catch (_) {
      return false;
    }
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
    listenable: c.appearance,
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
          // The system setting, or an older app-level choice (cleared by
          // Reset preferences).
          disableAnimations:
              MediaQuery.disableAnimationsOf(context) ||
              c.state?.settings['reducedMotion'] == true,
        ),
        child: widget.lifetime == null
            ? _styled(child)
            : LifetimeScope(notifier: widget.lifetime!, child: _styled(child)),
      ),
      home: _ready(() => HabitShell(scope: scope)),
    ),
  );

  Widget _styled(Widget child) => Builder(
    builder: (context) {
      final pro = LifetimeScope.maybeOf(context)?.pro == true;
      c.automationAllowed = pro;
      if (_widgetPro != pro) {
        _widgetPro = pro;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _sync();
            if (pro && c.state != null) _evaluateRules();
          }
        });
      }
      return Theme(
        data: habitTheme(
          Theme.of(context),
          style: StudioStyle.read(
            c.state?.settings ?? {},
            pro: LifetimeScope.maybeOf(context)?.pro == true,
          ),
        ),
        child: Focus(onKeyEvent: _key, child: child),
      );
    },
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
