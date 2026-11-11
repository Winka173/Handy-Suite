import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import '../today/beads.dart';
import 'motion.dart';
import 'story_scene.dart';

enum PracticeStep { read, water, start, finish, done }

/// A pretend Today at a phone's real size: two habits and a tiny routine.
/// Everything is dark except the one thing to do next, in a lit window
/// with a word beside it (the Spotlight of Boards and Bookmark). The beads
/// really fill and the ring really closes. Nothing is written anywhere.
class PracticeToday extends StatefulWidget {
  final ValueChanged<PracticeStep> onStep;
  const PracticeToday({super.key, required this.onStep});
  @override
  State<PracticeToday> createState() => PracticeTodayState();
}

class PracticeTodayState extends State<PracticeToday> {
  static const goal = 3;
  PracticeStep step = PracticeStep.read;
  bool read = false, running = false, finished = false;
  int water = 0;
  final readBead = GlobalKey(),
      waterBead = GlobalKey(),
      start = GlobalKey(),
      done = GlobalKey();

  void _to(PracticeStep next) {
    setState(() => step = next);
    widget.onStep(next);
  }

  void _haptic() {
    if (moves(context)) HapticFeedback.lightImpact();
  }

  void _read() {
    if (step != PracticeStep.read) return;
    _haptic();
    setState(() => read = true);
    _to(PracticeStep.water);
  }

  void _drink() {
    if (step != PracticeStep.water) return;
    _haptic();
    setState(() => water++);
    if (water >= goal) _to(PracticeStep.start);
  }

  void _start() {
    if (step != PracticeStep.start) return;
    setState(() => running = true);
    _to(PracticeStep.finish);
  }

  void _finish() {
    if (step != PracticeStep.finish) return;
    _haptic();
    setState(() {
      running = false;
      finished = true;
    });
    _to(PracticeStep.done);
  }

  /// The guide's "Do it for me": the current step, all at once.
  void advance() {
    switch (step) {
      case PracticeStep.read:
        _read();
      case PracticeStep.water:
        setState(() => water = goal - 1);
        _drink();
      case PracticeStep.start:
        _start();
      case PracticeStep.finish:
        _finish();
      case PracticeStep.done:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = switch (step) {
      PracticeStep.read => readBead,
      PracticeStep.water => waterBead,
      PracticeStep.start => start,
      PracticeStep.finish => done,
      PracticeStep.done => null,
    };
    final label = switch (step) {
      PracticeStep.read => tr(context, 'Tap today’s bead', 'Chạm hạt hôm nay'),
      PracticeStep.water => tr(
        context,
        'Tap + until 3 of 3',
        'Chạm + tới đủ 3/3',
      ),
      PracticeStep.start => tr(
        context,
        'Start the routine',
        'Bắt đầu quy trình',
      ),
      PracticeStep.finish => tr(context, 'Finish the step', 'Xong bước này'),
      PracticeStep.done => null,
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        Spotlight(
          target: target,
          label: label,
          radius: 16,
          child: _Screen(state: this),
        ),
        // A marker for tests and screen shots: which step is showing.
        Positioned(
          left: 0,
          top: 0,
          child: SizedBox.shrink(
            key: Key('practice-instruction-${step.index}'),
          ),
        ),
      ],
    );
  }
}

