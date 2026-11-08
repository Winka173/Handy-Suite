import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import 'card_tile.dart';

/// What the person can do on a Kanban. Every callback is optional: a
/// template preview passes none and gets the same board, read-only.
class KanbanActions {
  final void Function(BoardRecord card)? open;
  final Future<void> Function(String card, String column, int index)? move;
  final Future<void> Function(String column, String title)? add;
  final void Function(BoardRecord column)? columnMenu;
  final void Function(BoardRecord card)? cardMenu;
  final void Function(String subtask, bool done)? tick;
  final VoidCallback? addColumn;

  /// Column › From my templates (Pro): a fresh card from a card template.
  final void Function(String column)? fromTemplate;
  const KanbanActions({
    this.open,
    this.move,
    this.add,
    this.columnMenu,
    this.cardMenu,
    this.tick,
    this.addColumn,
    this.fromTemplate,
  });
  bool get readOnly => move == null;
}

/// Which cards show: one category (or Uncategorised with [uncategorised]),
/// and a text search over titles and notes. [focus] only highlights a
/// category's cards (the rest stay, quieter); it never hides anything.
class KanbanFilter {
  final String? category;
  final bool uncategorised;
  final String query;
  final bool dueSoon;

  /// A category id, [uncategorisedFocus], or null.
  final String? focus;
  const KanbanFilter({
    this.category,
    this.uncategorised = false,
    this.query = '',
    this.dueSoon = false,
    this.focus,
  });

  static const uncategorisedFocus = '';

  /// Whether [card] is one of the focused category's (null: no focus).
  bool? focused(BoardRecord card) => focus == null
      ? null
      : focus == uncategorisedFocus
      ? card.data['category'] == null
      : card.data['category'] == focus;
  bool get active =>
      category != null || uncategorised || query.trim().isNotEmpty || dueSoon;
  bool shows(BoardRecord card, DateTime now) {
    if (category != null && card.data['category'] != category) return false;
    if (uncategorised && card.data['category'] != null) return false;
    if (dueSoon) {
      final d = dueDay(card);
      final today = DateTime(now.year, now.month, now.day);
      if (d == null || d.difference(today).inDays > 3) return false;
    }
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return card.str('title').toLowerCase().contains(q) ||
        card.str('notes').toLowerCase().contains(q);
  }
}

/// The board's columns side by side. Phones see one column at a time,
/// almost full width, with the next column's edge showing and snapping
/// between them; wider screens show 300 px columns that scroll sideways
/// inside their own area, never the page.
class KanbanView extends StatefulWidget {
  final BoardsState state;
  final String board;
  final KanbanFilter filter;
  final KanbanActions actions;
  final DateTime now;
  final bool detailed;

  /// The column fill of the board's look (null: the theme's).
  final Color? columnColor;
  const KanbanView({
    super.key,
    required this.state,
    required this.board,
    required this.now,
    this.filter = const KanbanFilter(),
    this.actions = const KanbanActions(),
    this.detailed = false,
    this.columnColor,
  });
  @override
  State<KanbanView> createState() => KanbanViewState();
}

class KanbanViewState extends State<KanbanView> {
  PageController? _pages;
  final _wide = ScrollController();
  double _fraction = 1;
  bool dragging = false;
  Timer? _edge;

  @override
  void dispose() {
    _pages?.dispose();
    _wide.dispose();
    _edge?.cancel();
    super.dispose();
  }

