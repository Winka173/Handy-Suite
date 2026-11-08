import 'package:handy_ui/kit.dart';
import '../covers/cover_art.dart';
import '../design/theme.dart';

/// The pictures of How to use: small pieces of a Boards screen drawn in the
/// app's own colours (never a photo of one), each with the one place a step
/// is about ringed in the hue.

/// A cut-out of a screen: a surface with an optional title bar.
class MockCard extends StatelessWidget {
  final String? title;
  final Widget child;
  const MockCard({super.key, this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    // A picture, not text to read: its words keep their normal size (the
    // step above it carries the meaning at the reader's size), and on a
    // narrow screen the whole picture is drawn at 340 px and scaled down.
    final picture = Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(BoardsRadii.tile),
        border: Border.all(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: p.line)),
              ),
              child: Text(
                title!,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
    return ExcludeSemantics(
      child: MediaQuery.withNoTextScaling(
        child: LayoutBuilder(
          builder: (context, box) => box.maxWidth >= 340
              ? picture
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: SizedBox(width: 340, child: picture),
                ),
        ),
      ),
    );
  }
}

/// A ring around the place to tap.
class Ringed extends StatelessWidget {
  final Widget child;
  final double radius;
  const Ringed({super.key, required this.child, this.radius = 12});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius + 3),
      border: Border.all(color: BoardsPalette.of(context).primary, width: 2.5),
    ),
    child: child,
  );
}

Widget _ring(bool on, Widget child, {double radius = 12}) =>
    on ? Ringed(radius: radius, child: child) : child;

/// A row of chips; one is ringed.
class MockChips extends StatelessWidget {
  final List<(IconData?, String)> chips;
  final int ringed;
  final String? title;
  const MockChips({
    super.key,
    required this.chips,
    this.ringed = 0,
    this.title,
  });
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    Widget chip((IconData?, String) c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: p.raised,
        borderRadius: BorderRadius.circular(BoardsRadii.chip),
        border: Border.all(color: p.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c.$1 != null) ...[
            Icon(c.$1, size: 16, color: p.ink),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              c.$2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
    return MockCard(
      title: title,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final (i, c) in chips.indexed)
            _ring(i == ringed, chip(c), radius: BoardsRadii.chip),
        ],
      ),
    );
  }
}

/// Settings-like lines with an icon, one ringed.
class MockRows extends StatelessWidget {
  final List<(IconData, String)> rows;
  final int ringed;
  final String? title;
  const MockRows({super.key, required this.rows, this.ringed = 0, this.title});
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    Widget row((IconData, String) r) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        children: [
          Icon(r.$1, size: 20, color: p.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(r.$2, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Icon(Icons.chevron_right, size: 18, color: p.muted),
        ],
      ),
    );
    return MockCard(
      title: title,
      child: Column(
        children: [
          for (final (i, r) in rows.indexed)
            _ring(i == ringed, row(r), radius: 8),
        ],
      ),
    );
  }
}

/// One card as it sits in a column: its category dot, title and a small
/// subtask count.
Widget _card(
  BuildContext context,
  String title, {
  int hue = 0,
  String? count,
  bool done = false,
  bool lifted = false,
}) {
  final p = BoardsPalette.of(context);
  final h = HandyPalette.of(context, hue);
  final text = Theme.of(context).textTheme;
  return Container(
    padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
    decoration: BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(BoardsRadii.card - 4),
      border: Border.all(color: lifted ? p.primary : p.line),
      boxShadow: lifted
          ? [
              BoxShadow(
                color: p.ink.withValues(alpha: .14),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(color: h.mark, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? p.muted : p.ink,
                ),
              ),
            ),
          ],
        ),
        if (count != null)
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 12),
            child: Text(
              count,
              style: text.labelSmall?.copyWith(color: p.muted),
            ),
          ),
      ],
    ),
  );
}

