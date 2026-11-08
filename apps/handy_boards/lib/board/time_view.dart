import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';
import 'card_tile.dart';
import 'kanban_view.dart';
import 'time_actions.dart';
import 'time_range_picker.dart';

/// One part of the time view: a day, a week, the carry-over tray, or the
/// unplanned tray.
class _Bucket {
  final String key;
  final String title;
  final DateTime? first, end; // [first, end) ; null for the trays
  final bool today, carry;
  final List<BoardRecord> cards = [];

  /// Cards planned elsewhere whose deadline falls here: shown as a line
  /// pointing at the one card, never as a second card or a second count.
  final List<BoardRecord> deadlines = [];
  _Bucket(
    this.key,
    this.title, {
    this.first,
    this.end,
    this.today = false,
    this.carry = false,
  });
}

/// The Time Navigator: the board's own cards laid out by the day they are
/// planned for (or, without a plan, due), by day for short ranges and by
/// week for long ones. Earlier and later windows are one tap away, with
/// markers where unfinished or upcoming work sits; cards from the past
/// move to today and future ones can be done early, changing only the
/// day they are planned for. Dropping a card on a day still sets its due
/// day, as before.
class TimeView extends StatefulWidget {
  final BoardsState state;
  final String board;
  final KanbanFilter filter;
  final DateTime now;
  final TimeRange range;
  final ValueChanged<TimeRange> onRange;
  final void Function(BoardRecord card)? open;
  final Future<void> Function(String card, DateTime? day)? setDue;

  /// Needed for quick moves, history and the backlog; without it the view
  /// is read only (template previews, pictures).
  final BoardsScope? scope;
  const TimeView({
    super.key,
    required this.state,
    required this.board,
    required this.now,
    required this.range,
    required this.onRange,
    this.filter = const KanbanFilter(),
    this.open,
    this.setDue,
    this.scope,
  });
  @override
  State<TimeView> createState() => _TimeViewState();
}

class _TimeViewState extends State<TimeView> {
  late TimeWindow window = currentWindow(widget.range, widget.now);
  final todayKey = GlobalKey();
  bool scrolled = false, selecting = false;
  final picked = <String>{};

  TimeWindow get _current => currentWindow(widget.range, widget.now);
  bool _shows(BoardRecord t) => widget.filter.shows(t, widget.now);

