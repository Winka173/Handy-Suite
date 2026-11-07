import 'package:handy_ui/kit.dart';
import 'motion.dart';

/// Where the practice is: move the card to Doing, filter by its category,
/// tick one of its subtasks, finish it, done.
enum PracticeStep { drag, filter, tick, finish, done }

/// A small pretend board for the guide, drawn at a phone's real size: three
/// columns, a few cards with their categories, and the category strip.
/// Everything is dark except the one thing to do next, in a lit window with
/// a word beside it. The card really drags; the category really filters.
/// Nothing is written anywhere.
class PracticeBoard extends StatefulWidget {
  final ValueChanged<PracticeStep> onStep;
  const PracticeBoard({super.key, required this.onStep});
  @override
  State<PracticeBoard> createState() => PracticeBoardState();
}

class PracticeBoardState extends State<PracticeBoard> {
  PracticeStep step = PracticeStep.drag;

  /// Column of the practice card: 0 To Do, 1 Doing, 2 Done.
  int column = 0;
  bool filtered = false;
  final card = GlobalKey(),
      chip = GlobalKey(),
      doing = GlobalKey(),
      tick = GlobalKey();
  bool ticked = false;

  void _to(PracticeStep next) {
    setState(() => step = next);
    widget.onStep(next);
  }

  /// The drag-free way through (the guide's "Move it for me").
  void advance() {
    switch (step) {
      case PracticeStep.drag:
        _drop(1);
      case PracticeStep.filter:
        _filter();
      case PracticeStep.tick:
        _tick();
      case PracticeStep.finish:
        _drop(2);
      case PracticeStep.done:
        break;
    }
  }

  void _drop(int to) {
    if (step == PracticeStep.drag && to == 1) {
      setState(() => column = 1);
      _to(PracticeStep.filter);
    } else if (step == PracticeStep.finish && to == 2) {
      setState(() => column = 2);
      _to(PracticeStep.done);
    }
  }

  void _filter() {
    if (step != PracticeStep.filter) return;
    setState(() => filtered = true);
    _to(PracticeStep.tick);
  }

  void _tick() {
    if (step != PracticeStep.tick) return;
    setState(() => ticked = true);
    _to(PracticeStep.finish);
  }

  @override
  Widget build(BuildContext context) {
    final target = switch (step) {
      PracticeStep.drag || PracticeStep.finish => card,
      PracticeStep.filter => chip,
      PracticeStep.tick => tick,
      PracticeStep.done => null,
    };
    final label = switch (step) {
      PracticeStep.drag => tr(
        context,
        'Hold, then drag to Doing',
        'Giữ rồi kéo sang Đang làm',
      ),
      PracticeStep.filter => tr(context, 'Tap Maths', 'Chạm Toán'),
      PracticeStep.tick => tr(context, 'Tick a subtask', 'Tick một việc con'),
      PracticeStep.finish => tr(context, 'Drag it to Done', 'Kéo sang Xong'),
      PracticeStep.done => null,
    };
    return Spotlight(
      target: target,
      label: label,
      radius: 14,
      child: _Board(state: this),
    );
  }
}

const _maths = (Color(0xFF3A6FD8), Color(0xFFE3EBFA));
const _lit = (Color(0xFFD9930B), Color(0xFFFBEFD8));
const _home = (Color(0xFF3E9A4B), Color(0xFFE2F1E4));

