import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_files/backup_folder.dart' show privateBackupFolders;
import 'package:handy_ui/kit.dart';
import 'board/board_page.dart';
import 'card/card_sheet.dart';
import 'controller.dart';
import 'create/gallery.dart';
import 'create/new_board.dart';
import 'create/setup_page.dart';
import 'design/identity.dart';
import 'design/theme.dart';
import 'export/export_page.dart';
import 'home/home_page.dart';
import 'pages/more_pages.dart';
import 'platform/export_job.dart';
import 'platform/home_surface.dart';
import 'platform/reminders.dart';
import 'platform/share_inbox.dart';
import 'pro/pro.dart';
import 'scope.dart';
import 'settings/how_to_page.dart';
import 'sync/drive_sync.dart';
import 'settings/settings_page.dart';
import 'welcome/welcome_page.dart';

const boardsBrand = boardsIdentity;

/// Handy Boards: Home (my boards) → a board (Kanban + category strip) →
/// a card. Templates, Settings and Pro are pushed screens with their own
/// web URLs (`/board/<id>`, `/templates`, `/settings`, `/pro`).
class BoardsApp extends StatefulWidget {
  final BoardsController? controller;
  final DateTime Function()? clock;
  const BoardsApp({super.key, this.controller, this.clock});
  @override
  State<BoardsApp> createState() => _BoardsAppState();
}

