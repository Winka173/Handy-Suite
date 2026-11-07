import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import 'card_tile.dart';
import 'kanban_view.dart';

/// How far the time view looks: a number of days, weeks or months.
@immutable
class TimeSpan {
  final String unit;
  final int count;
  const TimeSpan(this.unit, this.count);
  static const standard = TimeSpan('week', 1);

  static TimeSpan read(Object? raw) {
    if (raw is Map &&
        const {'day', 'week', 'month'}.contains(raw['unit']) &&
        raw['count'] is int) {
      return TimeSpan(
        raw['unit'] as String,
        (raw['count'] as int).clamp(1, 12),
      );
    }
    return standard;
  }

  Json toJson() => {'unit': unit, 'count': count};

  @override
  bool operator ==(Object other) =>
      other is TimeSpan && other.unit == unit && other.count == count;
  @override
  int get hashCode => Object.hash(unit, count);

  String label(BuildContext context) => switch ((unit, count)) {
    ('day', 1) => tr(context, 'Today', 'Hôm nay'),
    ('day', final n) => tr(context, '$n days', '$n ngày'),
    ('week', 1) => tr(context, 'Week', 'Tuần'),
    ('week', final n) => tr(context, '$n weeks', '$n tuần'),
    ('month', 1) => tr(context, 'Month', 'Tháng'),
    (_, final n) => tr(context, '$n months', '$n tháng'),
  };
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _monday(DateTime d) => _day(d).subtract(Duration(days: d.weekday - 1));

/// The first day shown for [span] around [d].
DateTime spanStart(TimeSpan span, DateTime d) => switch (span.unit) {
  'week' => _monday(d),
  'month' => DateTime(d.year, d.month),
  _ => _day(d),
};

/// The day after the last one shown.
DateTime spanEnd(TimeSpan span, DateTime start) => switch (span.unit) {
  'week' => DateTime(start.year, start.month, start.day + 7 * span.count),
  'month' => DateTime(start.year, start.month + span.count),
  _ => DateTime(start.year, start.month, start.day + span.count),
};

/// One part of the time view: a day, a week, Overdue, or No due date.
class _Bucket {
  final String key;
  final String title;
  final DateTime? first, end; // [first, end) ; null for the trays
  final bool today, overdue;
  final List<BoardRecord> cards = [];
  _Bucket(
    this.key,
    this.title, {
    this.first,
    this.end,
    this.today = false,
    this.overdue = false,
  });
}

/// When things are due: the board's cards laid out by day (or by week for
/// long spans), with Overdue first and No due date as a tray. Dropping a
/// card on a day sets that due day; on the tray, takes it off.
class TimeView extends StatefulWidget {
  final BoardsState state;
  final String board;
  final KanbanFilter filter;
  final DateTime now;
  final TimeSpan span;
  final ValueChanged<TimeSpan> onSpan;
  final void Function(BoardRecord card)? open;
  final Future<void> Function(String card, DateTime? day)? setDue;
  const TimeView({
    super.key,
    required this.state,
    required this.board,
    required this.now,
    required this.span,
    required this.onSpan,
    this.filter = const KanbanFilter(),
    this.open,
    this.setDue,
  });
  @override
  State<TimeView> createState() => _TimeViewState();
}

class _TimeViewState extends State<TimeView> {
  late DateTime start = spanStart(widget.span, widget.now);
  final todayKey = GlobalKey();
  bool scrolled = false;

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

  void _today() => setState(() {
    start = spanStart(widget.span, widget.now);
    scrolled = false;
  });

  @override
  void didUpdateWidget(TimeView old) {
    super.didUpdateWidget(old);
    if (old.span != widget.span) {
      start = spanStart(widget.span, widget.now);
      scrolled = false;
    }
  }

  void _shift(int dir) => setState(() {
    scrolled = false;
    start = switch (widget.span.unit) {
      'month' => DateTime(start.year, start.month + dir * widget.span.count),
      'week' => DateTime(
        start.year,
        start.month,
        start.day + dir * 7 * widget.span.count,
      ),
      _ => DateTime(
        start.year,
        start.month,
        start.day + dir * widget.span.count,
      ),
    };
  });

