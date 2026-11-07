import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import 'motion.dart';

/// One picture for both story beats. Keep this widget's key when gathering:
/// each scrap retains its identity as it travels to its column.
class BoardsStoryScene extends StatelessWidget {
  const BoardsStoryScene({super.key, required this.gathered});
  final bool gathered;

  @override
  Widget build(BuildContext context) {
    final moving = moves(context);
    final duration = moving ? const Duration(milliseconds: 780) : Duration.zero;
    return ExcludeSemantics(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Beat(
          // Reveal and the late desaturation must also rest when an enclosing
          // guide clock is still running with reduced motion enabled.
          clock: moving ? Beat.of(context) : const AlwaysStoppedAnimation(1),
          child: FittedBox(
            child: SizedBox(
              width: 400,
              height: 560,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedOpacity(
                      duration: duration,
                      opacity: gathered ? 1 : 0,
                      child: AnimatedScale(
                        duration: duration,
                        curve: Curves.easeOutBack,
                        scale: gathered ? 1 : .94,
                        child: const _Board(),
                      ),
                    ),
                  ),
                  if (!gathered)
                    const Positioned(
                      left: 74,
                      right: 74,
                      top: 8,
                      child: Reveal(
                        from: .65,
                        to: .92,
                        rise: 8,
                        child: _LostNote(),
                      ),
                    ),
                  for (final (i, task) in _tasks.indexed)
                    AnimatedPositioned(
                      key: ValueKey(task.en),
                      duration: duration,
                      curve: Curves.easeOutBack,
                      left: (gathered ? task.card : task.scrap).left,
                      top: (gathered ? task.card : task.scrap).top,
                      width: (gathered ? task.card : task.scrap).width,
                      height: (gathered ? task.card : task.scrap).height,
                      child: AnimatedRotation(
                        duration: duration,
                        curve: Curves.easeOutBack,
                        turns: gathered ? 0 : task.turn / 6.283185,
                        child: gathered
                            // Lay out card typography at its resting size;
                            // morph the picture while the short scraps fly.
                            ? FittedBox(
                                fit: BoxFit.fill,
                                child: SizedBox(
                                  width: task.card.width,
                                  height: task.card.height,
                                  child: _TaskCard(task),
                                ),
                              )
                            : Reveal(
                                from: .06 + i * .075,
                                to: .3 + i * .075,
                                rise: 32,
                                scale: .88,
                                child: _LoseColour(child: _Scrap(task, i)),
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

class _Task {
  final String en, vi, categoryEn, categoryVi;
  final int hue;
  final Rect scrap, card;
  final double turn;
  final bool done, subtasks;
  const _Task(
    this.en,
    this.vi,
    this.categoryEn,
    this.categoryVi,
    this.hue,
    this.scrap,
    this.card,
    this.turn, {
    this.done = false,
    this.subtasks = false,
  });
}

// Notes → Doing, chat → To Do, sticky → Done, paper → To Do,
// calendar → Doing. Positions and content share this stable mapping.
const _tasks = [
  _Task(
    'Revise chapter 3',
    'Ôn chương 3 Toán',
    'Maths',
    'Toán',
    0,
    Rect.fromLTWH(18, 72, 202, 112),
    Rect.fromLTWH(148, 172, 104, 148),
    -.075,
    subtasks: true,
  ),
  _Task(
    'Hand in maths',
    'Nộp bài Toán',
    'Maths',
    'Toán',
    0,
    Rect.fromLTWH(134, 206, 246, 112),
    Rect.fromLTWH(20, 172, 104, 134),
    .06,
  ),
  _Task(
    'Buy markers',
    'Mua bút dạ',
    'Home',
    'Việc nhà',
    2,
    Rect.fromLTWH(24, 332, 164, 140),
    Rect.fromLTWH(276, 172, 104, 134),
    -.085,
    done: true,
  ),
  _Task(
    'Hand in the essay',
    'Nộp bài Văn',
    'Literature',
    'Văn',
    1,
    Rect.fromLTWH(212, 350, 166, 122),
    Rect.fromLTWH(20, 318, 104, 134),
    .09,
  ),
  _Task(
    'Call the AC repair',
    'Gọi thợ sửa máy lạnh',
    'Home',
    'Việc nhà',
    2,
    Rect.fromLTWH(126, 492, 248, 56),
    Rect.fromLTWH(148, 332, 104, 148),
    -.035,
  ),
];

TextStyle _type(
  double size, {
  Color color = GuideColors.ink,
  FontWeight weight = FontWeight.w500,
}) => TextStyle(
  fontFamily: 'PlusJakartaSans',
  fontSize: size,
  height: 1.35,
  color: color,
  fontWeight: weight,
);

class _Board extends StatelessWidget {
  const _Board();

  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.canvas,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: p.line),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 20,
              right: 20,
              top: 24,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.asset(
                      'assets/icon.png',
                      width: 28,
                      height: 28,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr(context, 'Semester 1', 'Học kỳ 1'),
                      style: _type(23, weight: FontWeight.w700),
                    ),
                  ),
                  Icon(Icons.more_horiz, size: 20, color: p.muted),
                ],
              ),
            ),
            Positioned(
              left: 20,
              top: 68,
              child: Text(
                tr(context, '5 cards · 3 categories', '5 việc · 3 nhóm'),
                style: _type(13, color: p.muted),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              top: 101,
              child: Container(height: 1, color: p.line),
            ),
            for (var i = 0; i < 3; i++) ...[
              Positioned(
                left: 14 + i * 128,
                top: 116,
                width: 116,
                height: 390,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.raised.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              Positioned(
                left: 22 + i * 128,
                top: 132,
                width: 100,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          tr(context, 'To Do', 'Cần làm'),
                          tr(context, 'Doing', 'Đang làm'),
                          tr(context, 'Done', 'Xong'),
                        ][i],
                        style: _type(13, weight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      tr(context, i == 2 ? '1' : '2', i == 2 ? '1' : '2'),
                      style: _type(12, color: p.muted),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final _Task task;
  const _TaskCard(this.task);

  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final hue = HandyPalette.of(context, task.hue);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: GuideColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line.withValues(alpha: .7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, task.en, task.vi),
            style:
                _type(
                  14,
                  weight: FontWeight.w600,
                  color: task.done ? GuideColors.muted : GuideColors.ink,
                ).copyWith(
                  decoration: task.done ? TextDecoration.lineThrough : null,
                  decorationColor: GuideColors.muted,
                ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: hue.tint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: hue.mark,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    tr(context, task.categoryEn, task.categoryVi),
                    style: _type(11, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          if (task.subtasks || task.done) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                Icon(
                  task.done ? Icons.check_circle_outline : Icons.checklist,
                  size: 14,
                  color: task.done ? p.positive : p.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  task.done
                      ? tr(context, 'Done', 'Xong')
                      : tr(context, '2/5', '2/5'),
                  style: _type(11, color: p.muted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Scrap extends StatelessWidget {
  final _Task task;
  final int kind;
  const _Scrap(this.task, this.kind);

  @override
  Widget build(BuildContext context) {
    final title = tr(context, task.en, task.vi);
    final hue = HandyPalette.of(context, task.hue);
    final Widget contents;
    switch (kind) {
      case 0:
        contents = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Source(
              Icons.notes_rounded,
              tr(context, 'Notes', 'Ghi chú'),
              const Color(0xFF99721D),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_box_outline_blank_rounded,
                  size: 18,
                  color: GuideColors.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: _type(16, weight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        );
      case 1:
        contents = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Source(
              Icons.chat_bubble_outline_rounded,
              tr(context, 'Class chat', 'Nhóm lớp'),
              const Color(0xFF39745E),
            ),
            const SizedBox(height: 9),
            Text(
              tr(
                context,
                'Remember to hand in maths on Friday',
                'Nhớ nộp bài Toán thứ Sáu nhé',
              ),
              style: _type(16),
            ),
          ],
        );
      case 2:
        contents = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(context, 'DON’T FORGET', 'ĐỪNG QUÊN'),
              style: _type(
                10,
                color: const Color(0xFF806020),
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: _type(22, weight: FontWeight.w600)),
          ],
        );
      case 3:
        contents = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _type(19, weight: FontWeight.w600)),
            const SizedBox(height: 9),
            Text(
              tr(context, 'before 5 pm', 'trước 17 giờ'),
              style: _type(13, color: GuideColors.muted),
            ),
          ],
        );
      default:
        contents = Row(
          children: [
            Container(width: 3, height: 30, color: hue.mark),
            const SizedBox(width: 10),
            Icon(Icons.calendar_today_outlined, size: 18, color: hue.mark),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, style: _type(14, weight: FontWeight.w600)),
            ),
          ],
        );
    }
    return CustomPaint(
      painter: _Paper(kind, hue.tint),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, kind == 3 ? 22 : 14, 16, 12),
        // A picture: whatever the face's metrics, the words shrink to fit
        // the scrap instead of spilling over it.
        child: LayoutBuilder(
          builder: (context, box) => !box.hasBoundedWidth
              ? contents
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: SizedBox(width: box.maxWidth, child: contents),
                ),
        ),
      ),
    );
  }
}

class _Source extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color colour;
  const _Source(this.icon, this.label, this.colour);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: colour),
      const SizedBox(width: 6),
      Text(
        label,
        style: _type(11, color: colour, weight: FontWeight.w700),
      ),
    ],
  );
}

