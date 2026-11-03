import 'package:handy_core/handy_core.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_pdf/handy_pdf.dart';
import 'package:handy_ui/kit.dart';
import '../corner_editor.dart';
import '../session.dart';
import 'page_grid.dart';
import 'scan_store.dart';

/// The pages of the current scan as sheets of paper. Tap a sheet to fix its
/// corners; the bar at the foot adds pages and makes the PDF.
class ScanScreen extends StatefulWidget {
  final ScanStore store;
  final HandyFiles files;
  const ScanScreen({super.key, required this.store, required this.files});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CancellationToken? token;
  double progress = 0;
  bool busy = false;
  ScanStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    if (store.openCamera) {
      store.openCamera = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) add(camera: true);
      });
    }
  }

  Future<void> run(Future<void> Function() task, {String? done}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await task();
      if (done != null && mounted) showHandyMessage(context, done);
    } on Cancelled {
      if (mounted)
        showHandyMessage(
          context,
          tr(
            context,
            'Canceled. Your pages are unchanged.',
            'Đã hủy. Các trang vẫn giữ nguyên.',
          ),
        );
    } catch (e) {
      if (mounted)
        showHandyMessage(
          context,
          '${errorText(context, e)}. ${tr(context, 'Your pages are unchanged.', 'Các trang vẫn giữ nguyên.')}',
        );
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          token = null;
        });
      }
    }
  }

  /// Checks the picture first: a bad file never opens the editor.
  Future<void> edit(ImportedBytes file, {ScanPage? replace}) async {
    decodeScanImage(file.bytes);
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CornerEditor(
          bytes: file.bytes,
          onCommit: (png) => store.put(png, file.name, replace: replace),
        ),
      ),
    );
  }

  Future<void> add({bool camera = false}) => run(() async {
    final file = camera
        ? await store.camera.capture()
        : await widget.files.importBytes(
            extensions: ['png', 'jpg', 'jpeg'],
            maxBytes: 12000000,
          );
    if (file != null && mounted) await edit(file);
  });

  void export({bool searchable = false}) {
    token = CancellationToken();
    progress = 0;
    final vi = Localizations.localeOf(context).languageCode == 'vi';
    void step(double v) => mounted ? setState(() => progress = v) : null;
    run(
      () => searchable
          ? store.exportSearchablePdf(
              widget.files,
              token!,
              step,
              vi ? 'vi' : 'en',
            )
          : store.exportPdf(widget.files, token!, step),
      done: tr(context, 'PDF saved.', 'Đã lưu PDF.'),
    );
  }

  Future<void> restore() => run(() async {
    final file = await widget.files.importBytes(
      extensions: ['json'],
      maxBytes: 24000000,
    );
    if (file == null || !mounted) return;
    final next = ScanStore.parseBackup(file.bytes);
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Restore this scan?', 'Khôi phục bản quét này?'),
      message: tr(
        context,
        'Its ${next.pages.length} pages replace the ${store.pages.length} here. Back up first to keep both.',
        '${next.pages.length} trang trong file sẽ thay ${store.pages.length} trang hiện có. Hãy sao lưu trước nếu muốn giữ cả hai.',
      ),
      confirmLabel: tr(context, 'Restore', 'Khôi phục'),
    );
    if (ok) await store.commit(next.pages);
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final pages = store.pages;
      final camera = store.camera.supported;
      return PopScope(
        canPop: !busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(tr(context, 'Scan', 'Quét giấy tờ')),
            actions: [
              HandyMenuButton(
                items: [
                  if (supportsPdfEditing)
                    HandyMenuItem(
                      Icons.manage_search,
                      tr(
                        context,
                        'Searchable PDF (reads the text)',
                        'PDF tìm được chữ (nhận dạng chữ)',
                      ),
                      pages.isEmpty || busy
                          ? null
                          : () => export(searchable: true),
                      key: const Key('scan-export-searchable'),
                    ),
                  HandyMenuItem(
                    Icons.archive_outlined,
                    tr(context, 'Back up this scan', 'Sao lưu bản quét'),
                    pages.isEmpty || busy
                        ? null
                        : () => run(
                            () => store.backup(widget.files),
                            done: tr(
                              context,
                              'Backup saved.',
                              'Đã lưu bản sao lưu.',
                            ),
                          ),
                    key: const Key('scan-backup'),
                  ),
                  HandyMenuItem(
                    Icons.unarchive_outlined,
                    tr(context, 'Restore a scan', 'Khôi phục bản quét'),
                    busy ? null : restore,
                    key: const Key('scan-restore'),
                  ),
                ],
              ),
            ],
          ),
          bottomNavigationBar: HandyBottomBar(
            child: busy && token != null
                ? Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progress == 0 ? null : progress,
                        ),
                      ),
                      const SizedBox(width: HandySpace.m),
                      TextButton(
                        key: const Key('scan-cancel'),
                        onPressed: token?.cancel,
                        child: Text(tr(context, 'Cancel', 'Hủy')),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      if (camera) ...[
                        IconButton.outlined(
                          key: const Key('scan-camera'),
                          tooltip: tr(context, 'Take a photo', 'Chụp ảnh'),
                          onPressed: busy || store.full
                              ? null
                              : () => add(camera: true),
                          icon: const Icon(Icons.photo_camera_outlined),
                        ),
                        const SizedBox(width: HandySpace.s),
                      ],
                      OutlinedButton.icon(
                        key: const Key('scan-import'),
                        onPressed: busy || store.full ? null : add,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(tr(context, 'Add image', 'Thêm ảnh')),
                      ),
                      const SizedBox(width: HandySpace.s),
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('scan-export'),
                          onPressed: busy || pages.isEmpty ? null : export,
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: Text(tr(context, 'Make PDF', 'Xuất PDF')),
                        ),
                      ),
                    ],
                  ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(HandySpace.l),
            children: [
              if (store.recovered != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: HandySpace.l),
                  child: HandyNotice(
                    tr(
                      context,
                      'A photo was taken while the app was closed.',
                      'Có một ảnh chụp lúc app bị đóng.',
                    ),
                    action: Wrap(
                      children: [
                        TextButton(
                          onPressed: () => edit(
                            store.recovered!,
                          ).then((_) => store.dismissRecovered()),
                          child: Text(tr(context, 'Use it', 'Dùng ảnh này')),
                        ),
                        TextButton(
                          onPressed: store.dismissRecovered,
                          child: Text(tr(context, 'Dismiss', 'Bỏ qua')),
                        ),
                      ],
                    ),
                  ),
                ),
              if (pages.isEmpty)
                HandyEmpty(
                  title: tr(
                    context,
                    'Photograph a page to begin',
                    'Chụp một trang để bắt đầu',
                  ),
                  message: tr(
                    context,
                    'Each photo is straightened from its four corners. Up to 20 pages become one PDF.',
                    'Mỗi ảnh được nắn thẳng theo bốn góc. Tối đa 20 trang gộp thành một PDF.',
                  ),
                )
              else
                PageGrid(
                  store: store,
                  busy: busy,
                  files: widget.files,
                  onEdit: (p) =>
                      run(() => edit(ImportedBytes(p.name, p.png), replace: p)),
                  onRun: run,
                ),
            ],
          ),
        ),
      );
    },
  );
}
