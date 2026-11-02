import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/export_history.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'bench/bench_page.dart';
import 'bench/catalog.dart';
import 'bench/tape.dart';
import 'settings_page.dart';
import 'specs.dart';

/// Tools' hue in the suite palette (docs/UX_REDESIGN.md).
const toolsAccent = Color(0xFFE8590C);

class HandyToolsApp extends StatefulWidget {
  final PreferencesRepository? repository;
  final HandyFiles files;
  final DocumentRepository? qrHistoryDocuments;
  final ExportHistory? exportHistory;
  const HandyToolsApp({
    super.key,
    this.repository,
    this.qrHistoryDocuments,
    this.exportHistory,
    this.files = const SystemHandyFiles(),
  });
  @override
  State<HandyToolsApp> createState() => _HandyToolsAppState();
}

class _HandyToolsAppState extends State<HandyToolsApp> {
  late final PreferencesRepository repository =
      widget.repository ?? DevicePreferencesRepository('handy-tools');
  final preferences = ValueNotifier<HandyPreferences?>(null);
  final tape = TapeController();
  Object? error;
  late final scope = BenchScope(
    read: () => preferences.value!,
    save: save,
    files: widget.files,
    tape: tape,
    qrHistoryDocuments: widget.qrHistoryDocuments,
    exportHistory: widget.exportHistory,
  );

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    preferences.dispose();
    tape.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final state = await repository.load();
      if (mounted) setState(() => preferences.value = state);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  /// Writes first; the screen changes only once the write succeeded.
  Future<void> save(HandyPreferences next) async {
    await repository.save(next);
    if (mounted) setState(() => preferences.value = next);
  }

  /// `/tool/<id>` and `/settings`. A deep link waits for saved settings.
  Route<dynamic>? route(RouteSettings settings) {
    final name = settings.name ?? '/';
    Widget? page;
    if (name == '/settings') {
      page = ToolsSettingsPage(
        read: scope.read,
        save: save,
        files: widget.files,
      );
    } else if (name.startsWith('/tool/')) {
      // Old links to the four case tools open `case` in that mode.
      final asked = name.substring(6), id = canonicalToolId(asked);
      if (!specById.containsKey(id) && !generators.any((g) => g.$1 == id)) {
        return null;
      }
      final args = settings.arguments;
      page = BenchPage(
        scope: scope,
        toolId: id,
        initial: {
          ...legacyValues(asked),
          if (args is Map<String, String>) ...args,
        },
      );
    }
    if (page == null) return null;
    final ready = page;
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => ValueListenableBuilder<HandyPreferences?>(
        valueListenable: preferences,
        builder: (context, p, _) =>
            p == null ? HandyLoading(error: error) : ready,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = preferences.value;
    return HandyApp(
      brand: HandyBrand.tools,
      app: 'tools',
      title: 'Handy Tools',
      accent: toolsAccent,
      theme: p?.theme ?? 'system',
      locale: p?.locale ?? 'system',
      onGenerateRoute: route,
      home: p == null
          ? HandyLoading(error: error, retry: error == null ? null : load)
          : BenchPage(scope: scope),
    );
  }
}
