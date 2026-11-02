import 'package:flutter/services.dart';
import 'package:handy_dev_engine/handy_dev_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_ui/kit.dart';
import 'http_transport.dart';
import 'inspect/inspector.dart';
import 'requests/requests_area.dart';
import 'requests/workspace.dart';
import 'settings_page.dart';

/// Dev's hue in the suite palette (docs/UX_REDESIGN.md).
const devAccent = Color(0xFF0F8A5F);

Set<String> get devPreferenceIds => devTools.map((t) => t.id).toSet();

/// Ids a saved favorite or draft may still carry from before the 2026-11-03
/// merge; [safeDevPreferences] moves them to the tool they became.
Set<String> get devStoredIds => {
  ...devPreferenceIds,
  ...devToolAliases.keys,
  ...devRemovedTools,
};

/// Moves favorites and drafts of merged tools to the merged tool and drops
/// those of removed tools. A merged tool keeps the first draft it gets.
HandyPreferences migrateDevPreferences(HandyPreferences p) {
  String? to(String id) =>
      devRemovedTools.contains(id) ? null : devToolAliases[id]?.$1 ?? id;
  final drafts = <String, String>{};
  for (final e in p.drafts.entries) {
    final id = to(e.key);
    if (id != null) drafts.putIfAbsent(id, () => e.value);
  }
  return p.copyWith(
    favorites: {for (final f in p.favorites) ?to(f)},
    drafts: drafts,
  );
}

/// Steps a saved chain may hold; never a sensitive tool.
const devWorkflowIds = {
  'base64-encode',
  'base64-decode',
  'url-encode',
  'url-decode',
  'sha256',
  'sha512',
};

PreferencesRepository devPreferences() => DevicePreferencesRepository(
  'handy-dev',
  knownTools: devStoredIds,
  workflowSteps: devWorkflowIds,
);

/// Drops drafts of sensitive tools (JWT, .env, HAR, redaction) before any
/// read or write, so they can never be persisted or restored.
HandyPreferences safeDevPreferences(HandyPreferences input) {
  input = migrateDevPreferences(input);
  return HandyPreferences.fromJson(
    input
        .copyWith(
          drafts: {
            for (final e in input.drafts.entries)
              if (devTools.any((t) => t.id == e.key && !t.sensitive))
                e.key: e.value,
          },
        )
        .toJson(),
    knownTools: devPreferenceIds,
    workflowSteps: devWorkflowIds,
  );
}

class DevApp extends StatefulWidget {
  final HandyFiles files;
  final PreferencesRepository? preferences;
  final DocumentRepository? documents;
  final HttpTransport? transport;
  const DevApp({
    super.key,
    this.files = const SystemHandyFiles(),
    this.preferences,
    this.documents,
    this.transport,
  });
  @override
  State<DevApp> createState() => _DevAppState();
}

