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
            height: 330,
            child: Stack(
              children: [
                for (var i = 0; i < 3; i++)
                  AnimatedPositioned(
                    duration: time,
                    curve: Curves.easeInOutCubic,
                    left: gathered ? 16 : [8.0, 100.0, 34.0][i],
                    top: gathered ? 16 + i * 100 : [8.0, 112.0, 226.0][i],
                    width: gathered ? 328 : 220,
                    child: AnimatedRotation(
                      duration: time,
                      turns: gathered ? 0 : [-.025, .025, -.015][i],
                      child: TweenAnimationBuilder<double>(
                        duration: time * 2,
                        tween: Tween(begin: 1, end: gathered ? 1 : .65),
                        builder: (context, opacity, child) =>
                            Opacity(opacity: opacity, child: child),
                        child: Container(
                          padding: const EdgeInsets.all(16),
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
                              if (gathered)
                                BeadWeek(
                                  completed: 4 + i,
                                  color: i == 1 ? p.ochre : p.vermilion,
                                )
                              else
                                Row(
                                  children: [
                                    Icon(
                                      [
                                        Icons.sticky_note_2_outlined,
                                        Icons.local_fire_department_outlined,
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(context, 'One week of reading', 'Một tuần đọc sách'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                Bead(
                  status: i == 4 ? 'missed' : 'completed',
                  fill: 1,
                  size: 24,
                  color: p.ochre,
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            tr(
              context,
              '6 of 7 days kept · 86% consistency',
              'Giữ được 6/7 ngày · Đều đặn 86%',
            ),
            style: TextStyle(color: p.ochre, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            tr(
              context,
              'Current streak: 2 days. Best: 4 days. A missed day restarts the current streak; it never erases the days you kept.',
              'Chuỗi hiện tại: 2 ngày. Tốt nhất: 4 ngày. Ngày lỡ bắt đầu lại chuỗi hiện tại, không xóa những ngày đã làm.',
            ),
          ),
        ],
      ),
    );
  }
}
