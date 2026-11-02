import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:handy_files/handy_files.dart';
import 'package:handy_home_widget/handy_home_widget.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_notifications/controller.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_storage/recovery.dart';
import 'package:handy_ui/kit.dart';
import 'card_link.dart';
import 'deck/deck_page.dart';
import 'home/home_page.dart';
import 'home_widget.dart';
import 'import/anki_page.dart';
import 'review/review_page.dart';
import 'scope.dart';
import 'settings_page.dart';
import 'study/recall_store.dart';
import 'study/speaker.dart';

export 'card/card_editor.dart' show CardEditor;
export 'home/home_page.dart' show RecallHome;

/// Recall's hue in the suite palette (docs/UX_REDESIGN.md).
const recallAccent = Color(0xFF4D7C0F);

class RecallApp extends StatefulWidget {
  final DocumentRepository? documents;
  final HandyFiles files;
  final PreferencesRepository? preferences;
  final ReminderController? reminders;

  /// Reads cards aloud; the device's own voices unless a test gives one.
  final Speaker? speaker;

  /// A fixed "now" for tests and screenshots; the real clock otherwise.
  final DateTime Function()? clock;

  /// Off in host tests: no folder backups, no home-screen widget.
  final bool device;
  const RecallApp({
    super.key,
    this.documents,
    this.files = const SystemHandyFiles(),
    this.preferences,
    this.reminders,
    this.speaker,
    this.clock,
    this.device = true,
  });
  @override
  State<RecallApp> createState() => _RecallAppState();
}

class _RecallAppState extends State<RecallApp> with WidgetsBindingObserver {
  late final repo =
      widget.preferences ??
      DevicePreferencesRepository(
        'handy-recall',
        knownTools: {},
        workflowSteps: {},
      );
  final prefs = ValueNotifier<HandyPreferences?>(null);
  late final store = RecallStore(
    widget.documents ?? localDocuments('handy-recall'),
  )..clock = widget.clock ?? DateTime.now;
  late final reminders =
      widget.reminders ?? ReminderController('recall', dailyReview: true);
  late final scope = RecallScope(
    store: store,
    files: widget.files,
    speaker: widget.speaker ?? DeviceSpeaker(),
    autoBackup: widget.device
        ? HandyAutoBackup.local(
            app: 'recall',
            extension: 'json',
            build: () async => Uint8List.fromList(
              utf8.encode(exportRecallBackup(store.state!)),
            ),
          )
        : null,
  );
  final navigator = GlobalKey<NavigatorState>();
  final widgetFeed = HomeWidgetFeed(recallWidgetClass);
  StreamSubscription<Uri>? _links;
  Uri? _pendingLink;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadPreferences();
    store.load();
    store.addListener(_stored);
    reminders.load();
    if (widget.device) _links = widgetFeed.links().listen(_link);
  }

  /// After every change: the backup clock and the home-screen widget.
  void _stored() {
    final s = store.state;
    if (s == null || !store.loaded) return;
    scope.autoBackup?.attach();
    if (widget.device) {
      final locale = prefs.value?.locale ?? 'system';
      final vi =
          locale == 'vi' ||
          locale == 'system' &&
              WidgetsBinding.instance.platformDispatcher.locale.languageCode ==
                  'vi';
      unawaited(widgetFeed.publish(recallWidgetView(s, scope.now, vi: vi)));
    }
    final link = _pendingLink;
    if (link != null) {
      _pendingLink = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _link(link));
    }
  }

  /// A widget tap or a card from another app.
  void _link(Uri uri) {
    final nav = navigator.currentState, context = navigator.currentContext;
    if (!store.loaded ||
        store.state == null ||
        nav == null ||
        context == null) {
      _pendingLink = uri;
      return;
    }
    nav.popUntil((r) => r.isFirst);
    final card = CardLink.parse(uri);
    if (card != null) {
      unawaited(scope.addFromLink(context, card));
    } else if (uri.host == 'review') {
      unawaited(scope.review(context));
    }
  }

  @override
  void dispose() {
    unawaited(_links?.cancel());
    store.removeListener(_stored);
    scope.autoBackup?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (widget.reminders == null) reminders.dispose();
    store.dispose();
    prefs.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reminders.resume();
  }

  Future<void> loadPreferences() async {
    try {
      final p = await repo.load();
      if (mounted) setState(() => prefs.value = p);
    } catch (_) {
      // Unreadable preferences fall back to defaults; the library is apart.
      if (mounted) setState(() => prefs.value = HandyPreferences());
    }
  }

  Future<void> save(HandyPreferences next) async {
    await repo.save(next);
    if (mounted) setState(() => prefs.value = next);
  }

  Widget _ready(Widget Function() page) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      if (store.error != null) {
        return HandyLoadError(
          title: tr(
            context,
            'Recall could not read your library',
            'Recall chưa đọc được thư viện',
          ),
          error: store.error!,
          onRetry: store.load,
          recovery: DocumentRecoveryButton(
            documents: store.documents,
            files: widget.files,
            reload: store.load,
          ),
        );
      }
      if (!store.loaded) return const HandyLoading();
      return page();
    },
  );

  Route<dynamic>? route(RouteSettings s) {
    final Widget Function()? page = switch ((s.name ?? '/').split('/')) {
      ['', 'settings'] => () => RecallSettingsPage(
        read: () => prefs.value!,
        save: save,
        scope: scope,
        reminders: reminders,
      ),
      ['', 'review'] => () => ReviewPage(scope: scope),
      ['', 'review', final id] => () => ReviewPage(scope: scope, deckId: id),
      ['', 'deck', final id] => () => DeckPage(scope: scope, id: id),
      ['', 'import'] => () => AnkiImportPage(
        scope: scope,
        pickNow: s.arguments == true,
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
      brand: HandyBrand.recall,
      app: 'recall',
      title: 'Handy Recall',
      accent: recallAccent,
      theme: p?.theme ?? 'system',
      locale: p?.locale ?? 'system',
      onGenerateRoute: route,
      navigatorKey: navigator,
      home: p == null
          ? const HandyLoading()
          : _ready(() => RecallHome(scope: scope)),
    );
  }
}