  /// Brings today's day (or week) into view, once per range shown.
  void _toToday() {
    if (scrolled) return;
    scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = todayKey.currentContext;
      if (c != null && c.mounted) {
        Scrollable.ensureVisible(c, alignment: .05, duration: Duration.zero);
      }
    });
  }

  void _go(TimeWindow w) => setState(() {
    window = w;
    scrolled = false;
  });
  void _today() => _go(_current);
  void _shift(int dir) => _go(shiftWindow(widget.range, window, dir));

  @override
  void didUpdateWidget(TimeView old) {
    super.didUpdateWidget(old);
    if (old.range != widget.range) {
      window = _current;
      scrolled = false;
    }
  }

  String _dayName(BuildContext context, DateTime d) {
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const vi = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return tr(
      context,
      '${en[d.weekday - 1]} ${d.day}/${d.month}',
      '${vi[d.weekday - 1]} ${d.day}/${d.month}',
    );
  }

  /// The window in words: its real dates, never "previous week".
  String _label(BuildContext context, TimeWindow w) {
    final last = w.last;
    if (w.first == last) return _dayName(context, w.first);
    final wholeMonths =
        w.first.day == 1 && addDays(last, 1).day == 1 && w.days > 27;
    if (wholeMonths && w.first.month == last.month) {
      return tr(
        context,
        '${w.first.month}/${w.first.year}',
        'Tháng ${w.first.month}/${w.first.year}',
      );
    }
    final year = last.year != widget.now.year || w.first.year != last.year;
    return '${w.first.day}/${w.first.month}${w.first.year != last.year ? '/${w.first.year}' : ''}'
        ' – ${last.day}/${last.month}${year ? '/${last.year}' : ''}';
  }

  /// The day a card sits on: its plan, else its deadline.
  DateTime? _primary(BoardRecord t) => scheduledDay(t) ?? dueDay(t);

  List<_Bucket> _buckets(BuildContext context) {
    final today = calendarDay(widget.now);
    final w = window;
    final buckets = <_Bucket>[];
    final carry = _Bucket(
      'overdue',
      tr(context, 'Still open from before', 'Còn tồn từ trước'),
      carry: true,
    );
    final none = _Bucket('none', tr(context, 'Not planned', 'Chưa lên lịch'));
    if (w.days <= 14) {
      for (var i = 0; i < w.days; i++) {
        final d = addDays(w.first, i);
        buckets.add(
          _Bucket(
            'd$i',
            d == today
                ? '${tr(context, 'Today', 'Hôm nay')} · ${_dayName(context, d)}'
                : _dayName(context, d),
            first: d,
            end: addDays(d, 1),
            today: d == today,
          ),
        );
      }
    } else {
      var m = mondayOf(w.first);
      while (m.isBefore(w.end)) {
        final from = m.isBefore(w.first) ? w.first : m;
        final next = addDays(m, 7);
        final to = next.isAfter(w.end) ? w.end : next;
        final last = addDays(to, -1);
        buckets.add(
          _Bucket(
            'w${isoDay(from)}',
            '${from.day}/${from.month} – ${last.day}/${last.month}',
            first: from,
            end: to,
            today: !today.isBefore(from) && today.isBefore(to),
          ),
        );
        m = next;
      }
    }
    _Bucket? at(DateTime d) {
      for (final b in buckets) {
        if (!d.isBefore(b.first!) && d.isBefore(b.end!)) return b;
      }
      return null;
    }

    final done = {
      for (final c in columnsOf(widget.state, widget.board))
        c.id: c.flag('done'),
    };
    final showsToday = w.contains(today);
    final cards =
        topTasks(widget.state, board: widget.board).where(_shows).toList()
          ..sort((a, b) => a.number('order').compareTo(b.number('order')));
    for (final t in cards) {
      final finished = done[t.str('status')] ?? false;
      final day = _primary(t);
      if (day == null) {
        if (!finished) none.cards.add(t);
        continue;
      }
      if (!finished && showsToday && day.isBefore(w.first)) {
        carry.cards.add(t);
        continue;
      }
      final home = at(day);
      home?.cards.add(t);
      // A deadline on another day of this window points back to the card.
      final due = dueDay(t);
      if (scheduledDay(t) != null && due != null) {
        final there = at(due);
        if (there != null && there != home) there.deadlines.add(t);
      }
    }
    return [if (carry.cards.isNotEmpty) carry, ...buckets, none];
  }

  /// The day a drop on [b] sets as the due day: that day; for a week, the
  /// card's own day if it is already in that week, else the week's first.
  DateTime? _dropDay(_Bucket b, BoardRecord card) {
    if (b.key == 'none') return null;
    if (b.carry) return calendarDay(widget.now);
    final due = dueDay(card);
    if (due != null && !due.isBefore(b.first!) && due.isBefore(b.end!)) {
      return due;
    }
    return b.first;
  }

  Future<void> _move(
    List<String> ids, {
    required String reason,
    DateTime? day,
  }) async {
    final scope = widget.scope;
    if (scope == null) return;
    final ok = await quickSchedule(
      context,
      scope,
      ids,
      reason: reason,
      day: day,
    );
    if (ok && mounted) {
      setState(() {
        picked.clear();
        selecting = false;
      });
    }
  }

  Future<void> _plan(BoardRecord card) async {
    final scope = widget.scope;
    if (scope == null) return;
    final picked = await pickHandyDate(
      context,
      card.data['scheduled'] as String? ?? '',
    );
    if (picked == null || !mounted) return;
    if (picked.isEmpty) {
      await scope.run(
        context,
        () => scope.controller.change(
          (s) => scheduleCards(s, [card.id], null, now: scope.clock()),
        ),
      );
      return;
    }
    await _move([card.id], reason: 'manual', day: DateTime.parse(picked));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final buckets = _buckets(context);
    final today = calendarDay(widget.now);
    _toToday();
    final done = {
      for (final c in columnsOf(widget.state, widget.board))
        c.id: c.flag('done'),
    };
    final desktop = {
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    }.contains(defaultTargetPlatform);
    final canAct = widget.scope != null;

    /// The card's dates in words and the one move that fits it.
    Widget footer(BoardRecord card, bool finished) {
      final planned = scheduledDay(card), due = dueDay(card);
      final day = _primary(card);
      final late = !finished && due != null && due.isBefore(today);
      final words = [
        if (planned != null)
          tr(
            context,
            'Plan ${shortDay(planned, widget.now)}',
            'Làm ${shortDay(planned, widget.now)}',
          ),
        if (due != null)
          tr(
            context,
            'Due ${shortDay(due, widget.now)}',
            'Hạn ${shortDay(due, widget.now)}',
          ),
        if (late) tr(context, 'Overdue', 'Quá hạn'),
      ];
      Widget? action;
      if (selecting && !finished) {
        action = Checkbox(
          key: Key('time-pick-${card.id}'),
          value: picked.contains(card.id),
          onChanged: (v) => setState(
            () => v == true ? picked.add(card.id) : picked.remove(card.id),
          ),
        );
      } else if (canAct && finished) {
        action = TextButton(
          key: Key('time-history-${card.id}'),
          onPressed: () => showCardHistory(context, widget.scope!, card.id),
          child: Text(tr(context, 'History', 'Lịch sử')),
        );
      } else if (canAct && day == null) {
        action = TextButton.icon(
          key: Key('time-plan-${card.id}'),
          onPressed: () => _plan(card),
          icon: const Icon(Icons.event_available_outlined, size: 18),
          label: Text(tr(context, 'Plan', 'Lên lịch')),
        );
      } else if (canAct && day!.isBefore(today)) {
        action = TextButton.icon(
          key: Key('time-now-${card.id}'),
          onPressed: () => _move([card.id], reason: 'move to now'),
          icon: const Icon(Icons.today_outlined, size: 18),
          label: Text(tr(context, 'To today', 'Về hôm nay')),
        );
      } else if (canAct && day!.isAfter(today)) {
        action = TextButton.icon(
          key: Key('time-early-${card.id}'),
          onPressed: () => _move([card.id], reason: 'do early'),
          icon: const Icon(Icons.bolt_outlined, size: 18),
          label: Text(tr(context, 'Do early', 'Làm sớm')),
        );
      } else if (canAct) {
        action = IconButton(
          key: Key('time-plan-${card.id}'),
          tooltip: tr(context, 'Plan another day', 'Lên lịch ngày khác'),
          onPressed: () => _plan(card),
          icon: const Icon(Icons.event_available_outlined, size: 20),
        );
      }
      if (words.isEmpty && action == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 0, 0),
        child: Row(
          children: [
            if (late) ...[
              Icon(Icons.error_outline, size: 16, color: p.danger),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                words.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: late ? p.danger : p.muted,
                ),
              ),
            ),
            ?action,
          ],
        ),
      );
    }

    Widget tile(BoardRecord card) {
      final finished = done[card.str('status')] ?? false;
      final t = CardTile(
        key: ValueKey('time-card-${card.id}'),
        state: widget.state,
        card: card,
        now: widget.now,
        done: finished,
        onOpen: widget.open == null ? null : () => widget.open!(card),
      );
      final body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [t, footer(card, finished)],
      );
      if (widget.setDue == null || selecting) {
        return Padding(padding: const EdgeInsets.only(bottom: 8), child: body);
      }
      final feedback = Material(
        color: Colors.transparent,
        child: SizedBox(width: 260, child: Opacity(opacity: .92, child: t)),
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: desktop
            ? Draggable<String>(
                data: card.id,
                feedback: feedback,
                childWhenDragging: Opacity(opacity: .35, child: body),
                child: body,
              )
            : LongPressDraggable<String>(
                data: card.id,
                feedback: feedback,
                childWhenDragging: Opacity(opacity: .35, child: body),
                onDragStarted: HapticFeedback.mediumImpact,
                child: body,
              ),
      );
    }

    Widget deadline(BoardRecord card) => InkWell(
      key: Key('time-deadline-${card.id}'),
      onTap: widget.open == null ? null : () => widget.open!(card),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.flag_outlined, size: 16, color: p.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tr(
                  context,
                  'Due: ${card.str('title')}',
                  'Hạn nộp: ${card.str('title')}',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
              ),
            ),
          ],
        ),
      ),
    );

    Widget section(_Bucket b, {required bool column}) => KeyedSubtree(
      key: b.today ? todayKey : null,
      child: DragTarget<String>(
        key: Key('time-${b.key}'),
        onAcceptWithDetails: (d) {
          final card = widget.state.maybe('tasks', d.data);
          if (card != null) widget.setDue?.call(d.data, _dropDay(b, card));
        },
        builder: (context, candidates, _) {
          final lit = candidates.isNotEmpty;
          final head = Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
            child: Row(
              children: [
                Flexible(
                  child: Semantics(
                    header: true,
                    child: Text(
                      b.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: b.carry
                            ? p.danger
                            : (b.today
                                  ? (theme.brightness == Brightness.dark
                                        ? p.primary
                                        : p.pressed)
                                  : p.ink),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${b.cards.length}',
                  style: theme.textTheme.labelMedium?.copyWith(color: p.muted),
                ),
                if (b.carry && canAct) ...[
                  const Spacer(),
                  TextButton(
                    key: const Key('time-carry-all'),
                    onPressed: () => _move([
                      for (final c in b.cards) c.id,
                    ], reason: 'move to now'),
                    child: Text(
                      tr(context, 'All to today', 'Tất cả về hôm nay'),
                    ),
                  ),
                ],
              ],
            ),
          );
          final empty = Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Text(
              b.key == 'none'
                  ? tr(
                      context,
                      'Everything has a day.',
                      'Việc nào cũng có ngày.',
                    )
                  : tr(context, 'Free', 'Trống'),
              style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
            ),
          );
          // On a phone an empty day is one line, so a quiet week stays short.
          final compact =
              !column &&
              b.cards.isEmpty &&
              b.deadlines.isEmpty &&
              b.key != 'none';
          final body = [
            head,
            for (final c in b.cards) tile(c),
            for (final c in b.deadlines) deadline(c),
            if (b.cards.isEmpty && b.deadlines.isEmpty && !compact) empty,
          ];
          return AnimatedContainer(
            duration: HandyMotion.of(context, HandyMotion.short),
            margin: column
                ? const EdgeInsets.only(right: 12)
                : EdgeInsets.only(bottom: compact ? 6 : 12),
            padding: compact
                ? const EdgeInsets.fromLTRB(8, 8, 8, 0)
                : const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: lit
                  ? p.tint
                  : (b.today
                        ? p.tint.withValues(alpha: .55)
                        : p.raised.withValues(alpha: .7)),
              borderRadius: BorderRadius.circular(BoardsRadii.column),
              border: lit ? Border.all(color: p.primary, width: 1.5) : null,
            ),
            child: column
                ? SizedBox(
                    width: 280,
                    child: ListView(padding: EdgeInsets.zero, children: body),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: body,
                  ),
          );
        },
      ),
    );

    final narrow = MediaQuery.sizeOf(context).width < 600;
    final navigation = <Widget>[
      IconButton(
        key: const Key('time-prev'),
        tooltip: tr(context, 'Earlier', 'Trước'),
        onPressed: () => _shift(-1),
        icon: const Icon(Icons.chevron_left),
      ),
      Flexible(
        child: Semantics(
          liveRegion: true,
          child: Text(
            _label(context, window),
            key: const Key('time-range'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
        ),
      ),
      IconButton(
        key: const Key('time-next'),
        tooltip: tr(context, 'Later', 'Sau'),
        onPressed: () => _shift(1),
        icon: const Icon(Icons.chevron_right),
      ),
      if (narrow)
        IconButton(
          key: const Key('time-today'),
          tooltip: tr(context, 'Today', 'Hôm nay'),
          onPressed: _today,
          icon: const Icon(Icons.today_outlined),
        )
      else
        TextButton(
          key: const Key('time-today'),
          onPressed: _today,
          child: Text(tr(context, 'Today', 'Hôm nay')),
        ),
    ];
    final tools = <Widget>[
      if (canAct)
        IconButton(
          key: const Key('time-select'),
          tooltip: selecting
              ? tr(context, 'Stop choosing', 'Thôi chọn')
              : tr(context, 'Choose several', 'Chọn nhiều'),
          isSelected: selecting,
          onPressed: () => setState(() {
            selecting = !selecting;
            picked.clear();
          }),
          icon: const Icon(Icons.checklist),
        ),
      TimeRangeButton(
        range: widget.range,
        onRange: widget.onRange,
        from: window.first,
      ),
    ];
    // One row when it fits; on a narrow phone or with large text the
    // tools drop under the dates instead of squeezing them.
    final roomy =
        MediaQuery.sizeOf(context).width >= 420 &&
        MediaQuery.textScalerOf(context).scale(1) <= 1.3;
    final bar = Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 4),
      child: roomy
          ? Row(children: [...navigation, const Spacer(), ...tools])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: navigation),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [for (final t in tools) Flexible(child: t)],
                ),
              ],
            ),
    );

    final marks = _Markers(
      state: widget.state,
      board: widget.board,
      range: widget.range,
      window: window,
      now: widget.now,
      shows: _shows,
      label: (w) => _label(context, w),
      go: _go,
      backlog: canAct
          ? () => showBacklog(
              context,
              widget.scope!,
              widget.board,
              shows: _shows,
              open: widget.open,
            )
          : null,
    );

    final choose = selecting && picked.isNotEmpty
        ? SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: FilledButton.icon(
                key: const Key('time-move-picked'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => _move(picked.toList(), reason: 'move to now'),
                icon: const Icon(Icons.today_outlined),
                label: Text(
                  tr(
                    context,
                    'Plan ${picked.length} for today',
                    'Chuyển ${picked.length} thẻ về hôm nay',
                  ),
                ),
              ),
            ),
          )
        : null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _shift(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _shift(1),
      },
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 600;
          // Wide: the unplanned tray first, as a column like the days;
          // phones: last.
          final ordered = wide
              ? [buckets.last, ...buckets.take(buckets.length - 1)]
              : buckets;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              bar,
              marks,
              Expanded(
                // Every part is built (a window holds at most about 53),
                // so today can always be scrolled to.
                child: wide
                    ? SingleChildScrollView(
                        key: const Key('time-columns'),
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(24, 0, 12, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final b in ordered) section(b, column: true),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        key: const Key('time-list'),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final b in ordered) section(b, column: false),
                          ],
                        ),
                      ),
              ),
              ?choose,
            ],
          );
        },
      ),
    );
  }
}

