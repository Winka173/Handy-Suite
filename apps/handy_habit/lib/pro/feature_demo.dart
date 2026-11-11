import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../insights/smart_demo.dart';
import '../insights/insight_dates.dart';
import '../design/palette.dart';
import '../design/studio_style.dart';
import '../design/studio_preview.dart';
import '../design/theme.dart';
import 'entitlements.dart';

Widget featureDemo(BuildContext c, HabitProFeature f, bool after) {
  String t(String en, String vi) => tr(c, en, vi);
  final s = smartDemoState(), index = HabitIndex.of(s);
  final count = insightCount(
    s.habits,
    after ? '2026-11-01' : '2026-10-01',
    after ? '2026-11-10' : '2026-10-10',
    smartDemoToday,
    index,
  );
  final mood = moodCooccurrence(
    s,
    s.habits.single,
    '2026-10-14',
    '2026-11-10',
    smartDemoToday,
  );
  final label = switch (f) {
    HabitProFeature.convenience =>
      after
          ? t('After morning: Water +1', 'Sau buổi sáng: Nước +1')
          : t(
              'Save your view · preview a batch',
              'Lưu bộ lọc · xem trước thay đổi',
            ),
    HabitProFeature.comparisons => t(
      '${after ? 'This' : 'Last'} month · ${count.kept}/${count.eligible} goals kept',
      'Tháng ${after ? 'này' : 'trước'} · giữ ${count.kept}/${count.eligible} mục tiêu',
    ),
    HabitProFeature.patterns => t(
      '${count.missed}/${count.eligible} missed · ${count.percent}% consistency',
      'Lỡ ${count.missed}/${count.eligible} · đều đặn ${count.percent}%',
    ),
    HabitProFeature.goals =>
      after
          ? t('Try 8 pages from tomorrow?', 'Thử 8 trang từ ngày mai?')
          : t(
              '9/10 at 6 pages · your choice',
              '9/10 ở mức 6 trang · bạn quyết định',
            ),
    HabitProFeature.mood =>
      after
          ? t(
              'On other eligible days, mood was ${mood.otherAverage?.toStringAsFixed(1)}/5 (${mood.otherDays} days).',
              'Ngày hợp lệ còn lại, tâm trạng là ${mood.otherAverage?.toStringAsFixed(1)}/5 (${mood.otherDays} ngày).',
            )
          : t(
              'On days you read, mood was ${mood.keptAverage?.toStringAsFixed(1)}/5 (${mood.keptDays} days).',
              'Vào ngày đọc sách, tâm trạng là ${mood.keptAverage?.toStringAsFixed(1)}/5 (${mood.keptDays} ngày).',
            ),
    HabitProFeature.heatmap =>
      after
          ? t(
              'Morning · Learning · daily goals',
              'Buổi sáng · Học tập · mục tiêu ngày',
            )
          : t('All habits · November', 'Mọi thói quen · Tháng 11'),
    HabitProFeature.reports =>
      after
          ? t(
              'Preview PDF · counts and methods included',
              'Xem trước PDF · có số liệu và cách tính',
            )
          : t(
              'Handy Habit · your monthly review',
              'Handy Habit · nhìn lại tháng',
            ),
    _ =>
      after
          ? t(
              'Grove · framed cards · quiet runner',
              'Tán lá · thẻ có khung · màn chạy tĩnh',
            )
          : t(
              'Vermilion · open rows · bead runner',
              'Đỏ son · hàng mở · màn chạy hạt',
            ),
  };
  final p = HabitPalette.of(c);
  final style = StudioStyle(
    palette: after ? 'grove' : 'vermilion',
    layout: after ? 'cards' : 'rows',
    runner: after ? 'quiet' : 'beads',
  );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        liveRegion: true,
        child: Text(
          label,
          key: const Key('pro-demo-input'),
          style: Theme.of(c).textTheme.titleMedium,
        ),
      ),
      const SizedBox(height: 12),
      if (f == HabitProFeature.studio)
        Theme(
          data: habitTheme(Theme.of(c), style: style),
          child: StudioPreview(style: style),
        )
      else if (f == HabitProFeature.comparisons ||
          f == HabitProFeature.patterns) ...[
        LinearProgressIndicator(
          value: count.kept / count.eligible,
          color: p.vermilion,
          backgroundColor: p.surface,
          minHeight: 12,
        ),
        const SizedBox(height: 8),
        Text(
          t(
            'Read · ${count.kept} kept, ${count.missed} missed out of ${count.eligible}',
            'Đọc · giữ ${count.kept}, lỡ ${count.missed} trên ${count.eligible}',
          ),
        ),
      ] else if (f == HabitProFeature.heatmap)
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final d in progressDays(
              s.habits,
              after ? '2026-11-01' : '2026-10-01',
              after ? '2026-11-10' : '2026-10-10',
              smartDemoToday,
              index,
            ))
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                color: d.kept > 0 ? p.tint : p.surface,
                child: Text(d.day.substring(8)),
              ),
          ],
        )
      else if (f == HabitProFeature.goals)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < 10; i++)
              Icon(
                i < 9
                    ? Icons.check_circle_outline
                    : Icons.radio_button_unchecked,
                color: i < 9 ? p.vermilion : p.muted,
              ),
          ],
        )
      else if (f == HabitProFeature.mood)
        Row(
          children: [
            for (var i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  i < (after ? mood.otherAverage! : mood.keptAverage!)
                      ? Icons.circle
                      : Icons.circle_outlined,
                  size: 20,
                  color: p.ink,
                ),
              ),
          ],
        )
      else if (f == HabitProFeature.convenience)
        Row(
          children: [
            const Icon(Icons.water_drop_outlined),
            const SizedBox(width: 8),
            Expanded(child: Text(t('Water', 'Uống nước'))),
            Text(after ? '+1' : '0'),
          ],
        )
      else if (f == HabitProFeature.reports)
        Container(
          color: p.surface,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Handy Habit', style: Theme.of(c).textTheme.titleLarge),
              const Divider(),
              Text(insightDates(c, '2026-11-01', '2026-11-10')),
              Text('${count.kept}/${count.eligible} · ${count.percent}%'),
              if (after)
                Text(
                  t(
                    'Your PDF includes goal totals, how they are counted and the number of days with mood records.',
                    'PDF có tổng mục tiêu, cách tính và số ngày có ghi tâm trạng.',
                  ),
                ),
            ],
          ),
        ),
      Text(
        f == HabitProFeature.mood
            ? t(
                'Co-occurrence only. No cause is inferred.',
                'Chỉ là cùng xuất hiện. Không suy ra nguyên nhân.',
              )
            : t(
                'Example history · nothing is saved',
                'Lịch sử ví dụ · không lưu gì',
              ),
        style: Theme.of(c).textTheme.bodySmall,
      ),
    ],
  );
}
