import 'package:handy_ui/kit.dart';
import 'detect.dart';
import 'lenses.dart';

/// How the payload was read, the lenses for that reading, and the one
/// option the chosen lens needs.
class LensBar extends StatelessWidget {
  final List<DataKind> kinds;
  final int kind;
  final List<Lens> lenses;
  final int lens;
  final TextEditingController option;
  final ValueChanged<int> onKind, onLens;
  final VoidCallback onOption;

  /// Chosen settings of the lens, by setting id.
  final Map<String, String> picks;
  final void Function(String id, String value) onPick;
  const LensBar({
    super.key,
    required this.kinds,
    required this.kind,
    required this.lenses,
    required this.lens,
    required this.option,
    required this.onKind,
    required this.onLens,
    required this.onOption,
    this.picks = const {},
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: c.muted);
    final chosen = lenses[lens];
    final o = chosen.option;
    final field = o == null
        ? null
        : HandyField(
            label:
                o.label(context) +
                (o.optional
                    ? tr(context, ' (optional)', ' (không bắt buộc)')
                    : ''),
            child: o.secret
                ? SecretField(controller: option, onChanged: onOption)
                : TextField(
                    key: const Key('lens-option'),
                    controller: option,
                    minLines: o.multiline ? 3 : 1,
                    maxLines: o.multiline ? 8 : 1,
                    onChanged: (_) => onOption(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'GeistMono',
                      package: 'handy_ui',
                    ),
                    decoration: InputDecoration(hintText: o.hint),
                  ),
          );
    // Phones get one sideways-scrolling line per row so the result stays
    // close to the source; wider screens wrap.
    final narrow = MediaQuery.sizeOf(context).width < 600;
    Widget row(String label, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(bottom: HandySpace.m),
      child: narrow
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(label, style: muted),
                  for (final c in chips)
                    Padding(
                      padding: const EdgeInsets.only(left: HandySpace.s),
                      child: c,
                    ),
                ],
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 104,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(label, style: muted),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: HandySpace.s,
                    runSpacing: HandySpace.s,
                    children: chips,
                  ),
                ),
              ],
            ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kinds.length > 1)
          row(tr(context, 'Read as', 'Hiểu là'), [
            for (var i = 0; i < kinds.length; i++)
              ChoiceChip(
                key: Key('kind-${kinds[i].name}'),
                label: Text(kindLabel(context, kinds[i])),
                selected: i == kind,
                onSelected: (_) => onKind(i),
              ),
          ]),
        for (final g in LensGroup.values)
          if (lenses.any((l) => lensGroup(l) == g))
            row(lensGroupLabel(context, g), [
              for (var i = 0; i < lenses.length; i++)
                if (lensGroup(lenses[i]) == g)
                  ChoiceChip(
                    key: Key('lens-${lenses[i].id}'),
                    avatar: lenses[i].sensitive
                        ? const Icon(Icons.lock_outline, size: 16)
                        : null,
                    label: Text(lenses[i].title(context)),
                    selected: i == lens,
                    onSelected: (_) => onLens(i),
                  ),
            ]),
        // A required option (the HMAC key) comes before the settings; an
        // optional one (another offset) after them.
        if (field != null && !chosen.option!.optional) field,
        for (final choice in chosen.choices)
          row(choice.label(context), [
            for (final (value, en, vi) in choice.values)
              ChoiceChip(
                key: Key('pick-${choice.id}-$value'),
                label: Text(tr(context, en, vi)),
                selected: chosen.pick(picks, choice.id) == value,
                onSelected: (_) => onPick(choice.id, value),
              ),
          ]),
        if (field != null && chosen.option!.optional) field,
        if (chosen.sensitive)
          Padding(
            padding: const EdgeInsets.only(bottom: HandySpace.m),
            child: HandyNotice(
              tr(
                context,
                'Sensitive: shown here only. Never saved as a draft or a step.',
                'Nhạy cảm: chỉ hiện ở đây. Không bao giờ lưu nháp hay thành bước.',
              ),
              tone: HandyTone.warning,
            ),
          ),
      ],
    );
  }
}

/// A key field: hidden while typed, no keyboard learning, with a show
/// toggle. What is typed lives only in the controller for this session.
class SecretField extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onChanged;
  const SecretField({
    super.key,
    required this.controller,
    required this.onChanged,
  });
  @override
  State<SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<SecretField> {
  bool shown = false;
  @override
  Widget build(BuildContext context) => TextField(
    key: const Key('lens-option'),
    controller: widget.controller,
    obscureText: !shown,
    autocorrect: false,
    enableSuggestions: false,
    enableIMEPersonalizedLearning: false,
    keyboardType: TextInputType.visiblePassword,
    autofillHints: null,
    onChanged: (_) => widget.onChanged(),
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontFamily: 'GeistMono',
      package: 'handy_ui',
    ),
    decoration: InputDecoration(
      suffixIcon: IconButton(
        key: const Key('secret-show'),
        tooltip: shown
            ? tr(context, 'Hide key', 'Ẩn khóa')
            : tr(context, 'Show key', 'Hiện khóa'),
        icon: Icon(
          shown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
        ),
        onPressed: () => setState(() => shown = !shown),
      ),
    ),
  );
}
