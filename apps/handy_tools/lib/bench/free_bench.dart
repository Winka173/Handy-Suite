import 'package:flutter/services.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_workflow/handy_workflow.dart';
import '../specs.dart';
import 'answer.dart';
import 'examples.dart';
import 'evaluate.dart';
import 'intent.dart';
import 'tape.dart';

/// The bench's free entry: type anything, read the answer, keep it on the tape.
class FreeBench extends StatefulWidget {
  final TapeController tape;
  final HandyFiles files;
  final List<Recipe> chains;
  final List<String> pinned;
  final FocusNode focus;
  final TextEditingController input;
  final void Function(String id, Map<String, String> values) onOpenTool;
  final Future<void> Function(Recipe) onSaveChain;
  final VoidCallback onOpenCatalog;
  const FreeBench({
    super.key,
    required this.tape,
    required this.files,
    required this.chains,
    required this.pinned,
    required this.focus,
    required this.input,
    required this.onOpenTool,
    required this.onSaveChain,
    required this.onOpenCatalog,
  });
  @override
  State<FreeBench> createState() => FreeBenchState();
}

class FreeBenchState extends State<FreeBench> {
  int reading = 0;
  bool submitted = false, ran = false;
  final chain = <String>[];

  String get text => widget.input.text;

  void changed() => setState(() {
    reading = 0;
    submitted = false;
    ran = false;
  });

  /// Current answer, or null while the entry is empty or incomplete.
  ({Reading intent, Evaluation result})? current(BuildContext context) {
    final vi = Localizations.localeOf(context).languageCode == 'vi';
    final intents = interpret(text, vi: vi);
    if (intents.isEmpty) return null;
    final intent = intents[reading.clamp(0, intents.length - 1)];
    if (intent.toolId == 'qr') return null;
    if (text.length > liveLimit && !ran) return null;
    final prose = intents.first.toolId == 'count';
    final result = prose && chain.isNotEmpty
        ? runChain(chain, text)
        : evaluate(context, intent.spec!, intent.values);
    return (intent: intent, result: result);
  }

  /// Enter and Copy both put the answer on the tape.
  void record() {
    final now = current(context);
    if (now == null || !now.result.ok) {
      setState(() => submitted = true);
      return;
    }
    widget.tape.add(
      tapeEntry(
        context,
        input: text,
        toolId: chain.isEmpty ? now.intent.toolId : 'chain',
        values: now.intent.values,
        result: now.result,
        free: true,
      ),
    );
  }

  Future<void> copy() async {
    final now = current(context);
    if (now == null || !now.result.ok) return;
    record();
    await copyToClipboard(context, now.result.copy);
  }

  void fill(String value) {
    widget.input.text = value;
    widget.input.selection = TextSelection.collapsed(offset: value.length);
    changed();
    widget.focus.requestFocus();
  }

