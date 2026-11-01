import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:handy_files/handy_files.dart';
import 'package:handy_storage/export_history.dart';
import 'package:handy_ui/kit.dart';
import '../specs.dart';
import '../tool_fields.dart';
import 'answer.dart';
import 'evaluate.dart';
import 'tape.dart';

const _typed = {
  FieldType.decimal,
  FieldType.integer,
  FieldType.text,
  FieldType.longText,
  FieldType.color,
};

/// Drafts are `{"v":1,"f":{...}}`; older drafts were the raw engine input.
Map<String, String> decodeDraft(ToolSpec spec, String draft) {
  if (draft.isEmpty) return {};
  try {
    final j = jsonDecode(draft);
    if (j is Map && j['v'] == 1 && j['f'] is Map) {
      return (j['f'] as Map).map((k, v) => MapEntry('$k', '$v'));
    }
  } catch (_) {}
  final typed = spec.fields.where((f) => _typed.contains(f.type)).toList();
  if (typed.length == 1 || typed.first.type == FieldType.longText) {
    return {typed.first.id: draft};
  }
  final parts = draft.split(',');
  return {
    for (var i = 0; i < typed.length && i < parts.length; i++)
      typed[i].id: parts[i].trim(),
  };
}

/// A tool as a form on the bench: labelled fields, the answer under them.
/// Opened from the catalog, a pinned chip, or "Open as form" on a free entry.
class ToolPanel extends StatefulWidget {
  final ToolSpec spec;
  final HandyFiles files;
  final ExportHistory? history;
  final TapeController tape;
  final Map<String, String> initial;
  final String draft;
  final Future<void> Function(String draft)? onSaveDraft;

  /// Builds the bench header around this panel's own actions.
  final Widget Function(BuildContext, List<Widget>)? header;
  const ToolPanel({
    super.key,
    required this.spec,
    required this.files,
    required this.tape,
    this.history,
    this.initial = const {},
    this.draft = '',
    this.onSaveDraft,
    this.header,
  });
  @override
  State<ToolPanel> createState() => ToolPanelState();
}

class ToolPanelState extends State<ToolPanel> {
  late final start = {
    ...decodeDraft(widget.spec, widget.draft),
    ...widget.initial,
  };
  late final controllers = {
    for (final f in widget.spec.fields)
      if (_typed.contains(f.type))
        f.id: TextEditingController(text: start[f.id] ?? f.initial),
  };
  late final picks = {
    for (final f in widget.spec.fields)
      if (!_typed.contains(f.type)) f.id: start[f.id] ?? f.initial,
  };
  late final history = widget.history ?? ExportHistory('tools');
  bool ran = false, busy = false;

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> values() => {
    for (final f in widget.spec.fields)
      f.id: controllers[f.id] == null
          ? picks[f.id]!
          : switch (f.type) {
              FieldType.decimal => controllers[f.id]!.text.trim().replaceAll(
                ',',
                '.',
              ),
              FieldType.longText => controllers[f.id]!.text,
              _ => controllers[f.id]!.text.trim(),
            },
  };

  bool get complete =>
      widget.spec.fields.every((f) => f.optional || values()[f.id]!.isNotEmpty);
  bool get large =>
      values().values.fold<int>(0, (n, s) => n + s.length) > liveLimit;

  /// Current evaluation, or null while fields are missing or text is large.
  Evaluation? result(BuildContext context) => !complete || (large && !ran)
      ? null
      : evaluate(context, widget.spec, values());

  void changed(String id, String value) => setState(() {
    ran = false;
    if (controllers[id] == null) picks[id] = value;
    if (id == 'kind') {
      final units = widget.spec.fields
          .firstWhere((f) => f.id == 'from')
          .choices!({'kind': value});
      picks['from'] = units[0].$1;
      picks['to'] = units[1].$1;
    }
  });

  void record(Evaluation r) => widget.tape.add(
    tapeEntry(
      context,
      input: [
        for (final f in widget.spec.fields) values()[f.id]!,
      ].where((s) => s.isNotEmpty).join(' · '),
      toolId: widget.spec.id,
      values: values(),
      result: r,
    ),
  );

