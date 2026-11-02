import 'dart:async';
import 'package:handy_core/handy_core.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'fill_controller.dart';
import 'fill_tools.dart';
import 'page_canvas.dart';
import 'signature_store.dart';

/// Signing and filling a PDF: the page as the largest thing, the tools
/// beside it (in a sheet on a phone), then the new copy to look through
/// before it is saved. The original is never changed.
class FillPage extends StatefulWidget {
  final FillController fill;
  final SignatureStore signatures;
  final HandyFiles files;
  const FillPage({
    super.key,
    required this.fill,
    required this.signatures,
    required this.files,
  });
  @override
  State<FillPage> createState() => _FillPageState();
}

class _FillPageState extends State<FillPage> {
  bool busy = false, saved = false;
  CancellationToken? token;
  FillController get fill => widget.fill;

  @override
  void initState() {
    super.initState();
    run(fill.open);
  }

  @override
  void dispose() {
    token?.cancel();
    super.dispose();
  }

  Future<void> run(
    Future<void> Function() task, {
    CancellationToken? cancel,
  }) async {
    if (busy) return;
    final t = cancel;
    setState(() {
      busy = true;
      token = t;
    });
    try {
      await task();
    } on Cancelled {
      if (mounted) {
        showHandyMessage(
          context,
          tr(
            context,
            'Canceled. Your marks are still on the page.',
            'Đã hủy. Các món đã đặt vẫn còn trên trang.',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showHandyMessage(
          context,
          '${e is FormatException ? e.message : errorText(context, e)}. ${tr(context, 'The original PDF is unchanged.', 'PDF gốc vẫn giữ nguyên.')}',
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

  void make() {
    final t = CancellationToken();
    run(() => fill.make(t), cancel: t);
  }

  Future<void> save() => run(() async {
    final uri = await fill.save(widget.files, CancellationToken());
    if (!mounted) return;
    if (uri != null) saved = true;
    showHandyMessage(
      context,
      uri == null
          ? tr(context, 'Export canceled', 'Đã hủy xuất')
          : tr(context, 'Signed copy saved', 'Đã lưu bản đã ký'),
    );
  });

  Future<void> leave() async {
    final ok = await confirmHandy(
      context,
      title: tr(context, 'Leave without saving?', 'Rời đi mà không lưu?'),
      message: tr(
        context,
        'The signatures and text you placed are dropped. The original PDF stays as it is.',
        'Chữ ký và chữ đã đặt sẽ mất. PDF gốc vẫn giữ nguyên.',
      ),
      confirmLabel: tr(context, 'Leave', 'Rời đi'),
      destructive: true,
    );
    if (ok && mounted) {
      saved = true;
      Navigator.pop(context);
    }
  }

  void tools(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          HandySpace.l,
          0,
          HandySpace.l,
          HandySpace.l,
        ),
        child: FillTools(
          fill: fill,
          signatures: widget.signatures,
          files: widget.files,
          busy: busy,
          run: run,
          onPlaced: () {
            if (Navigator.canPop(sheet)) Navigator.pop(sheet);
          },
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: fill,
    builder: (context, _) {
      final preview = fill.preview != null;
      return PopScope(
        canPop: !busy && (saved || !fill.dirty),
        onPopInvokedWithResult: (popped, _) {
          if (!popped && !busy) leave();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              fill.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: HandySpace.m),
                child: preview
                    ? FilledButton.icon(
                        key: const Key('fill-save'),
                        onPressed: busy ? null : save,
                        icon: const Icon(Icons.save_alt),
                        label: Text(tr(context, 'Save PDF', 'Lưu PDF')),
                      )
                    : FilledButton(
                        key: const Key('fill-make'),
                        onPressed: busy || fill.items.isEmpty ? null : make,
                        child: Text(
                          tr(context, 'See the new copy', 'Xem bản mới'),
                        ),
                      ),
              ),
            ],
          ),
          bottomNavigationBar: busy && token != null
              ? HandyBottomBar(
                  child: Row(
                    children: [
                      const Expanded(child: LinearProgressIndicator()),
                      const SizedBox(width: HandySpace.m),
                      TextButton(
                        key: const Key('fill-cancel'),
                        onPressed: token?.cancel,
                        child: Text(tr(context, 'Cancel', 'Hủy')),
                      ),
                    ],
                  ),
                )
              : null,
          body: LayoutBuilder(builder: (context, box) => _body(context, box)),
        ),
      );
    },
  );

  Widget _body(BuildContext context, BoxConstraints box) {
    final c = HandyColors.of(context);
    final wide = box.maxWidth >= 900;
    final preview = fill.preview != null;
    final well = Expanded(
      child: ColoredBox(
        color: c.ground,
        child: LayoutBuilder(
          builder: (context, area) => _well(context, area, wide),
        ),
      ),
    );
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 264,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(HandySpace.l),
              child: preview
                  ? _previewNote(context)
                  : FillTools(
                      fill: fill,
                      signatures: widget.signatures,
                      files: widget.files,
                      busy: busy,
                      run: run,
                    ),
            ),
          ),
          VerticalDivider(width: 1, color: c.rule),
          well,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (preview)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              HandySpace.l,
              HandySpace.m,
              HandySpace.l,
              HandySpace.s,
            ),
            child: _previewNote(context),
          ),
        well,
        if (!preview && !busy)
          HandyBottomBar(
            child: FilledButton.tonalIcon(
              key: const Key('fill-tools'),
              onPressed: () => tools(context),
              icon: const Icon(Icons.add),
              label: Text(
                tr(context, 'Signature, text or date', 'Chữ ký, chữ hoặc ngày'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _previewNote(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      HandyNotice(
        tr(
          context,
          'This is the new copy, with the marks drawn in. The original PDF stays as it is.',
          'Đây là bản mới, các nét đã gộp vào trang. PDF gốc vẫn giữ nguyên.',
        ),
        tone: HandyTone.success,
      ),
      const SizedBox(height: HandySpace.s),
      OutlinedButton.icon(
        key: const Key('fill-edit'),
        onPressed: busy ? null : fill.edit,
        icon: const Icon(Icons.edit_outlined),
        label: Text(tr(context, 'Keep editing', 'Sửa tiếp')),
      ),
    ],
  );

  Widget _well(BuildContext context, BoxConstraints area, bool wide) {
    final preview = fill.preview != null;
    final count = preview ? fill.preview!.pageCount : fill.source.pageCount;
    final at = preview ? fill.previewPage : fill.page;
    final aspect = fill.pageAspect;
    // The sheet fills the well, leaving room for the page row below it.
    final width = ((area.maxHeight - 120) * aspect)
        .clamp(160.0, area.maxWidth - 2 * HandySpace.l)
        .toDouble();
    final sheet = preview
        ? Container(
            key: const Key('fill-preview'),
            width: width,
            height: width / aspect,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: HandyColors.of(context).border),
            ),
            child: fill.previewPicture == null
                ? const SizedBox.shrink()
                : Image.memory(
                    fill.previewPicture!,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                    semanticLabel: tr(
                      context,
                      'New copy, page ${at + 1}',
                      'Bản mới, trang ${at + 1}',
                    ),
                  ),
          )
        : PageCanvas(fill: fill, width: width);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: HandySpace.l),
      child: Column(
        children: [
          if (!preview && fill.items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HandySpace.l,
                0,
                HandySpace.l,
                HandySpace.m,
              ),
              child: Text(
                wide
                    ? tr(
                        context,
                        'Pick a signature, text or a date on the left to place it.',
                        'Chọn chữ ký, ô chữ hoặc ngày bên trái để đặt lên trang.',
                      )
                    : tr(
                        context,
                        'Add a signature, text or a date from the bar below.',
                        'Thêm chữ ký, chữ hoặc ngày từ thanh bên dưới.',
                      ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          Center(child: sheet),
          const SizedBox(height: HandySpace.s),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const Key('fill-previous'),
                tooltip: tr(context, 'Previous page', 'Trang trước'),
                onPressed: busy || at == 0
                    ? null
                    : () => run(
                        () => preview
                            ? fill.turnPreview(at - 1)
                            : fill.turn(at - 1),
                      ),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                tr(
                  context,
                  'Page ${at + 1} of $count',
                  'Trang ${at + 1} / $count',
                ),
              ),
              IconButton(
                key: const Key('fill-next'),
                tooltip: tr(context, 'Next page', 'Trang sau'),
                onPressed: busy || at + 1 >= count
                    ? null
                    : () => run(
                        () => preview
                            ? fill.turnPreview(at + 1)
                            : fill.turn(at + 1),
                      ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