  Future<void> paste() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) fill(data!.text!);
  }

  Future<void> saveFile(String body) async {
    try {
      final uri = await widget.files.exportText('handy-text.txt', body);
      if (mounted && uri != null)
        showHandyMessage(context, tr(context, 'Saved', 'Đã lưu'));
    } catch (_) {
      if (mounted)
        showHandyMessage(
          context,
          tr(context, 'Could not save the file.', 'Chưa lưu được file.'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vi = Localizations.localeOf(context).languageCode == 'vi';
    final intents = interpret(text, vi: vi);
    final prose = intents.isNotEmpty && intents.first.toolId == 'count';
    final now = current(context);
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              HandySpace.l,
              HandySpace.s,
              HandySpace.xs,
              HandySpace.s,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('bench-input'),
                    controller: widget.input,
                    focusNode: widget.focus,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 8,
                    textInputAction: TextInputAction.done,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: 'Geist',
                      package: 'handy_ui',
                      fontWeight: FontWeight.w400,
                      fontSize: 22,
                    ),
                    onChanged: (_) => changed(),
                    onSubmitted: (_) => record(),
                    decoration: InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: tr(
                        context,
                        'Type or paste anything',
                        'Gõ hoặc dán bất cứ thứ gì',
                      ),
                      hintMaxLines: 1,
                    ),
                  ),
                ),
                if (text.isEmpty)
                  IconButton(
                    key: const Key('bench-paste'),
                    tooltip: tr(context, 'Paste', 'Dán'),
                    icon: const Icon(Icons.content_paste, size: 20),
                    onPressed: paste,
                  )
                else
                  IconButton(
                    key: const Key('bench-clear'),
                    tooltip: tr(context, 'Clear', 'Xóa'),
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      chain.clear();
                      fill('');
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: HandySpace.m),
        if (intents.isEmpty)
          BenchExamples(
            onPick: fill,
            pinned: widget.pinned,
            onOpenTool: (id) => widget.onOpenTool(id, const {}),
            onOpenCatalog: widget.onOpenCatalog,
          )
        else ...[
          if (!prose)
            ReadingRow(
              ids: [for (final i in intents) i.toolId],
              selected: reading,
              onSelect: (i) => setState(() => reading = i),
            )
          else
            HandyChainBar(
              chain: chain,
              saved: widget.chains,
              steps: textTransforms,
              label: (c, id) => specById[id]!.title(c),
              onAdd: (id) => setState(() => chain.add(id)),
              onRemove: (i) => setState(() => chain.removeAt(i)),
              onUse: (r) => setState(
                () => chain
                  ..clear()
                  ..addAll(r.steps),
              ),
              onSave: () => saveHandyChain(context, chain, widget.onSaveChain),
            ),
          const SizedBox(height: HandySpace.l),
          // The state (hint, answer, error) fades; the answer itself updates
          // in place while typing.
          HandySwap(
            child: Column(
              key: ValueKey(
                intents[reading.clamp(0, intents.length - 1)].toolId == 'qr'
                    ? 'qr'
                    : text.length > liveLimit && !ran
                    ? 'run'
                    : now != null && now.result.ok
                    ? 'answer'
                    : now != null && submitted
                    ? 'error'
                    : 'hint',
              ),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (intents[reading.clamp(0, intents.length - 1)].toolId ==
                    'qr')
                  FilledButton.icon(
                    key: const Key('bench-make-qr'),
                    onPressed: () =>
                        widget.onOpenTool('qr', {'text': text.trim()}),
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: Text(
                      tr(
                        context,
                        'Make a QR code for this link',
                        'Tạo mã QR cho liên kết này',
                      ),
                    ),
                  )
                else if (text.length > liveLimit && !ran)
                  FilledButton(
                    key: const Key('run-tool'),
                    onPressed: () => setState(() => ran = true),
                    child: Text(
                      tr(
                        context,
                        'Run on this large text',
                        'Chạy với văn bản lớn này',
                      ),
                    ),
                  )
                else if (now != null && now.result.ok)
                  AnswerPanel(
                    key: const Key('bench-answer'),
                    result: now.result,
                    onCopy: copy,
                    onRecord: record,
                    extra: [
                      if (!prose)
                        IconButton.outlined(
                          key: const Key('bench-open-form'),
                          tooltip: tr(context, 'Open as form', 'Mở dạng form'),
                          onPressed: () => widget.onOpenTool(
                            now.intent.toolId,
                            now.intent.values,
                          ),
                          icon: const Icon(Icons.tune, size: 20),
                        )
                      else
                        IconButton.outlined(
                          key: const Key('bench-save-file'),
                          tooltip: tr(
                            context,
                            'Save as file',
                            'Lưu thành file',
                          ),
                          icon: const Icon(Icons.download_outlined, size: 20),
                          onPressed: () => saveFile(now.result.copy),
                        ),
                    ],
                  )
                else if (now != null && submitted)
                  HandyNotice(
                    tr(
                      context,
                      'Check the entry: ${now.result.error}',
                      'Kiểm tra lại: ${now.result.error}',
                    ),
                    key: const Key('tool-error'),
                    tone: HandyTone.error,
                  )
                else
                  Text(
                    tr(
                      context,
                      'Keep typing — the answer appears as soon as it makes sense.',
                      'Gõ tiếp — kết quả hiện ngay khi đủ nghĩa.',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
