import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../habits/habit_editor.dart';
import '../habits/habit_appearance.dart';
import '../scope.dart';
import '../today/beads.dart';
import '../ui/words.dart';

Future<void> openWeekReview(BuildContext context, HabitScope scope) =>
    Navigator.pushNamed(context, '/progress/week');

/// The week to look back on, or null on days it is not worth offering:
/// from the week's last day to two days after it, when something was due.
WeekReview? reviewDue(HabitScope scope) {
  final s = scope.state, today = scope.today;
  final start = reviewWeekStart(today, s.weekStart);
  if (date(today).difference(date(addDays(start, 6))).inDays > 2) return null;
  final r = weekReview(s, scope.index, start, today);
  return r.due == 0 ? null : r;
}

/// The Today row that opens the review on its days.
class WeekReviewRow extends StatelessWidget {
  final HabitScope scope;
  final WeekReview review;
  const WeekReviewRow({super.key, required this.scope, required this.review});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: HandySpace.l),
    child: HandyGroup(
      children: [
        HandyTile(
          key: const Key('week-review-open'),
          icon: Icons.event_note_outlined,
          title: tr(context, 'Look back at the week', 'Nhìn lại tuần qua'),
          subtitle: tr(
            context,
            'Kept ${review.kept} of ${review.due}',
            'Giữ được ${review.kept} trên ${review.due} lần',
          ),
          navigates: true,
          onTap: () => openWeekReview(context, scope),
        ),
      ],
    ),
  );
}

/// One week looked back on: what was kept, the day that slips, and the
/// habits worth making smaller for the week ahead.
class WeekReviewPage extends StatelessWidget {
  final HabitScope scope;
  final String? from;
  const WeekReviewPage({super.key, required this.scope, this.from});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.controller,
    builder: (context, _) {
      final s = scope.state, today = scope.today;
      final r = weekReview(
        s,
        scope.index,
        from != null && _validDay(from!)
            ? from!
            : reviewWeekStart(today, s.weekStart),
        today,
      );
      final theme = Theme.of(context);
      final c = HandyColors.of(context);
      final title = tr(context, 'The week', 'Nhìn lại tuần');
      if (r.due == 0) {
        return HandyPage(
          title: title,
          children: [
            HandyEmpty(
              title: tr(
                context,
                s.liveHabits.any((h) => h.isNegative)
                    ? 'No closed periods to review yet.'
                    : 'Nothing was due that week.',
                s.liveHabits.any((h) => h.isNegative)
                    ? 'Chưa có kỳ đã chốt để nhìn lại.'
                    : 'Tuần đó chưa có gì đến hạn.',
              ),
              message: tr(
                context,
                'Habits you keep show up here at the end of each week.',
                'Cuối mỗi tuần, các thói quen bạn giữ sẽ hiện ở đây.',
              ),
            ),
          ],
        );
      }
      final facts = [
        if (r.habits.any((w) => w.habit.isNegative))
          tr(
            context,
            'Weekly limits: counted from what you recorded. Pauses, unknown days and unfinished weeks are left out.',
            'Giới hạn tuần: tính từ những lần bạn đã ghi. Không tính ngày nghỉ, ngày chưa rõ và tuần chưa hết.',
          ),
        if (r.dueBefore > 0)
          tr(
            context,
            'The week before: ${r.keptBefore} of ${r.dueBefore}.',
            'Tuần trước nữa: ${r.keptBefore} trên ${r.dueBefore}.',
          ),
        if (r.hardestDay != null)
          tr(
            context,
            '${weekdayLong(context, r.hardestDay!)} slips most often.',
            '${weekdayLong(context, r.hardestDay!)} hay bị lỡ nhất.',
          ),
      ];
      return HandyPage(
        title: title,
        children: [
          Text(
            '${formatDay(context, r.start)} – ${formatDay(context, r.end)}',
            style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
          ),
          const SizedBox(height: HandySpace.xs),
          // The week's one finding, set as the page's headline.
          Semantics(
            header: true,
            child: Text(
              tr(
                context,
                'Kept ${r.kept} of ${r.due}.',
                'Giữ được ${r.kept} trên ${r.due} lần.',
              ),
              key: const Key('week-review-kept'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 34,
                fontWeight: FontWeight.w400,
                height: 1.15,
              ),
            ),
          ),
          if (facts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: HandySpace.s),
              child: Text(facts.join(' '), style: theme.textTheme.bodyLarge),
            ),
          HandySection(
            title: tr(context, 'Each habit', 'Từng thói quen'),
            children: [
              for (final w in r.habits) _HabitWeekRow(scope, w, r.start),
            ],
          ),
        ],
      );
    },
  );
}

class _HabitWeekRow extends StatelessWidget {
  final HabitScope scope;
  final HabitWeek week;
  final String start;
  const _HabitWeekRow(this.scope, this.week, this.start);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = week.habit;
    return Padding(
      key: Key('week-review-${h.id}'),
      padding: const EdgeInsets.all(HandySpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (h.isNegative)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: habitMark(context, h),
                  ),
                )
              else
                HandyDot(scope.habitHue(h.id), size: 8),
              const SizedBox(width: HandySpace.s),
              Expanded(child: Text(h.title, style: theme.textTheme.bodyLarge)),
              Text(
                '${week.kept}/${week.due}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontFeatures: tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: HandySpace.s),
          Semantics(
            label: [
              for (var i = 0; i < 7; i++)
                '${weekdayShort(context, date(addDays(start, i)).weekday)}: ${statusLabel(context, week.days[i])}',
            ].join('; '),
            excludeSemantics: true,
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: HandySpace.s),
                    child: Bead(
                      status: week.days[i],
                      fill: dayFill(h, addDays(start, i), scope.index),
                      size: 14,
                      // The habit's own colour, as on Today.
                      color: habitMark(context, h),
                    ),
                  ),
              ],
            ),
          ),
          if (h.isNegative) ...[
            const SizedBox(height: HandySpace.s),
            Text(
              tr(
                context,
                'Kept ${week.kept} of ${week.due} ${negativeGoalOn(h, start)?.window == 'week' ? 'weeks' : 'days'} · ${week.unknown} ${week.unknown == 1 ? 'day' : 'days'} left unknown.',
                'Giữ được ${week.kept}/${week.due} ${negativeGoalOn(h, start)?.window == 'week' ? 'tuần' : 'ngày'} · ${week.unknown} ngày chưa ghi.',
              ),
            ),
          ],
          if (week.struggling) ...[
            const SizedBox(height: HandySpace.s),
            Text(
              tr(
                context,
                'Under half kept. A smaller step may hold next week.',
                'Giữ chưa được một nửa. Một bước nhỏ hơn có thể giữ được tuần tới.',
              ),
              style: theme.textTheme.bodyMedium,
            ),
            TextButton(
              key: Key('week-review-smaller-${h.id}'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 48),
              ),
              onPressed: () => openHabitEditor(context, scope, h),
              child: Text(tr(context, 'Make it smaller', 'Làm nhỏ lại')),
            ),
          ],
        ],
      ),
    );
  }
}

bool _validDay(String value) {
  try {
    date(value);
    return true;
  } catch (_) {
    return false;
  }
}