/// Three columns of a board. [ringAdd] rings the first column's
/// "Add a card"; [drag] lifts a card between the first two columns with an
/// arrow; [ringMove] rings a card's Move to….
class MockColumns extends StatelessWidget {
  final bool ringAdd, drag, ringDone;
  const MockColumns({
    super.key,
    this.ringAdd = false,
    this.drag = false,
    this.ringDone = false,
  });
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final text = Theme.of(context).textTheme;
    Widget column(String title, int n, List<Widget> cards, {Widget? foot}) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: p.sunk,
              borderRadius: BorderRadius.circular(BoardsRadii.control),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
                  child: Text(
                    '$title  $n',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final c in cards) ...[c, const SizedBox(height: 5)],
                ?foot,
              ],
            ),
          ),
        );
    final add = Padding(
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          Icon(Icons.add, size: 14, color: p.muted),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              tr(context, 'Add a card', 'Thêm thẻ'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(color: p.muted),
            ),
          ),
        ],
      ),
    );
    final moving = _card(
      context,
      tr(context, 'Read', 'Đọc bài'),
      hue: 1,
      count: '1/3',
      lifted: drag,
    );
    return MockCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              column(
                tr(context, 'To do', 'Cần làm'),
                drag ? 1 : 2,
                [
                  _card(context, tr(context, 'Essay', 'Dàn ý')),
                  if (!drag) moving,
                ],
                foot: _ring(ringAdd, add, radius: 8),
              ),
              const SizedBox(width: 6),
              column(tr(context, 'Doing', 'Đang làm'), 1, [
                _card(
                  context,
                  tr(context, 'Report', 'Báo cáo'),
                  hue: 2,
                  count: '2/4',
                ),
              ]),
              const SizedBox(width: 6),
              column(tr(context, 'Done', 'Xong'), 1, [
                _ring(
                  ringDone,
                  _card(
                    context,
                    tr(context, 'Quiz', 'Ôn thi'),
                    hue: 1,
                    done: true,
                  ),
                  radius: 8,
                ),
              ]),
            ],
          ),
          // The card being dragged, lifted under the columns and
          // heading up to Doing.
          if (drag)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: Transform.rotate(angle: -.04, child: moving),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.north_east_rounded, color: p.primary, size: 28),
                  const Spacer(flex: 3),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The category strip: each category with done/total and a thin bar.
class MockStrip extends StatelessWidget {
  final int ringed;
  const MockStrip({super.key, this.ringed = -1});
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final text = Theme.of(context).textTheme;
    final rows = [
      (tr(context, 'Maths', 'Toán'), 2, 5),
      (tr(context, 'Literature', 'Văn'), 1, 3),
      (tr(context, 'Chemistry', 'Hoá'), 3, 4),
      (tr(context, 'English', 'Tiếng Anh'), 0, 2),
    ];
    Widget tile(int i) {
      final (name, done, total) = rows[i];
      final h = HandyPalette.of(context, i);
      return Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
        decoration: BoxDecoration(
          color: h.tint,
          borderRadius: BorderRadius.circular(BoardsRadii.control),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text('$done/$total', style: text.labelSmall),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: done / total,
                minHeight: 3,
                color: h.mark,
                backgroundColor: p.surface,
              ),
            ),
          ],
        ),
      );
    }

    return MockCard(
      child: Column(
        children: [
          for (final r in [0, 2]) ...[
            Row(
              children: [
                Expanded(child: _ring(ringed == r, tile(r))),
                const SizedBox(width: 6),
                Expanded(child: _ring(ringed == r + 1, tile(r + 1))),
              ],
            ),
            if (r == 0) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

/// A card's detail: its chips and subtasks with progress.
class MockCardDetail extends StatelessWidget {
  /// 'subtask', 'due' or 'cover'.
  final String ring;
  const MockCardDetail({super.key, this.ring = 'subtask'});
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final text = Theme.of(context).textTheme;
    Widget chip(IconData icon, String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: p.raised,
        borderRadius: BorderRadius.circular(BoardsRadii.chip),
        border: Border.all(color: p.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: p.ink),
          const SizedBox(width: 4),
          Text(label, style: text.labelMedium),
        ],
      ),
    );
    Widget sub(String label, bool done) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_box : Icons.check_box_outline_blank,
            size: 18,
            color: done ? p.primary : p.muted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(
                decoration: done ? TextDecoration.lineThrough : null,
                color: done ? p.muted : p.ink,
              ),
            ),
          ),
        ],
      ),
    );
    final subtasks = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, 'Subtasks  1/3', 'Việc con  1/3'),
          style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        sub(tr(context, 'Read pages 40–52', 'Đọc trang 40–52'), true),
        sub(tr(context, 'Write a summary', 'Viết tóm tắt'), false),
        sub(tr(context, 'Do exercises 1–5', 'Làm bài 1–5'), false),
      ],
    );
    return MockCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr(context, 'Read chapter 3', 'Đọc chương 3'),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _ring(
                ring == 'cover',
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: const SizedBox(
                    width: 52,
                    height: 34,
                    child: CoverArt('study.open-book'),
                  ),
                ),
                radius: 8,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ring(
                ring == 'due',
                chip(Icons.event_outlined, tr(context, 'Thu 13', 'T5 13/11')),
                radius: BoardsRadii.chip,
              ),
              chip(
                Icons.notifications_none,
                tr(context, 'Remind 19:00', 'Nhắc 19:00'),
              ),
              chip(Icons.repeat, tr(context, 'Weekly', 'Hằng tuần')),
            ],
          ),
          const SizedBox(height: 10),
          _ring(ring == 'subtask', subtasks, radius: 8),
        ],
      ),
    );
  }
}

