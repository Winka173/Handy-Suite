import 'package:handy_ui/kit.dart';

class TripField {
  final String key, en, vi, kind;
  final bool optional;
  final Map<String, String>? choices;
  const TripField(
    this.key,
    this.en,
    this.vi, {
    this.kind = 'text',
    this.optional = false,
    this.choices,
  });
}

TripField foldField(BuildContext context, {String key = 'fold'}) => TripField(
  key,
  'Repeated local time (DST)',
  'Giờ địa phương trùng (DST)',
  kind: 'choice',
  choices: {
    'earlier': tr(context, 'First occurrence', 'Lần đầu'),
    'later': tr(context, 'Second occurrence', 'Lần sau'),
  },
);

Future<void> tripForm(
  BuildContext context,
  String title,
  List<TripField> fields,
  Map<String, dynamic> initial,
  Future<void> Function(Map<String, dynamic>) save, {
  List<Widget> footer = const [],
  String? saveLabel,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _Form(title, fields, initial, save, footer, saveLabel),
);

class _Form extends StatefulWidget {
  final String title;
  final List<TripField> fields;
  final Map<String, dynamic> initial;
  final Future<void> Function(Map<String, dynamic>) save;
  final List<Widget> footer;
  final String? saveLabel;
  const _Form(
    this.title,
    this.fields,
    this.initial,
    this.save,
    this.footer,
    this.saveLabel,
  );
  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  late final values = Map<String, dynamic>.of(widget.initial);
  late final controllers = {
    for (final f in widget.fields.where(
      (f) => !['date', 'time', 'toggle', 'choice'].contains(f.kind),
    ))
      f.key: TextEditingController(text: '${values[f.key] ?? ''}'),
  };
  @override
  void dispose() {
    for (final c in controllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HandyCommitDialog(
    title: widget.title,
    saveLabel: widget.saveLabel ?? tr(context, 'Save', 'Lưu'),
    saveKey: const Key('trip-form-save'),
    onCommit: () async {
      for (final e in controllers.entries) values[e.key] = e.value.text.trim();
      for (final f in widget.fields)
        if (!f.optional &&
            f.kind != 'toggle' &&
            (values[f.key] == null || values[f.key].toString().isEmpty))
          throw FormatException(
            tr(context, 'Complete required fields', 'Điền đủ trường bắt buộc'),
          );
      await widget.save(Map.of(values));
    },
    fields: (context, busy) => [
      for (final f in widget.fields)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (f.kind != 'toggle')
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(tr(context, f.en, f.vi)),
                ),
              if (f.kind == 'choice')
                DropdownButtonFormField<String>(
                  key: Key('field-${f.key}'),
                  initialValue: f.choices!.containsKey(values[f.key])
                      ? values[f.key] as String?
                      : null,
                  isExpanded: true,
                  items: [
                    for (final e in f.choices!.entries)
                      DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (v) => setState(() => values[f.key] = v),
                ),
              if (f.kind == 'toggle')
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr(context, f.en, f.vi)),
                  value: values[f.key] == true,
                  onChanged: busy
                      ? null
                      : (v) => setState(() => values[f.key] = v),
                ),
              if (f.kind == 'date' || f.kind == 'time')
                OutlinedButton(
                  key: Key('field-${f.key}'),
                  onPressed: busy
                      ? null
                      : () async {
                          String? value;
                          if (f.kind == 'date') {
                            value = await pickHandyDate(
                              context,
                              values[f.key] as String? ??
                                  DateTime.now().toIso8601String().substring(
                                    0,
                                    10,
                                  ),
                            );
                          } else {
                            final old =
                                    (values[f.key]?.toString().isNotEmpty ==
                                                true
                                            ? values[f.key] as String
                                            : '09:00')
                                        .split(':'),
                                picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(
                                    hour: int.parse(old[0]),
                                    minute: int.parse(old[1]),
                                  ),
                                );
                            if (picked != null)
                              value =
                                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                          }
                          if (mounted && value != null)
                            setState(() => values[f.key] = value);
                        },
                  child: Text(
                    values[f.key]?.toString().isNotEmpty == true
                        ? values[f.key].toString()
                        : tr(context, 'Choose', 'Chọn'),
                  ),
                ),
              if (controllers.containsKey(f.key))
                Semantics(
                  label: tr(context, f.en, f.vi),
                  child: TextField(
                    key: Key('field-${f.key}'),
                    controller: controllers[f.key],
                    enabled: !busy,
                    maxLength: f.kind == 'note' ? 10000 : 500,
                    maxLines: f.kind == 'note' ? 3 : 1,
                    keyboardType: f.kind == 'number'
                        ? const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          )
                        : TextInputType.text,
                    decoration: const InputDecoration(counterText: ''),
                  ),
                ),
            ],
          ),
        ),
      for (final item in widget.footer)
        AbsorbPointer(absorbing: busy, child: item),
    ],
  );
}

Future<bool> tripConfirm(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'Confirm', 'Xác nhận')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'Cancel', 'Hủy')),
          ),
          FilledButton(
            key: const Key('trip-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'Confirm', 'Xác nhận')),
          ),
        ],
      ),
    ) ??
    false;