class _Board extends StatelessWidget {
  final PracticeBoardState state;
  const _Board({required this.state});
  @override
  Widget build(BuildContext context) {
    final s = state;
    final columns = [
      tr(context, 'To Do', 'Cần làm'),
      tr(context, 'Doing', 'Đang làm'),
      tr(context, 'Done', 'Xong'),
    ];
    // The other cards on the board, by column.
    final others = <int, List<(String, (Color, Color), String)>>{
      0: [
        (
          tr(context, 'Outline the essay', 'Lập dàn ý bài Văn'),
          _lit,
          tr(context, 'Literature', 'Văn'),
        ),
      ],
      1: [
        (
          tr(context, 'Buy markers', 'Mua bút dạ'),
          _home,
          tr(context, 'Home', 'Việc nhà'),
        ),
      ],
      2: [
        (
          tr(context, 'Unit 2 test', 'Kiểm tra bài 2'),
          _maths,
          tr(context, 'Maths', 'Toán'),
        ),
      ],
    };
    Widget tile(
      String title,
      (Color, Color) hue,
      String cat, {
      Key? key,
      bool done = false,
      bool mine = false,
    }) {
      final dim = s.filtered && hue != _maths;
      return AnimatedOpacity(
        duration: HandyMotion.of(context, HandyMotion.medium),
        opacity: dim ? .25 : 1,
        child: Container(
          key: key,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            color: GuideColors.card,
            borderRadius: BorderRadius.circular(10),
            boxShadow: mine
                ? const [
                    BoxShadow(
                      color: GuideColors.shadow,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: done ? GuideColors.muted : GuideColors.ink,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: hue.$2,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: hue.$1,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        cat,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: GuideColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (mine && s.column < 2) ...[
                const SizedBox(height: 4),
                Text(
                  s.ticked ? '3/5' : '2/5',
                  style: const TextStyle(
                    fontSize: 11,
                    color: GuideColors.muted,
                  ),
                ),
              ],
              // In Doing, once filtered: two of its subtasks, one to tick.
              if (mine &&
                  key != null &&
                  s.column == 1 &&
                  s.step.index >= PracticeStep.tick.index) ...[
                const SizedBox(height: 6),
                for (final (title, done, rowKey) in [
                  (
                    tr(context, 'Review the formula', 'Ôn công thức'),
                    true,
                    null,
                  ),
                  (
                    tr(context, 'Five exercises', 'Làm 5 bài tập'),
                    s.ticked,
                    s.tick,
                  ),
                ])
                  GestureDetector(
                    key: rowKey,
                    onTap: rowKey == null ? null : s._tick,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(
                            done
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            size: 16,
                            color: done ? GuideColors.teal : GuideColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: done
                                    ? GuideColors.muted
                                    : GuideColors.ink,
                                decoration: done
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
    }

    // Only the card on the board carries the spotlight's key; its copies
    // (the one being dragged, the ghost left behind) do not.
    Widget mineTile([Key? key]) => tile(
      tr(context, 'Revise chapter 3', 'Ôn chương 3'),
      _maths,
      tr(context, 'Maths', 'Toán'),
      key: key,
      mine: true,
      done: s.column == 2,
    );
    final mine = mineTile(s.card);
    final canDrag =
        s.step == PracticeStep.drag || s.step == PracticeStep.finish;
    final draggable = !canDrag
        ? mine
        : LayoutBuilder(
            builder: (context, box) => Draggable<String>(
              data: 'mine',
              feedback: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: box.maxWidth,
                  child: Transform.rotate(
                    angle: moves(context) ? -.04 : 0,
                    child: mineTile(),
                  ),
                ),
              ),
              childWhenDragging: Opacity(opacity: .3, child: mineTile()),
              child: mine,
            ),
          );

    return ColoredBox(
      color: const Color(0xFFE6EFE4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(
                tr(context, 'Semester 1', 'Học kỳ 1'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: GuideColors.ink,
                ),
              ),
            ),
            Wrap(
              runSpacing: 6,
              children: [
                for (final (name, hue, key) in [
                  (tr(context, 'Maths', 'Toán'), _maths, s.chip),
                  (tr(context, 'Literature', 'Văn'), _lit, null),
                  (tr(context, 'Home', 'Việc nhà'), _home, null),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      key: key,
                      onTap: key == null ? null : s._filter,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: key != null && s.filtered
                              ? GuideColors.tint
                              : GuideColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: key != null && s.filtered
                              ? Border.all(color: GuideColors.teal, width: 1.5)
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: hue.$1,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: GuideColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: DragTarget<String>(
                        key: i == 1 ? s.doing : null,
                        onAcceptWithDetails: (_) => s._drop(i),
                        builder: (context, candidates, _) => AnimatedContainer(
                          duration: HandyMotion.of(context, HandyMotion.short),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: candidates.isNotEmpty
                                ? GuideColors.tint
                                : const Color(0x8CFFFFFF),
                            borderRadius: BorderRadius.circular(12),
                            border: candidates.isNotEmpty
                                ? Border.all(
                                    color: GuideColors.teal,
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
                                child: Text(
                                  columns[i],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: GuideColors.ink,
                                  ),
                                ),
                              ),
                              if (s.column == i) draggable,
                              for (final o in others[i]!)
                                tile(o.$1, o.$2, o.$3, done: i == 2),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
