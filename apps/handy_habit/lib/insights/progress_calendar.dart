import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/palette.dart';
import '../ui/words.dart';

String heatDayLabel(BuildContext context, HeatDay d, String today) {
  final counts = tr(
    context,
    '${d.kept} of ${d.eligible} kept',
    '${d.kept}/${d.eligible} đã giữ',
  );
  final state = d.day.compareTo(today) > 0
      ? tr(context, 'Later', 'Sắp tới')
      : d.eligible > 0
      ? counts
      : d.unknown > 0
      ? tr(context, 'Nothing recorded', 'Chưa ghi nhận')
      : d.paused > 0
      ? tr(context, 'Rest day', 'Ngày nghỉ')
      : tr(context, 'No finished goal', 'Chưa có mục tiêu hoàn tất');
  return '${formatDay(context, d.day)}: $state';
}

Color heatFill(BuildContext context, HeatDay d, Color hue) => d.kept == 0
    ? HabitPalette.of(context).raised
    : Color.lerp(HabitPalette.of(context).raised, hue, .3 + .7 * d.ratio)!;

class ProgressCalendar extends StatelessWidget {
  final List<HeatDay> days;
  final int weekStart;
  final String today;
  final Color hue;
  final ValueChanged<HeatDay> onDay;
  const ProgressCalendar({
    super.key,
    required this.days,
    required this.weekStart,
    required this.today,
    required this.hue,
    required this.onDay,
  });
  @override
  Widget build(BuildContext context) {
    final lead = (date(days.first.day).weekday - weekStart + 7) % 7;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Text(
                  weekdayShort(context, (weekStart + i - 1) % 7 + 1),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          key: const Key('progress-calendar'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            mainAxisExtent: MediaQuery.textScalerOf(context).scale(14) * 2 + 24,
          ),
          itemCount: ((lead + days.length + 6) ~/ 7) * 7,
          itemBuilder: (context, i) {
            if (i < lead || i >= lead + days.length) return const SizedBox();
            final d = days[i - lead],
                label = heatDayLabel(context, days[i - lead], today);
            return Semantics(
              label: label,
              button: true,
              excludeSemantics: true,
              child: Tooltip(
                message: label,
                child: InkWell(
                  key: Key('calendar-${d.day}'),
                  onTap: () => onDay(d),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: heatFill(
                        context,
                        d,
                        hue,
                      ).withValues(alpha: d.day.compareTo(today) > 0 ? .35 : 1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: d.day == today
                            ? hue
                            : d.unknown > 0
                            ? HabitPalette.of(context).control
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date(d.day).day}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: d.kept > 0 && d.ratio > .5
                                    ? (hue.computeLuminance() > .4
                                          ? Colors.black
                                          : Colors.white)
                                    : null,
                              ),
                        ),
                        if (d.eligible == 0 && d.unknown > 0)
                          Container(
                            key: const Key('calendar-unknown-mark'),
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: HabitPalette.of(context).control,
                              ),
                            ),
                          )
                        else
                          Text(
                            d.eligible > 0 ? '${d.kept}/${d.eligible}' : '–',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 11,
                                  color: d.kept > 0 && d.ratio > .5
                                      ? (hue.computeLuminance() > .4
                                            ? Colors.black
                                            : Colors.white)
                                      : null,
                                ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Seven weekday lanes and civil-date columns; scroll stays inside this frame.
class YearHeatmap extends StatelessWidget {
  final List<HeatDay> days;
  final String today;
  final int weekStart;
  final Color hue;
  final ValueChanged<HeatDay> onDay;
  const YearHeatmap({
    super.key,
    required this.days,
    required this.today,
    required this.weekStart,
    required this.hue,
    required this.onDay,
  });
  @override
  Widget build(BuildContext context) {
    final lead = (date(days.first.day).weekday - weekStart + 7) % 7;
    final weeks = (lead + days.length + 6) ~/ 7;
    return SingleChildScrollView(
      key: const Key('year-heatmap'),
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var w = 0; w < weeks; w++)
            SizedBox(
              width: 18,
              child: Column(
                children: [
                  SizedBox(
                    height: 26,
                    child: Builder(
                      builder: (context) {
                        final firsts = [
                          for (var j = 0; j < 7; j++)
                            if (w * 7 + j - lead >= 0 &&
                                w * 7 + j - lead < days.length)
                              days[w * 7 + j - lead].day,
                        ].where((d) => date(d).day == 1);
                        final first = firsts.firstOrNull;
                        return Text(
                          first == null ? '' : '${date(first).month}',
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(fontSize: 11),
                        );
                      },
                    ),
                  ),
                  for (var j = 0; j < 7; j++) _cell(context, w * 7 + j - lead),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, int i) {
    if (i < 0 || i >= days.length) return const SizedBox(width: 18, height: 18);
    final d = days[i], label = heatDayLabel(context, days[i], today);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Semantics(
        label: label,
        button: true,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: () => onDay(d),
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: d.unknown > 0 && d.eligible == 0
                    ? Colors.transparent
                    : heatFill(
                        context,
                        d,
                        hue,
                      ).withValues(alpha: d.day.compareTo(today) > 0 ? .3 : 1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: d.unknown > 0
                      ? HabitPalette.of(context).control
                      : Colors.transparent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
