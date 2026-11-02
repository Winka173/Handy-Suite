import 'package:flutter/services.dart';
import 'package:handy_card_engine/handy_card_engine.dart';
import 'package:handy_ui/kit.dart';
import 'paint.dart';

/// A number typed exactly; it applies on Enter or when focus leaves, and the
/// arrow keys step it (Shift for ten steps).
class NumberField extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double step, min, max;
  final int decimals;
  final String? unit;
  const NumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.step = 1,
    this.min = -100000,
    this.max = 100000,
    this.decimals = 1,
    this.unit,
  });
  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  late final text = TextEditingController(text: _format(widget.value));
  final focus = FocusNode();
  String _format(double v) {
    final s = v.toStringAsFixed(widget.decimals);
    return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  }

  @override
  void initState() {
    super.initState();
    focus.addListener(() {
      if (!focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(NumberField old) {
    super.didUpdateWidget(old);
    if (!focus.hasFocus && old.value != widget.value)
      text.text = _format(widget.value);
  }

  @override
  void dispose() {
    text.dispose();
    focus.dispose();
    super.dispose();
  }

  void _commit() {
    final v = double.tryParse(text.text.replaceAll(',', '.'));
    if (v == null || !v.isFinite) {
      text.text = _format(widget.value);
      return;
    }
    final clamped = v.clamp(widget.min, widget.max).toDouble();
    if ((clamped - widget.value).abs() > 1e-9) widget.onChanged(clamped);
    text.text = _format(clamped);
  }

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: (_, e) {
      if (e is! KeyDownEvent && e is! KeyRepeatEvent)
        return KeyEventResult.ignored;
      final dir = e.logicalKey == LogicalKeyboardKey.arrowUp
          ? 1
          : e.logicalKey == LogicalKeyboardKey.arrowDown
          ? -1
          : 0;
      if (dir == 0) return KeyEventResult.ignored;
      final step =
          widget.step * (HardwareKeyboard.instance.isShiftPressed ? 10 : 1);
      final v = (widget.value + dir * step)
          .clamp(widget.min, widget.max)
          .toDouble();
      widget.onChanged(v);
      text.text = _format(v);
      return KeyEventResult.handled;
    },
    child: TextField(
      controller: text,
      focusNode: focus,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      textAlign: TextAlign.end,
      style: const TextStyle(fontFeatures: tabular),
      onSubmitted: (_) => _commit(),
      decoration: InputDecoration(
        labelText: widget.label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixText: widget.unit,
        isDense: true,
      ),
    ),
  );
}

/// A row of two or three fields sharing the width.
class FieldRow extends StatelessWidget {
  final List<Widget> children;
  const FieldRow(this.children, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: HandySpace.s),
    child: Row(
      children: [
        for (final (i, c) in children.indexed) ...[
          if (i > 0) const SizedBox(width: HandySpace.s),
          Expanded(child: c),
        ],
      ],
    ),
  );
}

/// Swatches drawn from print-safe neutrals and a few clear hues; any hex
/// can be typed. Picks null ("none") when [allowNone].
const _swatches = [
  'FFFFFF',
  'F2F4F7',
  'C9CED6',
  '8A929C',
  '4A5059',
  '111111',
  'FBF8F2',
  'E8D9BF',
  'A88B5A',
  '6B5A3A',
  '1E1B16',
  'FFF7ED',
  'C2410C',
  'B42318',
  'C2255C',
  '0B3D2E',
  '1F7A5A',
  '2E7D32',
  '0E7490',
  '0284C7',
  '1450F5',
  '1D5FBF',
  '4D7C0F',
  'B7791F',
];

class ColorField extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool allowNone;
  const ColorField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowNone = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: HandySpace.s),
      child: InkWell(
        borderRadius: BorderRadius.circular(HandyRadius.control),
        onTap: () async {
          final picked = await showDialog<(String?,)>(
            context: context,
            builder: (context) =>
                _ColorDialog(value: value, allowNone: allowNone),
          );
          if (picked != null) onChanged(picked.$1);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: HandySpace.m),
          decoration: BoxDecoration(
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(HandyRadius.control),
          ),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                value == null ? tr(context, 'None', 'Không') : '#$value',
                style: TextStyle(color: c.muted, fontFeatures: tabular),
              ),
              const SizedBox(width: HandySpace.s),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: value == null ? null : hexColor(value!),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: c.control),
                ),
                child: value == null
                    ? Icon(Icons.block, size: 14, color: c.muted)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorDialog extends StatefulWidget {
  final String? value;
  final bool allowNone;
  const _ColorDialog({required this.value, required this.allowNone});
  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late final hex = TextEditingController(text: widget.value ?? '');
  String? error;
  @override
  void dispose() {
    hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(tr(context, 'Colour', 'Màu')),
    content: SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in _swatches)
                Semantics(
                  label: '#$s',
                  button: true,
                  selected: s == widget.value,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, (s,)),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: hexColor(s),
                        border: Border.all(
                          color: s == widget.value
                              ? Theme.of(context).colorScheme.onSurface
                              : HandyColors.of(context).border,
                          width: s == widget.value ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: HandySpace.m),
          TextField(
            controller: hex,
            decoration: InputDecoration(
              prefixText: '#',
              hintText: 'RRGGBB',
              errorText: error,
            ),
            onSubmitted: (_) => _apply(),
          ),
        ],
      ),
    ),
    actions: [
      if (widget.allowNone)
        TextButton(
          onPressed: () => Navigator.pop(context, (null,)),
          child: Text(tr(context, 'None', 'Không')),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr(context, 'Cancel', 'Hủy')),
      ),
      FilledButton(onPressed: _apply, child: Text(tr(context, 'Use', 'Dùng'))),
    ],
  );

  void _apply() {
    try {
      Navigator.pop(context, (
        cardColor(hex.text.trim().replaceFirst('#', '')),
      ));
    } on FormatException {
      setState(
        () => error = tr(
          context,
          'Six hex digits, like 1450F5',
          'Sáu chữ số hex, ví dụ 1450F5',
        ),
      );
    }
  }
}

/// A labelled dropdown with string values.
class ChoiceField extends StatelessWidget {
  final String label, value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  const ChoiceField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: HandySpace.s),
    child: DropdownButtonFormField<String>(
      initialValue: options.containsKey(value) ? value : options.keys.first,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      items: [
        for (final e in options.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text(e.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    ),
  );
}

/// A slider with its value shown, for properties that are felt rather
/// than typed (opacity, crop).
class SliderRow extends StatelessWidget {
  final String label, shown;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  const SliderRow({
    super.key,
    required this.label,
    required this.shown,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 84, child: Text(label)),
      Expanded(
        child: Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          semanticFormatterCallback: (_) => shown,
          onChanged: onChanged,
        ),
      ),
      SizedBox(
        width: 44,
        child: Text(
          shown,
          textAlign: TextAlign.end,
          style: const TextStyle(fontFeatures: tabular),
        ),
      ),
    ],
  );
}
