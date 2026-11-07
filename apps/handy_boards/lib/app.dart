import 'dart:async';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import 'board/board_page.dart';
import 'card/card_sheet.dart';
import 'controller.dart';
import 'create/templates.dart';
import 'design/identity.dart';
import 'design/theme.dart';
import 'export/export_page.dart';
import 'home/home_page.dart';
import 'pages/more_pages.dart';
import 'platform/home_surface.dart';
import 'platform/reminders.dart';
import 'platform/share_inbox.dart';
import 'pro/pro.dart';
import 'scope.dart';
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
      c.load().then((_) => _tidy());
    } else {
      _tidy();
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
    if (state == AppLifecycleState.resumed) unawaited(_takeShares());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    homeSurface.dispose();
    inbox.dispose();
    noAds.dispose();
    if (widget.controller == null) c.dispose();
    super.dispose();
  }

  Future<void> _welcomed(String? start) async {
    final vi = _vi(c.state!);
    String? board;
    await c.change((s) {
      var next = s.copy(preferences: {...s.preferences, 'welcomed': true});
      if (start != null) {
        board = newId();
        next = createKanbanBoard(
          next,
          title: start == 'study'
              ? (vi ? 'Học kỳ 1' : 'Semester 1')
              : (vi ? 'Bảng của tôi' : 'My board'),
          preset: start == 'study' ? presetById('study') : null,
          vi: vi,
          now: scope.clock(),
          boardId: board,
        );
      }
      return next;
    }, history: false);
    if (mounted) setState(() => replayWelcome = false);
    if (board != null) navigator.currentState?.pushNamed('/board/$board');
  }

  Route<void>? _route(RouteSettings settings) {
    final name = settings.name ?? '/';
    Widget? page;
    if (name.startsWith('/board/')) {
      page = BoardPage(scope: scope, board: name.substring(7));
    } else {
      page = switch (name) {
        '/templates' => TemplateGallery(scope: scope),
        '/settings' => SettingsPage(
          scope: scope,
          onReplayWelcome: () {
            navigator.currentState?.popUntil((r) => r.isFirst);
            setState(() => replayWelcome = true);
          },
        ),
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
            ? WelcomePage(scope: scope, onDone: _welcomed)
            : HomePage(scope: scope),
      );
    },
  );
}
