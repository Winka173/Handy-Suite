import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/documents.dart';
import 'package:handy_storage/export_history.dart';
import 'package:handy_storage/handy_storage.dart';
import 'package:handy_storage/recovery.dart';
import 'package:handy_ui/kit.dart';
import 'dart:typed_data';
import 'capture.dart';
import 'desk/desk_page.dart';
import 'ocr/ocr_job.dart';
import 'ocr/ocr_page.dart';
import 'pdf/pdf_desk.dart';
import 'pdf/pdf_page.dart';
import 'read/read_page.dart';
import 'read/reader_store.dart';
import 'scan/scan_screen.dart';
import 'scan/scan_store.dart';
import 'scope.dart';
import 'settings_page.dart';
import 'sign/fill_controller.dart';
import 'sign/fill_route.dart';
import 'sign/signature_store.dart';
import 'write/draft.dart';
import 'write/write_page.dart';

export 'desk/desk_page.dart' show DeskPage;

/// Docs' hue in the suite palette (docs/UX_REDESIGN.md).
const docsAccent = Color(0xFF1D5FBF);

class DocsApp extends StatefulWidget {
  final HandyFiles files;
  final DocumentRepository? documents,
      markdownDocuments,
      readerDocuments,
      signatureDocuments;
  final PreferencesRepository? preferences;
  final ScanCamera? camera;
  final ExportHistory? history;

  /// Opens a PDF's pages for signing; tests pass pages without PDFium.
  final Future<FillSource> Function(Uint8List bytes)? openFillSource;

  /// The open PDFs; tests pass one that needs no PDFium.
  final PdfDesk? pdfDesk;

  /// Off in host tests: no folder backups.
  final bool device;
  const DocsApp({
    super.key,
    this.files = const SystemHandyFiles(),
    this.documents,
    this.markdownDocuments,
    this.readerDocuments,
    this.signatureDocuments,
    this.preferences,
    this.camera,
    this.history,
    this.openFillSource,
    this.pdfDesk,
    this.device = true,
  });
  @override
  State<DocsApp> createState() => _DocsAppState();
}

class _DocsAppState extends State<DocsApp> {
  late final repo =
      widget.preferences ??
      DevicePreferencesRepository(
        'handy-docs',
        knownTools: docsTools,
        workflowSteps: docsWorkflowSteps,
      );
  final prefs = ValueNotifier<HandyPreferences?>(null);
  late final scope = DocsScope(
    files: widget.files,
    preferences: repo,
    scan: ScanStore(
      widget.documents ?? localDocuments('handy-docs-scan', maxBytes: 24000000),
      widget.camera ?? SystemScanCamera(),
    ),
    draft: DraftController(
      widget.markdownDocuments ??
          localDocuments('handy-docs-markdown', maxBytes: 6100000),
      history: widget.history,
    ),
    pdf: widget.pdfDesk ?? PdfDesk(),
    reader: ReaderStore(
      widget.readerDocuments ??
          localDocuments('handy-docs-reader', maxBytes: 8000000),
    ),
    signatures: SignatureStore(
      widget.signatureDocuments ??
          localDocuments('handy-docs-signatures', maxBytes: 4000000),
    ),
  );

  @override
  void initState() {
    super.initState();
    loadPreferences();
    if (widget.device) {
      final reader = scope.reader.store;
      scope.autoBackup = HandyAutoBackup.local(
        app: 'docs',
        extension: 'zip',
        build: () async => reader.backup(),
      );
      void ready() {
        if (reader.library != null) scope.autoBackup?.attach();
      }

      reader.addListener(ready);
    }
    scope.load();
  }

  @override
  void dispose() {
    scope.dispose();
    prefs.dispose();
    super.dispose();
  }

  Future<void> loadPreferences() async {
    try {
      final p = await repo.load();
      if (mounted) setState(() => prefs.value = p);
    } catch (_) {
      // Unreadable preferences fall back to defaults; documents are apart.
      if (mounted) setState(() => prefs.value = HandyPreferences());
    }
  }

  Future<void> save(HandyPreferences next) async {
    await repo.save(next);
    if (mounted) setState(() => prefs.value = next);
  }

  /// [page] once [store] has loaded; its own error and recovery otherwise.
  Widget _ready(
    Listenable store,
    bool Function() loaded,
    Object? Function() error,
    DocumentRepository documents,
    Future<void> Function() reload,
    String Function(BuildContext) title,
    Widget Function() page,
  ) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      if (error() != null) {
        return Scaffold(
          appBar: AppBar(),
          body: HandyLoadError(
            title: title(context),
            error: error()!,
            onRetry: reload,
            recovery: DocumentRecoveryButton(
              documents: documents,
              files: widget.files,
              reload: reload,
            ),
          ),
        );
      }
      return loaded() ? page() : const Scaffold(body: HandyLoading());
    },
  );

  Route<dynamic>? route(RouteSettings s) {
    final scan = scope.scan, draft = scope.draft;
    final Widget Function()? page = switch (s.name) {
      '/settings' => () => DocsSettingsPage(
        read: () => prefs.value!,
        save: save,
        scope: scope,
      ),
      '/scan' => () => _ready(
        scan,
        () => scan.session != null,
        () => scan.error,
        scan.documents,
        scan.load,
        (c) => tr(c, 'The scan could not be opened', 'Chưa mở được bản quét'),
        () => ScanScreen(store: scan, files: widget.files),
      ),
      '/write' => () => _ready(
        draft,
        () => draft.loaded,
        () => draft.error,
        draft.documents,
        draft.load,
        (c) => tr(c, 'The draft could not be read', 'Chưa đọc được bản nháp'),
        () =>
            WritePage(draft: draft, files: widget.files, opener: scope.opener),
      ),
      '/pdf' => () => PdfPage(desk: scope.pdf, files: widget.files),
      '/pdf/fill' => () => FillRoute(
        desk: scope.pdf,
        signatures: scope.signatures,
        files: widget.files,
        openSource: widget.openFillSource ?? PdfFillSource.open,
      ),
      '/ocr' => () => OcrRoute(
        source: s.arguments is OcrSource ? s.arguments as OcrSource : null,
        files: widget.files,
        opener: scope.opener,
      ),
      '/read' => () => ReadPage(actions: scope.reader),
      _ => null,
    };
    if (page == null) return null;
    return MaterialPageRoute<void>(settings: s, builder: (_) => page());
  }

  @override
  Widget build(BuildContext context) {
    final p = prefs.value;
    return HandyApp(
      brand: HandyBrand.docs,
      app: 'docs',
      title: 'Handy Docs',
      accent: docsAccent,
      theme: p?.theme ?? 'system',
      locale: p?.locale ?? 'system',
      onGenerateRoute: route,
      home: p == null ? const HandyLoading() : DeskPage(scope: scope),
    );
  }
}
