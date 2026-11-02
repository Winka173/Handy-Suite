import 'package:handy_inventory/handy_inventory.dart';
import 'package:handy_ui/kit.dart';
import '../ui/words.dart';

/// What the things on screen are worth, per currency, with how many have no
/// price. [label] names the view it adds up ("Packed in 3 boxes · 7 items").
///
/// [lead] sets the figure large: in the box view (moving, insurance), a
/// single box and the loan view the value is part of the answer. On the
/// everyday list it is one quiet line under the filters.
class ValueSummary extends StatelessWidget {
  final String label;
  final KeepValue value;
  final bool lead;
  const ValueSummary({
    super.key,
    required this.label,
    required this.value,
    this.lead = false,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final note = unpricedNote(context, value);
    final figure = moneyLine(context, value);
    if (!lead) {
      return Padding(
        padding: const EdgeInsets.only(top: HandySpace.m),
        child: Text.rich(
          key: const Key('keep-value'),
          TextSpan(
            children: [
              TextSpan(text: '$label  '),
              TextSpan(
                text: figure,
                style: TextStyle(
                  color: value.hasPrices ? theme.colorScheme.onSurface : null,
                  fontFeatures: tabular,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (note.isNotEmpty) TextSpan(text: ' · $note'),
            ],
          ),
          style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
        ),
      );
    }
    return Semantics(
      container: true,
      label: [label, figure, note].where((s) => s.isNotEmpty).join(', '),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(top: HandySpace.l),
          child: Column(
            key: const Key('keep-value'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
              ),
              const SizedBox(height: HandySpace.xs),
              Text(
                figure,
                key: const Key('keep-value-figure'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontFeatures: tabular,
                  color: value.hasPrices ? null : c.muted,
                ),
              ),
              if (note.isNotEmpty)
                Text(
                  note,
                  key: const Key('keep-value-unpriced'),
                  style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A place's value under its heading: "4,250,000 đ · 2 without a price".
class PlaceValue extends StatelessWidget {
  final KeepValue value;
  const PlaceValue(this.value, {super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final note = unpricedNote(context, value);
    return Text.rich(
      TextSpan(
        children: [
          if (value.hasPrices)
            TextSpan(
              text: moneyLine(context, value),
              style: theme.textTheme.bodyLarge?.copyWith(fontFeatures: tabular),
            ),
          if (value.hasPrices && note.isNotEmpty) const TextSpan(text: ' · '),
          if (note.isNotEmpty) TextSpan(text: note),
        ],
      ),
      style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
    );
  }
}
