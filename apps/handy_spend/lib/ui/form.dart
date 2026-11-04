import 'package:handy_ui/kit.dart';
import '../money.dart';
import '../scope.dart';
import 'figures.dart';
import 'sheet.dart';

enum FieldKind { text, note, money, date, choice, toggle, count }

/// One input of a [SpendForm]. Labels sit above their field; [help] stays
/// beside it for what the field accepts.
class SpendField {
  final String id, en, vi;
  final FieldKind kind;
  final Map<String, String>? options;
  final bool required;
  final String? helpEn, helpVi;

  /// Money fields: the currency to read the amount in, from the values.
  final String Function(Map<String, dynamic> values)? currency;

  /// Money fields that may carry a sign (an adjustment, a schedule).
  final bool signed;
  final List<String> suggestions;

  /// Drawn under the field and redrawn as it is typed in (what the value
  /// would mean), given the raw text.
  final Widget Function(BuildContext context, String raw)? live;
  const SpendField(
    this.id,
    this.en,
    this.vi, {
    this.kind = FieldKind.text,
    this.options,
    this.required = true,
    this.helpEn,
    this.helpVi,
    this.currency,
    this.signed = false,
    this.suggestions = const [],
    this.live,
  });
}

/// Opens a form for [fields]. Money arrives in [save] as minor units
/// (BigInt), counts as int; a failed save keeps the form and what was
/// typed. True when saved.
Future<bool> showSpendForm(
  BuildContext context,
  SpendScope scope, {
  required String title,
  required List<SpendField> fields,
  required Map<String, dynamic> initial,
  required Future<void> Function(Map<String, dynamic> values) save,
  String saveLabel = '',
}) async =>
    await openSheet<bool>(
      context,
      scope,
      (_) => SpendForm(
        scope: scope,
        title: title,
        fields: fields,
        initial: initial,
        save: save,
        saveLabel: saveLabel,
      ),
    ) ==
    true;

class SpendForm extends StatefulWidget {
  final SpendScope scope;
  final String title, saveLabel;
  final List<SpendField> fields;
  final Map<String, dynamic> initial;
  final Future<void> Function(Map<String, dynamic>) save;
  const SpendForm({
    super.key,
    required this.scope,
    required this.title,
    required this.fields,
    required this.initial,
    required this.save,
    this.saveLabel = '',
  });
  @override
  State<SpendForm> createState() => _SpendFormState();
}

class _SpendFormState extends State<SpendForm> {
  late final values = Map<String, dynamic>.from(widget.initial);
  late final text = {
    for (final f in widget.fields)
      if (const [
        FieldKind.text,
        FieldKind.note,
        FieldKind.money,
        FieldKind.count,
      ].contains(f.kind))
        f.id: TextEditingController(text: _initialText(f)),
  };
  final errors = <String, String>{};
  bool busy = false;
  String error = '';

  String _initialText(SpendField f) {
    final v = widget.initial[f.id];
    if (v is BigInt) return '${v.isNegative ? '-' : ''}${_grouped(v.abs(), f)}';
    return v?.toString() ?? '';
  }

  String _grouped(BigInt v, SpendField f) {
    final currency = f.currency!(widget.initial);
    return editableAmount(v, currency, vi: vi);
  }

