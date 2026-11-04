import 'package:handy_card_engine/handy_card_engine.dart';
import 'package:handy_ui/kit.dart';
import 'studio_controller.dart';

/// The whole design in other colours, one tap, one undo step. Only a design
/// drawn in one of the palettes can be switched; colours the person chose
/// for single elements stay as they are.
Future<void> openPalettes(BuildContext context, StudioController c) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // The card stays in view, barely dimmed, so each tap shows the result.
      barrierColor: Colors.black12,
      builder: (context) => _PaletteSheet(c),
    );

class _PaletteSheet extends StatelessWidget {
  final StudioController c;
  const _PaletteSheet(this.c);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final theme = Theme.of(context);
      final colors = HandyColors.of(context);
      final current = paletteOf(c.doc);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            HandySpace.l,
            0,
            HandySpace.l,
            HandySpace.l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  tr(context, 'Colours', 'Bảng màu'),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: HandySpace.xs),
              Text(
                current == null
                    ? tr(
                        context,
                        'This design uses colours of its own. Change them one element at a time in the inspector.',
                        'Thiết kế này dùng màu riêng. Đổi từng phần trong bảng thuộc tính.',
                      )
                    : tr(
                        context,
                        'The whole card changes; colours you picked yourself stay. Undo takes it back.',
                        'Cả thẻ đổi màu; màu bạn tự chọn giữ nguyên. Hoàn tác để trở lại.',
                      ),
                key: const Key('palette-note'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.muted,
                ),
              ),
              const SizedBox(height: HandySpace.m),
              // One row, so the sheet stays short and the card visible.
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: cardPalettes.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: HandySpace.s),
                  itemBuilder: (context, i) {
                    final p = cardPalettes[i];
                    return _Swatch(
                      palette: p,
                      selected: p.id == current?.id,
                      onTap: current == null || p.id == current.id
                          ? null
                          : () => c.editDoc(
                              'Colours',
                              (d) => recolorDocument(d, p) ?? d,
                            ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// A palette as its ground with the accent and ink on it, and its name.
class _Swatch extends StatelessWidget {
  final CardPalette palette;
  final bool selected;
  final VoidCallback? onTap;
  const _Swatch({required this.palette, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    Color hex(String h) => Color(colorValue(h));
    final colors = HandyColors.of(context);
    final name = tr(context, palette.en, palette.vi);
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null || selected,
      label: name,
      excludeSemantics: true,
      child: InkWell(
        key: Key('palette-${palette.id}'),
        borderRadius: BorderRadius.circular(HandyRadius.control),
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null && !selected ? .45 : 1,
          child: Container(
            width: 104,
            padding: const EdgeInsets.all(HandySpace.s),
            decoration: BoxDecoration(
              color: hex(palette.bg),
              borderRadius: BorderRadius.circular(HandyRadius.control),
              border: Border.all(
                color: selected ? colors.accent : colors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (final h in [
                      palette.accent,
                      palette.ink,
                      palette.muted,
                    ])
                      Container(
                        width: 16,
                        height: 16,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: hex(h),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: HandySpace.s),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: hex(palette.ink)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
