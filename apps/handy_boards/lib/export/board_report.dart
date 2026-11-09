import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../ui/look.dart';

const _ink = Color(0xFF231A21), _muted = Color(0xFF62575F);
const _rule = Color(0xFFD9D1D3), _bar = Color(0xFFB53C0A);

/// Export › Report (Pro): one page that answers "where does this board
/// stand?": four figures, finished per week for 8 weeks (real completion
/// times), progress by category, and the open cards in deadline order with
/// their column, category, dates and, when asked, custom fields. Fixed light
/// colours so the saved file reads the same on any device.
class BoardReport extends StatelessWidget {
  final BoardsState state;
  final String board;
  final DateTime now;
  final bool fields;
  const BoardReport({
    super.key,
    required this.state,
    required this.board,
    required this.now,
    this.fields = false,
  });

  @override
  Widget build(BuildContext context) {
    final s = state, b = s.get('boards', board);
    final vi = Localizations.localeOf(context).languageCode == 'vi';
    final loc = MaterialLocalizations.of(context);
    final sum = boardSummary(s, board, now: now);
    final weeks = weeklyThroughput(s, board, now);
    final most = weeks.fold(1, (m, w) => w.$2 > m ? w.$2 : m);
    final cats = [
      for (final c in categoryProgress(s, board))
        if (c.total > 0) c,
    ];
    final shownFields = fields ? fieldsOf(s, board) : const <BoardRecord>[];
    final today = calendarDay(now);
    final open =
        [
          for (final c in topTasks(s, board: board))
            if (isOpenCard(s, c)) c,
        ]..sort((a, b) {
          final da = dueDay(a) ?? scheduledDay(a),
              db = dueDay(b) ?? scheduledDay(b);
          if (da == null && db == null)
            return a.str('title').compareTo(b.str('title'));
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db);
        });
    String day(DateTime? d) => d == null ? '' : loc.formatShortMonthDay(d);
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    );
    Widget figure(String value, String label) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
          ),
          Text(label, style: const TextStyle(fontSize: 13, color: _muted)),
        ],
      ),
    );
    final cell = const TextStyle(fontSize: 13);
    final head = const TextStyle(
      fontSize: 12,
      color: _muted,
      fontWeight: FontWeight.w600,
    );
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.light,
        extensions: [BoardsPalette.light],
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontFamily: handyFontFamily('PlusJakartaSans'),
          color: _ink,
          fontSize: 14,
        ),
        child: Container(
          key: const Key('board-report'),
          width: 820,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(40, 36, 40, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                b.str('title'),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  context,
                  'Progress report · ${loc.formatFullDate(today)}',
                  'Báo cáo tiến độ · ${loc.formatFullDate(today)}',
                ),
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  figure(
                    '${sum.cards - sum.done}',
                    tr(context, 'open', 'đang mở'),
                  ),
                  figure('${sum.done}', tr(context, 'done', 'đã xong')),
                  figure(
                    '${sum.dueToday}',
                    tr(context, 'due today', 'hạn hôm nay'),
                  ),
                  figure('${sum.overdue}', tr(context, 'overdue', 'quá hạn')),
                ],
              ),
              heading(tr(context, 'Finished per week', 'Hoàn thành mỗi tuần')),
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final (monday, n) in weeks)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('$n', style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              Container(
                                height: n == 0 ? 2 : 70 * n / most,
                                color: n == 0 ? _rule : _bar,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                day(monday),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                tr(
                  context,
                  'Cards counted in the week they reached a finished column.',
                  'Thẻ được tính vào tuần nó vào cột hoàn thành.',
                ),
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
              if (cats.isNotEmpty) ...[
                heading(tr(context, 'By category', 'Theo nhóm')),
                for (final c in cats)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 200,
                          child: Text(
                            categoryName(context, c.category),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: c.total == 0 ? 0 : c.done / c.total,
                              minHeight: 8,
                              color: categoryHue(context, c.category).mark,
                              backgroundColor: const Color(0xFFEDE7E8),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          child: Text(
                            '${c.done}/${c.total}',
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              heading(
                tr(
                  context,
                  'Open cards (${open.length})',
                  'Thẻ đang mở (${open.length})',
                ),
              ),
              if (open.isEmpty)
                Text(
                  tr(context, 'Nothing open.', 'Không còn thẻ mở.'),
                  style: const TextStyle(color: _muted),
                )
              else
                Table(
                  columnWidths: {
                    0: const FlexColumnWidth(3),
                    for (var i = 1; i < 5 + shownFields.length; i++)
                      i: const FlexColumnWidth(1.4),
                  },
                  border: const TableBorder(
                    horizontalInside: BorderSide(color: _rule),
                    bottom: BorderSide(color: _rule),
                  ),
                  children: [
                    TableRow(
                      children: [
                        for (final h in [
                          tr(context, 'Card', 'Thẻ'),
                          tr(context, 'Column', 'Cột'),
                          tr(context, 'Category', 'Nhóm'),
                          tr(context, 'Due', 'Hạn'),
                          tr(context, 'Planned', 'Dự định'),
                          for (final f in shownFields) f.str('title'),
                        ])
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(h, style: head),
                          ),
                      ],
                    ),
                    for (final c in open.take(80))
                      TableRow(
                        children: [
                          for (final v in [
                            c.str('title'),
                            s
                                    .maybe('statuses', c.str('status'))
                                    ?.str('title') ??
                                '',
                            c.data['category'] == null
                                ? ''
                                : categoryName(
                                    context,
                                    s.maybe('categories', c.str('category')),
                                  ),
                            day(dueDay(c)) +
                                (dueDay(c) != null && dueDay(c)!.isBefore(today)
                                    ? tr(context, ' (late)', ' (trễ)')
                                    : ''),
                            day(scheduledDay(c)),
                            for (final f in shownFields)
                              (c.data['custom'] as Map?)?[f.id] == null
                                  ? ''
                                  : fieldText(
                                      f,
                                      (c.data['custom'] as Map)[f.id],
                                      vi: vi,
                                    ),
                          ])
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 2,
                              ),
                              child: Text(v, style: cell),
                            ),
                        ],
                      ),
                  ],
                ),
              if (open.length > 80)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    tr(
                      context,
                      '+${open.length - 80} more; the CSV export has every card.',
                      '+${open.length - 80} thẻ nữa; bản CSV có đủ mọi thẻ.',
                    ),
                    style: const TextStyle(color: _muted),
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'Handy Boards',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom field values of [card] as "Name: value" lines, for the poster
/// cards when fields are included.
List<String> cardFieldLines(
  BoardsState s,
  BoardRecord card, {
  bool vi = false,
}) {
  final values = card.data['custom'];
  if (values is! Map) return const [];
  return [
    for (final f in fieldsOf(s, card.str('board')))
      if (values[f.id] != null && '${values[f.id]}'.isNotEmpty)
        '${f.str('title')}: ${fieldText(f, values[f.id], vi: vi)}',
  ];
}
