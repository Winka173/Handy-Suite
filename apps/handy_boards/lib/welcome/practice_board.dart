import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:handy_ui/kit.dart';
import 'motion.dart';

/// Where the practice is: add a card, move it to Doing, focus its
/// category (the other cards stay), tick one of its subtasks, done.
enum PracticeStep { add, drag, focus, tick, done }

/// A small pretend board for the guide, drawn at a phone's real size: three
/// columns, a few cards with their categories, and the category strip.
/// Everything is dark except the one thing to do next, in a lit window with
/// a word beside it. The card really drags; the category really lights up
/// its cards without hiding the others. Nothing is written anywhere.
class PracticeBoard extends StatefulWidget {
  final ValueChanged<PracticeStep> onStep;
  const PracticeBoard({super.key, required this.onStep});
  @override
  State<PracticeBoard> createState() => PracticeBoardState();
}

class PracticeBoardState extends State<PracticeBoard> {
  PracticeStep step = PracticeStep.add;

  /// Column of the practice card: 0 To Do, 1 Doing, 2 Done.
  int column = -1;
  bool focused = false;
  final card = GlobalKey(),
      chip = GlobalKey(),
      doing = GlobalKey(),
      tick = GlobalKey();
  bool ticked = false;
  final adder = GlobalKey(), finished = GlobalKey();

  void _add() {
    if (step != PracticeStep.add) return;
    setState(() => column = 0);
    _to(PracticeStep.drag);
  }

  void _to(PracticeStep next) {
    setState(() => step = next);
    widget.onStep(next);
  }

  /// The drag-free way through (the guide's "Move it for me").
  void advance() {
    switch (step) {
      case PracticeStep.add:
        _add();
      case PracticeStep.drag:
        _drop(1);
      case PracticeStep.focus:
        _focus();
      case PracticeStep.tick:
        _tick();
      case PracticeStep.done:
        break;
    }
  }

  void _drop(int to) {
    if (step == PracticeStep.drag && to == 1) {
      setState(() => column = 1);
      _to(PracticeStep.focus);
    }
  }

  void _focus() {
    if (step != PracticeStep.focus) return;
    setState(() => focused = true);
    _to(PracticeStep.tick);
  }

  void _tick() {
    if (step != PracticeStep.tick) return;
    setState(() => ticked = true);
    _to(PracticeStep.done);
  }

  @override
  Widget build(BuildContext context) {
    final target = switch (step) {
      PracticeStep.add => adder,
      PracticeStep.drag => card,
      PracticeStep.focus => chip,
      PracticeStep.tick => tick,
      PracticeStep.done => null,
    };
    final label = switch (step) {
      PracticeStep.add => tr(context, 'Tap Add card', 'Chạm Thêm thẻ'),
      PracticeStep.drag => tr(
        context,
        'Hold, then drag to Doing',
        'Giữ rồi kéo sang Đang làm',
      ),
      PracticeStep.focus => tr(context, 'Tap Maths', 'Chạm Toán'),
      PracticeStep.tick => tr(context, 'Tick a subtask', 'Tick một việc con'),
      PracticeStep.done => null,
    };
    final dragTo = switch (step) {
      PracticeStep.drag => doing,
      _ => null,
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        Spotlight(
          target: target,
          label: label,
          radius: 14,
          child: _Board(state: this),
        ),
        // Over the dark: an arrow from the card to where it goes.
        if (dragTo != null)
          IgnorePointer(
            child: DragHint(key: ValueKey(step), from: card, to: dragTo),
          ),
      ],
    );
  }
}

/// A curved arrow drawn from [from] to [to] (two widgets on the board),
/// with a light running along it: "drag this there". It draws itself a few
/// times, then rests; with reduced motion it is simply there.
class DragHint extends StatefulWidget {
  final GlobalKey from, to;
  const DragHint({super.key, required this.from, required this.to});
  @override
  State<DragHint> createState() => _DragHintState();
}

