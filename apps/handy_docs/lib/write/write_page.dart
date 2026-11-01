import 'dart:async';
import 'package:flutter/services.dart';
import 'package:handy_core/handy_core.dart';
import 'package:handy_docs_engine/handy_docs_engine.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'draft.dart';
import 'export_sheet.dart';
import 'find_row.dart';
import 'leave_dialog.dart';
import 'write_layout.dart';
import 'write_menu.dart';

/// Writing Markdown: the text and how it will look, side by side on wide
/// screens, one at a time on phones. Ctrl S saves, Ctrl F finds, Ctrl P
/// makes the PDF.
class WritePage extends StatefulWidget {
  final DraftController draft;
  final HandyFiles files;
  const WritePage({super.key, required this.draft, required this.files});
  @override
  State<WritePage> createState() => _WritePageState();
}

class _WritePageState extends State<WritePage> {
  DraftController get draft => widget.draft;
  bool busy = false, finding = false, preview = false, wide = false;
  CancellationToken? token;
  MarkdownDocument? doc;
  String? problem;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    draft.source.addListener(_schedule);
  }

  @override
  void dispose() {
    draft.source.removeListener(_schedule);
    _debounce?.cancel();
    token?.cancel();
    super.dispose();
  }

  void _schedule() {
    if (!wide && !preview) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(_render);
    });
  }

  void _render() {
    try {
      doc = draft.render();
      problem = null;
    } on FormatException catch (e) {
      doc = null;
      problem = e.message;
    }
  }

  Future<void> run(Future<void> Function() task, {CancellationToken? t}) async {
    if (busy) return;
    setState(() {
      busy = true;
      token = t;
    });
    try {
      await task();
    } on Cancelled {
      if (mounted)
        showHandyMessage(
          context,
          tr(context, 'Export canceled', 'Đã hủy xuất'),
        );
    } catch (e) {
      if (mounted) {
        showHandyMessage(
          context,
          '${e is FormatException ? e.message : errorText(context, e)}. ${tr(context, 'Your draft is unchanged.', 'Bản nháp vẫn giữ nguyên.')}',
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

  Future<void> save() => run(() async {
    await draft.save();
    if (mounted)
      showHandyMessage(context, tr(context, 'Draft saved', 'Đã lưu bản nháp'));
  });

  Future<void> export([String? kind]) async {
    final choice = kind == null
        ? await pickExport(context)
        : (kind: kind, share: false);
    if (choice == null || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final from = choice.share && box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    final t = CancellationToken();
    await run(t: t, () async {
      final file = await draft.output(choice.kind, t);
      final result = await draft.deliver(
        widget.files,
        file,
        token: t,
        shareFrom: from,
      );
      if (!mounted) return;
      showHandyMessage(
        context,
        exportMessage(context, result, draft.historyUnavailable),
      );
    });
  }

  /// Asks before an import replaces words that are not saved.
  Future<bool> mayReplace() async =>
      !draft.dirty ||
      await confirmHandy(
        context,
        title: tr(context, 'Replace unsaved draft?', 'Thay bản nháp chưa lưu?'),
        message: tr(
          context,
          'Export or save a copy before replacing it.',
          'Xuất hoặc lưu một bản trước khi thay thế.',
        ),
        confirmLabel: tr(context, 'Replace', 'Thay thế'),
      );

  Future<void> leave() async {
    final choice = await askLeave(context);
    if (!mounted || choice == null) return;
    if (choice == 'save') await save();
    if (choice == 'discard') draft.revert();
    if (mounted && !draft.dirty) Navigator.pop(context);
  }

  void setPreview(bool value) => setState(() {
    preview = value;
    if (value) _render();
  });

  @override
  Widget build(BuildContext context) {
    final mac = {
      TargetPlatform.macOS,
      TargetPlatform.iOS,
    }.contains(Theme.of(context).platform);
    SingleActivator key(LogicalKeyboardKey k) =>
        SingleActivator(k, control: !mac, meta: mac);
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) => PopScope(
        canPop: !busy && !draft.dirty,
        onPopInvokedWithResult: (popped, _) {
          if (!popped && !busy) leave();
        },
        child: CallbackShortcuts(
          bindings: {
            key(LogicalKeyboardKey.keyS): () => busy ? null : save(),
            key(LogicalKeyboardKey.keyF): () => setState(() => finding = true),
            key(LogicalKeyboardKey.keyP): () => busy ? null : export('pdf'),
          },
          child: Scaffold(
            appBar: AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Flexible(
                    child: Text('Markdown', overflow: TextOverflow.ellipsis),
                  ),
                  HandyReveal(
                    child: draft.dirty
                        ? Semantics(
                            label: tr(
                              context,
                              'Unsaved changes',
                              'Thay đổi chưa lưu',
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: HandySpace.s,
                              ),
                              child: CircleAvatar(
                                radius: 4,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  key: const Key('markdown-save'),
                  onPressed: busy || !draft.dirty ? null : save,
                  child: Text(tr(context, 'Save', 'Lưu')),
                ),
                IconButton(
                  key: const Key('markdown-export'),
                  tooltip: tr(context, 'Export', 'Xuất'),
                  onPressed: busy ? null : export,
                  icon: const Icon(Icons.ios_share),
                ),
                WriteMenu(
                  draft: draft,
                  files: widget.files,
                  busy: busy,
                  run: run,
                  mayReplace: mayReplace,
                  onFind: () => setState(() => finding = true),
                ),
              ],
            ),
            bottomNavigationBar: token == null
                ? null
                : HandyBottomBar(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(tr(context, 'Exporting…', 'Đang xuất…')),
                        ),
                        TextButton(
                          key: const Key('markdown-cancel'),
                          onPressed: token?.cancel,
                          child: Text(tr(context, 'Cancel export', 'Hủy xuất')),
                        ),
                      ],
                    ),
                  ),
            body: Column(
              children: [
                if (token != null) const LinearProgressIndicator(minHeight: 2),
                HandyReveal(
                  child: finding
                      ? FindRow(
                          draft: draft,
                          onClose: () => setState(() => finding = false),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                Expanded(
                  child: WriteLayout(
                    draft: draft,
                    busy: busy,
                    preview: preview,
                    document: doc,
                    problem: problem,
                    onPreview: setPreview,
                    onWide: (v) {
                      if (v && !wide) {
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => mounted ? setState(_render) : null,
                        );
                      }
                      wide = v;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
