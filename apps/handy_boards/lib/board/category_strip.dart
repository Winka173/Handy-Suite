import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../ui/look.dart';

/// The category strip: every category of the board as a block (its colour,
/// name, "done/total" across all columns and a thin bar), which is both the
/// overview and the filter. Phones fit four as a 2×2; more scroll sideways.
///
/// [selected] holds the picked category ids ([uncategorisedKey] for
/// Uncategorised); empty shows every card. A tap adds or removes one.
class CategoryStrip extends StatelessWidget {
  static const uncategorisedKey = '';
  final BoardsState state;
  final String board;
  final Set<String> selected;
  final ValueChanged<String> onSelect;
  final VoidCallback? onEdit;

  /// Controls beside the strip's heading (the board's quick filters).
  final List<Widget> trailing;

  /// The "Categories" heading row; the board page keeps its controls in
  /// the Filter sheet and shows the tiles alone.
  final bool showHeader;
  const CategoryStrip({
    super.key,
    required this.state,
    required this.board,
    required this.selected,
    required this.onSelect,
    this.onEdit,
    this.trailing = const [],
    this.showHeader = true,
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
          selected: selected.contains(key),
          dimmed: selected.isNotEmpty && !selected.contains(key),
          onTap: () => onSelect(key),
        ),
      );
    }

    final theme = Theme.of(context);
    final heading = Semantics(
      header: true,
      child: Text(
        tr(context, 'Categories', 'Nhóm'),
        style: theme.textTheme.titleSmall?.copyWith(color: p.muted),
      ),
    );
    final edit = onEdit == null
        ? null
        : TextButton(
            key: const Key('strip-edit'),
            onPressed: onEdit,
            child: Text(tr(context, 'Edit', 'Sửa')),
          );
    // Wide: the heading, then the quick filters and Edit at the right, on
    // one line. Phone: the heading with Edit at the right, the quick
    // filters on their own row from the page margin, scrolling sideways.
    Widget header(bool phone) => phone
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
                child: Row(
                  children: [
                    Expanded(child: heading),
                    ?edit,
                  ],
                ),
              ),
              if (trailing.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      for (final (k, w) in trailing.indexed) ...[
                        if (k > 0) const SizedBox(width: 6),
                        w,
                      ],
                    ],
                  ),
                ),
            ],
          )
        : Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 16, 0),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                heading,
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [...trailing, ?edit],
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
        final side = phone ? 16.0 : 24.0;
        final Widget body;
        if (grid) {
          body = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final b in blocks)
                  block(b, width: (box.maxWidth - 32 - 10) / 2),
              ],
            ),
          );
        } else if (!phone && blocks.length <= 4 && scale <= 1.3) {
          body = Padding(
            padding: EdgeInsets.symmetric(horizontal: side),
            child: Row(
              children: [
                for (final (k, b) in blocks.indexed) ...[
                  if (k > 0) const SizedBox(width: 12),
                  Expanded(child: block(b)),
                ],
                // Fewer than four keep a tile's width, not the row's.
                for (var k = blocks.length; k < 4; k++) ...[
                  const SizedBox(width: 12),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ],
            ),
          );
        } else {
          body = SizedBox(
            height: 92 * scale.clamp(1.0, 2.0),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: side),
              children: [
                for (final b in blocks)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: block(b, width: 172 * scale.clamp(1.0, 1.4)),
                  ),
              ],
            ),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [if (showHeader) header(phone), body],
        );
      },
    );
  }
}

class _Block extends StatelessWidget {
  final CategoryProgress progress;
  final bool selected;

  /// Another category is picked: this one steps back.
  final bool dimmed;
  final VoidCallback onTap;
  const _Block({
    required this.progress,
    required this.selected,
    required this.onTap,
    this.dimmed = false,
  });
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final theme = Theme.of(context);
    final hue = categoryHue(context, progress.category);
    final ink = categoryInk(context, progress.category);
    final name = categoryName(context, progress.category);
    final ratio = progress.total == 0 ? 0.0 : progress.done / progress.total;
    // Its own pale field with the dark of its hue as ink; picked, a
    // deeper step of the same field and a tick.
    final field = progress.category == null
        ? (selected ? p.sunk : p.surface)
        : selected
        ? Color.lerp(hue.tint, hue.mark, .3)!
        : hue.tint;
    return Semantics(
      button: true,
      selected: selected,
      label: tr(
        context,
        '$name, ${progress.done} of ${progress.total} done',
        '$name, xong ${progress.done} trên ${progress.total}',
      ),
      excludeSemantics: true,
      child: AnimatedOpacity(
        opacity: dimmed ? .5 : 1,
        duration: HandyMotion.of(context),
        child: Material(
          key: Key('strip-${progress.category?.id ?? 'none'}'),
          color: field,
          borderRadius: BorderRadius.circular(BoardsRadii.card),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (selected)
                        Icon(Icons.check_circle, size: 18, color: ink),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${progress.done}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: ink,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                        TextSpan(
                          text:
                              '/${progress.total} ${tr(context, 'done', 'xong')}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: ink,
                          ),
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
                          ColoredBox(color: p.surface.withValues(alpha: .7)),
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
      ),
    );
  }
}