  String _dayName(BuildContext context, DateTime d) {
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const vi = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return tr(
      context,
      '${en[d.weekday - 1]} ${d.day}/${d.month}',
      '${vi[d.weekday - 1]} ${d.day}/${d.month}',
    );
  }

  List<_Bucket> _buckets(BuildContext context) {
    final today = _day(widget.now);
    final end = spanEnd(widget.span, start);
    final days = end.difference(start).inDays;
    final buckets = <_Bucket>[];
    final overdue = _Bucket(
      'overdue',
      tr(context, 'Overdue', 'Quá hạn'),
      overdue: true,
    );
    final none = _Bucket('none', tr(context, 'No due date', 'Chưa có hạn'));
    if (days <= 14) {
      for (var i = 0; i < days; i++) {
        final d = DateTime(start.year, start.month, start.day + i);
        buckets.add(
          _Bucket(
            'd$i',
            d == today
                ? '${tr(context, 'Today', 'Hôm nay')} · ${_dayName(context, d)}'
                : _dayName(context, d),
            first: d,
            end: DateTime(d.year, d.month, d.day + 1),
            today: d == today,
          ),
        );
      }
    } else {
      var w = _monday(start);
      while (w.isBefore(end)) {
        final from = w.isBefore(start) ? start : w;
        final next = DateTime(w.year, w.month, w.day + 7);
        final to = next.isAfter(end) ? end : next;
        final last = to.subtract(const Duration(days: 1));
        buckets.add(
          _Bucket(
            'w${from.millisecondsSinceEpoch}',
            '${from.day}/${from.month} – ${last.day}/${last.month}',
            first: from,
            end: to,
            today: !today.isBefore(from) && today.isBefore(to),
          ),
        );
        w = next;
      }
    }
    final columns = {
      for (final c in columnsOf(widget.state, widget.board))
        c.id: c.flag('done'),
    };
    final showsToday = !today.isBefore(start) && today.isBefore(end);
    final cards =
        topTasks(
            widget.state,
            board: widget.board,
          ).where((t) => widget.filter.shows(t, widget.now)).toList()
          ..sort((a, b) => a.number('order').compareTo(b.number('order')));
    for (final t in cards) {
      final due = dueDay(t);
      final done = columns[t.str('status')] ?? false;
      if (due == null) {
        if (!done) none.cards.add(t);
        continue;
      }
      if (due.isBefore(today) && !done && showsToday && due.isBefore(start)) {
        overdue.cards.add(t);
        continue;
      }
      for (final b in buckets) {
        if (!due.isBefore(b.first!) && due.isBefore(b.end!)) {
          b.cards.add(t);
          break;
        }
      }
    }
    return [if (overdue.cards.isNotEmpty) overdue, ...buckets, none];
  }

  /// The day a drop on [b] sets: that day; for a week, the card's own day
  /// if it is already in that week, else the week's first day shown.
  DateTime? _dropDay(_Bucket b, BoardRecord card) {
    if (b.key == 'none') return null;
    if (b.overdue) return _day(widget.now);
    final due = dueDay(card);
    if (due != null && !due.isBefore(b.first!) && due.isBefore(b.end!))
      return due;
    return b.first;
  }

  String _range(BuildContext context) {
    final end = spanEnd(widget.span, start).subtract(const Duration(days: 1));
    if (widget.span.unit == 'month' && widget.span.count == 1) {
      return tr(
        context,
        '${start.month}/${start.year}',
        'Tháng ${start.month}/${start.year}',
      );
    }
    if (start == end) return _dayName(context, start);
    return '${start.day}/${start.month} – ${end.day}/${end.month}${end.year != widget.now.year ? '/${end.year}' : ''}';
  }

