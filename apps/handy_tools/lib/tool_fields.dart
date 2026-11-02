import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import 'specs.dart';

/// One input of a tool form, rendered by its type. Text-like fields own a
/// controller; choices and dates report through [onChanged].
class ToolField extends StatelessWidget {
  final FieldSpec spec;
  final TextEditingController? controller;
  final String value;
  final Map<String, String> values;
  final ValueChanged<String> onChanged;
  final VoidCallback? onPaste;
  final bool enabled;
  const ToolField({
    super.key,
    required this.spec,
    required this.value,
    required this.values,
    required this.onChanged,
    this.controller,
    this.onPaste,
    this.enabled = true,
  });

  Widget text(BuildContext context, {TextInputType? keyboard, Widget? prefix}) {
    final long = spec.type == FieldType.longText;
    return TextField(
      key: Key('field-${spec.id}'),
      controller: controller,
      enabled: enabled,
      keyboardType: keyboard,
      minLines: long ? 6 : 1,
      maxLines: long ? 14 : 1,
      maxLength: spec.type == FieldType.color ? 7 : null,
      inputFormatters: switch (spec.type) {
        FieldType.integer => [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
        ],
        FieldType.decimal => [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,eE+-]')),
        ],
        _ => null,
      },
      onChanged: (v) => onChanged(
        spec.type == FieldType.decimal ? v.replaceAll(',', '.') : v,
      ),
      style: spec.type == FieldType.decimal || spec.type == FieldType.integer
          ? const TextStyle(fontFeatures: tabular)
          : null,
      decoration: InputDecoration(
        hintText: (spec.hintOf?.call(values) ?? spec.hint).isEmpty
            ? (long
                  ? tr(context, 'Paste or type text', 'Dán hoặc nhập văn bản')
                  : null)
            : spec.hintOf?.call(values) ?? spec.hint,
        counterText: '',
        prefixIcon: prefix,
      ),
    );
  }

  Future<void> pickDate(BuildContext context) async {
    final picked = await pickHandyDate(context, value);
    if (picked != null) onChanged(picked);
  }

  Widget choice(BuildContext context, List<Choice> options) {
    if (spec.segmented && options.length > 3)
      // Four or more joined buttons squeeze their words on a phone; below
      // about 88px a segment, the same choices become a row of chips.
      return LayoutBuilder(
        builder: (context, box) => box.maxWidth >= options.length * 88
            ? SegmentedButton<String>(
                key: Key('field-${spec.id}'),
                showSelectedIcon: false,
                segments: [
                  for (final o in options)
                    ButtonSegment(
                      value: o.$1,
                      label: Text(tr(context, o.$2, o.$3)),
                    ),
                ],
                selected: {value},
                onSelectionChanged: enabled ? (s) => onChanged(s.first) : null,
              )
            : Wrap(
                key: Key('field-${spec.id}'),
                spacing: HandySpace.s,
                runSpacing: HandySpace.s,
                children: [
                  for (final o in options)
                    ChoiceChip(
                      label: Text(tr(context, o.$2, o.$3)),
                      selected: value == o.$1,
                      onSelected: enabled ? (_) => onChanged(o.$1) : null,
                    ),
                ],
              ),
      );
    if (options.length <= 3)
      return SegmentedButton<String>(
        key: Key('field-${spec.id}'),
        showSelectedIcon: false,
        segments: [
          for (final o in options)
            ButtonSegment(value: o.$1, label: Text(tr(context, o.$2, o.$3))),
        ],
        selected: {value},
        onSelectionChanged: enabled ? (s) => onChanged(s.first) : null,
      );
    return DropdownButtonFormField<String>(
      key: Key('field-${spec.id}-$value'),
      initialValue: options.any((o) => o.$1 == value) ? value : null,
      isExpanded: true,
      items: [
        for (final o in options)
          DropdownMenuItem(value: o.$1, child: Text(tr(context, o.$2, o.$3))),
      ],
      onChanged: enabled ? (v) => onChanged(v!) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final input = switch (spec.type) {
      FieldType.decimal => text(
        context,
        keyboard: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
      ),
      FieldType.integer => text(context, keyboard: TextInputType.number),
      FieldType.text => text(context),
      FieldType.longText => text(context, keyboard: TextInputType.multiline),
      FieldType.color => text(
        context,
        prefix: Padding(
          padding: const EdgeInsets.all(10),
          child: _Swatch(value),
        ),
      ),
      FieldType.date => InkWell(
        key: Key('field-${spec.id}'),
        borderRadius: BorderRadius.circular(HandyRadius.control),
        onTap: enabled ? () => pickDate(context) : null,
        child: InputDecorator(
          decoration: const InputDecoration(
            suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
          ),
          child: Text(
            value.isEmpty ? tr(context, 'Choose a date', 'Chọn ngày') : value,
            style: TextStyle(
              fontFeatures: tabular,
              color: value.isEmpty ? HandyColors.of(context).muted : null,
            ),
          ),
        ),
      ),
      FieldType.choice => choice(context, spec.choices!(values)),
    };
    final label =
        spec.label(context) +
        (spec.optional ? tr(context, ' (optional)', ' (không bắt buộc)') : '');
    if (onPaste == null) return HandyField(label: label, child: input);
    return Padding(
      padding: const EdgeInsets.only(bottom: HandySpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton.icon(
                key: const Key('paste'),
                onPressed: enabled ? onPaste : null,
                icon: const Icon(Icons.content_paste, size: 16),
                label: Text(tr(context, 'Paste', 'Dán')),
              ),
            ],
          ),
          const SizedBox(height: HandySpace.xs),
          input,
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final String hex;
  const _Swatch(this.hex);
  @override
  Widget build(BuildContext context) {
    final ok = RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex);
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: ok ? Color(int.parse('FF${hex.substring(1)}', radix: 16)) : null,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: HandyColors.of(context).control),
      ),
    );
  }
}
