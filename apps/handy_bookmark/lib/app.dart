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
import 'package:handy_files/backup_folder.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'bookmark/bookmark_page.dart';
import 'controller.dart';
import 'data/import_export.dart';
import 'focus/focus_page.dart';
import 'library/library_page.dart';
import 'library/results_page.dart';
import 'links/link_tasks.dart';
import 'platform/store.dart';
import 'reader/reader_page.dart';
import 'scope.dart';
import 'security/app_lock.dart';
import 'bookmark/add_link.dart';
import 'platform/home_widgets.dart';
import 'services/problem_notices.dart';
import 'settings/widgets_page.dart';
import 'services/reminders.dart';
import 'services/share_targets.dart';
import 'ui/collection_picker.dart';
import 'library/trash_page.dart';
import 'settings/duplicates_page.dart';
import 'settings/how_to_page.dart';
import 'settings/save_settings.dart';
import 'shell/save_shell.dart';
import 'view/library_view.dart';
import 'welcome/welcome_page.dart';
import 'share_sheet/snapshot.dart';
import 'sync/drive_sync.dart';

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
            // In the app's own storage: nothing to choose (see Settings).
            folders: privateBackupFolders(),
            // An unchanged library is not copied again.
            revision: () {
              final l = c.library;
              if (l == null) return null;
              final last = [
                for (final b in l.bookmarks) b.updatedAt,
              ].fold<String>('', (a, b) => b.compareTo(a) > 0 ? b : a);
              return '${l.bookmarks.length}|${l.collections.length}|'
                  '${l.trash.length}|$last';
            },
          )
        : null,
    drive: widget.device && driveSyncOffered ? DriveSync(c) : null,
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
    c.onShareReminderMoved = reminders.cancelShare;
    scope.autoBackup?.addListener(_checkProblems);
    tasks.addListener(_taskChanged);
    if (widget.device) {
      _widgetLinks = homeWidgets.links().listen(_openWidgetLink);
    }
    scope.drive?.addListener(_checkProblems);
    // What is already there is not new: only later saves meet the rules.
    if (c.library != null) _seen = {for (final b in c.library!.bookmarks) b.id};
    _loadPreferences();
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_changed);
    scope.autoBackup?.removeListener(_checkProblems);
    tasks.removeListener(_taskChanged);
    _widgetLinks?.cancel();
    homeWidgets.dispose();
    scope.drive?.removeListener(_checkProblems);
    scope.autoBackup?.dispose();
    scope.drive?.dispose();
    _sync?.cancel();
    tasks.cancel();
    tasks.dispose();
    view.dispose();
    if (widget.controller == null) c.dispose();
    prefs.dispose();
    super.dispose();
  }

  final homeWidgets = BookmarkHomeWidgets();
  StreamSubscription<Uri>? _widgetLinks;

  /// Keeps the home-screen widgets in step with the library.
  void _publishWidgets() {
    final l = c.library, ctx = navigator.currentContext;
    if (!widget.device || l == null || ctx == null) return;
    homeWidgets.schedule(
      l,
      c.preferences,
      vi: prefs.value?.locale == 'vi',
      pro: hasPro(ctx),
      thumbnail: c.thumbnail,
    );
  }

  /// A tap on a widget: paste a link, an item, a collection, the unread,
  /// or the Pro page for a locked one.
  void _openWidgetLink(Uri uri) {
    final nav = navigator.currentState, ctx = navigator.currentContext;
    if (nav == null || ctx == null || c.library == null) return;
    final id = uri.queryParameters['id'];
    switch (uri.host) {
      case 'save':
        nav.popUntil((r) => r.isFirst);
        unawaited(addLinks(ctx, scope, fromClipboard: true));
      case 'item' when id != null:
        nav.pushNamed('/bookmark/$id');
      case 'collection' when id != null:
        nav.pushNamed('/collection/$id');
      case 'unread':
        nav.pushNamed('/place/unread');
      case 'inbox':
        nav.pushNamed('/place/inbox');
      case 'library':
        nav.pushNamed('/library');
      case 'pro':
        nav.pushNamed('/pro');
    }
  }

  LinkJobReport? _toldReport;

  /// A link check or offline-copy run that ended while the app was away:
  /// one notification when the person turned that on (off by default).
  void _taskChanged() {
    final r = tasks.last;
    if (r == null || identical(r, _toldReport)) return;
    _toldReport = r;
    if (r.cancelled ||
        _foreground ||
        !widget.device ||
        c.preferences['taskNotices'] != true)
      return;
    unawaited(
      notifyTaskDone(
        reminders,
        check: r.job == LinkJob.check,
        done: r.done,
        broken: r.broken,
        vietnamese: prefs.value?.locale == 'vi',
      ).catchError((Object _) {}),
    );
  }

  /// Whether the app is on screen (then problems show in it, not as a
  /// notification).
  bool _foreground = true;
  late final problems = ProblemNotices(reminders);

  /// Backup, sync or shares that need the person, as notifications while
  /// the app is away (Settings › Notifications › Needs attention).
  void _checkProblems() {
    if (!widget.device || c.library == null) return;
    final vi = prefs.value?.locale == 'vi';
    unawaited(
      problems
          .update(
            currentProblems(
              vietnamese: vi,
              backupError: scope.autoBackup?.settings.enabled == true
                  ? scope.autoBackup?.settings.lastError
                  : null,
              syncState: scope.drive?.enabled == true
                  ? scope.drive?.state.name
                  : null,
              failedShares: c.invalidShares.length,
            ),
            enabled: c.preferences['problemNotices'] != false,
            foreground: _foreground,
            vietnamese: vi,
          )
          .catchError((Object _) {}),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (state != AppLifecycleState.resumed) _checkProblems();
    if (state == AppLifecycleState.resumed) {
      unawaited(c.drain());
      // Buttons pressed on a reminder while the app was away.
      unawaited(_applyNotifyActions());
      scope.drive?.resumed();
    }
    if (state == AppLifecycleState.paused) scope.drive?.paused();
  }

  Future<void> _start() async {
    if (c.library == null) await c.initialize();
    if (!mounted) return;
    await view.reload();
    try {
      _pendingOpen = await reminders.initialize(
        _openFromNotification,
        onButton: () => unawaited(_applyNotifyActions()),
      );
      await _applyNotifyActions();
    } catch (_) {
      // Reminders are optional; the links work without them.
    }
    if (_pendingOpen != null) _openFromNotification(_pendingOpen!);
    scope.autoBackup?.attach();
    // Sync left on: the other devices' changes arrive now.
    unawaited(scope.drive?.syncNow());
    if (mounted) setState(() {});
    if (widget.guide && c.library != null && shouldShowGuide(scope))
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => navigator.currentState?.pushNamed('/welcome'),
      );
  }

  /// A tapped notification: a reminder opens its item (and is done), a
  /// share sheet reminder opens the item that share became, a "needs
  /// attention" one opens where it is fixed.
  void _openFromNotification(String payload) {
    final nav = navigator.currentState;
    if (nav == null || c.library == null) {
      _pendingOpen = payload;
      return;
    }
    _pendingOpen = null;
    switch (payload) {
      case 'problem:backup' || 'problem:sync':
        nav.pushNamed('/settings');
        return;
      case 'problem:shares':
        nav.popUntil((r) => r.isFirst);
        return;
    }
    if (payload.startsWith(sharePrefix)) {
      unawaited(() async {
        final share = payload.substring(sharePrefix.length);
        if (!c.sharedInto.containsKey(share)) await c.drain();
        final id = c.sharedInto[share];
        if (id != null) _openReminded(id);
      }());
      return;
    }
    _openReminded(readPayload(payload).id);
  }

  void _openReminded(String id) {
    final b = c.library?.bookmarks.where((b) => b.id == id).firstOrNull;
    if (b == null) return;
    navigator.currentState?.pushNamed('/bookmark/$id');
    final at = b.reminderAt == null ? null : DateTime.tryParse(b.reminderAt!);
    if (at != null && !at.isAfter(DateTime.now())) {
      unawaited(
        c
            .put(b.copyWith(reminderAt: null, updatedAt: saveTime()))
            .catchError((Object _) {}),
      );
    }
  }

  /// "Mark as read" and "Remind in 1 hour" pressed on notifications, put
  /// into the library before reminders are planned again.
  Future<void> _applyNotifyActions() async {
    if (c.library == null || !reminders.supported) return;
    try {
      final actions = await takeNotifyActions();
      if (actions.isEmpty) return;
      final byId = {for (final a in actions) a.id: a};
      await c.update(
        (l) => l.copyWith(
          bookmarks: [
            for (final b in l.bookmarks)
              if (byId[b.id] case final a?)
                a.action == readAction
                    ? b.copyWith(
                        isRead: true,
                        reminderAt: null,
                        updatedAt: saveTime(),
                      )
                    : b.copyWith(
                        reminderAt: a.at?.toUtc().toIso8601String(),
                        updatedAt: saveTime(),
                      )
              else
                b,
          ],
        ),
      );
    } catch (_) {
      // Kept for the next start.
    }
  }

  /// After any change: rebuild, and keep the OS reminders in step.
  String? _offered, _sheet;

  /// Keeps the share sheet's top row in step with the library: the four
  /// collections saved into most recently, each in its own colour. Sent
  /// only when that set changes (the system limits how often apps may).
  void _offerCollections() {
    final l = c.library, context = navigator.currentContext;
    if (!widget.device || l == null || context == null) return;
    // What the share sheet lists (all collections, their counts, the
    // theme): written on the device whenever it changes.
    final sheet = sheetSnapshot(
      l,
      c.preferences,
      theme: prefs.value?.theme ?? 'system',
      locale: prefs.value?.locale ?? 'system',
    );
    if (sheet != _sheet) {
      _sheet = sheet;
      unawaited(c.inbox.offerSheet(sheet));
    }
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

  void _changed() {
    if (mounted) setState(() {});
    scope.drive?.changed();
    _organizeNew();
    _offerCollections();
    _sync?.cancel();
    _sync = Timer(const Duration(milliseconds: 300), () async {
      final p = c.preferences;
      if (c.library == null) return;
      _checkProblems();
      _publishWidgets();
      final on = p['notifications'] == true;
      // With every reminder off, what was scheduled is cancelled once
      // (sync cancels all of ours when nothing is wanted), then left be.
      if (!on && _remindersCleared) return;
      try {
        await reminders.sync(
          c.library!.bookmarks,
          enabled: on,
          vietnamese: prefs.value?.locale == 'vi',
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
    // The share sheet follows the theme and language too.
    _offerCollections();
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
      ['', 'widgets'] => () => WidgetsPage(scope: scope),
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
