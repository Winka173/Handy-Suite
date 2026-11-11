import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/words.dart';
import '../habits/habit_appearance.dart';

/// One day of a habit, as a bead: full when done, filled part way when
/// begun, an empty grey ring when planned and not done, a ring with a
/// dash when skipped with a reason, a pale disc with no ring when paused.
class Bead extends StatelessWidget {
  final String status;

  /// How full, 0 to 1, for a day begun.
  final double fill;
  final double size;
  final Color color;
  const Bead({
    super.key,
    required this.status,
    required this.fill,
    required this.size,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _BeadPainter(
      status: status,
      fill: fill,
      color: color,
      ring: HandyColors.of(context).muted.withValues(alpha: .55),
    ),
  );
}

class _BeadPainter extends CustomPainter {
  final String status;
  final double fill;
  final Color color, ring;
  _BeadPainter({
    required this.status,
    required this.fill,
    required this.color,
    required this.ring,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.width / 2;
    final stroke = math.max(1.5, size.width / 14);
    final ringPaint = Paint()
      ..color = status == 'partial' || status == 'progress'
          ? color.withValues(alpha: .35)
          : status == 'open'
          ? color
          : ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    switch (status) {
      case 'withinLimit':
      case 'completed':
        canvas.drawCircle(c, r, Paint()..color = color);
      case 'overLimit':
        canvas.drawCircle(c, r * .62, Paint()..color = ring);
        canvas.drawCircle(c, r - stroke / 2, ringPaint);
      case 'partial':
        canvas.drawCircle(c, r - stroke / 2, ringPaint);
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r - stroke / 2),
          -math.pi / 2,
          2 * math.pi * fill.clamp(0.0, 1.0),
          true,
          Paint()..color = color,
        );
      case 'skipped':
        canvas.drawCircle(c, r - stroke / 2, ringPaint);
        canvas.drawLine(
          c.translate(-r * .45, 0),
          c.translate(r * .45, 0),
          ringPaint,
        );
      // Today's bead: a ring that fills clockwise, its centre kept clear.
      case 'progress':
        canvas.drawCircle(c, r - stroke, ringPaint..strokeWidth = stroke * 1.4);
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r - stroke),
          -math.pi / 2,
          2 * math.pi * fill.clamp(0.0, 1.0),
          false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke * 2.2
            ..strokeCap = StrokeCap.round,
        );
      // A day off: a pale disc, never the ring of a day not done.
      case 'paused':
        canvas.drawCircle(
          c,
          r * .82,
          Paint()..color = ring.withValues(alpha: ring.a * .45),
        );
      // A day before the habit began: a faint thin ring, never "missed".
      case 'before':
        canvas.drawCircle(
          c,
          r - stroke / 2,
          Paint()
            ..color = ring.withValues(alpha: ring.a * .35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, stroke * .6),
        );
      // A day with no plan (a days-a-week habit not done that day).
      case 'notScheduled':
        canvas.drawCircle(c, r * .22, Paint()..color = ring);
      default:
        canvas.drawCircle(c, r - stroke / 2, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BeadPainter old) =>
      old.status != status ||
      old.fill != fill ||
      old.color != color ||
      old.ring != ring;
}

/// The last planned days before today, oldest first (at most [count],
/// looking back up to 60 days). Days without a plan have no bead.
List<String> earlierDays(Habit h, String today, {int count = 6}) {
  final out = <String>[];
  for (var i = 1; i <= 60 && out.length < count; i++) {
    final d = addDays(today, -i);
    if (d.compareTo(h.created) < 0) break;
    if (isScheduledOn(h, d)) out.add(d);
  }
  return out.reversed.toList();
}

/// How full a day is, 0 to 1.
double dayFill(Habit h, String d, HabitIndex index) {
  final target = scheduleOn(h, d)?.target ?? 1000;
  return (index.value(h.id, d) / target).clamp(0.0, 1.0);
}

/// Recent beads carry the habit's identity; missed and paused remain neutral.
class EarlierBeads extends StatelessWidget {
  final HabitDay data;
  const EarlierBeads({super.key, required this.data});
  @override
  Widget build(BuildContext context) {
    final ink = habitMark(context, data.habit);
    final days = earlierDays(data.habit, data.today);
    // A new habit still shows a string of six: the days before it began
    // are faint rings, so the string is the same length from day one.
    final before = 6 - days.length;
    return Semantics(
      label: [
        for (final d in days)
          '${formatDay(context, d)}: ${statusLabel(context, habitStatus(data.habit, d, data.today, data.index))}',
      ].join('; '),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < before; i++)
            const Padding(padding: EdgeInsets.only(right: 6), child: _Before()),
          for (final d in days)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Bead(
                status: habitStatus(data.habit, d, data.today, data.index),
                fill: dayFill(data.habit, d, data.index),
                size: 18,
                color: ink,
              ),
            ),
        ],
      ),
    );
  }
}

