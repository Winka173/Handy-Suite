import 'design/identity.dart';
import 'dart:async';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'bookmark/bookmark_page.dart';
import 'controller.dart';
import 'data/import_export.dart';
import 'focus/focus_page.dart';
import 'library/results_page.dart';
import 'links/link_tasks.dart';
import 'platform/store.dart';
import 'reader/reader_page.dart';
import 'scope.dart';
import 'services/reminders.dart';
import 'library/trash_page.dart';
import 'settings/duplicates_page.dart';
import 'settings/save_settings.dart';
import 'shell/save_shell.dart';
import 'view/library_view.dart';
import 'welcome/welcome_page.dart';

/// Save's hue in the suite palette (docs/UX_REDESIGN.md).
const saveAccent = Color(0xFF0E7490);

class SaveApp extends StatefulWidget {
  final SaveController? controller;
  final PreferencesRepository? preferences;
  final HandyFiles files;
  final SaveReminders? reminders;

  /// Off in host tests: no folder backups.
  final bool device;

  /// Opens the first-run guide on an empty library (off in most tests).
  final bool guide;
  const SaveApp({
    super.key,
    this.controller,
    this.preferences,
    this.files = const SystemHandyFiles(),
    this.reminders,
    this.device = true,
    this.guide = true,
  });
  @override
  State<SaveApp> createState() => _SaveAppState();
}

