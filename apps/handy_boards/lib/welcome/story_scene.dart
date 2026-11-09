import 'dart:math' as math;
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../covers/cover_art.dart';
import '../design/looks.dart';
import '../design/theme.dart';
import 'motion.dart';

/// One picture for both beats. Keep its key so the same scraps fly home.
class BoardsStoryScene extends StatelessWidget {
  const BoardsStoryScene({super.key, required this.gathered});
  final bool gathered;

  @override
  Widget build(BuildContext context) {
    final moving = moves(context);
    return ExcludeSemantics(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: Beat(
          clock: moving ? Beat.of(context) : const AlwaysStoppedAnimation(1),
          child: FittedBox(
            child: SizedBox(
              width: 400,
              height: 560,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: gathered ? 1 : 0, end: gathered ? 1 : 0),
                duration: moving
                    ? const Duration(milliseconds: 1120)
                    : Duration.zero,
                builder: (context, progress, _) => _Picture(
                  progress: moving ? progress : (gathered ? 1 : 0),
                  gathered: gathered,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _between(double value, double from, double to) =>
    ((value - from) / (to - from)).clamp(0.0, 1.0);

// Five 700 ms flights, leaving 75 ms apart; the labels arrive afterwards.
double _flight(double progress, int i) =>
    _between(progress, i * 75 / 1120, (700 + i * 75) / 1120);

final _storyBoard = BoardRecord({
  'id': 'welcome-story',
  'cover': 'study.notebook-grid',
});

class _Picture extends StatelessWidget {
  final double progress;
  final bool gathered;
  const _Picture({required this.progress, required this.gathered});

  @override
  Widget build(BuildContext context) {
    final ground = boardGround(context, _storyBoard);
    final boardOpacity = Curves.easeOut.transform(_between(progress, 0, .35));
    final labels = Curves.easeOut.transform(_between(progress, .88, 1));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomMultiChildLayout(
          delegate: _StoryLayout(progress),
          children: [
            LayoutId(
              id: 'ground',
              child: Opacity(
                opacity: boardOpacity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ground.page,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: coverTone(
                        'study.notebook-grid',
                      ).withValues(alpha: .9),
                    ),
                  ),
                ),
              ),
            ),
            LayoutId(
              id: 'header',
              child: Opacity(
                opacity: boardOpacity,
                child: const _BoardHeading(),
              ),
            ),
            LayoutId(
              id: 'strip',
              child: Opacity(opacity: labels, child: const _CategoryStrip()),
            ),
            for (var column = 0; column < 3; column++) ...[
              LayoutId(
                id: 'panel-$column',
                child: Opacity(
                  opacity: boardOpacity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: ground.column,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              LayoutId(
                id: 'heading-$column',
                child: Opacity(opacity: labels, child: _ColumnHeading(column)),
              ),
            ],
            for (final (i, task) in _tasks.indexed) ...[
              LayoutId(
                id: 'card-$i',
                child: _Airborne(
                  task: task,
                  flight: _flight(progress, i),
                  card: true,
                  child: _TaskCard(task),
                ),
              ),
              LayoutId(
                id: 'scrap-$i',
                child: _Airborne(
                  task: task,
                  flight: _flight(progress, i),
                  card: false,
                  child: gathered
                      ? _Scrap(task, i)
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
          ],
        ),
        if (!gathered)
          Positioned(
            left: 74,
            right: 74,
            top: 8,
            child: Opacity(
              opacity: 1 - progress,
              child: const Reveal(
                from: .65,
                to: .92,
                rise: 8,
                child: _LostNote(),
              ),
            ),
          ),
      ],
    );
  }
}

/// Measure the cards at their resting width before placing any of them.
/// The next card follows the measured bottom, including with fallback fonts.
class _StoryLayout extends MultiChildLayoutDelegate {
  final double progress;
  _StoryLayout(this.progress);

  @override
  void performLayout(Size size) {
    const inset = 8.0, gap = 6.0, panelInset = 5.0;
    final panelWidth = (size.width - inset * 2 - gap * 2) / 3;
    final cardWidth = panelWidth - panelInset * 2;
    BoxConstraints natural(double width) =>
        BoxConstraints.tightFor(width: width);

    final header = layoutChild('header', natural(size.width - 28));
    final strip = layoutChild('strip', natural(size.width - inset * 2));
    final headingSizes = [
      for (var column = 0; column < 3; column++)
        layoutChild('heading-$column', natural(cardWidth - 4)),
    ];
    final headingHeight = headingSizes.map((s) => s.height).reduce(math.max);
    final cardSizes = [
      for (var i = 0; i < _tasks.length; i++)
        layoutChild('card-$i', natural(cardWidth)),
    ];
    final scrapSizes = [
      for (var i = 0; i < _tasks.length; i++)
        layoutChild('scrap-$i', BoxConstraints.tight(_tasks[i].scrap.size)),
    ];
    final stacks = [0.0, 0.0, 0.0];
    for (var i = 0; i < _tasks.length; i++) {
      stacks[_tasks[i].column] += cardSizes[i].height + 9;
    }
    final panelHeight = math.max(
      274.0,
      headingHeight + 24 + stacks.reduce(math.max),
    );
    final panelTop = 14 + header.height + 14 + strip.height + 12;
    final boardHeight = panelTop + panelHeight + 10;
    final top = (size.height - boardHeight) / 2;

    layoutChild('ground', BoxConstraints.tight(Size(size.width, boardHeight)));
    positionChild('ground', Offset(0, top));
    positionChild('header', Offset(14, top + 14));
    positionChild('strip', Offset(inset, top + 14 + header.height + 14));
    final nextY = List.filled(3, top + panelTop + headingHeight + 18);
    for (var column = 0; column < 3; column++) {
      final x = inset + column * (panelWidth + gap);
      layoutChild(
        'panel-$column',
        BoxConstraints.tight(Size(panelWidth, panelHeight)),
      );
      positionChild('panel-$column', Offset(x, top + panelTop));
      positionChild(
        'heading-$column',
        Offset(x + panelInset + 2, top + panelTop + 8),
      );
    }
    for (var i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      final card = cardSizes[i];
      final end = Offset(
        inset + task.column * (panelWidth + gap) + panelInset,
        nextY[task.column],
      );
      nextY[task.column] += card.height + 9;
      final t = _flight(progress, i);
      final eased = Curves.easeOutCubic.transform(t);
      // A shallow arc, then a two-pixel settle as the paper touches down.
      final lift = math.sin(math.pi * t);
      final settle = t > .8 ? math.sin((t - .8) / .2 * math.pi) * 2 : 0.0;
      final center =
          Offset.lerp(
            task.scrap.center,
            end + Offset(card.width / 2, card.height / 2),
            eased,
          )! +
          Offset(0, -22 * lift + settle);
      positionChild(
        'card-$i',
        center - Offset(card.width / 2, card.height / 2),
      );
      final scrap = scrapSizes[i];
      positionChild(
        'scrap-$i',
        center - Offset(scrap.width / 2, scrap.height / 2),
      );
    }
  }

  @override
  bool shouldRelayout(_StoryLayout old) => old.progress != progress;
}

class _Airborne extends StatelessWidget {
  final _Task task;
  final double flight;
  final bool card;
  final Widget child;
  const _Airborne({
    required this.task,
    required this.flight,
    required this.card,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final lift = math.sin(math.pi * flight);
    final morph = Curves.easeInOut.transform(_between(flight, .16, .28));
    return Opacity(
      opacity: card ? morph : 1 - morph,
      child: Transform.rotate(
        angle: task.turn * (1 - Curves.easeOutCubic.transform(flight)),
        child: Transform.scale(
          scale: 1 + .075 * lift,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(card ? 12 : 8),
              boxShadow: [
                if (flight > 0 && flight < 1)
                  BoxShadow(
                    color: GuideColors.shadow.withValues(alpha: .18 * lift),
                    blurRadius: 18 * lift,
                    offset: Offset(0, 9 * lift),
                  ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Task {
  final String en, vi, categoryEn, categoryVi;
  final int hue, column;
  final Rect scrap;
  final double turn;
  final bool done, subtasks;
  final String? cover, factEn, factVi;
  const _Task(
    this.en,
    this.vi,
    this.categoryEn,
    this.categoryVi,
    this.hue,
    this.scrap,
    this.column,
    this.turn, {
    this.done = false,
    this.subtasks = false,
    this.cover,
    this.factEn,
    this.factVi,
  });
}

// Notes → Doing, chat → To Do, sticky → Done, paper → To Do,
// calendar → Doing. The same five things retain their category throughout.
const _tasks = [
  _Task(
    'Revise chapter 3',
    'Ôn chương 3 Toán',
    'Maths',
    'Toán',
    0,
    Rect.fromLTWH(18, 72, 202, 112),
    1,
    -.075,
    subtasks: true,
    cover: 'study.notebook-grid',
  ),
  _Task(
    'Hand in maths',
    'Nộp bài Toán',
    'Maths',
    'Toán',
    0,
    Rect.fromLTWH(134, 206, 246, 112),
    0,
    .06,
    factEn: 'Friday',
    factVi: 'Thứ Sáu',
  ),
  _Task(
    'Buy markers',
    'Mua bút dạ',
    'Home',
    'Việc nhà',
    2,
    Rect.fromLTWH(24, 332, 164, 140),
    2,
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
    0,
    .09,
    cover: 'study.open-book',
    factEn: '5 pm',
    factVi: '17 giờ',
  ),
  _Task(
    'Call the AC repair',
    'Gọi thợ sửa máy lạnh',
    'Home',
    'Việc nhà',
    2,
    Rect.fromLTWH(126, 492, 248, 56),
    1,
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

class _BoardHeading extends StatelessWidget {
  const _BoardHeading();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: const SizedBox(
          width: 48,
          height: 42,
          child: CoverArt('study.notebook-grid'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(context, 'Semester 1', 'Học kỳ 1'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _type(21, weight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              tr(context, '5 cards · 3 categories', '5 việc · 3 nhóm'),
              style: _type(11, color: GuideColors.muted),
            ),
          ],
        ),
      ),
      const Icon(Icons.more_horiz, size: 20, color: GuideColors.muted),
    ],
  );
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < 3; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Expanded(child: _CategoryBlock(i)),
      ],
    ],
  );
}

class _CategoryBlock extends StatelessWidget {
  final int index;
  const _CategoryBlock(this.index);

  @override
  Widget build(BuildContext context) {
    final hue = HandyPalette.of(context, index);
    final tasks = _tasks.where((task) => task.hue == index);
    final task = tasks.first;
    final done = tasks.where((task) => task.done).length;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: GuideColors.card.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                _Dot(hue.mark),
                const SizedBox(width: 5),
                Text(
                  tr(context, task.categoryEn, task.categoryVi),
                  style: _type(11, weight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text(
                  '$done/${tasks.length}',
                  style: _type(10, color: GuideColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: done / tasks.length,
              minHeight: 3,
              color: hue.mark,
              backgroundColor: hue.tint,
              // A still miniature, independent of platform progress animation.
              stopIndicatorColor: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColumnHeading extends StatelessWidget {
  final int column;
  const _ColumnHeading(this.column);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            [
              tr(context, 'To Do', 'Cần làm'),
              tr(context, 'Doing', 'Đang làm'),
              tr(context, 'Done', 'Xong'),
            ][column],
            style: _type(12, weight: FontWeight.w700),
          ),
        ),
      ),
      const SizedBox(width: 4),
      Text(
        '${_tasks.where((task) => task.column == column).length}',
        style: _type(11, color: GuideColors.muted),
      ),
    ],
  );
}

class _TaskCard extends StatelessWidget {
  final _Task task;
  const _TaskCard(this.task);

  @override
  Widget build(BuildContext context) {
    final p = BoardsPalette.of(context);
    final hue = HandyPalette.of(context, task.hue);
    return Container(
      key: ValueKey('story-card-${task.en}'),
      decoration: BoxDecoration(
        color: GuideColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.line.withValues(alpha: .7)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (task.cover != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
              child: SizedBox(height: 28, child: CoverArt(task.cover)),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, task.en, task.vi),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      _type(
                        14,
                        weight: FontWeight.w600,
                        color: task.done ? GuideColors.muted : GuideColors.ink,
                      ).copyWith(
                        decoration: task.done
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: GuideColors.muted,
                      ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: hue.tint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Dot(hue.mark),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          tr(context, task.categoryEn, task.categoryVi),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _type(11, weight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                if (task.subtasks || task.factEn != null) ...[
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(
                        task.subtasks ? Icons.checklist : Icons.schedule,
                        size: 13,
                        color: p.muted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          task.subtasks
                              ? '2/5'
                              : tr(context, task.factEn!, task.factVi!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _type(10, color: p.muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot(this.color);

  @override
  Widget build(BuildContext context) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
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
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              tr(context, 'Where was it?', 'Đang ở đâu nhỉ?'),
              style: _type(14, color: GuideColors.muted),
            ),
          ),
        ),
      ],
    ),
  );
}
