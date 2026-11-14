import 'package:handy_ui/kit.dart';
import '../design/theme.dart';

/// Rows or cards, beside a list's heading: two icon buttons in one frame,
/// the chosen one filled. [cards] null means neither (a Pro layout is on);
/// either button then leaves it.
class ViewToggle extends StatelessWidget {
  final bool? cards;
  final ValueChanged<bool> onChanged;
  const ViewToggle({super.key, required this.cards, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget side(bool asCards) {
      final on = cards == asCards;
      final label = asCards
          ? tr(context, 'Show as cards', 'Xem dạng lưới')
          : tr(context, 'Show as rows', 'Xem dạng danh sách');
      return Semantics(
        button: true,
        selected: on,
        label: label,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: InkWell(
            key: Key(asCards ? 'view-cards' : 'view-rows'),
            onTap: on ? null : () => onChanged(asCards),
            borderRadius: BorderRadius.circular(BookmarkRadii.thumb),
            // 48 to touch; the filled pill inside is the 36 the eye sees.
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Container(
                  width: 40,
                  height: 36,
                  decoration: BoxDecoration(
                    color: on ? p.tint : Colors.transparent,
                    borderRadius: BorderRadius.circular(BookmarkRadii.thumb),
                  ),
                  child: Icon(
                    asCards ? Icons.grid_view_rounded : Icons.view_list_rounded,
                    size: 20,
                    color: on ? (dark ? p.ink : p.pressed) : p.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      key: const Key('view-toggle'),
      decoration: BoxDecoration(
        border: Border.all(color: p.control),
        borderRadius: BorderRadius.circular(BookmarkRadii.item),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [side(false), side(true)],
      ),
    );
  }
}
