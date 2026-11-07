import 'design/identity.dart';
import 'pro/organize_page.dart';
import 'pro/picture_text.dart';
import 'library/find_page.dart';
import 'pro/export/export_studio.dart';
import 'design/theme.dart';
import 'design/looks.dart';
import 'pro/entitlements.dart';
import 'pro/explore_pro.dart';
import 'pro/theme_studio.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'bookmark/bookmark_page.dart';
import 'controller.dart';
import 'data/import_export.dart';
import 'focus/focus_page.dart';
import 'home/file_shared_sheet.dart';
import 'library/library_page.dart';
import 'library/results_page.dart';
import 'links/link_tasks.dart';
import 'platform/store.dart';
import 'reader/reader_page.dart';
import 'scope.dart';
import 'security/app_lock.dart';
import 'services/reminders.dart';
import 'services/revisit.dart';
import 'services/share_targets.dart';
import 'ui/collection_picker.dart';
import 'library/trash_page.dart';
import 'settings/duplicates_page.dart';
import 'settings/how_to_page.dart';
import 'settings/save_settings.dart';
import 'shell/save_shell.dart';
import 'view/library_view.dart';
import 'welcome/welcome_page.dart';

bool _photoCredits = false;

/// The guide's photographs are CC BY / CC BY-SA: their credits show in
/// Settings > Licenses beside the fonts'.
void _registerPhotoCredits() {
  if (_photoCredits) return;
  _photoCredits = true;
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Handy Bookmark guide photographs',
    ], await rootBundle.loadString('assets/welcome/CREDITS.txt'));
  });
}

/// Save's hue in the suite palette (docs/UX_REDESIGN.md).
const saveAccent = Color(0xFF0E7490);

final _noAds = ValueNotifier<bool>(false);

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
    _registerPhotoCredits();
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_changed);
    // What is already there is not new: only later saves meet the rules.
    if (c.library != null) _seen = {for (final b in c.library!.bookmarks) b.id};
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
    if (id == revisitPayload) {
      nav.pushNamed('/focus');
    } else if (c.library!.bookmarks.any((b) => b.id == id)) {
      nav.pushNamed('/bookmark/$id');
    }
  }

  /// After any change: rebuild, and keep the OS reminders in step.
  String? _offered;

  /// Keeps the share sheet's top row in step with the library: the four
  /// collections saved into most recently, each in its own colour. Sent
  /// only when that set changes (the system limits how often apps may).
  void _offerCollections() {
    final l = c.library, context = navigator.currentContext;
    if (!widget.device || l == null || context == null) return;
    final targets = [
      for (final col in shareTargets(l))
        (
          id: col.id,
          name: col.name,
          color: HandyPalette.of(
            context,
            collectionHue(l, col.id),
          ).mark.toARGB32(),
        ),
    ];
    final key = [
      for (final t in targets) '${t.id}|${t.name}|${t.color}',
    ].join(';');
    if (key == _offered) return;
    _offered = key;
    unawaited(c.inbox.offerCollections(targets));
  }

  Set<String>? _seen;

  /// New saves meet the person's Auto-organize rules (Pro, opt-in).
  void _organizeNew() {
    final l = c.library;
    if (l == null) return;
    final ids = {for (final b in l.bookmarks) b.id};
    final before = _seen;
    _seen = ids;
    if (before == null) return;
    final fresh = ids.difference(before);
    final context = navigator.currentContext;
    if (fresh.isEmpty || context == null || !hasPro(context)) return;
    unawaited(organizeNewSaves(c, fresh).catchError((Object _) {}));
    // New pictures are read for Search in the background (Pro, offline).
    PictureTextQueue.add(c, [
      for (final b in l.bookmarks)
        if (b.isImage && fresh.contains(b.id)) b.id,
    ]);
  }

  /// Whether the "Saved, put it in?" sheet is open.
  bool _filing = false;

  /// After a Share without a collection has been saved: ask where it goes.
  /// Shares that arrive while the sheet is open wait for the next one.
  void _fileShared() {
    if (_filing || c.sharedToFile.isEmpty) return;
    _filing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context = navigator.currentState?.overlay?.context;
      if (!mounted || context == null) {
        _filing = false;
        return;
      }
      final ids = [...c.sharedToFile];
      c.sharedToFile.clear();
      try {
        await showFileShared(context, scope, ids);
      } finally {
        _filing = false;
      }
      if (mounted) _fileShared();
    });
  }

  void _changed() {
    if (mounted) setState(() {});
    _organizeNew();
    _offerCollections();
    _fileShared();
    _sync?.cancel();
    _sync = Timer(const Duration(milliseconds: 300), () async {
      final p = c.preferences;
      if (c.library == null) return;
      final on = p['notifications'] == true || p['revisit'] == true;
      // With every reminder off, what was scheduled is cancelled once
      // (sync cancels all of ours when nothing is wanted), then left be.
      if (!on && _remindersCleared) return;
      try {
        await reminders.sync(
          c.library!.bookmarks,
          enabled: p['notifications'] == true,
          vietnamese: prefs.value?.locale == 'vi',
          revisit: p['revisit'] == true
              ? planRevisit(
                  c.library!.bookmarks,
                  now: DateTime.now(),
                  weekday: p['revisitDay'] as int? ?? DateTime.sunday,
                  hour: p['revisitHour'] as int? ?? 19,
                )
              : null,
        );
        _remindersCleared = !on;
      } catch (_) {
        // Turned off: tried again on the next change, without a message.
        if (on) c.notice = 'notifications_unavailable';
      }
    });
  }

  /// Every reminder is off and the scheduled ones were cancelled.
  bool _remindersCleared = false;

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
      // The chosen look (a premium one only while Pro is verified).
      return LookScope(chosen: c.preferences['look'] as String?, child: page());
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
      ['', 'how-to'] => () => const HowToPage(),
      ['', 'duplicates'] => () => DuplicatesPage(scope: scope),
      ['', 'trash'] => () => TrashPage(scope: scope),
      ['', 'library'] => () => LibraryPage(scope: scope),
      ['', 'find'] => () => FindPage(scope: scope, onExport: export),
      ['', 'looks'] => () => ThemeStudio(scope: scope),
      ['', 'organize'] => () => OrganizePage(scope: scope),
      ['', 'export', final id] => () => ExportStudio(
        scope: scope,
        collectionId: id,
      ),
      ['', 'pro'] => () => ExplorePro(
        scope: scope,
        focus: s.arguments is ProFeature ? s.arguments as ProFeature : null,
      ),
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
      themeOverride: bookmarkTheme,
      // Handy Bookmark carries no ads, whatever the shared config says.
      adsVisible: _noAds,
      app: 'bookmark',
      title: 'Handy Bookmark',
      accent: saveAccent,
      theme: p?.theme ?? 'system',
      locale: p?.locale ?? 'system',
      navigatorKey: navigator,
      onGenerateRoute: _route,
      // The app lock covers everything, sheets and dialogs included.
      wrap: (context, child) => LockGate(
        enabled: c.preferences[appLockKey] == true,
        loaded: c.library != null,
        child: child,
      ),
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
