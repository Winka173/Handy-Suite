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

  /// In a period gone by: brings an unfinished card to the current one,
  /// shown on the card with [carryLabel].
  final void Function(BoardRecord card)? carry;
  final String? carryLabel;
  const KanbanActions({
    this.open,
    this.move,
    this.add,
    this.columnMenu,
    this.cardMenu,
    this.tick,
    this.addColumn,
    this.fromTemplate,
    this.carry,
    this.carryLabel,
  });
  bool get readOnly => move == null;
}

/// Which cards show: any of the chosen categories (Uncategorised is
/// [CategoryStrip.uncategorisedKey], an empty string), a text search over
/// titles and notes, "due in 3 days", a saved filter, and on a timeline
/// the period shown.
class KanbanFilter {
  /// Category ids; empty shows every category.
  final Set<String> categories;
  final String query;
  final bool dueSoon;

  /// A saved filter in use: the ids of the cards it lets through.
  final Set<String>? only;

  /// On a timeline, the period shown: a card shows when its day (the day it
  /// is planned for, else the day it was made) falls in it. Null shows
  /// every card.
  final TimeWindow? window;
  const KanbanFilter({
    this.categories = const {},
    this.query = '',
    this.dueSoon = false,
    this.only,
    this.window,
  });

  bool get active =>
      categories.isNotEmpty ||
      query.trim().isNotEmpty ||
      dueSoon ||
      only != null ||
      window != null;

  bool shows(BoardRecord card, DateTime now, [BoardsState? s]) {
    if (only != null && !only!.contains(card.id)) return false;
    if (categories.isNotEmpty &&
        !categories.contains(card.data['category'] as String? ?? ''))
      return false;
    if (dueSoon) {
      final d = dueDay(card);
      final today = DateTime(now.year, now.month, now.day);
      if (d == null || d.difference(today).inDays > 3) return false;
    }
    if (window != null && !window!.contains(cardDay(card, fallback: now)))
      return false;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return card.str('title').toLowerCase().contains(q) ||
        card.str('notes').toLowerCase().contains(q);
  }
}

/// The board's columns side by side. Phones see one column at a time,
/// on the page's margins, with both neighbours showing their edge at the
/// sides (a drag near a side turns to them) and a row of column chips above to jump between them;
/// wider screens show 300 px columns that scroll sideways
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
    this.columnChips = true,
  });

  /// The phone's row of column chips (off in small previews).
  final bool columnChips;
  @override
  State<KanbanView> createState() => KanbanViewState();
}

class KanbanViewState extends State<KanbanView> {
  PageController? _pages;
  final _wide = ScrollController();
  double _fraction = 1;
  bool dragging = false;
  Timer? _edge;

  /// The column a phone shows, for the chips.
  final _page = ValueNotifier<int>(0);

  @override
  void dispose() {
    _pages?.dispose();
    _wide.dispose();
    _edge?.cancel();
    _page.dispose();
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
    // The neighbour edges and the margin: a thumb near the side turns.
    final dir = x < 44 ? -1 : (x > width - 44 ? 1 : 0);
    if (dir == 0) {
      _edge?.cancel();
      _edge = null;
      return;
    }
    _edge ??= Timer.periodic(const Duration(milliseconds: 600), (_) {
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
          // The column on the page's 16 pt margins; each neighbour shows
          // its edge in the 11 pt beyond them.
          final fraction = ((box.maxWidth - 22) / box.maxWidth).clamp(.7, 1.0);
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
          final pages = PageView.builder(
            key: const Key('kanban-pages'),
            controller: _pages,
            onPageChanged: (i) => _page.value = i,
            itemCount: columns.length + (addColumn == null ? 0 : 1),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: i == columns.length ? _AddColumn(addColumn!) : column(i),
            ),
          );
          if (!widget.columnChips || columns.length < 2) return pages;
          return Column(
            children: [
              ValueListenableBuilder<int>(
                valueListenable: _page,
                builder: (context, at, _) => _ColumnChips(
                  names: [
                    for (final c in columns)
                      (
                        c.str('title'),
                        cardsIn(widget.state, c.id)
                            .where(
                              (x) => widget.filter.shows(
                                x,
                                widget.now,
                                widget.state,
                              ),
                            )
                            .length,
                      ),
                  ],
                  at: at,
                  onTap: reveal,
                ),
              ),
              Expanded(child: pages),
            ],
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
    final cards = all
        .where((c) => widget.filter.shows(c, widget.now, widget.state))
        .toList();
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
        onCarry: a.carry == null ? null : () => a.carry!(card),
        carryLabel: a.carryLabel,
      );
      final t = plain;
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
          // The name and its count take the room; the menu sits at the edge.
          Expanded(
            child: Row(
              children: [
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
                  // "2/6" only when some cards are filtered out.
                  cards.length != all.length
                      ? '${cards.length}/${all.length}'
                      : '${all.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: p.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
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
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: Key('add-card-open-${widget.column.id}'),
                    onPressed: () => setState(() => adding = true),
                    icon: const Icon(Icons.add),
                    label: Text(tr(context, 'Add card', 'Thêm thẻ')),
                  ),
                ),
              ),
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

/// The phone's column chips: each column's name and its card count, the
/// shown one filled in ink; a tap turns to it. Scrolls inside its own row.
class _ColumnChips extends StatelessWidget {
  final List<(String, int)> names;
  final int at;
  final ValueChanged<int> onTap;
  const _ColumnChips({
    required this.names,
    required this.at,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final theme = Theme.of(context);
    return SizedBox(
      height: 48,
      child: ListView(
        key: const Key('column-chips'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final (i, (name, n)) in names.indexed)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: Semantics(
                  selected: i == at,
                  button: true,
                  child: Material(
                    color: i == at ? p.ink : p.raised,
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: Key('column-chip-$i'),
                      onTap: () => onTap(i),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 36),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              '$name  $n',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: i == at ? p.canvas : p.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
