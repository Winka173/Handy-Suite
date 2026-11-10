import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import 'sheet.dart';
import 'words.dart';

enum FieldKind {
  text,
  note,
  amount,
  count,
  date,
  time,
  choice,
  toggle,
  weekdays,

  /// Several of [HabitField.options], as a list of their keys.
  many,
}

/// One input of a [HabitForm]. Labels sit above their field; [help] says
/// what the field accepts.
class HabitField {
  final String id, en, vi;
  final FieldKind kind;
  final Map<String, String>? options;
  final bool required;
  final bool advanced;
  final Set<String> advancedOptions;
  final String? helpEn, helpVi;

  /// Shows the field only while this holds for the values typed so far.
  final bool Function(Map<String, dynamic> values)? when;
  const HabitField(
    this.id,
    this.en,
    this.vi, {
    this.kind = FieldKind.text,
    this.options,
    this.required = true,
    this.advanced = false,
    this.advancedOptions = const {},
    this.helpEn,
    this.helpVi,
    this.when,
  });
}

/// Opens a form. Amounts arrive as engine thousandths (int), counts as
/// int, weekdays as a sorted list, times as `HH:mm`, dates as
/// `YYYY-MM-DD`. A failed save keeps the form. True when saved.
Future<bool> showHabitForm(
  BuildContext context, {
  required String title,
  required List<HabitField> fields,
  required Map<String, dynamic> initial,
  required Future<void> Function(Map<String, dynamic> values) save,
  String saveLabel = '',
}) async =>
    await openSheet<bool>(
      context,
      (_) => HabitForm(
        title: title,
        fields: fields,
        initial: initial,
        save: save,
        saveLabel: saveLabel,
      ),
    ) ==
    true;

class HabitForm extends StatefulWidget {
  final String title, saveLabel;
  final List<HabitField> fields;
  final Map<String, dynamic> initial;
  final Future<void> Function(Map<String, dynamic>) save;
  const HabitForm({
    super.key,
    required this.title,
    required this.fields,
    required this.initial,
    required this.save,
    this.saveLabel = '',
  });
  @override
  State<HabitForm> createState() => _HabitFormState();
}

class _HabitFormState extends State<HabitForm> {
  late final values = Map<String, dynamic>.from(widget.initial);
  late final text = {
    for (final f in widget.fields)
      if (const [
        FieldKind.text,
        FieldKind.note,
        FieldKind.amount,
        FieldKind.count,
      ].contains(f.kind))
        f.id: TextEditingController(text: _initial(f)),
  };
  final errors = <String, String>{};
  bool busy = false, advanced = false;
  String error = '';

  String _initial(HabitField f) {
    final v = widget.initial[f.id];
    if (v == null) return '';
    if (f.kind == FieldKind.amount && v is int) return figure(context, v);
    return '$v';
  }

