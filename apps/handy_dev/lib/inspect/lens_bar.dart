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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: c.muted);
    final chosen = lenses[lens];
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
        if (chosen.option != null)
          HandyField(
            label:
                chosen.option!.label(context) +
                (chosen.option!.optional
                    ? tr(context, ' (optional)', ' (không bắt buộc)')
                    : ''),
            child: TextField(
              key: const Key('lens-option'),
              controller: option,
              minLines: chosen.option!.multiline ? 3 : 1,
              maxLines: chosen.option!.multiline ? 8 : 1,
              onChanged: (_) => onOption(),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'GeistMono',
                package: 'handy_ui',
              ),
              decoration: InputDecoration(hintText: chosen.option!.hint),
            ),
          ),
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
