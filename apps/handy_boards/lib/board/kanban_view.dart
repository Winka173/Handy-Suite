import 'dart:math' as math;
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

  /// A template preview: every card is an example, labelled so.
  final bool examples;

  /// Puts a whole column at [index] (held by its header and dropped on
  /// another column).
  final Future<void> Function(String column, int index)? moveColumn;
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
    this.examples = false,
    this.moveColumn,
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
/// centred, with both neighbours showing a 22 pt strip at the sides
/// (places to drop a dragged card; a drag near a side turns to them) and a row of column chips above to jump between them;
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
  /// The phone's columns, side by side, stopping at [_snaps].
  final _lanes = ScrollController();
  final _wide = ScrollController();
  bool dragging = false;
  Timer? _edge;

  /// Where the phone's row stops for each column: the first at the left
  /// margin, the last at the right one, the others centred with both
  /// neighbours showing.
  List<double> _snaps = const [];

  /// The column a phone shows, for the chips.
  final _page = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _lanes.addListener(() {
      final at = _at;
      if (_page.value != at) _page.value = at;
    });
  }

  @override
  void dispose() {
    _lanes.dispose();
    _wide.dispose();
    _edge?.cancel();
    _page.dispose();
    super.dispose();
  }

  /// The column nearest to where the phone's row stands.
  int get _at {
    if (!_lanes.hasClients || _snaps.isEmpty) return 0;
    final x = _lanes.offset;
    var best = 0;
    for (var i = 1; i < _snaps.length; i++) {
      if ((_snaps[i] - x).abs() < (_snaps[best] - x).abs()) best = i;
    }
    return best;
  }

  void _goTo(int column, [Duration? duration]) {
    if (!_lanes.hasClients || _snaps.isEmpty) return;
    final to = _snaps[column.clamp(0, _snaps.length - 1)];
    final d = duration ?? HandyMotion.of(context);
    if (d == Duration.zero) {
      _lanes.jumpTo(to);
    } else {
      _lanes.animateTo(to, duration: d, curve: Curves.easeOutCubic);
    }
  }

  /// Shows [column] (after a move from the menu, or a filter).
  void reveal(int column) {
    if (_lanes.hasClients) {
      _goTo(column);
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
    // The neighbours' strips and a little more: a thumb near a side turns.
    final dir = x < 44 ? -1 : (x > width - 44 ? 1 : 0);
    if (dir == 0) {
      _edge?.cancel();
      _edge = null;
      return;
    }
    _edge ??= Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (_lanes.hasClients) {
        _goTo(_at + dir, const Duration(milliseconds: 260));
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
          // The first column on the left margin, the last on the right one
          // (each with 40 pt of its neighbour showing); the ones between
          // centred with 24 pt of both neighbours: places to drop a dragged
          // card, and a sign there is more.
          const margin = 16.0, gap = 8.0, inset = 32.0;
          final w = box.maxWidth;
          final lane = w - 2 * inset;
          final n = columns.length + (addColumn == null ? 0 : 1);
          final end = math.max(0.0, 2 * margin + n * lane + (n - 1) * gap - w);
          _snaps = [
            for (var k = 0; k < n; k++)
              k == 0
                  ? 0.0
                  : k == n - 1
                  ? end
                  : (margin + k * (lane + gap) - inset).clamp(0.0, end),
          ];
          final pages = ListView.separated(
            key: const Key('kanban-pages'),
            controller: _lanes,
            scrollDirection: Axis.horizontal,
            physics: _LaneSnap(() => _snaps),
            padding: const EdgeInsets.symmetric(horizontal: margin),
            itemCount: n,
            separatorBuilder: (_, _) => const SizedBox(width: gap),
            itemBuilder: (context, i) => SizedBox(
              width: lane,
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
              // Air between the chips and the column.
              const SizedBox(height: 12),
              Expanded(child: pages),
            ],
          );
        }
        // Wide: the columns share the width evenly when each keeps 240 pt
        // (a narrow lane to add one at the end); more scroll sideways.
        const addWidth = 200.0, gap = 12.0;
        final room = box.maxWidth - 48;
        final shared =
            (room -
                (addColumn == null ? 0 : addWidth + gap) -
                gap * (columns.length - 1)) /
            math.max(1, columns.length);
        if (columns.isNotEmpty && shared >= 240) {
          return Padding(
            key: const Key('kanban-wide'),
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < columns.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  Expanded(child: column(i)),
                ],
                if (addColumn != null) ...[
                  const SizedBox(width: gap),
                  SizedBox(width: addWidth, child: _AddColumn(addColumn)),
                ],
              ],
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

  /// A card from another column is held over this one: it lights up, so
  /// the person sees where the card will land.
  bool landing = false;

  /// Another column is held over this one (to take its place).
  bool columnLanding = false;

  /// Whether [card] comes from another column.
  bool _foreign(String card) =>
      widget.state.maybe('tasks', card)?.str('status') != widget.column.id;

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
      onWillAcceptWithDetails: (d) {
        setState(() {
          hover = index;
          landing = _foreign(d.data);
        });
        return true;
      },
      onLeave: (_) => setState(() {
        hover = null;
        landing = false;
      }),
      onAcceptWithDetails: (d) {
        setState(() {
          hover = null;
          landing = false;
        });
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
        example: a.examples,
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

    final heading = Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 2, 0),
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
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
    // Held down, the header carries the whole column to a new place.
    final header = a.moveColumn == null
        ? heading
        : LongPressDraggable<ColumnMove>(
            data: ColumnMove(widget.column.id),
            onDragStarted: widget.onDragStart,
            onDragUpdate: (d) => widget.onDragMove(d.globalPosition),
            onDragEnd: (_) => widget.onDragEnd(),
            childWhenDragging: Opacity(opacity: .4, child: heading),
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                width: 220,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: widget.color ?? p.raised,
                  borderRadius: BorderRadius.circular(BoardsRadii.column),
                  border: Border.all(color: p.primary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  '${widget.column.str('title')} · ${all.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
              ),
            ),
            child: heading,
          );

    final body = <Widget>[
      if (!a.readOnly) slot(0),
      for (var i = 0; i < cards.length; i++) ...[
        // A card that arrives here fades in; one already here does not
        // replay (its key is stable).
        HandyAppear(key: ValueKey('in-${cards[i].id}'), child: tile(cards[i])),
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
      onWillAcceptWithDetails: (d) {
        setState(() => landing = _foreign(d.data));
        return true;
      },
      onLeave: (_) => setState(() => landing = false),
      onAcceptWithDetails: (d) {
        setState(() => landing = false);
        a.move?.call(d.data, widget.column.id, all.length);
      },
      builder: (context, candidates, _) => ListView(
        key: PageStorageKey('column-${widget.column.id}'),
        padding: EdgeInsets.zero,
        children: children,
      ),
    );
    final ground = widget.color ?? p.raised;
    final lit = landing || columnLanding;
    return DragTarget<ColumnMove>(
      onWillAcceptWithDetails: (d) {
        final other = d.data.column != widget.column.id;
        if (other != columnLanding) setState(() => columnLanding = other);
        return other;
      },
      onLeave: (_) => setState(() => columnLanding = false),
      onAcceptWithDetails: (d) {
        setState(() => columnLanding = false);
        a.moveColumn?.call(d.data.column, widget.index);
      },
      builder: (context, _, _) => AnimatedContainer(
        duration: HandyMotion.of(context),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: lit ? Color.lerp(ground, p.primary, .14) : ground,
          borderRadius: BorderRadius.circular(BoardsRadii.column),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BoardsRadii.column),
          border: Border.all(
            color: lit ? p.primary : Colors.transparent,
            width: 2,
          ),
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
      height: 40,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              '$name  $n',
                              style: theme.textTheme.labelMedium?.copyWith(
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

/// Stops the phone's row of columns at a column after a fling or a drag:
/// the next one along the fling, else the nearest.
class _LaneSnap extends ScrollPhysics {
  final List<double> Function() snaps;
  const _LaneSnap(this.snaps, {super.parent});

  @override
  _LaneSnap applyTo(ScrollPhysics? ancestor) =>
      _LaneSnap(snaps, parent: buildParent(ancestor));

  double _target(ScrollMetrics position, double velocity) {
    final s = snaps();
    final x = position.pixels;
    if (s.isEmpty) return x;
    var best = s.first;
    for (final v in s) {
      if ((v - x).abs() < (best - x).abs()) best = v;
    }
    final speed = toleranceFor(position).velocity;
    if (velocity > speed) {
      return s.firstWhere((v) => v > x + 1, orElse: () => s.last);
    }
    if (velocity < -speed) {
      return s.lastWhere((v) => v < x - 1, orElse: () => s.first);
    }
    return best;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final to = _target(position, velocity);
    if ((to - position.pixels).abs() < .5) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      to,
      velocity,
      tolerance: toleranceFor(position),
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}

/// What a column carries while it is dragged by its header.
class ColumnMove {
  final String column;
  const ColumnMove(this.column);
}
