import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../ui/look.dart';

/// The category strip: every category of the board as a block (its colour,
/// name, "done/total" across all columns and a thin bar), which is both the
/// overview and the filter. Phones fit four as a 2×2; more scroll sideways.
///
/// [selected] is a category id, [uncategorisedKey] for Uncategorised, or
/// null for all cards.
class CategoryStrip extends StatelessWidget {
  static const uncategorisedKey = '';
  final BoardsState state;
  final String board;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final VoidCallback? onEdit;

  /// Controls beside the strip's heading (the board's quick filters).
  final List<Widget> trailing;
  const CategoryStrip({
    super.key,
    required this.state,
    required this.board,
    required this.selected,
    required this.onSelect,
    this.onEdit,
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    final blocks = categoryProgress(state, board);
    final p = BoardsPalette.of(context);
    if (blocks.isEmpty) {
      if (onEdit == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('strip-add-category'),
            onPressed: onEdit,
            icon: const Icon(Icons.add),
            label: Text(tr(context, 'Add a category', 'Thêm nhóm')),
          ),
        ),
      );
    }
    Widget block(CategoryProgress b, {double? width}) {
      final key = b.category?.id ?? uncategorisedKey;
      return SizedBox(
        width: width,
        child: _Block(
          progress: b,
          selected: selected == key,
          onTap: () => onSelect(selected == key ? null : key),
        ),
      );
    }

    final theme = Theme.of(context);
    // The heading on the left, the quick filters and Edit on the right;
    // on a narrow screen with large text the controls drop to a second line.
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          Semantics(
            header: true,
            child: Text(
              tr(context, 'Categories', 'Nhóm'),
              style: theme.textTheme.titleSmall?.copyWith(color: p.muted),
            ),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              ...trailing,
              if (onEdit != null)
                TextButton(
                  key: const Key('strip-edit'),
                  onPressed: onEdit,
                  child: Text(tr(context, 'Edit', 'Sửa')),
                ),
            ],
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final phone = box.maxWidth < 600;
        // Up to four fit a phone as a 2×2; more, or large text, scroll
        // sideways so the board keeps its height.
        final grid =
            phone && blocks.length <= 4 && scale <= 1.3 && box.maxWidth >= 300;
        final body = grid
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final b in blocks)
                      block(b, width: (box.maxWidth - 32 - 8) / 2),
                  ],
                ),
              )
            : SizedBox(
                height: 84 * scale.clamp(1.0, 2.0),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: phone ? 16 : 24),
                  children: [
                    for (final b in blocks)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: block(b, width: 168 * scale.clamp(1.0, 1.4)),
                      ),
                  ],
                ),
              );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, body],
        );
      },
    );
  }
}

class _Block extends StatelessWidget {
  final CategoryProgress progress;
  final bool selected;
  final VoidCallback onTap;
  const _Block({
    required this.progress,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final theme = Theme.of(context);
    final hue = categoryHue(context, progress.category);
    final name = categoryName(context, progress.category);
    final ratio = progress.total == 0 ? 0.0 : progress.done / progress.total;
    return Semantics(
      button: true,
      selected: selected,
      label: tr(
        context,
        '$name, ${progress.done} of ${progress.total} done',
        '$name, xong ${progress.done} trên ${progress.total}',
      ),
      excludeSemantics: true,
      child: Material(
        key: Key('strip-${progress.category?.id ?? 'none'}'),
        color: selected ? p.tint : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BoardsRadii.card),
          side: selected
              ? BorderSide(color: p.primary, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(BoardsRadii.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: hue.mark,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    if (selected)
                      Icon(Icons.filter_alt, size: 16, color: p.primary),
                  ],
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${progress.done}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text:
                            '/${progress.total} ${tr(context, 'done', 'xong')}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    height: 4,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: hue.tint),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: ratio,
                          child: ColoredBox(color: hue.mark),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
