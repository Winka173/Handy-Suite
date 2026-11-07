import 'package:handy_ui/kit.dart';
import 'labels.dart';
import 'package:flutter/services.dart';

class BoardField {
  final String id, en, vi, kind;
  final Map<String, String>? options;
  final bool optional, advanced;
  final bool Function(Map<String, dynamic>)? visibleWhen;
  const BoardField(
    this.id,
    this.en,
    this.vi, {
    this.kind = 'text',
    this.options,
    this.optional = false,
    this.advanced = false,
    this.visibleWhen,
  });
}

Future<void> boardForm(
  BuildContext context,
  String title,
  List<BoardField> fields,
  Map<String, dynamic> initial,
  Future<void> Function(Map<String, dynamic>) save, {
  List<Widget> footer = const [],
  String? saveLabel,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _BoardForm(title, fields, initial, save, footer, saveLabel),
);

class _BoardForm extends StatefulWidget {
  final String title;
  final List<BoardField> fields;
  final Map<String, dynamic> initial;
  final Future<void> Function(Map<String, dynamic>) save;
  final List<Widget> footer;
  final String? saveLabel;
  const _BoardForm(
    this.title,
    this.fields,
    this.initial,
    this.save,
    this.footer,
    this.saveLabel,
  );
  @override
  State<_BoardForm> createState() => _FormState();
}

class _FormState extends State<_BoardForm> {
  late final values = Map<String, dynamic>.of(widget.initial);
  late final inputs = {
    for (final f in widget.fields.where(
      (f) => !['select', 'bool', 'date', 'multi'].contains(f.kind),
    ))
      f.id: TextEditingController(text: values[f.id]?.toString() ?? ''),
  };
  String? error;
  bool busy = false;
  bool advanced = false;
  @override
  void dispose() {
    for (final c in inputs.values) c.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      for (final f in widget.fields) {
        if (!(f.visibleWhen?.call(values) ?? true)) continue;
        if (inputs.containsKey(f.id)) values[f.id] = inputs[f.id]!.text;
        if (!f.optional &&
            f.kind != 'bool' &&
            !(f.kind == 'select' &&
                f.options?.containsKey('') == true &&
                values[f.id] == '') &&
            (values[f.id] == null ||
                values[f.id].toString().trim().isEmpty ||
                values[f.id] is List && (values[f.id] as List).isEmpty))
          throw FormatException(
            tr(
              context,
              'Complete required fields',
              'Hãy điền các mục bắt buộc',
            ),
          );
      }
      await widget.save(values);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(() {
          error = boardsError(context, e);
          busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (!busy) submit();
        },
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
          if (!busy) submit();
        },
      },
      child: AlertDialog(
        title: Text(widget.title),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final f in [
                  ...widget.fields.where((f) => !f.advanced),
                  if (advanced) ...widget.fields.where((f) => f.advanced),
                ].where((f) => f.visibleWhen?.call(values) ?? true))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (f.kind != 'bool' ||
                            MediaQuery.textScalerOf(context).scale(14) > 20)
                          Text(
                            tr(context, f.en, f.vi),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        const SizedBox(height: 8),
                        switch (f.kind) {
                          'select' => Semantics(
                            label: tr(context, f.en, f.vi),
                            child: DropdownButtonFormField<String>(
                              initialValue: values[f.id] as String?,
                              isExpanded: true,
                              items: [
                                for (final e in f.options!.entries)
                                  DropdownMenuItem(
                                    value: e.key,
                                    child: Text(
                                      e.value,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: busy
                                  ? null
                                  : (v) => setState(() => values[f.id] = v),
                            ),
                          ),
                          'multi' => Column(
                            children: [
                              for (final e in f.options!.entries)
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(e.value),
                                  value: (values[f.id] as List? ?? []).contains(
                                    e.key,
                                  ),
                                  onChanged: busy
                                      ? null
                                      : (checked) => setState(() {
                                          final selected = Set<String>.from(
                                            values[f.id] as List? ?? [],
                                          );
                                          checked == true
                                              ? selected.add(e.key)
                                              : selected.remove(e.key);
                                          values[f.id] = selected.toList();
                                        }),
                                ),
                            ],
                          ),
                          'bool' =>
                            MediaQuery.textScalerOf(context).scale(14) > 20
                                ? Align(
                                    alignment: Alignment.centerLeft,
                                    child: Semantics(
                                      label: tr(context, f.en, f.vi),
                                      child: Switch(
                                        value: values[f.id] == true,
                                        onChanged: busy
                                            ? null
                                            : (v) => setState(
                                                () => values[f.id] = v,
                                              ),
                                      ),
                                    ),
                                  )
                                : SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(tr(context, f.en, f.vi)),
                                    value: values[f.id] == true,
                                    onChanged: busy
                                        ? null
                                        : (v) =>
                                              setState(() => values[f.id] = v),
                                  ),
                          'date' => Row(
                            children: [
                              Expanded(
                                child: Semantics(
                                  label: tr(context, f.en, f.vi),
                                  child: OutlinedButton(
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            final result = await pickHandyDate(
                                              context,
                                              values[f.id] as String? ?? '',
                                            );
                                            if (result != null && mounted)
                                              setState(
                                                () => values[f.id] = result,
                                              );
                                          },
                                    child: Text(
                                      values[f.id] as String? ??
                                          tr(
                                            context,
                                            'Choose date',
                                            'Chọn ngày',
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              if (f.optional)
                                IconButton(
                                  tooltip: tr(context, 'Clear date', 'Bỏ ngày'),
                                  onPressed: busy
                                      ? null
                                      : () =>
                                            setState(() => values[f.id] = null),
                                  icon: const Icon(Icons.close),
                                ),
                            ],
                          ),
                          _ => Semantics(
                            label: tr(context, f.en, f.vi),
                            child: TextField(
                              key: Key('boards-field-${f.id}'),
                              controller: inputs[f.id],
                              enabled: !busy,
                              maxLines: f.kind == 'note' ? 5 : 1,
                              maxLength: f.kind == 'note' ? 100000 : 1000,
                              keyboardType: f.kind == 'number'
                                  ? TextInputType.number
                                  : null,
                              decoration: const InputDecoration(
                                counterText: '',
                              ),
                            ),
                          ),
                        },
                      ],
                    ),
                  ),
                if (widget.fields.any((f) => f.advanced))
                  OutlinedButton.icon(
                    key: const Key('boards-form-advanced'),
                    onPressed: busy
                        ? null
                        : () => setState(() => advanced = !advanced),
                    icon: Icon(
                      advanced ? Icons.expand_less : Icons.expand_more,
                    ),
                    label: Text(
                      advanced
                          ? tr(
                              context,
                              'Hide advanced options',
                              'Ẩn tuỳ chọn nâng cao',
                            )
                          : tr(
                              context,
                              'Advanced options',
                              'Tuỳ chọn nâng cao',
                            ),
                    ),
                  ),
                ...widget.footer,
                if (error != null)
                  SelectableText(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: Text(tr(context, 'Cancel', 'Hủy')),
          ),
          FilledButton(
            key: const Key('boards-form-save'),
            onPressed: busy ? null : submit,
            child: Text(
              busy
                  ? tr(context, 'Saving…', 'Đang lưu…')
                  : widget.saveLabel ?? tr(context, 'Save', 'Lưu'),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<bool> confirmBoards(
  BuildContext context,
  String title,
  String body,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'Cancel', 'Hủy')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'Confirm', 'Xác nhận')),
          ),
        ],
      ),
    ) ??
    false;
