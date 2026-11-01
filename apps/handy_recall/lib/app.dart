import 'package:handy_files/handy_files.dart';
import 'package:handy_notifications/controller.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_storage/recovery.dart';
import 'package:handy_ui/kit.dart';
import 'deck/deck_page.dart';
import 'home/home_page.dart';
import 'review/review_page.dart';
import 'scope.dart';
import 'settings_page.dart';
import 'study/recall_store.dart';

export 'card/card_editor.dart' show CardEditor;
export 'home/home_page.dart' show RecallHome;

/// Recall's hue in the suite palette (docs/UX_REDESIGN.md).
const recallAccent = Color(0xFF4D7C0F);

class RecallApp extends StatefulWidget {
  final DocumentRepository? documents;
  final HandyFiles files;
  final PreferencesRepository? preferences;
  final ReminderController? reminders;

  /// A fixed "now" for tests and screenshots; the real clock otherwise.
  final DateTime Function()? clock;
  const RecallApp({
    super.key,
    this.documents,
    this.files = const SystemHandyFiles(),
    this.preferences,
    this.reminders,
    this.clock,
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
  late final scope = RecallScope(store: store, files: widget.files);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadPreferences();
    store.load();
    reminders.load();
  }

  @override
  void dispose() {
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
      _ => null,
    };
    if (page == null) return null;
    return MaterialPageRoute<void>(settings: s, builder: (_) => _ready(page));
  }

  @override
  Widget build(BuildContext context) {
    final p = prefs.value;
    return HandyApp(
      app: 'recall',
      title: 'Handy Recall',
      accent: recallAccent,
      theme: p?.theme ?? 'system',
      locale: p?.locale ?? 'system',
      onGenerateRoute: route,
      home: p == null
          ? const HandyLoading()
          : _ready(() => RecallHome(scope: scope)),
    );
  }
}