  /// Shows [column] (after a move from the menu, or a filter).
  void reveal(int column) {
    final pages = _pages;
    if (pages != null && pages.hasClients) {
      pages.animateToPage(
        column,
        duration: HandyMotion.of(context),
        curve: Curves.easeOutCubic,
      );
    } else if (_wide.hasClients) {
      _wide.animateTo(
        (column * 312.0).clamp(0, _wide.position.maxScrollExtent),
        duration: HandyMotion.of(context),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _dragAt(Offset global, double width) {
    // Near an edge while dragging: turn to the next column.
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final x = box.globalToLocal(global).dx;
    final dir = x < 28 ? -1 : (x > width - 28 ? 1 : 0);
    if (dir == 0) {
      _edge?.cancel();
      _edge = null;
      return;
    }
    _edge ??= Timer.periodic(const Duration(milliseconds: 650), (_) {
      final pages = _pages;
      if (pages != null && pages.hasClients) {
        final page = (pages.page ?? 0).round() + dir;
        if (page >= 0)
          pages.animateToPage(
            page,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
          );
      } else if (_wide.hasClients) {
        _wide.animateTo(
          (_wide.offset + dir * 280).clamp(0, _wide.position.maxScrollExtent),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _dragEnd() {
    _edge?.cancel();
    _edge = null;
    if (mounted) setState(() => dragging = false);
  }

  @override
  Widget build(BuildContext context) {
    final columns = columnsOf(widget.state, widget.board);
    return LayoutBuilder(
      builder: (context, box) {
        final phone = box.maxWidth < 600;
        Widget column(int i) => ColumnView(
          key: ValueKey(columns[i].id),
          state: widget.state,
          column: columns[i],
          index: i,
          count: columns.length,
          filter: widget.filter,
          actions: widget.actions,
          now: widget.now,
          detailed: widget.detailed,
          color: widget.columnColor,
          onDragStart: () => setState(() => dragging = true),
          onDragMove: (g) => _dragAt(g, box.maxWidth),
          onDragEnd: _dragEnd,
        );
        final addColumn = widget.actions.addColumn;
        if (phone) {
          final fraction = ((box.maxWidth - 40) / box.maxWidth).clamp(.7, 1.0);
          if (_pages == null || _fraction != fraction) {
            final page = _pages?.hasClients == true
                ? (_pages!.page ?? 0).round()
                : 0;
            _pages?.dispose();
            _pages = PageController(
              viewportFraction: fraction,
              initialPage: page,
            );
            _fraction = fraction;
          }
          return PageView.builder(
            key: const Key('kanban-pages'),
            controller: _pages,
            padEnds: false,
            itemCount: columns.length + (addColumn == null ? 0 : 1),
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.only(left: i == 0 ? 16 : 6, right: 6),
              child: i == columns.length ? _AddColumn(addColumn!) : column(i),
            ),
          );
        }
        return Scrollbar(
          controller: _wide,
          child: ListView(
            key: const Key('kanban-wide'),
            controller: _wide,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            children: [
              for (var i = 0; i < columns.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(width: 300, child: column(i)),
                ),
              if (addColumn != null)
                SizedBox(width: 300, child: _AddColumn(addColumn)),
            ],
          ),
        );
      },
    );
  }
}

/// One column: its header, its cards (drop targets between them) and the
/// add-a-card field at its foot.
class ColumnView extends StatefulWidget {
  final BoardsState state;
  final BoardRecord column;
  final int index, count;
  final KanbanFilter filter;
  final KanbanActions actions;
  final DateTime now;
  final bool detailed;
  final Color? color;
  final VoidCallback onDragStart, onDragEnd;
  final ValueChanged<Offset> onDragMove;
  const ColumnView({
    super.key,
    required this.state,
    required this.column,
    required this.index,
    required this.count,
    required this.filter,
    required this.actions,
    required this.now,
    required this.detailed,
    this.color,
    required this.onDragStart,
    required this.onDragMove,
    required this.onDragEnd,
  });
  @override
  State<ColumnView> createState() => _ColumnViewState();
}

class _ColumnViewState extends State<ColumnView> {
  bool adding = false;
  final text = TextEditingController();
  final focus = FocusNode();
  int? hover;

  @override
  void dispose() {
    text.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = text.text.trim();
    if (title.isEmpty) {
      setState(() => adding = false);
      return;
    }
    await widget.actions.add!(widget.column.id, title);
    text.clear();
    if (mounted) focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final theme = Theme.of(context);
    final all = cardsIn(widget.state, widget.column.id);
    final cards = all.where((c) => widget.filter.shows(c, widget.now)).toList();
    final done = widget.column.flag('done');
    final a = widget.actions;

    Widget slot(int index) => DragTarget<String>(
      onWillAcceptWithDetails: (_) {
        setState(() => hover = index);
        return true;
      },
      onLeave: (_) => setState(() => hover = null),
      onAcceptWithDetails: (d) {
        setState(() => hover = null);
        // Index among every card of the column, filtered or not.
        final target = index < cards.length
            ? all.indexWhere((c) => c.id == cards[index].id)
            : all.length;
        final from = all.indexWhere((c) => c.id == d.data);
        a.move!(
          d.data,
          widget.column.id,
          from >= 0 && from < target ? target - 1 : target,
        );
      },
      builder: (context, candidates, _) => AnimatedContainer(
        duration: HandyMotion.of(context, HandyMotion.short),
        height: candidates.isNotEmpty ? 56 : 8,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty ? p.tint : Colors.transparent,
          borderRadius: BorderRadius.circular(BoardsRadii.card),
          border: candidates.isNotEmpty
              ? Border.all(color: p.primary.withValues(alpha: .5), width: 1.5)
              : null,
        ),
      ),
    );

    Widget tile(BoardRecord card) {
      final plain = CardTile(
        key: ValueKey('card-${card.id}'),
        state: widget.state,
        card: card,
        now: widget.now,
        done: done,
        detailed: widget.detailed,
        onOpen: a.open == null ? null : () => a.open!(card),
        onTick: a.tick,
        onMenu: a.cardMenu == null ? null : () => a.cardMenu!(card),
      );
      final t = _focusMark(context, widget.state, widget.filter, card, plain);
      if (a.readOnly) return t;
      final feedback = Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 280,
          child: Transform.rotate(
            angle: MediaQuery.maybeDisableAnimationsOf(context) == true
                ? 0
                : -.03,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(BoardsRadii.card),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: t,
            ),
          ),
        ),
      );
      final ghost = Opacity(opacity: .35, child: t);
      void start() {
        HapticFeedback.mediumImpact();
        widget.onDragStart();
      }

      void update(DragUpdateDetails d) => widget.onDragMove(d.globalPosition);
      void end() {
        HapticFeedback.selectionClick();
        widget.onDragEnd();
      }

      final desktop = {
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      }.contains(defaultTargetPlatform);
      return _Movable(
        card: card,
        index: widget.index,
        count: widget.count,
        position: all.indexWhere((c) => c.id == card.id),
        columnLength: all.length,
        move: a.move!,
        column: widget.column.id,
        state: widget.state,
        child: desktop
            ? Draggable<String>(
                data: card.id,
                feedback: feedback,
                childWhenDragging: ghost,
                onDragStarted: widget.onDragStart,
                onDragUpdate: update,
                onDragEnd: (_) => widget.onDragEnd(),
                child: t,
              )
            : LongPressDraggable<String>(
                data: card.id,
                feedback: feedback,
                childWhenDragging: ghost,
                onDragStarted: start,
                onDragUpdate: update,
                onDragEnd: (_) => end(),
                child: t,
              ),
      );
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 2, 4),
      child: Row(
        children: [
          if (done) ...[
            Icon(Icons.check_circle, size: 18, color: p.positive),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Semantics(
              header: true,
              child: Text(
                widget.column.str('title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.filter.active
                ? '${cards.length}/${all.length}'
                : '${all.length}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: p.muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          if (a.columnMenu != null)
            IconButton(
              tooltip: tr(context, 'Column options', 'Tuỳ chọn cột'),
              onPressed: () => a.columnMenu!(widget.column),
              icon: Icon(Icons.more_horiz, color: p.muted),
            )
          else
            const SizedBox(height: 48),
        ],
      ),
    );

    final body = <Widget>[
      if (!a.readOnly) slot(0),
      for (var i = 0; i < cards.length; i++) ...[
        tile(cards[i]),
        if (!a.readOnly) slot(i + 1) else const SizedBox(height: 8),
      ],
      if (cards.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Text(
            all.isNotEmpty
                ? tr(context, 'No card here matches.', 'Không có thẻ nào khớp.')
                : done
                ? tr(
                    context,
                    'Finished cards land here.',
                    'Thẻ đã xong nằm ở đây.',
                  )
                : tr(context, 'No cards yet.', 'Chưa có thẻ.'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
          ),
        ),
    ];

    final footer = a.add == null
        ? const SizedBox(height: 8)
        : adding
        ? Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
            child: TextField(
              key: Key('add-card-${widget.column.id}'),
              controller: text,
              focusNode: focus,
              autofocus: true,
              textInputAction: TextInputAction.done,
              maxLength: 1000,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              decoration: InputDecoration(
                hintText: tr(context, 'Card title', 'Tên thẻ'),
                suffixIcon: IconButton(
                  tooltip: tr(context, 'Add', 'Thêm'),
                  onPressed: _save,
                  icon: const Icon(Icons.arrow_upward),
                ),
              ),
              onSubmitted: (_) => _save(),
              onTapOutside: (_) {
                if (text.text.trim().isEmpty) setState(() => adding = false);
              },
            ),
          )
        : Row(
            children: [
              Flexible(
                child: TextButton.icon(
                  key: Key('add-card-open-${widget.column.id}'),
                  onPressed: () => setState(() => adding = true),
                  icon: const Icon(Icons.add),
                  label: Text(tr(context, 'Add card', 'Thêm thẻ')),
                ),
              ),
              const Spacer(),
              if (a.fromTemplate != null)
                IconButton(
                  key: Key('add-from-template-${widget.column.id}'),
                  tooltip: tr(context, 'From my templates', 'Từ mẫu của tôi'),
                  onPressed: () => a.fromTemplate!(widget.column.id),
                  icon: Icon(Icons.content_copy_outlined, color: p.muted),
                ),
            ],
          );

    // Dropped on the empty part of a column: at its end.
    Widget target(List<Widget> children) => DragTarget<String>(
      onAcceptWithDetails: (d) =>
          a.move?.call(d.data, widget.column.id, all.length),
      builder: (context, candidates, _) => ListView(
        key: PageStorageKey('column-${widget.column.id}'),
        padding: EdgeInsets.zero,
        children: children,
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: widget.color ?? p.raised,
        borderRadius: BorderRadius.circular(BoardsRadii.column),
      ),
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: LayoutBuilder(
        // A short column (a small preview, the keyboard up) scrolls as a
        // whole, header and add field included, instead of overflowing.
        builder: (context, box) => box.maxHeight < 200
            ? target([header, ...body, footer])
            : Column(
                children: [
                  header,
                  Expanded(child: target(body)),
                  footer,
                ],
              ),
      ),
    );
  }
}

/// Keyboard moves for a card: Alt+←/→ to the next column, Alt+↑/↓ within
/// it, so nothing needs a drag.
class _Movable extends StatelessWidget {
  final BoardRecord card;
  final BoardsState state;
  final String column;
  final int index, count, position, columnLength;
  final Future<void> Function(String card, String column, int index) move;
  final Widget child;
  const _Movable({
    required this.card,
    required this.state,
    required this.column,
    required this.index,
    required this.count,
    required this.position,
    required this.columnLength,
    required this.move,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    final columns = columnsOf(state, card.str('board'));
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () {
          if (index + 1 < count) move(card.id, columns[index + 1].id, 0);
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () {
          if (index > 0) move(card.id, columns[index - 1].id, 0);
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): () {
          if (position > 0) move(card.id, column, position - 1);
        },
        const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): () {
          if (position + 1 < columnLength) move(card.id, column, position + 1);
        },
      },
      child: child,
    );
  }
}

class _AddColumn extends StatelessWidget {
  final VoidCallback onTap;
  const _AddColumn(this.onTap);
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Material(
          color: p.raised.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(BoardsRadii.column),
          child: InkWell(
            borderRadius: BorderRadius.circular(BoardsRadii.column),
            onTap: onTap,
            child: SizedBox(
              height: 56,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: p.muted),
                    const SizedBox(width: 8),
                    Text(
                      tr(context, 'Add column', 'Thêm cột'),
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: p.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Category focus: the focused category's cards get a ring in its colour
/// and say so to screen readers; the others stay in place, quieter. Never
/// colour alone: the ring is thick and the label is spoken.
Widget _focusMark(
  BuildContext context,
  BoardsState s,
  KanbanFilter filter,
  BoardRecord card,
  Widget tile,
) {
  final on = filter.focused(card);
  if (on == null) return tile;
  if (!on) return Opacity(opacity: .45, child: tile);
  final category = s.maybe('categories', card.data['category']);
  final hue = category == null
      ? BoardsPalette.of(context).ink
      : HandyPalette.of(context, category.number('color')).mark;
  return Semantics(
    label: tr(context, 'In focus', 'Đang làm nổi'),
    child: DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BoardsRadii.card),
        border: Border.all(color: hue, width: 3),
      ),
      child: tile,
    ),
  );
}
