import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:handy_ui/kit.dart';
import '../today/beads.dart';
import 'motion.dart';

/// The story, one picture for both beats: three scraps of good intentions
/// (a sticky note, a message, a calendar page) lie about; on "Bring them
/// into today" each flies into a row of Today and becomes a bead string,
/// the beads fill in one by one and the kept ring closes to two of three.
class HabitStoryScene extends StatelessWidget {
  const HabitStoryScene({super.key, required this.gathered});
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
              width: 360,
              height: 500,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: gathered ? 1 : 0, end: gathered ? 1 : 0),
                duration: moving
                    ? const Duration(milliseconds: 1400)
                    : Duration.zero,
                builder: (context, t, _) =>
                    _Picture(progress: moving ? t : (gathered ? 1 : 0)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _between(double v, double from, double to) =>
    ((v - from) / (to - from)).clamp(0.0, 1.0);

/// Three 640 ms flights, leaving 110 ms apart; then beads and the ring.
double _flight(double progress, int i) =>
    _between(progress, i * .08, .46 + i * .08);

class _Habit {
  final String en, vi, scrapEn, scrapVi;
  final IconData icon;
  final Color color;
  final int kept;
  final bool today;
  const _Habit(
    this.en,
    this.vi,
    this.scrapEn,
    this.scrapVi,
    this.icon,
    this.color,
    this.kept,
    this.today,
  );
}

const _habits = [
  _Habit(
    'Drink water',
    'Uống nước',
    'Drink more water!',
    'Nhớ uống nước!',
    Icons.sticky_note_2_outlined,
    GuideColors.ochre,
    6,
    true,
  ),
  _Habit(
    'Read a little',
    'Đọc một chút',
    'Read 10 pages tonight',
    'Tối nay đọc 10 trang nhé',
    Icons.chat_bubble_outline,
    GuideColors.hue,
    5,
    true,
  ),
  _Habit(
    'Move today',
    'Vận động',
    'Gym: Mon, Wed…',
    'Tập: T2, T4…',
    Icons.calendar_today_outlined,
    GuideColors.deep,
    4,
    false,
  ),
];

// Where each scrap lies, and how it is turned.
const _scattered = [
  Rect.fromLTWH(10, 70, 210, 96),
  Rect.fromLTWH(140, 200, 210, 96),
  Rect.fromLTWH(24, 330, 210, 96),
];
const _turns = [-.05, .04, -.03];

// Where each lands: a row of Today.
Rect _row(int i) => Rect.fromLTWH(14, 128 + i * 116.0, 332, 100);

class _Picture extends StatelessWidget {
  final double progress;
  const _Picture({required this.progress});

  @override
  Widget build(BuildContext context) {
    final ground = Curves.easeOut.transform(_between(progress, 0, .3));
    final ring = Curves.easeInOutCubic.transform(_between(progress, .62, .95));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: ground,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: GuideColors.card,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: GuideColors.shadow,
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          top: 22,
          right: 20,
          child: Opacity(
            opacity: ground,
            child: _Header(ring: ring),
          ),
        ),
        for (final (i, h) in _habits.indexed)
          _Flying(
            habit: h,
            i: i,
            flight: _flight(progress, i),
            progress: progress,
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final double ring;
  const _Header({required this.ring});
  @override
  Widget build(BuildContext context) {
    final kept = ring >= 1 ? 2 : (ring > .5 ? 1 : 0);
    return Row(
      children: [
        SizedBox.square(
          dimension: 64,
          child: CustomPaint(painter: KeptRingPainter(ring * 2 / 3)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(context, 'Good morning.', 'Chào buổi sáng.'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: GuideColors.deep,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  context,
                  '$kept of 3 kept today',
                  'Hôm nay giữ được $kept/3',
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: GuideColors.hue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Today's kept/due ring: the track, and the kept part in vermilion.
class KeptRingPainter extends CustomPainter {
  final double kept;
  const KeptRingPainter(this.kept);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - 5,
    );
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = GuideColors.tint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9,
    );
    if (kept <= 0) return;
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * kept,
      false,
      Paint()
        ..color = GuideColors.hue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(KeptRingPainter old) => old.kept != kept;
}

/// A scrap on its way to its row; past the middle of the flight the scrap
/// fades and the row (name, beads, today's bead) takes its place.
class _Flying extends StatelessWidget {
  final _Habit habit;
  final int i;
  final double flight, progress;
  const _Flying({
    required this.habit,
    required this.i,
    required this.flight,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeInOutCubic.transform(flight);
    final rect = Rect.lerp(_scattered[i], _row(i), t)!;
    final turn = lerpDouble(_turns[i], 0, t)!;
    final swap = _between(flight, .55, 1);
    final scrap = Opacity(opacity: 1 - swap, child: _Scrap(habit, i));
    return Positioned.fromRect(
      rect: rect,
      child: Transform.rotate(
        angle: turn * math.pi * 2,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (progress == 0)
              Reveal(
                from: .05 + i * .1,
                to: .35 + i * .1,
                rise: 28,
                scale: .9,
                child: scrap,
              )
            else
              scrap,
            if (swap > 0)
              Opacity(
                opacity: swap,
                child: _Row(habit: habit, i: i, progress: progress),
              ),
          ],
        ),
      ),
    );
  }
}

class _Scrap extends StatelessWidget {
  final _Habit h;
  final int i;
  const _Scrap(this.h, this.i);
  @override
  Widget build(BuildContext context) {
    final bubble = i == 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: switch (i) {
          0 => const Color(0xFFF5EBCF),
          1 => GuideColors.card,
          _ => GuideColors.card,
        },
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(bubble ? 4 : 14),
          bottomRight: const Radius.circular(14),
        ),
        border: Border.all(color: GuideColors.line),
        boxShadow: const [
          BoxShadow(
            color: GuideColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      // A picture: large text or a wide test font shrinks it, never clips.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 176,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (i == 2)
                Container(
                  height: 6,
                  width: 48,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: GuideColors.hue,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              Row(
                children: [
                  Icon(h.icon, size: 20, color: GuideColors.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr(context, h.scrapEn, h.scrapVi),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: GuideColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final _Habit habit;
  final int i;
  final double progress;
  const _Row({required this.habit, required this.i, required this.progress});
  @override
  Widget build(BuildContext context) {
    final today = Curves.easeOutBack.transform(
      _between(progress, .78 + i * .05, .92 + i * .05),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: GuideColors.paper,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr(context, habit.en, habit.vi),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: GuideColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var d = 0; d < 6; d++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Transform.scale(
                            scale: Curves.easeOutBack.transform(
                              _between(
                                progress,
                                .5 + i * .06 + d * .035,
                                .62 + i * .06 + d * .035,
                              ),
                            ),
                            child: Bead(
                              status: d < habit.kept ? 'completed' : 'missed',
                              fill: 1,
                              size: 18,
                              color: habit.color,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox.square(
            dimension: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Bead(
                  status: habit.today && today > 0 ? 'completed' : 'open',
                  fill: 1,
                  size: 40 * (habit.today ? .8 + .2 * today : 1),
                  color: habit.color,
                ),
                if (habit.today && today > 0)
                  Transform.scale(
                    scale: today,
                    child: const Icon(
                      Icons.check,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Seven beads of one habit for a week, kept or not.
class BeadWeek extends StatelessWidget {
  final int completed;
  final Color color;
  const BeadWeek({super.key, required this.completed, required this.color});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      for (var i = 0; i < 7; i++)
        Bead(
          status: i < completed ? 'completed' : 'missed',
          fill: 1,
          size: 24,
          color: color,
        ),
    ],
  );
}

/// The last stage: a week of reading with one hollow bead. The beads come
/// in one by one, the missed one stays a plain ring, and the figures count
/// up: a missed day is a day, not a failure.
class HabitMissedScene extends StatelessWidget {
  const HabitMissedScene({super.key});
  @override
  Widget build(BuildContext context) {
    final clock = moves(context)
        ? Beat.of(context)
        : const AlwaysStoppedAnimation<double>(1);
    return ExcludeSemantics(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: FittedBox(
          child: AnimatedBuilder(
            animation: clock,
            builder: (context, _) {
              final v = clock.value;
              final count = Curves.easeOut.transform(_between(v, .45, .85));
              return Container(
                width: 360,
                height: 460,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: GuideColors.card,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: GuideColors.shadow,
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr(context, 'A week of reading', 'Một tuần đọc sách'),
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: GuideColors.ink,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < 7; i++)
                          Column(
                            children: [
                              Text(
                                tr(
                                  context,
                                  ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                                  ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][i],
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: GuideColors.muted,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Transform.scale(
                                scale: Curves.easeOutBack.transform(
                                  _between(v, .05 + i * .05, .2 + i * .05),
                                ),
                                child: Bead(
                                  status: i == 4 ? 'missed' : 'completed',
                                  fill: 1,
                                  size: 30,
                                  color: GuideColors.ochre,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 16,
                                child: i == 4
                                    ? Opacity(
                                        opacity: _between(v, .4, .6),
                                        child: Text(
                                          tr(context, 'missed', 'lỡ'),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: GuideColors.muted,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${(86 * count).round()}%',
                          style: const TextStyle(
                            fontSize: 48,
                            height: 1.05,
                            fontWeight: FontWeight.w800,
                            color: GuideColors.ochre,
                          ),
                        ),
                        Text(
                          tr(context, '6 of 7 days kept', 'Giữ được 6/7 ngày'),
                          style: const TextStyle(
                            fontSize: 16,
                            color: GuideColors.ochre,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Opacity(
                      opacity: Curves.easeOut.transform(_between(v, .6, .9)),
                      child: Text(
                        tr(
                          context,
                          'Current streak: 2 days. Best: 4 days. The days you kept stay kept.',
                          'Chuỗi hiện tại: 2 ngày. Tốt nhất: 4 ngày. Ngày đã giữ vẫn còn đó.',
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: GuideColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
