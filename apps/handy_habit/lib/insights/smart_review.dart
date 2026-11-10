import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../ui/words.dart';

typedef ReviewSection = (String, List<String>);

String insightCountText(BuildContext c, InsightCount n) => tr(
  c,
  '${n.kept}/${n.eligible} goals kept${n.percent == null ? '' : ' · ${n.percent}%'}',
  'Giữ ${n.kept}/${n.eligible} mục tiêu${n.percent == null ? '' : ' · ${n.percent}%'}',
);

String dayPartText(BuildContext c, String part) => switch (part) {
  'morning' => tr(c, 'Morning', 'Buổi sáng'),
  'afternoon' => tr(c, 'Afternoon', 'Buổi chiều'),
  'evening' => tr(c, 'Evening', 'Buổi tối'),
  _ => tr(c, 'Anytime', 'Bất kỳ lúc nào'),
};

String difficultyText(BuildContext c, String d) => switch (d) {
  'steady' => tr(c, 'Steady', 'Đều đặn'),
  'building' => tr(c, 'Building', 'Đang xây nhịp'),
  'stretch' => tr(c, 'A stretch', 'Cần nhẹ hơn'),
  _ => tr(c, 'Still learning', 'Cần thêm dữ liệu'),
};

/// The screen and PDF consume the same evidence and explanations.
List<ReviewSection> smartReview(
  BuildContext c,
  HabitState s,
  String today,
  String kind,
) {
  String t(String en, String vi) => tr(c, en, vi);
  final w = insightWindows(kind, today), index = HabitIndex.of(s);
  final from = addDays(today, -28), until = addDays(today, -1);
  final current = w.until == null
      ? const InsightCount(0, 0)
      : insightCount(s.liveHabits, w.from, w.until!, today, index);
  final previous = w.previousUntil == null
      ? const InsightCount(0, 0)
      : insightCount(
          s.liveHabits,
          w.previousFrom,
          w.previousUntil!,
          today,
          index,
        );
  final delta = current.percent == null || previous.percent == null
      ? null
      : current.percent! - previous.percent!;
  return [
    (
      t('Your rhythms, side by side', 'Đặt nhịp sống cạnh nhau'),
      [
        '${w.from} – ${w.until ?? w.from}: ${insightCountText(c, current)}',
        '${w.previousFrom} – ${w.previousUntil ?? w.previousFrom}: ${insightCountText(c, previous)}',
        if (delta != null)
          t(
            '${delta >= 0 ? '+' : ''}$delta percentage points vs the previous period.',
            '${delta >= 0 ? '+' : ''}$delta điểm phần trăm so với khoảng trước.',
          ),
        t(
          'Same elapsed portion, clamped for a shorter prior period. Only closed days and whole weeks; pauses, skips, unknown days and conflicts excluded. Each daily goal or weekly goal counts once.',
          'Cùng phần đã qua; rút ngắn nếu khoảng trước ngắn hơn. Chỉ ngày đã hết và tuần trọn; bỏ ngày nghỉ, bỏ qua, chưa rõ và xung đột. Mỗi mục tiêu ngày hoặc tuần tính một lần.',
        ),
        if (w.until == null)
          t(
            'This period has no closed day yet.',
            'Khoảng này chưa có ngày nào kết thúc.',
          ),
      ],
    ),
    for (final byCollection in [false, true])
      (
        byCollection
            ? t('By collection · last 28 days', 'Theo nhóm · 28 ngày qua')
            : t(
                'Morning and evening · last 28 days',
                'Sáng và tối · 28 ngày qua',
              ),
        [
          '$from – $until',
          for (final e in insightGroups(
            s,
            from,
            until,
            today,
            byCollection: byCollection,
          ).entries)
            '${byCollection ? (e.key.isEmpty ? t('Uncollected', 'Chưa có nhóm') : e.key) : dayPartText(c, e.key)}: ${insightCountText(c, e.value)}',
          t(
            'Current grouping, weighted by eligible goals. Time comes from your chosen day part, then earliest enabled habit reminder or routine. It is not the time of past check-ins.',
            'Nhóm hiện tại, tính theo số mục tiêu hợp lệ. Buổi lấy từ lựa chọn của bạn, rồi lịch nhắc hoặc quy trình sớm nhất. Đây không phải giờ ghi trong quá khứ.',
          ),
        ],
      ),
    (
      t('Difficulty & missed weekdays', 'Độ khó & thứ hay lỡ'),
      [
        '$from – $until',
        t(
          'Steady ≥80%, building ≥50%, otherwise a stretch. Fewer than 7 eligible goals: still learning. This describes your current goal, not you. Weekday patterns use daily goals only.',
          'Đều đặn ≥80%, đang xây nhịp ≥50%, còn lại cần nhẹ hơn. Dưới 7 mục tiêu hợp lệ: cần thêm dữ liệu. Mô tả mục tiêu hiện tại, không đánh giá bạn. Mẫu theo thứ chỉ dùng mục tiêu ngày.',
        ),
        for (final h in s.liveHabits) ...[
          () {
            final n = insightCount([h], from, until, today, index);
            return '${h.title}: ${difficultyText(c, n.difficulty)} · ${insightCountText(c, n)} · ${t('${n.missed} missed', 'lỡ ${n.missed}')}';
          }(),
          () {
            final days = weekdaySlips(h, from, until, today, index);
            return [
              for (var i = 0; i < 7; i++)
                if (days[i].eligible > 0)
                  '${weekdayShort(c, i + 1)} ${days[i].missed}/${days[i].eligible}',
            ].join(' · ');
          }(),
        ],
      ],
    ),
    (
      t('Mood alongside habits', 'Tâm trạng cùng thói quen'),
      [
        '$from – $until',
        t(
          'Co-occurrence, never causation. Mood is a recorded 1–5 rating, not a clinical score. Requires ≥14 paired days and ≥3 in each group. Weekly goals, unknowns, pauses and disputed moods are excluded.',
          'Cùng xuất hiện, không suy ra nguyên nhân. Tâm trạng là mức 1–5 tự ghi, không phải thang lâm sàng. Cần ≥14 ngày ghép và ≥3 ngày mỗi nhóm. Bỏ mục tiêu tuần, ngày chưa rõ, nghỉ và tâm trạng xung đột.',
        ),
        for (final h in s.liveHabits)
          () {
            final m = moodCooccurrence(s, h, from, until, today);
            return m.enough
                ? t(
                    'On days you kept ${h.title}, mood was ${m.keptAverage!.toStringAsFixed(1)}/5 (${m.keptDays} days); on other eligible days, ${m.otherAverage!.toStringAsFixed(1)}/5 (${m.otherDays} days).',
                    'Vào ngày giữ ${h.title}, tâm trạng là ${m.keptAverage!.toStringAsFixed(1)}/5 (${m.keptDays} ngày); ngày hợp lệ còn lại, ${m.otherAverage!.toStringAsFixed(1)}/5 (${m.otherDays} ngày).',
                  )
                : t(
                    '${h.title}: ${m.keptDays + m.otherDays} paired days (${m.keptDays} kept, ${m.otherDays} other). More observations needed.',
                    '${h.title}: ${m.keptDays + m.otherDays} ngày ghép (${m.keptDays} đã giữ, ${m.otherDays} còn lại). Cần thêm ghi nhận.',
                  );
          }(),
      ],
    ),
  ];
}