class _Before extends StatelessWidget {
  const _Before();
  @override
  Widget build(BuildContext context) => Bead(
    status: 'before',
    fill: 0,
    size: 18,
    color: HandyColors.of(context).muted,
  );
}

/// A habit seen on one day: what the bead strings need.
class HabitDay {
  final Habit habit;
  final String today;
  final HabitIndex index;
  const HabitDay(this.habit, this.today, this.index);
}

/// Today's bead, in the habit's hue: the state and the button.
class TodayBead extends StatelessWidget {
  final HabitScope scope;
  final Habit habit;
  final HabitIndex index;
  final VoidCallback onTap, onLongPress;

  /// Flies between Today and the habit's page (one per habit per route).
  final bool hero;
  const TodayBead({
    super.key,
    required this.scope,
    required this.habit,
    required this.index,
    required this.onTap,
    required this.onLongPress,
    this.hero = false,
  });
  @override
  Widget build(BuildContext context) {
    final today = scope.today;
    final status = habitStatus(habit, today, today, index);
    final target = scheduleOn(habit, today)?.target ?? 1000;
    final value = index.value(habit.id, today);
    final done = status == 'completed';
    final c = HandyColors.of(context);
    final color = habitMark(context, habit);
    final checkInk = color.computeLuminance() > .179
        ? Colors.black
        : Colors.white;
    final paused = status == 'paused';
    final label = habit.isNegative
        ? tr(
            context,
            'Log an incident for ${habit.title}. ${statusLabel(context, status)}',
            'Ghi một lần cho ${habit.title}. ${statusLabel(context, status)}',
          )
        : paused
        ? tr(
            context,
            '${habit.title}: paused today. Mark it done anyway',
            '${habit.title}: hôm nay đang nghỉ. Vẫn đánh dấu đã làm',
          )
        : done
        ? tr(
            context,
            '${habit.title}: done today',
            '${habit.title}: hôm nay đã xong',
          )
        : habit.type == 'binary'
        ? tr(
            context,
            'Mark ${habit.title} done',
            'Đánh dấu ${habit.title} đã xong',
          )
        : tr(
            context,
            'Add to ${habit.title}, ${progressText(context, habit, value, target)}',
            'Cộng cho ${habit.title}, ${progressText(context, habit, value, target)}',
          );
    return Semantics(
      button: true,
      label: label,
      hint: tr(context, 'Hold to edit the day', 'Giữ để sửa ngày'),
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          key: Key('bead-${habit.id}'),
          onTap: () {
            if (MediaQuery.maybeDisableAnimationsOf(context) != true) {
              HapticFeedback.lightImpact();
            }
            onTap();
          },
          onLongPress: onLongPress,
          radius: 28,
          child: _maybeHero(
            hero ? 'habit-bead-${habit.id}' : null,
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: dayFill(habit, today, index)),
                    duration: HandyMotion.of(
                      context,
                      const Duration(milliseconds: 320),
                    ),
                    curve: Curves.easeOutCubic,
                    builder: (context, fill, _) => Bead(
                      status: switch (status) {
                        'partial' => 'progress',
                        'open' || 'missed' => fill > 0 ? 'progress' : 'open',
                        'completed'
                            when fill < .999 && habit.type != 'binary' =>
                          'progress',
                        _ => status,
                      },
                      fill: fill,
                      size: 40,
                      color: color,
                    ),
                  ),
                  if (done)
                    _Pop(child: Icon(Icons.check, size: 22, color: checkInk))
                  else if (paused)
                    Icon(Icons.pause, size: 18, color: c.muted)
                  else if (habit.type != 'binary' && status != 'skipped')
                    Icon(
                      Icons.add,
                      size: 20,
                      color: status == 'withinLimit'
                          ? checkInk
                          : status == 'overLimit'
                          ? c.muted
                          : color,
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

/// Grows in from nothing with a little overshoot when it first appears
/// (the tick of a bead just filled); still with reduced motion.
class _Pop extends StatelessWidget {
  final Widget child;
  const _Pop({required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: HandyMotion.of(context, const Duration(milliseconds: 280)),
    curve: Curves.easeOutBack,
    builder: (context, k, child) =>
        Transform.scale(scale: math.max(0, k), child: child),
    child: child,
  );
}

/// A row arriving in a list: it opens to its height and fades in, so the
/// rows below move aside instead of jumping. Rows keyed by id only play it
/// once, when they are new. Still when motion is reduced.
class RowIn extends StatelessWidget {
  final Widget child;
  const RowIn({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final d = HandyMotion.of(context, const Duration(milliseconds: 300));
    if (d == Duration.zero) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: d,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: t,
          child: Opacity(opacity: t, child: child),
        ),
      ),
      child: child,
    );
  }
}

Widget _maybeHero(String? tag, Widget child) => tag == null
    ? child
    : Hero(
        tag: tag,
        child: Material(type: MaterialType.transparency, child: child),
      );