/// Small markers under the range: the nearest earlier windows that still
/// hold unfinished work (older ones gathered into one), everything left
/// behind in one list, and the next window with something planned. Icons
/// and words carry the meaning; only real overdue work is red.
class _Markers extends StatelessWidget {
  final BoardsState state;
  final String board;
  final TimeRange range;
  final TimeWindow window;
  final DateTime now;
  final bool Function(BoardRecord) shows;
  final String Function(TimeWindow) label;
  final ValueChanged<TimeWindow> go;
  final VoidCallback? backlog;
  const _Markers({
    required this.state,
    required this.board,
    required this.range,
    required this.window,
    required this.now,
    required this.shows,
    required this.label,
    required this.go,
    this.backlog,
  });

  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final marks = periodMarks(state, board, range, window, now, shows: shows);
    final behind = backlogOf(state, board, now, shows: shows).length;
    final past = marks.where((m) => m.past && m.open > 0).toList().reversed;
    final near = past.take(2).toList();
    final older = past.skip(2).toList();
    final later = marks.where((m) => !m.past && m.later > 0).firstOrNull;
    final chips = <Widget>[
      for (final m in near)
        ActionChip(
          key: Key('time-mark-${m.index}'),
          avatar: Icon(
            m.overdue > 0 ? Icons.error_outline : Icons.history,
            size: 18,
            color: m.overdue > 0 ? p.danger : p.muted,
          ),
          label: Text(
            m.overdue > 0
                ? tr(
                    context,
                    '${label(m.window)} · ${m.open} open, ${m.overdue} overdue',
                    '${label(m.window)} · ${m.open} còn tồn, ${m.overdue} quá hạn',
                  )
                : tr(
                    context,
                    '${label(m.window)} · ${m.open} open',
                    '${label(m.window)} · ${m.open} còn tồn',
                  ),
          ),
          onPressed: () => go(m.window),
        ),
      if (older.isNotEmpty)
        ActionChip(
          key: const Key('time-mark-older'),
          avatar: Icon(Icons.history, size: 18, color: p.muted),
          label: Text(
            tr(
              context,
              '${older.length} earlier periods with work',
              '${older.length} kỳ trước còn việc',
            ),
          ),
          onPressed: () => go(older.first.window),
        ),
      if (behind > 0 && backlog != null)
        ActionChip(
          key: const Key('time-backlog'),
          avatar: Icon(Icons.inbox_outlined, size: 18, color: p.ink),
          label: Text(
            tr(
              context,
              'See all left behind ($behind)',
              'Xem tất cả tồn đọng ($behind)',
            ),
          ),
          onPressed: backlog,
        ),
      if (later != null)
        ActionChip(
          key: Key('time-mark-${later.index}'),
          avatar: Icon(Icons.event_outlined, size: 18, color: p.muted),
          label: Text(
            tr(
              context,
              'Next: ${label(later.window)} · ${later.later}',
              'Sắp tới: ${label(later.window)} · ${later.later} việc',
            ),
          ),
          onPressed: () => go(later.window),
        ),
    ];
    if (chips.isEmpty) return const SizedBox(height: 4);
    return SizedBox(
      height: 48,
      child: ListView.separated(
        key: const Key('time-marks'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(child: chips[i]),
      ),
    );
  }
}