/// The Board | Time switch over a few days.
class MockTime extends StatelessWidget {
  const MockTime({super.key});
  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final text = Theme.of(context).textTheme;
    Widget segment(String label, bool on) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: on ? p.tint : null,
        borderRadius: BorderRadius.circular(BoardsRadii.chip),
      ),
      child: Text(
        label,
        style: text.labelLarge?.copyWith(
          fontWeight: on ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
    Widget day(String label, List<Widget> cards, {bool today = false}) =>
        Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: today ? p.tint : p.sunk,
            borderRadius: BorderRadius.circular(BoardsRadii.control),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label,
                style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              for (final c in cards) ...[const SizedBox(height: 5), c],
            ],
          ),
        );
    return MockCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  border: Border.all(color: p.line),
                  borderRadius: BorderRadius.circular(BoardsRadii.chip),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    segment(tr(context, 'Board', 'Bảng'), false),
                    Ringed(
                      radius: BoardsRadii.chip,
                      child: segment(tr(context, 'Time', 'Thời gian'), true),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                tr(context, 'Week', 'Tuần'),
                style: text.labelLarge?.copyWith(color: p.muted),
              ),
              Icon(Icons.expand_more, size: 18, color: p.muted),
            ],
          ),
          day(tr(context, 'Today · Fri 7', 'Hôm nay · T6 7/11'), [
            _card(
              context,
              tr(context, 'Report', 'Báo cáo'),
              hue: 2,
              count: '2/4',
            ),
          ], today: true),
          day(tr(context, 'Sat 8', 'T7 8/11'), [
            _card(
              context,
              tr(context, 'Read chapter 3', 'Đọc chương 3'),
              hue: 1,
              count: '1/3',
            ),
          ]),
        ],
      ),
    );
  }
}

/// A row of covers, one ringed: "a colour for each board".
class MockCovers extends StatelessWidget {
  const MockCovers({super.key});
  @override
  Widget build(BuildContext context) => MockCard(
    child: Row(
      children: [
        for (final (i, id) in const [
          'study.notebook-grid',
          'study.open-book',
          'study.pencil-case',
          'study.orbital-notes',
        ].indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _ring(
              i == 1,
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(aspectRatio: 1.5, child: CoverArt(id)),
              ),
              radius: 8,
            ),
          ),
        ],
      ],
    ),
  );
}