class _BoardsAppState extends State<BoardsApp> with WidgetsBindingObserver {
  final navigator = GlobalKey<NavigatorState>();
  final homeSurface = BoardsHomeSurface();
  final inbox = BoardsShareInbox();
  final noAds = ValueNotifier(false);
  late final c = widget.controller ?? BoardsController();
  late final BoardsReminders reminderPort = BoardsReminders(
    onTask: (id) {
      final ctx = navigator.currentContext;
      if (mounted && ctx != null && c.state?.maybe('tasks', id) != null)
        openCard(ctx, scope, id);
    },
  );
  late final scope = BoardsScope(
    c,
    clock: widget.clock,
    reminders: reminderPort,
    // On a device only (tests pass their own controller): a copy a day
    // when something changed, kept in the app's own storage.
    autoBackup: widget.controller == null && !kIsWeb
        ? HandyAutoBackup.local(
            app: 'boards',
            extension: 'zip',
            build: () => fullBackupBytes(c.state!, c.store),
            folders: privateBackupFolders(),
            revision: () => c.state?.revision.toString(),
          )
        : null,
    drive: widget.controller == null && driveSyncOffered
        ? BoardsDriveSync(c)
        : null,
  );
  bool replayWelcome = false, tidied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.controller == null)
      c.afterCommit = (s) async {
        await Future.wait<void>([
          reminderPort.sync(s),
          homeSurface.publish(s, DateTime.now(), vi: _vi(s)),
        ]);
      };
    if (c.state == null) {
      c.load().then((_) => _started());
    } else {
      _started();
    }
    inbox.listen(_takeShares);
    _takeShares();
    homeSurface.listen(_link);
  }

  bool _vi(BoardsState s) =>
      s.preferences['locale'] == 'vi' ||
      ((s.preferences['locale'] ?? 'system') == 'system' &&
          WidgetsBinding.instance.platformDispatcher.locale.languageCode ==
              'vi');

  void _started() {
    _tidy();
    if (c.state != null) scope.autoBackup?.attach();
    if (scope.drive case final drive?) {
      c.addListener(drive.changed);
      // Sync left on: the other devices' changes arrive now.
      unawaited(drive.syncNow());
    }
  }

  void _replay() {
    navigator.currentState?.popUntil((r) => r.isFirst);
    setState(() => replayWelcome = true);
  }

  /// Once per start: older data becomes one-level Kanban (nothing lost),
  /// and the archive preset runs if it is on.
  Future<void> _tidy() async {
    if (tidied || c.state == null) return;
    tidied = true;
    try {
      await c.change(
        (s) => archiveFinished(
          kanbanize(s, now: scope.clock()),
          now: scope.clock(),
        ),
        history: false,
      );
    } catch (e) {
      c.adapterWarning = e.toString();
    }
  }

  /// Text shared from another app becomes a card in the first column of
  /// the most recently used board (Undo is one tap away).
  Future<void> _takeShares() async {
    try {
      final rows = await inbox.pending();
      if (rows.isEmpty) return;
      if (c.state == null) await c.load();
      final s = c.state;
      final board = s == null ? null : homeBoards(s).firstOrNull;
      if (board == null) return;
      final column = columnsOf(s!, board.id).first.id;
      for (final share in rows) {
        final title =
            (share.title?.trim().isNotEmpty == true ? share.title! : share.text)
                .trim();
        await c.change((s) {
          final t =
              newTask(
                s,
                board.id,
                title.length > 1000 ? title.substring(0, 1000) : title,
              ).copy({
                'status': column,
                'order': -1,
                'notes': share.title == null ? '' : share.text,
              });
          return saveTask(s, t, now: scope.clock());
        });
        await inbox.acknowledge(share.id);
      }
      final ctx = navigator.currentContext;
      if (ctx != null && ctx.mounted)
        showUndo(
          ctx,
          scope,
          tr(
            ctx,
            'Added to ${board.str('title')}',
            'Đã thêm vào ${board.str('title')}',
          ),
        );
    } catch (_) {
      // Shares stay queued; they are taken next time.
    }
  }

  /// Home-screen widget links: open the app, a card, or quick-add.
  void _link(Uri uri) {
    final ctx = navigator.currentContext;
    final s = c.state;
    if (ctx == null || s == null || uri.scheme != 'handy-boards') return;
    if (uri.host == 'task') {
      final id = uri.queryParameters['id'];
      if (id != null && s.maybe('tasks', id) != null) openCard(ctx, scope, id);
    } else if (uri.host == 'capture') {
      final board = homeBoards(s).firstOrNull;
      if (board == null) {
        newBoard(ctx, scope);
      } else {
        navigator.currentState?.pushNamed('/board/${board.id}');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_takeShares());
      scope.drive?.resumed();
    }
    if (state == AppLifecycleState.paused) scope.drive?.paused();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    homeSurface.dispose();
    scope.autoBackup?.dispose();
    if (scope.drive case final drive?) {
      c.removeListener(drive.changed);
      drive.dispose();
    }
    inbox.dispose();
    noAds.dispose();
    if (widget.controller == null) c.dispose();
    super.dispose();
  }

  /// After the guide: remember it was seen and the purpose picked (only
  /// for suggestions), then open what was chosen. Nothing is created here:
  /// a template opens its own setup, a blank board its short form.
  Future<void> _welcomed(String? next, String? purpose) async {
    await c.change(
      (s) => s.copy(
        preferences: {...s.preferences, 'welcomed': true, 'purpose': ?purpose},
      ),
      history: false,
    );
    if (mounted) setState(() => replayWelcome = false);
    final nav = navigator.currentState;
    final ctx = navigator.currentContext;
    if (nav == null || ctx == null) return;
    if (next == 'gallery') {
      nav.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/templates'),
          builder: (_) => TemplateGallery(
            scope: scope,
            group: switch (purpose) {
              'study' => TemplateGroup.study,
              'work' => TemplateGroup.work,
              _ => null,
            },
          ),
        ),
      );
    } else if (next == 'blank') {
      if (ctx.mounted) await createBlank(ctx, scope);
    } else if (next != null && next.startsWith('template:')) {
      final t = templateById(next.substring(9));
      if (t != null)
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => SetupPage(scope: scope, template: t),
          ),
        );
    }
  }

  Route<void>? _route(RouteSettings settings) {
    final name = settings.name ?? '/';
    Widget? page;
    if (name.startsWith('/board/')) {
      page = BoardPage(scope: scope, board: name.substring(7));
    } else {
      page = switch (name) {
        '/templates' => TemplateGallery(scope: scope),
        '/settings' => SettingsPage(scope: scope),
        '/how-to' => HowToPage(onReplayWelcome: _replay),
        '/pro' => ProPage(focus: settings.arguments as ProFeature?),
        '/search' => SearchPage(scope: scope),
        '/trash' => TrashPage(scope: scope),
        '/insights' => InsightsPage(
          scope: scope,
          board: settings.arguments as String,
        ),
        '/export' => ExportPage(
          scope: scope,
          board: settings.arguments as String,
        ),
        _ => null,
      };
    }
    if (page == null) return null;
    final shown = page;
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => c.state == null ? const HandyLoading() : shown,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final s = c.state;
      final welcome =
          s != null &&
          (replayWelcome ||
              (s.preferences['welcomed'] != true && s.rows('boards').isEmpty));
      return HandyApp(
        app: 'boards',
        navigatorKey: navigator,
        title: 'Handy Boards',
        accent: BoardsPalette.light.primary,
        brand: boardsBrand,
        themeOverride: boardsTheme,
        locale: s?.preferences['locale'] ?? 'system',
        theme: s?.preferences['theme'] ?? 'system',
        // Handy Boards carries no ads.
        adsVisible: noAds,
        onGenerateRoute: _route,
        home: welcome
            ? WelcomePage(
                onDone: _welcomed,
                replay: replayWelcome && s.preferences['welcomed'] == true,
              )
            : HomePage(scope: scope),
      );
    },
  );
}