class _Screen extends StatelessWidget {
  final PracticeTodayState state;
  const _Screen({required this.state});
  @override
  Widget build(BuildContext context) {
    final s = state;
    final kept =
        (s.read ? 1 : 0) + (s.water >= PracticeTodayState.goal ? 1 : 0);
    final time = HandyMotion.of(context, HandyMotion.long);
    return ColoredBox(
      color: GuideColors.paper,
      // Very large text shrinks the pretend screen instead of cutting it.
      child: LayoutBuilder(
        builder: (context, box) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: box.maxWidth,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 28, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr(context, 'Good morning.', 'Chào buổi sáng.'),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      color: GuideColors.deep,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: kept / 2),
                        duration: time,
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => SizedBox.square(
                          dimension: 52,
                          child: CustomPaint(painter: KeptRingPainter(v)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HandySwap(
                              child: Text(
                                tr(
                                  context,
                                  kept == 2
                                      ? 'All done for today'
                                      : '$kept of 2 kept',
                                  kept == 2
                                      ? 'Hôm nay đã xong'
                                      : 'Đã giữ $kept/2',
                                ),
                                key: ValueKey(kept),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: GuideColors.hue,
                                ),
                              ),
                            ),
                            Text(
                              tr(
                                context,
                                'Monday, 2 November',
                                'Thứ Hai, 2 tháng 11',
                              ),
                              style: const TextStyle(color: GuideColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tr(context, 'Habits', 'Thói quen'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: GuideColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _HabitRow(
                    title: tr(context, 'Read a little', 'Đọc một chút'),
                    line: s.read
                        ? tr(context, 'Done today', 'Hôm nay đã xong')
                        : tr(context, 'Every day', 'Mỗi ngày'),
                    color: GuideColors.hue,
                    kept: 5,
                    fill: s.read ? 1 : 0,
                    plus: false,
                    beadKey: s.readBead,
                    beadId: 'practice-bead',
                    onTap: s._read,
                  ),
                  const SizedBox(height: 10),
                  _HabitRow(
                    title: tr(context, 'Drink water', 'Uống nước'),
                    line: tr(
                      context,
                      '${s.water} / ${PracticeTodayState.goal} glasses',
                      '${s.water} / ${PracticeTodayState.goal} cốc',
                    ),
                    color: GuideColors.ochre,
                    kept: 4,
                    fill: s.water / PracticeTodayState.goal,
                    plus: true,
                    beadKey: s.waterBead,
                    beadId: 'practice-water',
                    onTap: s._drink,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tr(context, 'Routines', 'Quy trình'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: GuideColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: GuideColors.card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: HandySwap(
                      child: s.running
                          ? Row(
                              key: const ValueKey('running'),
                              children: [
                                const Expanded(child: _Step()),
                                FilledButton(
                                  key: s.done,
                                  style: _button,
                                  onPressed: s._finish,
                                  child: Text(tr(context, 'Done', 'Xong')),
                                ),
                              ],
                            )
                          : Row(
                              key: ValueKey(s.finished),
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tr(
                                          context,
                                          'A small morning',
                                          'Buổi sáng nhỏ',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: GuideColors.ink,
                                        ),
                                      ),
                                      Text(
                                        s.finished
                                            ? tr(context, 'Finished', 'Đã xong')
                                            : tr(
                                                context,
                                                '1 step · 2 min',
                                                '1 bước · 2 phút',
                                              ),
                                        style: const TextStyle(
                                          color: GuideColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (s.finished)
                                  const Icon(
                                    Icons.check_circle,
                                    color: GuideColors.hue,
                                    size: 32,
                                  )
                                else
                                  OutlinedButton(
                                    key: s.start,
                                    onPressed: s._start,
                                    child: Text(
                                      tr(context, 'Start', 'Bắt đầu'),
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
      ),
    );
  }
}

final _button = FilledButton.styleFrom(
  backgroundColor: GuideColors.hue,
  foregroundColor: Colors.white,
);

class _Step extends StatelessWidget {
  const _Step();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        tr(context, 'Step 1 of 1', 'Bước 1/1'),
        style: const TextStyle(color: GuideColors.muted),
      ),
      Text(
        tr(context, 'Open the window', 'Mở cửa sổ'),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: GuideColors.ink,
        ),
      ),
    ],
  );
}

class _HabitRow extends StatelessWidget {
  final String title, line, beadId;
  final Color color;
  final int kept;
  final double fill;
  final bool plus;
  final GlobalKey beadKey;
  final VoidCallback onTap;
  const _HabitRow({
    required this.title,
    required this.line,
    required this.color,
    required this.kept,
    required this.fill,
    required this.plus,
    required this.beadKey,
    required this.beadId,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final full = fill >= 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: GuideColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: GuideColors.ink,
                  ),
                ),
                HandySwap(
                  child: Text(
                    line,
                    key: ValueKey(line),
                    style: const TextStyle(color: GuideColors.muted),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (var d = 0; d < 6; d++)
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: Bead(
                          status: d < kept ? 'completed' : 'missed',
                          fill: 1,
                          size: 16,
                          color: color,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: title,
            child: InkResponse(
              key: Key(beadId),
              radius: 30,
              onTap: onTap,
              child: SizedBox.square(
                key: beadKey,
                dimension: 56,
                child: TodayBeadPicture(
                  fill: fill,
                  color: color,
                  plus: plus && !full,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Today's bead as the real app draws it: a ring that fills, then a full
/// bead with a tick that pops in. Each change animates; none with reduced
/// motion.
class TodayBeadPicture extends StatelessWidget {
  final double fill;
  final Color color;
  final bool plus;
  const TodayBeadPicture({
    super.key,
    required this.fill,
    required this.color,
    this.plus = false,
  });
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: fill),
    duration: HandyMotion.of(context, const Duration(milliseconds: 320)),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) {
      final full = v >= .999;
      return Stack(
        alignment: Alignment.center,
        children: [
          Bead(
            status: full ? 'completed' : 'progress',
            fill: v,
            size: 44,
            color: color,
          ),
          if (full)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: HandyMotion.of(
                context,
                const Duration(milliseconds: 260),
              ),
              curve: Curves.easeOutBack,
              builder: (context, k, child) =>
                  Transform.scale(scale: math.max(0, k), child: child),
              child: const Icon(Icons.check, size: 24, color: Colors.white),
            )
          else if (plus)
            Icon(Icons.add, size: 20, color: color),
        ],
      );
    },
  );
}