  Future<void> guarded(Future<void> Function() action, String failure) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) showHandyMessage(context, failure);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> export(String text) => guarded(() async {
    final uri = await widget.files.exportText('${widget.spec.id}.txt', text);
    if (!mounted) return;
    if (uri == null)
      return showHandyMessage(context, tr(context, 'Not saved.', 'Chưa lưu.'));
    try {
      await history.record(
        tool: widget.spec.id,
        uri: uri,
        mime: 'text/plain',
        data: Uint8List.fromList(utf8.encode(text)),
      );
      if (mounted) showHandyMessage(context, tr(context, 'Saved', 'Đã lưu'));
    } catch (_) {
      if (mounted) {
        showHandyMessage(
          context,
          tr(
            context,
            'File saved; export history could not be updated.',
            'Đã lưu file; chưa cập nhật được lịch sử xuất.',
          ),
        );
      }
    }
  }, tr(context, 'Could not save the file.', 'Chưa lưu được file.'));

  Future<void> fill(String id, Future<String?> Function() source) => guarded(
    () async {
      final text = await source();
      if (text != null && mounted) setState(() => controllers[id]!.text = text);
    },
    tr(context, 'Could not read that text.', 'Chưa đọc được nội dung này.'),
  );

  /// Overflow actions; the bench puts them in its header.
  List<HandyMenuItem> menu(BuildContext context) {
    final long = widget.spec.fields.where((f) => f.type == FieldType.longText);
    return [
      if (long.isNotEmpty)
        HandyMenuItem(
          Icons.file_open_outlined,
          tr(context, 'Open text file', 'Mở file văn bản'),
          busy
              ? null
              : () => fill(
                  long.first.id,
                  () async => (await widget.files.importText())?.text,
                ),
        ),
      if (widget.onSaveDraft != null)
        HandyMenuItem(
          Icons.bookmark_add_outlined,
          tr(context, 'Save input', 'Lưu nội dung nhập'),
          busy
              ? null
              : () => guarded(
                  () async {
                    await widget.onSaveDraft!(
                      jsonEncode({'v': 1, 'f': values()}),
                    );
                    if (mounted)
                      showHandyMessage(
                        this.context,
                        tr(this.context, 'Input saved', 'Đã lưu nội dung nhập'),
                      );
                  },
                  tr(
                    context,
                    'Could not save input.',
                    'Chưa lưu được nội dung nhập.',
                  ),
                ),
          key: const Key('save-draft'),
        ),
      HandyMenuItem(
        Icons.backspace_outlined,
        tr(context, 'Clear', 'Xóa trắng'),
        busy
            ? null
            : () => setState(() {
                for (final f in widget.spec.fields) {
                  controllers[f.id]?.text = f.initial;
                  if (picks.containsKey(f.id)) picks[f.id] = f.initial;
                }
              }),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final v = {...values(), ...picks};
    final r = result(context);
    Widget field(FieldSpec f) => ToolField(
      spec: f,
      controller: controllers[f.id],
      value: v[f.id]!,
      values: v,
      enabled: !busy,
      onChanged: (value) => changed(f.id, value),
      onPaste: f.type == FieldType.longText
          ? () => fill(
              f.id,
              () async => (await Clipboard.getData('text/plain'))?.text,
            )
          : null,
    );
    final unitPair = spec.id == 'units';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.header != null)
          widget.header!(context, [HandyMenuButton(items: menu(context))]),
        for (final f in spec.fields.where(
          (f) => !unitPair || (f.id != 'from' && f.id != 'to'),
        )) ...[
          field(f),
          if (unitPair && f.id == 'value') _pair(context, field),
        ],
        const SizedBox(height: HandySpace.s),
        // The state (empty, answer, error) fades; the answer itself updates
        // in place while the fields change.
        HandySwap(
          child: Column(
            key: ValueKey(
              r == null
                  ? (large && complete ? 'run' : 'empty')
                  : r.ok
                  ? 'answer'
                  : 'error',
            ),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (r != null && r.ok)
                AnswerPanel(
                  key: const Key('bench-answer'),
                  result: r,
                  onCopy: () {
                    record(r);
                    copyToClipboard(context, r.copy);
                  },
                  onRecord: () => record(r),
                  extra: [
                    HandyShareButton(
                      name: '${spec.id}.txt',
                      mimeType: 'text/plain',
                      bytes: () => Uint8List.fromList(utf8.encode(r.copy)),
                    ),
                    IconButton.outlined(
                      key: const Key('export-result'),
                      tooltip: tr(context, 'Save as file', 'Lưu thành file'),
                      icon: const Icon(Icons.download_outlined, size: 20),
                      onPressed: busy ? null : () => export(r.copy),
                    ),
                  ],
                )
              else if (r != null)
                HandyNotice(
                  tr(
                    context,
                    'Check the values: ${r.error}',
                    'Kiểm tra lại giá trị: ${r.error}',
                  ),
                  key: const Key('tool-error'),
                  tone: HandyTone.error,
                )
              else if (large && complete)
                FilledButton(
                  key: const Key('run-tool'),
                  onPressed: () => setState(() => ran = true),
                  child: Text(tr(context, 'Run', 'Chạy')),
                )
              else
                HandyEmpty(
                  title: tr(
                    context,
                    'Fill in the fields — the answer appears here.',
                    'Điền các ô — kết quả hiện ở đây.',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pair(BuildContext context, Widget Function(FieldSpec) field) {
    FieldSpec f(String id) => widget.spec.fields.firstWhere((x) => x.id == id);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field(f('from'))),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 26, 4, 0),
          child: IconButton(
            key: const Key('swap-units'),
            tooltip: tr(context, 'Swap units', 'Đảo đơn vị'),
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => setState(() {
              final a = picks['from']!;
              picks['from'] = picks['to']!;
              picks['to'] = a;
            }),
          ),
        ),
        Expanded(child: field(f('to'))),
      ],
    );
  }
}