class _DragHintState extends State<DragHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController run = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  Offset? a, b;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!run.isAnimating && run.value == 0) {
      if (moves(context)) {
        // Three runs, then the whole arrow stays drawn.
        run.repeat(count: 3).whenCompleteOrCancel(() {
          if (mounted) run.value = 1;
        });
      } else {
        run.value = 1;
      }
    }
  }

  @override
  void dispose() {
    run.dispose();
    super.dispose();
  }

  /// Where the card and the target column are, in this layer's space:
  /// from the card's right edge to the target column, a little below its
  /// heading.
  void _measure() {
    if (!mounted) return;
    final me = context.findRenderObject() as RenderBox?;
    final from = widget.from.currentContext?.findRenderObject() as RenderBox?;
    final to = widget.to.currentContext?.findRenderObject() as RenderBox?;
    if (me == null ||
        from == null ||
        to == null ||
        !me.hasSize ||
        !from.hasSize ||
        !to.hasSize)
      return;
    final f = me.globalToLocal(
      from.localToGlobal(Offset(from.size.width - 4, from.size.height * .5)),
    );
    // Into the empty part of the target column, under the cards it holds.
    final top = me.globalToLocal(to.localToGlobal(Offset.zero));
    final t = Offset(
      top.dx + to.size.width * .55,
      math.min(f.dy + 48, top.dy + to.size.height - 40),
    );
    if (f != a || t != b) {
      setState(() {
        a = f;
        b = t;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    if (a == null || b == null) return const SizedBox.expand();
    return AnimatedBuilder(
      animation: run,
      builder: (context, _) =>
          CustomPaint(size: Size.infinite, painter: _Arrow(a!, b!, run.value)),
    );
  }
}

class _Arrow extends CustomPainter {
  final Offset a, b;
  final double t;
  _Arrow(this.a, this.b, this.t);
  static const _ink = Color(0xFFF6B08F);

  @override
  void paint(Canvas canvas, Size size) {
    // A soft arc over the columns, rising between the two ends.
    final mid = Offset((a.dx + b.dx) / 2 + 10, math.min(a.dy, b.dy) - 10);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
    final metric = path.computeMetrics().first;
    // Drawn in over the first 60 % of each run, then held.
    final drawn = (t / .6).clamp(0.0, 1.0);
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    // Dashes, so it reads as a gesture rather than a line on the board.
    final length = metric.length * drawn;
    for (var d = 0.0; d < length; d += 14) {
      canvas.drawPath(metric.extractPath(d, math.min(d + 8, length)), stroke);
    }
    if (drawn >= 1) {
      final end = metric.getTangentForOffset(metric.length)!;
      final dir = end.vector / end.vector.distance;
      final normal = Offset(-dir.dy, dir.dx);
      final tip = end.position;
      final head = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(
          tip.dx - dir.dx * 14 + normal.dx * 9,
          tip.dy - dir.dy * 14 + normal.dy * 9,
        )
        ..lineTo(
          tip.dx - dir.dx * 14 - normal.dx * 9,
          tip.dy - dir.dy * 14 - normal.dy * 9,
        )
        ..close();
      canvas.drawPath(head, Paint()..color = _ink);
    }
    // The light that travels along it once it is drawn.
    if (t > .6 && t < 1) {
      final at = metric
          .getTangentForOffset(metric.length * ((t - .6) / .4))!
          .position;
      canvas.drawCircle(
        at,
        7,
        Paint()
          ..color = Colors.white
          ..maskFilter = const ui.MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(at, 4, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_Arrow old) => old.t != t || old.a != a || old.b != b;
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
          tr(context, 'Learn 20 new words', 'Học 20 từ mới'),
          _home,
          tr(context, 'English', 'Tiếng Anh'),
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
      // Focusing a category lights its cards with a ring; the others stay
      // where they are, quieter (as in the app). Nothing is hidden.
      final quiet = s.focused && hue != _maths;
      final lit = s.focused && hue == _maths;
      return AnimatedOpacity(
        duration: HandyMotion.of(context, HandyMotion.medium),
        opacity: quiet ? .4 : 1,
        child: Container(
          key: key,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            color: GuideColors.card,
            borderRadius: BorderRadius.circular(10),
            border: lit ? Border.all(color: hue.$1, width: 2.5) : null,
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
              // In Doing, once focused: two of its subtasks, one to tick.
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
    final canDrag = s.step == PracticeStep.drag;
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
                  (tr(context, 'English', 'Tiếng Anh'), _home, null),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      key: key,
                      onTap: key == null ? null : s._focus,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: key != null && s.focused
                              ? GuideColors.tint
                              : GuideColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: key != null && s.focused
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
                        key: i == 1 ? s.doing : (i == 2 ? s.finished : null),
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
                              if (s.column == i)
                                // The new card arrives: it grows in and settles.
                                TweenAnimationBuilder<double>(
                                  key: ValueKey('mine-$i'),
                                  tween: Tween(
                                    begin: i == 0 && moves(context) ? 0 : 1,
                                    end: 1,
                                  ),
                                  duration: const Duration(milliseconds: 420),
                                  curve: Curves.easeOutBack,
                                  builder: (context, t, child) => Opacity(
                                    opacity: t.clamp(0.0, 1.0),
                                    child: Transform.scale(
                                      scale: .85 + .15 * t,
                                      child: child,
                                    ),
                                  ),
                                  child: draggable,
                                ),
                              for (final o in others[i]!)
                                tile(o.$1, o.$2, o.$3, done: i == 2),
                              if (i == 0)
                                GestureDetector(
                                  key: s.adder,
                                  onTap: s._add,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 2,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.add,
                                          size: 16,
                                          color: GuideColors.tealDeep,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            tr(context, 'Add card', 'Thêm thẻ'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: GuideColors.tealDeep,
                                            ),
                                          ),
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