/// Flat paper silhouettes, with the same simple folds and ruled lines as
/// Boards' illustrated covers. No lighting effects or simulated texture.
class _Paper extends CustomPainter {
  final int kind;
  final Color tint;
  const _Paper(this.kind, this.tint);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint();
    final colour = switch (kind) {
      1 => const Color(0xFFE6F1E9),
      2 => const Color(0xFFF8E4A0),
      3 => const Color(0xFFFAF6EB),
      4 => tint,
      _ => GuideColors.card,
    };
    if (kind == 3) {
      final paper = Path()..moveTo(0, 6);
      for (var x = 0.0; x < w; x += 12) {
        paper.lineTo(x + 6, 0);
        paper.lineTo((x + 12).clamp(0, w), 6);
      }
      paper.lineTo(w, h - 6);
      for (var x = w; x > 0; x -= 12) {
        paper.lineTo(x - 6, h);
        paper.lineTo((x - 12).clamp(0, w), h - 6);
      }
      paper.close();
      canvas.drawPath(paper, paint..color = colour);
      for (final y in [65.0, 90.0]) {
        canvas.drawLine(
          Offset(12, y),
          Offset(w - 12, y),
          paint
            ..color = const Color(0xFFE6DEC9)
            ..strokeWidth = 1,
        );
      }
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(kind == 2 ? 3 : 14),
        ),
        paint..color = colour,
      );
      if (kind == 1) {
        canvas.drawPath(
          Path()
            ..moveTo(20, h - 2)
            ..lineTo(12, h + 10)
            ..lineTo(42, h - 2)
            ..close(),
          paint,
        );
      }
      if (kind == 2) {
        canvas.drawPath(
          Path()
            ..moveTo(w - 26, h)
            ..lineTo(w, h - 26)
            ..lineTo(w - 26, h - 26)
            ..close(),
          paint..color = const Color(0xFFE2C675),
        );
      }
      if (kind == 0) {
        canvas.drawLine(
          const Offset(16, 40),
          Offset(w - 16, 40),
          paint
            ..color = const Color(0xFFF0EAE2)
            ..strokeWidth = 1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Paper old) => old.kind != kind || old.tint != tint;
}

class _LoseColour extends StatelessWidget {
  final Widget child;
  const _LoseColour({required this.child});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Beat.of(context),
    child: child,
    builder: (context, child) {
      final t = Curves.easeInOut.transform(
        ((Beat.of(context).value - .62) / .3).clamp(0.0, 1.0),
      );
      final r = .2126 * t, g = .7152 * t, b = .0722 * t;
      return Opacity(
        opacity: 1 - .22 * t,
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix([
            1 - t + r,
            g,
            b,
            0,
            0,
            r,
            1 - t + g,
            b,
            0,
            0,
            r,
            g,
            1 - t + b,
            0,
            0,
            0,
            0,
            0,
            1,
            0,
          ]),
          child: child,
        ),
      );
    },
  );
}

class _LostNote extends StatelessWidget {
  const _LostNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: GuideColors.card,
      border: Border.all(color: BoardsPalette.of(context).line),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.search, size: 18, color: GuideColors.muted),
        const SizedBox(width: 8),
        Text(
          tr(context, 'Where was it?', 'Đang ở đâu nhỉ?'),
          style: _type(14, color: GuideColors.muted),
        ),
      ],
    ),
  );
}