class _DevAppState extends State<DevApp> {
  late final repo = widget.preferences ?? devPreferences();
  final prefs = ValueNotifier<HandyPreferences?>(null);
  late final ws = Workspace(
    widget.documents ?? localDocuments('handy-dev-api', maxBytes: 1000000),
    widget.transport ?? HttpTransport(),
  )..load();
  Object? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    prefs.dispose();
    ws.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => error = null);
    try {
      final p = safeDevPreferences(await repo.load());
      if (mounted) setState(() => prefs.value = p);
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> save(HandyPreferences next) async {
    final safe = safeDevPreferences(next);
    await repo.save(safe);
    if (mounted) setState(() => prefs.value = safe);
  }

  HandyPreferences read() => prefs.value!;

  Route<dynamic>? route(RouteSettings s) {
    final page = switch (s.name) {
      '/settings' => DevSettingsPage(
        read: read,
        save: save,
        files: widget.files,
      ),
      '/requests' => DevHome(app: this, initialArea: 1),
      _ => null,
    };
    if (page == null) return null;
    return MaterialPageRoute<void>(
      settings: s,
      builder: (_) => ValueListenableBuilder<HandyPreferences?>(
        valueListenable: prefs,
        builder: (context, p, _) =>
            p == null ? HandyLoading(error: error) : page,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = prefs.value;
    return HandyApp(
      brand: HandyBrand.dev,
      app: 'dev',
      title: 'Handy Dev',
      accent: devAccent,
      theme: p?.theme ?? 'system',
      locale: p?.locale ?? 'system',
      onGenerateRoute: route,
      home: p == null
          ? HandyLoading(error: error, retry: error == null ? null : load)
          : DevHome(app: this),
    );
  }
}

/// The two areas of Dev behind one switch in the top bar.
class DevHome extends StatefulWidget {
  final _DevAppState app;
  final int initialArea;
  const DevHome({super.key, required this.app, this.initialArea = 0});
  @override
  State<DevHome> createState() => _DevHomeState();
}

class _DevHomeState extends State<DevHome> {
  late int area = widget.initialArea;
  final inspector = GlobalKey<InspectorState>();
  _DevAppState get app => widget.app;

  Future<void> find() async {
    final groups = (
      tr(context, 'JSON', 'JSON'),
      tr(context, 'Convert', 'Chuyển đổi'),
      tr(context, 'Encode & hash', 'Mã hóa & băm'),
      tr(context, 'Sensitive', 'Nhạy cảm'),
      tr(context, 'Time, IDs, text & colour', 'Thời gian, ID, văn bản & màu'),
    );
    String group(DevTool t) => t.sensitive
        ? groups.$4
        : t.id.startsWith('json') || ['schema', 'regex'].contains(t.id)
        ? groups.$1
        : [
            'timestamp',
            'uuid',
            'cron',
            'text-diff',
            'url-parse',
            'colors',
            'contrast',
          ].contains(t.id)
        ? groups.$5
        : ['base64', 'url', 'hash'].contains(t.id)
        ? groups.$3
        : groups.$2;
    final id = await showHandyCatalog(
      context,
      searchHint: tr(context, 'Find a tool', 'Tìm công cụ'),
      pinned: app.read().favorites.toSet(),
      onTogglePin: (id) {
        final pins = [...app.read().favorites];
        pins.contains(id) ? pins.remove(id) : pins.add(id);
        return app.save(app.read().copyWith(favorites: pins));
      },
      groups: [groups.$1, groups.$5, groups.$2, groups.$3, groups.$4],
      entries: [
        for (final t in devTools)
          HandyCatalogEntry(
            id: t.id,
            title: tr(context, t.titleEn, t.titleVi),
            hint: t.description,
            group: group(t),
            icon: t.sensitive ? Icons.lock_outline : Icons.data_object,
            keywords: '${t.titleEn} ${t.titleVi}',
          ),
      ],
    );
    if (id == null || !mounted) return;
    setState(() => area = 0);
    inspector.currentState?.use(id);
  }

  @override
  Widget build(BuildContext context) {
    // Phones: short labels, no icons, so neither label breaks.
    final narrow = MediaQuery.sizeOf(context).width < 560;
    final areas = _AreaTabs(
      key: const Key('area'),
      labels: [
        narrow
            ? tr(context, 'Data', 'Dữ liệu')
            : tr(context, 'Inspect', 'Soi dữ liệu'),
        tr(context, 'Requests', 'Request'),
      ],
      selected: area,
      onSelected: (i) => setState(() => area = i),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): find,
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): find,
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
            setState(() => area = 0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
            setState(() => area = 1),
      },
      child: Focus(
        child: Scaffold(
          appBar: HandyTopBar(
            mark: Icons.terminal,
            name: 'Handy Dev',
            onFind: find,
            findLabel: tr(context, 'Find a tool', 'Tìm công cụ'),
            areas: areas,
          ),
          body: SafeArea(
            top: false,
            child: IndexedStack(
              index: area,
              children: [
                Inspector(
                  key: inspector,
                  files: app.widget.files,
                  read: app.read,
                  save: app.save,
                  onOpenRequest: (r) {
                    app.ws.openDraft(r.copyWith(id: Workspace.newId('r')));
                    setState(() => area = 1);
                  },
                ),
                RequestsArea(ws: app.ws, files: app.widget.files),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The terminal's area switch: the selected area is underlined by the one
/// 1px line of the hue every selection in Dev uses.
class _AreaTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  const _AreaTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < labels.length; i++)
          Flexible(
            child: Semantics(
              selected: i == selected,
              button: true,
              child: InkWell(
                onTap: () => onSelected(i),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: HandySpace.s),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == selected ? c.accent : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: i == selected ? null : c.muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
