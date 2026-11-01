import 'dart:typed_data';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'make_panel.dart';
import 'page_viewer.dart';
import 'pdf_desk.dart';

/// The PDF screen: the page being looked at, and beside it (below it on a
/// phone) the new PDF being made from it.
class PdfPage extends StatefulWidget {
  final PdfDesk desk;
  final HandyFiles files;
  const PdfPage({super.key, required this.desk, required this.files});
  @override
  State<PdfPage> createState() => _PdfPageState();
}

class _PdfPageState extends State<PdfPage> {
  final range = TextEditingController(), watermark = TextEditingController();
  int rotation = 0;
  bool busy = false;
  CancellationToken? token;
  PdfDesk get desk => widget.desk;
  HandyFiles get files => widget.files;

  @override
  void dispose() {
    token?.cancel();
    range.dispose();
    watermark.dispose();
    super.dispose();
  }

  Future<void> run(
    Future<void> Function(CancellationToken t) task, {
    String? done,
  }) async {
    if (busy) return;
    final t = CancellationToken();
    setState(() {
      busy = true;
      token = t;
    });
    try {
      await task(t);
      if (done != null && mounted) showHandyMessage(context, done);
    } on Cancelled {
      if (mounted) {
        showHandyMessage(
          context,
          tr(
            context,
            'Canceled. The original PDFs are unchanged.',
            'Đã hủy. Các PDF gốc vẫn giữ nguyên.',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showHandyMessage(
          context,
          e is FormatException
              ? e.message
              : tr(
                  context,
                  'That did not work. The files are unchanged; encrypted or damaged PDFs cannot be opened.',
                  'Chưa làm được. Các tệp vẫn giữ nguyên; PDF mã hóa hoặc bị hỏng không mở được.',
                ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          token = null;
        });
      }
    }
  }

  Future<void> add() => run((t) async {
    final file = await files.importBytes(
      extensions: ['pdf'],
      maxBytes: PdfDesk.maxBytes,
      cancellation: t,
    );
    if (file != null) await desk.add(file, t);
  });

  Future<void> save(Uint8List bytes, String name, String mime) =>
      run((t) async {
        final uri = await files.exportBytes(
          name,
          bytes,
          mimeType: mime,
          cancellation: t,
        );
        if (mounted)
          showHandyMessage(
            context,
            uri == null
                ? tr(context, 'Export canceled', 'Đã hủy xuất')
                : tr(context, 'Saved', 'Đã lưu'),
          );
      });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: desk,
    builder: (context, _) => PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PDF'),
          actions: [
            if (desk.inputs.isNotEmpty)
              TextButton.icon(
                key: const Key('pdf-import'),
                onPressed: busy ? null : add,
                icon: const Icon(Icons.add),
                label: Text(tr(context, 'Add PDF', 'Thêm PDF')),
              ),
          ],
        ),
        bottomNavigationBar: busy
            ? HandyBottomBar(
                child: Row(
                  children: [
                    const Expanded(child: LinearProgressIndicator()),
                    const SizedBox(width: HandySpace.m),
                    TextButton(
                      key: const Key('pdf-cancel'),
                      onPressed: token?.cancel,
                      child: Text(tr(context, 'Cancel', 'Hủy')),
                    ),
                  ],
                ),
              )
            : null,
        body: desk.document == null
            ? _empty(context)
            : LayoutBuilder(builder: _layout),
      ),
    ),
  );

  Widget _empty(BuildContext context) => HandyEmpty(
    title: tr(context, 'Add a PDF to begin', 'Thêm một PDF để bắt đầu'),
    message: tr(
      context,
      'Pick pages, put them in order, turn them, stamp them, or merge several files. Up to 20 files and 30 MB; the originals are never changed.',
      'Chọn trang, sắp thứ tự, xoay, đóng dấu, hoặc ghép nhiều tệp. Tối đa 20 tệp và 30 MB; tệp gốc không bao giờ bị sửa.',
    ),
    action: FilledButton.icon(
      key: const Key('pdf-import'),
      onPressed: busy ? null : add,
      icon: const Icon(Icons.file_open_outlined),
      label: Text(tr(context, 'Add PDF', 'Thêm PDF')),
    ),
  );

  Widget _layout(BuildContext context, BoxConstraints box) {
    final wide = box.maxWidth >= 900;
    final sheet = wide
        ? ((box.maxHeight - 160) / 1.414).clamp(200.0, box.maxWidth - 460)
        : (box.maxWidth - 2 * HandySpace.l).clamp(200.0, 360.0);
    final viewer = PageViewer(
      desk: desk,
      busy: busy,
      width: sheet,
      onSelect: (i) => run((t) => desk.select(i, t)),
      onRemove: (i) => run((t) => desk.remove(i, t)),
      onTurn: (p) => run((t) => desk.turn(p, t)),
      onSavePage: () =>
          save(desk.preview!, 'pdf-page-${desk.page + 1}.png', 'image/png'),
    );
    final panel = MakePanel(
      desk: desk,
      busy: busy,
      range: range,
      watermark: watermark,
      rotation: rotation,
      onRotation: (v) {
        setState(() => rotation = v);
        desk.dropOutput();
      },
      onMake: () =>
          run((t) => desk.make(range.text, rotation, watermark.text, t)),
      onMerge: () => run(desk.merge),
      onSave: () => save(desk.output!, 'handy-document.pdf', 'application/pdf'),
    );
    if (!wide) {
      return ListView(
        padding: const EdgeInsets.only(
          top: HandySpace.s,
          bottom: HandySpace.xl,
        ),
        children: [
          viewer,
          Padding(padding: const EdgeInsets.all(HandySpace.l), child: panel),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ColoredBox(
            color: HandyColors.of(context).ground,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: HandySpace.l),
              child: viewer,
            ),
          ),
        ),
        VerticalDivider(width: 1, color: HandyColors.of(context).rule),
        SizedBox(
          width: 400,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(HandySpace.xl),
            child: panel,
          ),
        ),
      ],
    );
  }
}