class _SaveAppState extends State<SaveApp> with WidgetsBindingObserver {
  late final c = widget.controller ?? SaveController();
  late final repo =
      widget.preferences ??
      DevicePreferencesRepository(
        'handy-save',
        knownTools: {},
        workflowSteps: {},
      );
  late final view = LibraryView(c);
  late final reminders = widget.reminders ?? SaveReminders();
  late final tasks = LinkTasks(c);
  late final SaveScope scope = SaveScope(
    c: c,
    view: view,
    files: widget.files,
    reminders: reminders,
    tasks: tasks,
    autoBackup: widget.device
        ? HandyAutoBackup.local(
            app: 'bookmark',
            extension: 'zip',
            build: () => scope.fullBackup(),
          )
        : null,
  );
  final navigator = GlobalKey<NavigatorState>();
  final prefs = ValueNotifier<HandyPreferences?>(null);
  Timer? _sync;
  String? _pendingOpen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_changed);
    _loadPreferences();
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_changed);
    scope.autoBackup?.dispose();
    _sync?.cancel();
    tasks.cancel();
    tasks.dispose();
    view.dispose();
    if (widget.controller == null) c.dispose();
    prefs.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(c.drain());
  }

  Future<void> _start() async {
    if (c.library == null) await c.initialize();
    if (!mounted) return;
    await view.reload();
    try {
      _pendingOpen = await reminders.initialize(_openFromNotification);
    } catch (_) {
      // Reminders are optional; the links work without them.
    }
    if (_pendingOpen != null) _openFromNotification(_pendingOpen!);
    scope.autoBackup?.attach();
    if (mounted) setState(() {});
    if (widget.guide && c.library != null && shouldShowGuide(scope))
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => navigator.currentState?.pushNamed('/welcome'),
      );
  }

  void _openFromNotification(String id) {
    final nav = navigator.currentState;
    if (nav == null || c.library == null) {
      _pendingOpen = id;
      return;
    }
    _pendingOpen = null;
    if (c.library!.bookmarks.any((b) => b.id == id))
      nav.pushNamed('/bookmark/$id');
  }

  /// After any change: rebuild, and keep the OS reminders in step.
  void _changed() {
    if (mounted) setState(() {});
    _sync?.cancel();
    _sync = Timer(const Duration(milliseconds: 300), () async {
      if (c.library == null || c.preferences['notifications'] != true) return;
      try {
        await reminders.sync(
          c.library!.bookmarks,
          enabled: true,
          vietnamese: prefs.value?.locale == 'vi',
        );
      } catch (_) {
        c.notice = 'notifications_unavailable';
      }
    });
  }

  Future<void> _loadPreferences() async {
    try {
      final p = await repo.load();
      if (mounted) setState(() => prefs.value = p);
    } catch (_) {
      if (mounted) setState(() => prefs.value = HandyPreferences());
    }
  }

  Future<void> _save(HandyPreferences next) async {
    await repo.save(next);
    if (mounted) setState(() => prefs.value = next);
  }

  Future<void> _recover(BuildContext context) async {
    final ok = await confirmHandy(
      context,
      title: tr(
        context,
        'Keep a copy and start fresh?',
        'Giữ bản sao và bắt đầu lại?',
      ),
      message: tr(
        context,
        'The current database files are kept aside. Restore a backup afterwards.',
        'Các file dữ liệu hiện tại được giữ riêng. Sau đó hãy khôi phục bản sao lưu.',
      ),
      confirmLabel: tr(context, 'Keep and start fresh', 'Giữ và bắt đầu lại'),
    );
    if (!ok) return;
    await c.store?.close();
    c.store = null;
    await preserveAndResetBookmarkStore();
    await _start();
  }

  Widget _ready(Widget Function() page) => Builder(
    builder: (context) {
      if (c.library == null && c.error != null) {
        return HandyLoadError(
          title: tr(
            context,
            'Save could not open your links',
            'Save chưa mở được dữ liệu',
          ),
          error: c.error!,
          onRetry: _start,
          recovery: TextButton(
            key: const Key('save-recover'),
            onPressed: () => _recover(context),
            child: Text(
              tr(
                context,
                'Keep a copy and start fresh',
                'Giữ bản sao và bắt đầu lại',
              ),
            ),
          ),
        );
      }
      if (c.library == null) return const HandyLoading();
      return page();
    },
  );

  Route<dynamic>? _route(RouteSettings s) {
    void export() =>
        scope.exportLinks(navigator.currentContext!, selected: true);
    final parts = (s.name ?? '/').split('/');
    final Widget Function()? page = switch (parts) {
      ['', 'settings'] => () {
        return SaveSettingsPage(
          read: () => prefs.value!,
          save: _save,
          scope: scope,
        );
      },
      ['', 'focus'] => () => FocusPage(scope: scope),
      ['', 'welcome'] => () => WelcomePage(scope: scope),
      ['', 'duplicates'] => () => DuplicatesPage(scope: scope),
      ['', 'trash'] => () => TrashPage(scope: scope),
      ['', 'bookmark', final id] => () => BookmarkPage(scope: scope, id: id),
      ['', 'read', final id] => () => ReaderPage(scope: scope, id: id),
      ['', 'search', final id] => () => ResultsPage(
        scope: scope,
        place: Place.all,
        searchId: id,
        onExport: export,
      ),
      ['', 'collection', final id] => () => ResultsPage(
        scope: scope,
        place: Place.collection,
        id: id,
        onExport: export,
      ),
      ['', 'smart', final id] => () => ResultsPage(
        scope: scope,
        place: Place.smart,
        id: id,
        onExport: export,
      ),
      ['', 'tag', final t] => () => ResultsPage(
        scope: scope,
        place: Place.tag,
        id: Uri.decodeComponent(t),
        onExport: export,
      ),
      ['', 'place', final p] => () => ResultsPage(
        scope: scope,
        place: Place.values.firstWhere(
          (x) => x.name == p,
          orElse: () => Place.all,
        ),
        onExport: export,
      ),
      _ => null,
    };
    if (page == null) return null;
    return MaterialPageRoute<void>(settings: s, builder: (_) => _ready(page));
  }

  @override
  Widget build(BuildContext context) {
    final p = prefs.value;
    return HandyApp(
      brand: bookmarkIdentity,
      app: 'bookmark',
      title: 'Handy Bookmark',
      accent: saveAccent,
      theme: p?.theme ?? 'system',
      locale: p?.locale ?? 'system',
      navigatorKey: navigator,
      onGenerateRoute: _route,
      home: p == null
          ? const HandyLoading()
          : _ready(
              () => SaveShell(
                scope: scope,
                onExport: () => scope.exportLinks(
                  navigator.currentContext!,
                  selected: true,
                ),
              ),
            ),
    );
  }
}
