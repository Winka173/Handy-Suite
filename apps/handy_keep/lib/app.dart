import 'package:handy_files/camera.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_notifications/controller.dart';
import 'package:handy_notifications/handy_notifications.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'due_page.dart';
import 'home/home_page.dart';
import 'inventory/keep_store.dart';
import 'item/item_page.dart';
import 'scope.dart';
import 'settings_page.dart';
import 'package:handy_storage/recovery.dart';

export 'inventory/keep_store.dart' show AssetEdit;
export 'item/asset_editor.dart' show AssetEditor;
export 'home/home_page.dart' show KeepHome;

/// Keep's hue in the suite palette (docs/UX_REDESIGN.md).
const keepAccent = Color(0xFFB7791F);

class KeepApp extends StatefulWidget {
  final DocumentRepository? documents;
  final HandyFiles files;
  final ScanCamera? camera;
  final PreferencesRepository? preferences;
  final ReminderController? reminders;

  /// Off in host tests: no folder backups.
  final bool device;
  const KeepApp({
    super.key,
    this.documents,
    this.files = const SystemHandyFiles(),
    this.camera,
    this.preferences,
    this.reminders,
    this.device = true,
  });
  @override
  State<KeepApp> createState() => _KeepAppState();
}

class _KeepAppState extends State<KeepApp> with WidgetsBindingObserver {
  late final repo =
      widget.preferences ??
      DevicePreferencesRepository(
        'handy-keep',
        knownTools: {},
        workflowSteps: {},
      );
  final prefs = ValueNotifier<HandyPreferences?>(null);
  late final store = KeepStore(
    widget.documents ?? localDocuments('handy-keep', maxBytes: 16000000),
  );
  late final reminders = widget.reminders ?? ReminderController('keep');
  late final scope = KeepScope(
    store: store,
    files: widget.files,
    camera: widget.camera ?? SystemScanCamera(),
    autoBackup: widget.device
        ? HandyAutoBackup.local(
            app: 'keep',
            extension: 'zip',
            build: () async => store.library!.portable(),
          )
        : null,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.addListener(_syncReminders);
    loadPreferences();
    store.load();
    reminders.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.removeListener(_syncReminders);
    scope.autoBackup?.dispose();
    if (widget.reminders == null) reminders.dispose();
    store.dispose();
    prefs.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reminders.resume();
  }

  void _syncReminders() {
    final s = store.state;
    if (s == null) return;
    scope.autoBackup?.attach();
    reminders.update([
      for (final r in getKeepReminders(s, today()))
        ReminderDate('${r.assetId}-${r.kind}', r.date),
    ]);
  }

  Future<void> loadPreferences() async {
    try {
      final p = await repo.load();
      if (mounted) setState(() => prefs.value = p);
    } catch (_) {
      // Unreadable preferences fall back to defaults; the inventory is apart.
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
      if (store.error != null)
        return HandyLoadError(
          title: tr(
            context,
            'Keep could not read your inventory',
            'Keep chưa đọc được dữ liệu',
          ),
          error: store.error!,
          onRetry: store.load,
          recovery: DocumentRecoveryButton(
            documents: store.documents,
            files: widget.files,
            reload: store.load,
          ),
        );
      if (!store.loaded) return const HandyLoading();
      return page();
    },
  );

  Route<dynamic>? route(RouteSettings s) {
    final name = s.name ?? '/';
    final Widget Function()? page = switch (name.split('/')) {
      ['', 'settings'] => () => KeepSettingsPage(
        read: () => prefs.value!,
        save: save,
        scope: scope,
        reminders: reminders,
      ),
      ['', 'due'] => () => DuePage(scope: scope),
      ['', 'item', final id] => () => ItemPage(scope: scope, id: id),
      _ => null,
    };
    if (page == null) return null;
    return MaterialPageRoute<void>(settings: s, builder: (_) => _ready(page));
  }

  @override
  Widget build(BuildContext context) {
    final p = prefs.value;
    return HandyApp(
      brand: HandyBrand.keep,
      app: 'keep',
      title: 'Handy Keep',
      accent: keepAccent,
      theme: p?.theme ?? 'system',
      locale: p?.locale ?? 'system',
      onGenerateRoute: route,
      home: p == null
          ? const HandyLoading()
          : _ready(() => KeepHome(scope: scope)),
    );
  }
}
