import 'package:handy_ui/handy_ui.dart';

class EditField {
  final String id, en, vi;
  final Map<String, String>? options;
  final bool toggle, number, requiredValue;
  final List<String> suggestions;
  const EditField(
    this.id,
    this.en,
    this.vi, {
    this.options,
    this.toggle = false,
    this.number = false,
    this.requiredValue = true,
    this.suggestions = const [],
  });
}

class SpendEditor extends StatefulWidget {
  final String en, vi;
  final List<EditField> fields;
  final Map<String, dynamic> initial;
  final Future<void> Function(Map<String, dynamic>) save;
  const SpendEditor({
    super.key,
    required this.en,
    required this.vi,
    required this.fields,
    required this.initial,
    required this.save,
  });
  @override
  State<SpendEditor> createState() => _SpendEditorState();
}

class _SpendEditorState extends State<SpendEditor> {
  final form = GlobalKey<FormState>();
  late final values = Map<String, dynamic>.from(widget.initial);
  late final controllers = {
    for (final f in widget.fields.where((f) => !f.toggle && f.options == null))
      f.id: TextEditingController(text: values[f.id]?.toString() ?? ''),
  };
  bool busy = false;
  String error = '';
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    for (final e in controllers.entries) {
      values[e.key] = e.value.text;
    }
    if (!form.currentState!.validate() ||
        widget.fields.any(
          (f) =>
              f.requiredValue &&
              !f.toggle &&
              (values[f.id] == null || values[f.id].toString().trim().isEmpty),
        )) {
      setState(
        () => error = tr(
          context,
          'Complete all required fields.',
          '?i?n ??y ?? c?c m?c b?t bu?c.',
        ),
      );
      return;
    }
    setState(() => busy = true);
    try {
      await widget.save(Map.of(values));
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        setState(
          () => error = tr(
            context,
            'Could not save. Check amounts, dates, references and storage. Existing data was preserved.',
            'Không lưu được. Kiểm tra số tiền, ngày, liên kết và dung lượng. Dữ liệu hiện có được giữ lại.',
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: Text(tr(context, widget.en, widget.vi))),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error.isNotEmpty)
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              FilledButton(
                key: const Key('editor-save'),
                onPressed: busy ? null : submit,
                child: Text(
                  tr(
                    context,
                    busy ? 'Saving…' : 'Save',
                    busy ? 'Đang lưu…' : 'Lưu',
                  ),
                ),
              ),
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context, false),
                child: Text(tr(context, 'Cancel', 'Hủy')),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                for (final f in widget.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: f.toggle
                        ? SwitchListTile(
                            title: Text(tr(context, f.en, f.vi)),
                            value: values[f.id] == true,
                            onChanged: busy
                                ? null
                                : (v) => setState(() => values[f.id] = v),
                          )
                        : f.options != null
                        ? DropdownButtonFormField<String>(
                            initialValue: f.options!.containsKey(values[f.id])
                                ? values[f.id] as String
                                : null,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: tr(context, f.en, f.vi),
                            ),
                            items: f.options!.entries
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(
                                      e.value,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: busy
                                ? null
                                : (v) => setState(() => values[f.id] = v),
                            validator: (v) =>
                                f.requiredValue && (v == null || v.isEmpty)
                                ? tr(context, 'Required', 'Bắt buộc')
                                : null,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                key: ValueKey('field-${f.id}'),
                                controller: controllers[f.id],
                                enabled: !busy,
                                keyboardType: f.number
                                    ? const TextInputType.numberWithOptions(
                                        decimal: true,
                                        signed: true,
                                      )
                                    : TextInputType.text,
                                maxLength: f.id == 'note' ? 65536 : 1024,
                                maxLines: f.id == 'note' ? 3 : 1,
                                decoration: InputDecoration(
                                  labelText: tr(context, f.en, f.vi),
                                  counterText: '',
                                ),
                                validator: (v) =>
                                    f.requiredValue &&
                                        (v == null || v.trim().isEmpty)
                                    ? tr(context, 'Required', 'Bắt buộc')
                                    : null,
                              ),
                              if (f.suggestions.isNotEmpty)
                                Wrap(
                                  spacing: 6,
                                  children: f.suggestions
                                      .take(8)
                                      .map(
                                        (s) => ActionChip(
                                          label: Text(s),
                                          onPressed: busy
                                              ? null
                                              : () =>
                                                    controllers[f.id]!.text = s,
                                        ),
                                      )
                                      .toList(),
                                ),
                            ],
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
