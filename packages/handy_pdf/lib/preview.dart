import 'dart:async';
import 'dart:typed_data';
import 'package:handy_core/handy_core.dart';
import 'package:handy_ui/handy_ui.dart';
import 'handy_pdf.dart';

/// Read-only local preview, with no clickable document actions or external URLs.
class LocalPdfPreview extends StatefulWidget {
  final Uint8List bytes;
  final String title;
  const LocalPdfPreview({super.key, required this.bytes, required this.title});
  @override
  State<LocalPdfPreview> createState() => _LocalPdfPreviewState();
}

class _LocalPdfPreviewState extends State<LocalPdfPreview> {
  LocalPdf? document;
  Uint8List? png;
  String error = '';
  int page = 0;
  bool busy = false;
  final token = CancellationToken();
  Future<void>? pending;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    token.cancel();
    final old = document;
    if (pending == null) {
      unawaited(old?.close());
    } else {
      unawaited(pending!.whenComplete(() async => old?.close()));
    }
    super.dispose();
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    final completer = Completer<void>();
    pending = completer.future;
    LocalPdf? next;
    try {
      next = await LocalPdf.open(widget.bytes, cancellation: token);
      final image = await next.renderPng(0, cancellation: token);
      if (!mounted) {
        await next.close();
        return;
      }
      setState(() {
        document = next;
        png = image;
        page = 0;
      });
    } catch (_) {
      await next?.close();
      if (mounted)
        setState(
          () => error = tr(
            context,
            'This PDF could not be previewed. The attachment was preserved.',
            'Không xem trước được PDF này. Giữ nguyên file đính kèm.',
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
      pending = null;
      completer.complete();
    }
  }

  Future<void> go(int nextPage) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    final completer = Completer<void>();
    pending = completer.future;
    try {
      final image = await document!.renderPng(nextPage, cancellation: token);
      if (mounted)
        setState(() {
          page = nextPage;
          png = image;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => error = tr(
            context,
            'Page could not be rendered.',
            'Không hiển thị được trang.',
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
      pending = null;
      completer.complete();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Column(
      children: [
        if (busy) const LinearProgressIndicator(),
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (document == null && !busy)
          TextButton(
            onPressed: load,
            child: Text(tr(context, 'Retry', 'Thử lại')),
          ),
        if (document != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: tr(context, 'Previous page', 'Trang trước'),
                onPressed: busy || page == 0 ? null : () => go(page - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${page + 1} / ${document!.pages.length}'),
              IconButton(
                tooltip: tr(context, 'Next page', 'Trang sau'),
                onPressed: busy || page + 1 == document!.pages.length
                    ? null
                    : () => go(page + 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        if (png != null)
          Expanded(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.memory(
                  png!,
                  key: const Key('local-pdf-preview'),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          )
        else
          const Spacer(),
      ],
    ),
  );
}