  @override
  void dispose() {
    for (final c in text.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get vi => Localizations.localeOf(context).languageCode == 'vi';

  Future<void> submit() async {
    if (busy) return;
    errors.clear();
    final out = Map<String, dynamic>.from(values);
    for (final f in widget.fields) {
      final raw = text[f.id]?.text.trim();
      try {
        switch (f.kind) {
          case FieldKind.money:
            if (raw!.isEmpty) {
              if (f.required) throw const FormatException('');
              out[f.id] = BigInt.zero;
              break;
            }
            final v = parseAmount(raw, f.currency!(out), vi: vi);
            if (v.isNegative && !f.signed)
              throw const FormatException('Positive / Dương');
            out[f.id] = v;
          case FieldKind.count:
            if (raw!.isEmpty && !f.required) {
              out[f.id] = null;
              break;
            }
            out[f.id] = int.parse(raw);
          case FieldKind.text || FieldKind.note:
            if (raw!.isEmpty && f.required) throw const FormatException('');
            out[f.id] = raw;
          case FieldKind.choice || FieldKind.date:
            if ((out[f.id] ?? '') == '' && f.required)
              throw const FormatException('');
            out[f.id] ??= '';
          case FieldKind.toggle:
            out[f.id] = out[f.id] == true;
        }
      } catch (_) {
        errors[f.id] = (raw?.isEmpty ?? true) && f.kind != FieldKind.toggle
            ? tr(context, 'Required', 'Cần điền')
            : f.kind == FieldKind.money
            ? tr(context, 'Not an amount', 'Không phải số tiền')
            : tr(context, 'Not a number', 'Không phải số');
      }
    }
    if (errors.isNotEmpty) {
      setState(
        () => error = tr(
          context,
          'Check the marked fields.',
          'Kiểm tra các ô được đánh dấu.',
        ),
      );
      return;
    }
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await widget.save(out);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(
          () => error = tr(
            context,
            'Not saved: ${errorText(context, e)}. Nothing changed.',
            'Chưa lưu: ${errorText(context, e)}. Không có gì thay đổi.',
          ),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SheetFrame(
    title: widget.title,
    busy: busy,
    error: error,
    primary: FilledButton(
      key: const Key('editor-save'),
      onPressed: busy ? null : submit,
      child: Text(
        busy
            ? tr(context, 'Saving…', 'Đang lưu…')
            : widget.saveLabel.isEmpty
            ? tr(context, 'Save', 'Lưu')
            : widget.saveLabel,
      ),
    ),
    children: [for (final f in widget.fields) _field(f)],
  );

  Widget _field(SpendField f) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final label = tr(context, f.en, f.vi);
    final help = f.helpEn == null ? null : tr(context, f.helpEn!, f.helpVi!);
    if (f.kind == FieldKind.toggle) {
      return Padding(
        padding: const EdgeInsets.only(bottom: HandySpace.s),
        child: SwitchListTile.adaptive(
          key: Key('field-${f.id}'),
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: help == null ? null : Text(help),
          value: values[f.id] == true,
          onChanged: busy ? null : (v) => setState(() => values[f.id] = v),
        ),
      );
    }
    final Widget control = switch (f.kind) {
      FieldKind.choice when f.options!.length <= 6 => Wrap(
        spacing: HandySpace.s,
        runSpacing: HandySpace.s,
        children: [
          for (final o in f.options!.entries)
            ChoiceChip(
              key: Key('field-${f.id}-${o.key}'),
              label: Text(o.value),
              selected: values[f.id] == o.key,
              onSelected: busy
                  ? null
                  : (_) => setState(() => values[f.id] = o.key),
            ),
        ],
      ),
      FieldKind.choice => DropdownButtonFormField<String>(
        key: Key('field-${f.id}'),
        initialValue: f.options!.containsKey(values[f.id])
            ? values[f.id] as String
            : null,
        isExpanded: true,
        items: [
          for (final o in f.options!.entries)
            DropdownMenuItem(
              value: o.key,
              child: Text(o.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: busy ? null : (v) => setState(() => values[f.id] = v),
      ),
      FieldKind.date => Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          key: Key('field-${f.id}'),
          onPressed: busy
              ? null
              : () async {
                  final picked = await pickHandyDate(
                    context,
                    values[f.id] as String? ?? widget.scope.today,
                  );
                  if (picked != null) setState(() => values[f.id] = picked);
                },
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text(
            (values[f.id] as String? ?? '').isEmpty
                ? tr(context, 'Choose a date', 'Chọn ngày')
                : dayLabel(context, widget.scope, values[f.id] as String),
          ),
        ),
      ),
      _ => TextField(
        key: Key('field-${f.id}'),
        controller: text[f.id],
        enabled: !busy,
        keyboardType: switch (f.kind) {
          FieldKind.money => TextInputType.numberWithOptions(
            decimal: true,
            signed: f.signed,
          ),
          FieldKind.count => TextInputType.number,
          _ => TextInputType.text,
        },
        onChanged: f.live == null ? null : (_) => setState(() {}),
        maxLines: f.kind == FieldKind.note ? 3 : 1,
        maxLength: f.kind == FieldKind.note ? 8192 : 1024,
        textInputAction: f.kind == FieldKind.note
            ? TextInputAction.newline
            : TextInputAction.next,
        style: f.kind == FieldKind.money
            ? theme.textTheme.titleMedium?.copyWith(fontFeatures: tabular)
            : null,
        decoration: InputDecoration(
          counterText: '',
          errorText: errors[f.id],
          suffixText: f.kind == FieldKind.money
              ? currencyUnit(f.currency!(values))
              : null,
        ),
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: HandySpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: HandySpace.s),
          control,
          if (f.suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: HandySpace.s),
              child: Wrap(
                spacing: HandySpace.s,
                runSpacing: HandySpace.xs,
                children: [
                  for (final s in f.suggestions.take(6))
                    ActionChip(
                      label: Text(s),
                      onPressed: busy ? null : () => text[f.id]!.text = s,
                    ),
                ],
              ),
            ),
          if (help != null)
            Padding(
              padding: const EdgeInsets.only(top: HandySpace.xs),
              child: Text(
                help,
                style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
              ),
            ),
          if (f.live != null) f.live!(context, text[f.id]?.text ?? ''),
          if (errors[f.id] != null && f.kind == FieldKind.choice)
            Text(
              errors[f.id]!,
              style: theme.textTheme.bodySmall?.copyWith(color: c.negative),
            ),
        ],
      ),
    );
  }
}