  Future<void> _custom() async {
    var unit = widget.span.unit;
    var count = widget.span.count;
    final picked = await showDialog<TimeSpan>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text(tr(context, 'Show how long', 'Xem khoảng bao lâu')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    key: const Key('span-less'),
                    tooltip: tr(context, 'Fewer', 'Bớt'),
                    onPressed: count > 1 ? () => set(() => count--) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '$count',
                      key: const Key('span-count'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    key: const Key('span-more'),
                    tooltip: tr(context, 'More', 'Thêm'),
                    onPressed: count < 12 ? () => set(() => count++) : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                key: const Key('span-unit'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: 'day',
                    label: Text(tr(context, 'Days', 'Ngày')),
                  ),
                  ButtonSegment(
                    value: 'week',
                    label: Text(tr(context, 'Weeks', 'Tuần')),
                  ),
                  ButtonSegment(
                    value: 'month',
                    label: Text(tr(context, 'Months', 'Tháng')),
                  ),
                ],
                selected: {unit},
                onSelectionChanged: (v) => set(() => unit = v.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr(context, 'Cancel', 'Huỷ')),
            ),
            FilledButton(
              key: const Key('span-apply'),
              onPressed: () => Navigator.pop(context, TimeSpan(unit, count)),
              child: Text(tr(context, 'Show', 'Xem')),
            ),
          ],
        ),
      ),
    );
    if (picked != null) widget.onSpan(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BoardsPalette.of(context);
    final buckets = _buckets(context);
    _toToday();
    final presets = const [
      TimeSpan('day', 1),
      TimeSpan('day', 3),
      TimeSpan('week', 1),
      TimeSpan('week', 2),
      TimeSpan('month', 1),
      TimeSpan('month', 3),
    ];
    final columns = {
      for (final c in columnsOf(widget.state, widget.board))
        c.id: c.flag('done'),
    };
    final desktop = {
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
    }.contains(defaultTargetPlatform);

    Widget tile(BoardRecord card) {
      final t = CardTile(
        key: ValueKey('time-card-${card.id}'),
        state: widget.state,
        card: card,
        now: widget.now,
        done: columns[card.str('status')] ?? false,
        onOpen: widget.open == null ? null : () => widget.open!(card),
      );
      if (widget.setDue == null) return t;
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
                childWhenDragging: Opacity(opacity: .35, child: t),
                child: t,
              )
            : LongPressDraggable<String>(
                data: card.id,
                feedback: feedback,
                childWhenDragging: Opacity(opacity: .35, child: t),
                onDragStarted: HapticFeedback.mediumImpact,
                child: t,
              ),
      );
    }

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
                        color: b.overdue
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
          final compact = !column && b.cards.isEmpty && b.key != 'none';
          final body = [
            head,
            for (final c in b.cards) tile(c),
            if (b.cards.isEmpty && !compact) empty,
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
                    width: 260,
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

    final bar = Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 8),
      child: Row(
        children: [
          IconButton(
            key: const Key('time-prev'),
            tooltip: tr(context, 'Earlier', 'Trước'),
            onPressed: () => _shift(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Flexible(
            child: Text(
              _range(context),
              key: const Key('time-range'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ),
          IconButton(
            key: const Key('time-next'),
            tooltip: tr(context, 'Later', 'Sau'),
            onPressed: () => _shift(1),
            icon: const Icon(Icons.chevron_right),
          ),
          if (MediaQuery.sizeOf(context).width < 600)
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
          const Spacer(),
          PopupMenuButton<Object>(
            key: const Key('time-span'),
            tooltip: tr(context, 'How long to show', 'Khoảng thời gian'),
            onSelected: (v) => v is TimeSpan ? widget.onSpan(v) : _custom(),
            itemBuilder: (context) => [
              for (final s in presets)
                CheckedPopupMenuItem<Object>(
                  key: Key('span-${s.unit}-${s.count}'),
                  value: s,
                  checked: s == widget.span,
                  child: Text(s.label(context)),
                ),
              const PopupMenuDivider(),
              PopupMenuItem<Object>(
                key: const Key('span-custom'),
                value: 'custom',
                child: Text(tr(context, 'Custom…', 'Tuỳ chỉnh…')),
              ),
            ],
            child: Chip(
              avatar: const Icon(Icons.date_range, size: 18),
              label: Text(widget.span.label(context)),
            ),
          ),
        ],
      ),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _shift(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _shift(1),
      },
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 600;
          // Wide: the tray first, as a column like the days; phones: last.
          final ordered = wide
              ? [buckets.last, ...buckets.take(buckets.length - 1)]
              : buckets;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              bar,
              Expanded(
                child: wide
                    ? ListView(
                        key: const Key('time-columns'),
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(24, 0, 12, 8),
                        children: [
                          for (final b in ordered) section(b, column: true),
                        ],
                      )
                    : ListView(
                        key: const Key('time-list'),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          for (final b in ordered) section(b, column: false),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
