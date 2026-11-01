import 'dart:typed_data';
import 'package:handy_capture/handy_capture.dart';
import 'package:handy_files/camera.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/export_history.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_storage/recovery.dart';
import 'package:handy_ui/kit.dart';
import 'capture_draft.dart';
import 'guide/ids.dart';
import 'image/image_page.dart';
import 'native_capture_page.dart';
import 'settings_page.dart';
import 'studio/media_store.dart';
import 'studio/open_guide.dart';
import 'studio/studio_page.dart';
import 'subtitles/subtitle_page.dart';

export 'studio/studio_page.dart' show StudioPage;

/// Media's hue in the suite palette (docs/UX_REDESIGN.md).
const mediaAccent = Color(0xFFC2255C);

class MediaApp extends StatefulWidget {
  final HandyFiles files;
  final PreferencesRepository? preferences;
  final DocumentRepository? documents;
  final ScanCamera? camera;
  final ExportHistory? history;

  /// Each guide's draft store; the device's by default.
  final DocumentRepository Function(String id)? drafts;
  const MediaApp({
    super.key,
    this.files = const SystemHandyFiles(),
    this.preferences,
    this.documents,
    this.camera,
    this.history,
    this.drafts,
  });
  @override
  State<MediaApp> createState() => _MediaAppState();
}

class _MediaAppState extends State<MediaApp> {
  late final repo =
      widget.preferences ??
      DevicePreferencesRepository(
        'handy-media',
        knownTools: mediaTools,
        workflowSteps: {},
      );
  final prefs = ValueNotifier<HandyPreferences?>(null);
  late final store = MediaStore(
    widget.documents ??
        localDocuments('handy-media-capture', maxBytes: 30000000),
    drafts: widget.drafts ?? captureDraftDocuments,
  );

  @override
  void initState() {
    super.initState();
    loadPreferences();
    store.load();
  }

  @override
  void dispose() {
    store.dispose();
    prefs.dispose();
    super.dispose();
  }

  Future<void> loadPreferences() async {
    try {
      final p = await repo.load();
      if (mounted) setState(() => prefs.value = p);
    } catch (_) {
      // Unreadable preferences fall back to defaults; guides are apart.
      if (mounted) setState(() => prefs.value = HandyPreferences());
    }
  }

  Future<void> save(HandyPreferences next) async {
    await repo.save(next);
    if (mounted) setState(() => prefs.value = next);
  }

  /// Opens a native screenshot as a new one-step guide.
  Future<void> annotate(
    BuildContext context,
    CaptureResult result,
    Uint8List bytes,
  ) async {
    final step = ProjectStep(
      id: captureId('step'),
      title: '',
      body: '',
      imageUri: result.uri,
      imageWidth: result.width,
      imageHeight: result.height,
    );
    verifyProjectImage(bytes, step);
    final project = CaptureProject.create(captureId('project'));
    await openGuide(
      context,
      store: store,
      files: widget.files,
      camera: widget.camera,
      guide: PortableCapture(
        CaptureProject.parse({
          ...project.toJson(),
          'steps': [step.toJson()],
        }),
        {result.uri: bytes},
      ),
    );
  }

  Widget _studio() => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      if (store.error != null) {
        return HandyLoadError(
          title: tr(
            context,
            'Your guides could not be read',
            'Chưa đọc được các hướng dẫn',
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
      return StudioPage(
        store: store,
        files: widget.files,
        camera: widget.camera,
      );
    },
  );

  Route<dynamic>? route(RouteSettings s) {
    final Widget Function()? page = switch ((s.name ?? '/').split('/')) {
      ['', 'settings'] => () => MediaSettingsPage(
        read: () => prefs.value!,
        save: save,
        files: widget.files,
        store: store,
        history: widget.history ?? ExportHistory('media'),
      ),
      ['', 'image'] => () => ImagePage(
        files: widget.files,
        camera: widget.camera,
      ),
      ['', 'subtitles'] => () => SubtitlePage(
        files: widget.files,
        history: widget.history,
      ),
      ['', 'capture'] => () => Builder(
        builder: (context) => NativeCapturePage(
          files: widget.files,
          annotate: (r, b) => annotate(context, r, b),
        ),
      ),
      ['', 'guide', final id] => () => _GuideLink(
        id: id,
        store: store,
        files: widget.files,
        camera: widget.camera,
      ),
      _ => null,
    };
    if (page == null) return null;
    return MaterialPageRoute<void>(settings: s, builder: (_) => page());
  }

  @override
  Widget build(BuildContext context) {
    final p = prefs.value;
    return HandyApp(
      app: 'media',
      title: 'Handy Media',
      accent: mediaAccent,
      theme: p?.theme ?? 'system',
      locale: p?.locale ?? 'system',
      onGenerateRoute: route,
      home: p == null ? const HandyLoading() : _studio(),
    );
  }
}

/// A link to one guide (`#/guide/<id>`): opens it, then steps back.
class _GuideLink extends StatefulWidget {
  final String id;
  final MediaStore store;
  final HandyFiles files;
  final ScanCamera? camera;
  const _GuideLink({
    required this.id,
    required this.store,
    required this.files,
    this.camera,
  });
  @override
  State<_GuideLink> createState() => _GuideLinkState();
}

class _GuideLinkState extends State<_GuideLink> {
  bool missing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => go());
  }

  Future<void> go() async {
    if (!widget.store.loaded) await widget.store.load();
    final guide = widget.store.library?.projects
        .where((p) => p.project.id == widget.id)
        .firstOrNull;
    if (!mounted) return;
    if (guide == null) return setState(() => missing = true);
    await openGuide(
      context,
      store: widget.store,
      files: widget.files,
      camera: widget.camera,
      guide: guide,
    );
    if (mounted) Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: missing
        ? HandyEmpty(
            title: tr(
              context,
              'This guide is not on this device',
              'Hướng dẫn này không có trên máy',
            ),
          )
        : const HandyLoading(),
  );
}