  @override
  void dispose() {
    for (final c in text.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool shown(HabitField f) => f.when?.call(values) ?? true;

  Future<void> submit() async {
    if (busy) return;
    errors.clear();
    final out = Map<String, dynamic>.from(values);
    for (final f in widget.fields) {
      final raw = text[f.id]?.text.trim();
      if (!shown(f)) continue;
      try {
        switch (f.kind) {
          case FieldKind.amount:
            if (raw!.isEmpty) {
              if (f.required) throw const FormatException('');
              out[f.id] = 0;
              break;
            }
            out[f.id] = quantity(raw.replaceAll(',', '.'));
          case FieldKind.count:
            if (raw!.isEmpty && !f.required) {
              out[f.id] = null;
              break;
            }
            out[f.id] = int.parse(raw);
          case FieldKind.text || FieldKind.note:
            if (raw!.isEmpty && f.required) throw const FormatException('');
            out[f.id] = raw;
          case FieldKind.many:
            final keys = List<String>.from(out[f.id] as List? ?? []);
            if (keys.isEmpty && f.required) throw const FormatException('');
            out[f.id] = keys;
          case FieldKind.weekdays:
            final days = List<int>.from(out[f.id] as List? ?? [])..sort();
            if (days.isEmpty && f.required) throw const FormatException('');
            out[f.id] = days;
          case FieldKind.choice || FieldKind.date || FieldKind.time:
            if ((out[f.id] ?? '') == '' && f.required)
              throw const FormatException('');
            out[f.id] ??= '';
          case FieldKind.toggle:
            out[f.id] = out[f.id] == true;
        }
      } catch (_) {
        errors[f.id] =
            (raw?.isEmpty ?? false) ||
                f.kind == FieldKind.weekdays ||
                f.kind == FieldKind.many
            ? tr(context, 'Required', 'Cần điền')
            : tr(context, 'Not a number', 'Không phải số');
      }
    }
    if (errors.isNotEmpty) {
      if (widget.fields.any((f) => f.advanced && errors.containsKey(f.id))) {
        advanced = true;
      }
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
    children: [
      for (final f in widget.fields)
        if (!f.advanced && shown(f)) _field(f),
      if (widget.fields.any(
        (f) => f.advanced || f.advancedOptions.isNotEmpty,
      )) ...[
        SwitchListTile.adaptive(
          key: const Key('habit-form-advanced'),
          contentPadding: EdgeInsets.zero,
          title: Text(tr(context, 'Advanced settings', 'Thiết lập nâng cao')),
          subtitle: Text(
            tr(
              context,
              'Dates, grouping and less common schedules. Existing values are kept.',
              'Ngày, nhóm và lịch ít dùng. Giá trị đã lưu được giữ nguyên.',
            ),
          ),
          value: advanced,
          onChanged: busy ? null : (v) => setState(() => advanced = v),
        ),
        if (advanced)
          for (final f in widget.fields)
            if (f.advanced && shown(f)) _field(f),
      ],
    ],
  );

  Widget _field(HabitField f) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final label = tr(context, f.en, f.vi);
    final help = f.helpEn == null ? null : tr(context, f.helpEn!, f.helpVi!);
    if (f.kind == FieldKind.toggle) {
      return SwitchListTile.adaptive(
        key: Key('field-${f.id}'),
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: help == null ? null : Text(help),
        value: values[f.id] == true,
        onChanged: busy ? null : (v) => setState(() => values[f.id] = v),
      );
    }
    final Widget control = switch (f.kind) {
      FieldKind.weekdays => Wrap(
        spacing: HandySpace.xs,
        runSpacing: HandySpace.xs,
        children: [
          for (var d = 1; d <= 7; d++)
            FilterChip(
              key: Key('field-${f.id}-$d'),
              label: Text(weekdayShort(context, d)),
              tooltip: weekdayLong(context, d),
              showCheckmark: false,
              selected: (values[f.id] as List? ?? []).contains(d),
              onSelected: busy
                  ? null
                  : (on) => setState(() {
                      final days = List<int>.from(values[f.id] as List? ?? []);
                      on ? days.add(d) : days.remove(d);
                      values[f.id] = days..sort();
                    }),
            ),
        ],
      ),
      FieldKind.many => Wrap(
        spacing: HandySpace.xs,
        runSpacing: HandySpace.xs,
        children: [
          for (final o in f.options!.entries)
            FilterChip(
              key: Key('field-${f.id}-${o.key}'),
              label: Text(o.value),
              selected: (values[f.id] as List? ?? []).contains(o.key),
              onSelected: busy
                  ? null
                  : (on) => setState(() {
                      final keys = List<String>.from(
                        values[f.id] as List? ?? [],
                      );
                      on ? keys.add(o.key) : keys.remove(o.key);
                      values[f.id] = keys;
                    }),
            ),
        ],
      ),
      FieldKind.choice when f.options!.length <= 6 => Wrap(
        spacing: HandySpace.s,
        runSpacing: HandySpace.s,
        children: [
          for (final o in f.options!.entries)
            if (advanced ||
                !f.advancedOptions.contains(o.key) ||
                values[f.id] == o.key)
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
      FieldKind.date => _picker(
        f,
        Icons.calendar_today_outlined,
        (values[f.id] as String? ?? '').isEmpty
            ? tr(context, 'Choose a date', 'Chọn ngày')
            : formatDay(context, values[f.id] as String),
        () async {
          final picked = await pickHandyDate(
            context,
            values[f.id] as String? ?? '',
          );
          if (picked != null) setState(() => values[f.id] = picked);
        },
        clear: !f.required && (values[f.id] as String? ?? '').isNotEmpty,
      ),
      FieldKind.time => _picker(
        f,
        Icons.schedule,
        values[f.id] as String? ?? '08:00',
        () async {
          final now = (values[f.id] as String? ?? '08:00').split(':');
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(
              hour: int.parse(now[0]),
              minute: int.parse(now[1]),
            ),
          );
          if (picked != null)
            setState(
              () => values[f.id] =
                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
            );
        },
      ),
      _ => TextField(
        key: Key('field-${f.id}'),
        controller: text[f.id],
        enabled: !busy,
        keyboardType: switch (f.kind) {
          FieldKind.amount => const TextInputType.numberWithOptions(
            decimal: true,
          ),
          FieldKind.count => TextInputType.number,
          _ => TextInputType.text,
        },
        maxLines: f.kind == FieldKind.note ? 3 : 1,
        minLines: 1,
        maxLength: f.kind == FieldKind.note ? 4096 : 200,
        textCapitalization: f.kind == FieldKind.text
            ? TextCapitalization.sentences
            : TextCapitalization.none,
        decoration: InputDecoration(counterText: '', errorText: errors[f.id]),
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: HandySpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: theme.textTheme.titleSmall),
          const SizedBox(height: HandySpace.s),
          control,
          if (help != null)
            Padding(
              padding: const EdgeInsets.only(top: HandySpace.xs),
              child: Text(
                help,
                style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
              ),
            ),
          if (errors[f.id] != null &&
              const [
                FieldKind.choice,
                FieldKind.weekdays,
                FieldKind.many,
                FieldKind.date,
              ].contains(f.kind))
            Text(
              errors[f.id]!,
              style: theme.textTheme.bodySmall?.copyWith(color: c.negative),
            ),
        ],
      ),
    );
  }

  Widget _picker(
    HabitField f,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool clear = false,
  }) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      OutlinedButton.icon(
        key: Key('field-${f.id}'),
        onPressed: busy ? null : onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
      if (clear)
        IconButton(
          tooltip: tr(context, 'Clear', 'Bỏ'),
          onPressed: busy ? null : () => setState(() => values[f.id] = ''),
          icon: const Icon(Icons.close, size: 18),
        ),
    ],
  );
}
