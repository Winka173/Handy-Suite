import 'package:handy_ui/kit.dart';
import '../design/palette.dart';
import '../today/beads.dart';

/// Same intentions, first scattered/fading, then gathered as daily beads.
class HabitStoryScene extends StatelessWidget {
  final bool gathered;
  const HabitStoryScene({super.key, required this.gathered});
  @override
  Widget build(BuildContext context) {
    final p = HabitPalette.of(context);
    final time = HandyMotion.of(context, const Duration(milliseconds: 650));
    return ExcludeSemantics(
      child: MediaQuery.withNoTextScaling(
        child: FittedBox(
          child: SizedBox(
            width: 360,
            height: 440,
            child: Stack(
              children: [
                for (var i = 0; i < 3; i++)
                  AnimatedPositioned(
                    duration: time,
                    curve: Curves.easeInOutCubic,
                    left: gathered ? 8 : [8.0, 58.0, 20.0][i],
                    top: gathered ? 16 + i * 144 : [20.0, 166.0, 308.0][i],
                    width: gathered ? 344 : 286,
                    child: AnimatedRotation(
                      duration: time,
                      turns: gathered ? 0 : [-.025, .025, -.015][i],
                      child: TweenAnimationBuilder<double>(
                        duration: time * 4,
                        tween: Tween(begin: 0, end: gathered ? 0 : 1),
                        builder: (context, opacity, child) =>
                            Transform.translate(
                              offset: Offset(
                                (i.isEven ? -12 : 8) * opacity,
                                8 * opacity,
                              ),
                              child: Opacity(
                                opacity: 1 - opacity * (.14 + i * .08),
                                child: child,
                              ),
                            ),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: gathered ? p.surface : p.ochreField,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: p.line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr(
                                  context,
                                  [
                                    'Drink water',
                                    'Read a little',
                                    'Move today',
                                  ][i],
                                  [
                                    'Uống nước',
                                    'Đọc một chút',
                                    'Vận động hôm nay',
                                  ][i],
                                ),
                                style: TextStyle(
                                  color: p.ink,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 44,
                                child: Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    AnimatedOpacity(
                                      duration: time,
                                      opacity: gathered ? 1 : 0,
                                      child: BeadWeek(
                                        completed: 4 + i,
                                        color: i == 1 ? p.ochre : p.vermilion,
                                      ),
                                    ),
                                    AnimatedOpacity(
                                      duration: time,
                                      opacity: gathered ? 0 : 1,
                                      child: Row(
                                        children: [
                                          Icon(
                                            [
                                              Icons.sticky_note_2_outlined,
                                              Icons
                                                  .local_fire_department_outlined,
                                              Icons.calendar_today_outlined,
                                            ][i],
                                            color: p.muted,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              tr(
                                                context,
                                                [
                                                  'A note left behind',
                                                  'A streak forgotten',
                                                  'An empty calendar',
                                                ][i],
                                                [
                                                  'Tờ ghi chú bị quên',
                                                  'Chuỗi ngày bỏ dở',
                                                  'Lịch còn trống',
                                                ][i],
                                              ),
                                              style: TextStyle(color: p.muted),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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

class MissedDayScene extends StatelessWidget {
  const MissedDayScene({super.key});
  @override
  Widget build(BuildContext context) {
    final p = HabitPalette.of(context);
    return ExcludeSemantics(
      child: MediaQuery.withNoTextScaling(
        child: FittedBox(
          child: SizedBox(
            width: 360,
            height: 460,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    tr(context, 'One week of reading', 'Một tuần đọc sách'),
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
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
                              style: TextStyle(fontSize: 13, color: p.muted),
                            ),
                            const SizedBox(height: 16),
                            Bead(
                              status: i == 4 ? 'missed' : 'completed',
                              fill: 1,
                              size: 30,
                              color: p.ochre,
                            ),
                          ],
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '86%',
                        style: TextStyle(
                          fontSize: 44,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: p.ochre,
                        ),
                      ),
                      Text(
                        tr(
                          context,
                          '6 of 7 days kept · 86% consistency',
                          'Giữ được 6/7 ngày · Đều đặn 86%',
                        ),
                        style: TextStyle(fontSize: 15, color: p.ochre),
                      ),
                    ],
                  ),
                  Text(
                    tr(
                      context,
                      'Current streak: 2 days. Best: 4 days. A missed day restarts the current streak; it never erases the days you kept.',
                      'Chuỗi hiện tại: 2 ngày. Tốt nhất: 4 ngày. Ngày lỡ bắt đầu lại chuỗi hiện tại, không xóa những ngày đã làm.',
                    ),
                    style: TextStyle(fontSize: 16, height: 1.5, color: p.ink),
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
