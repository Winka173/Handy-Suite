import 'package:handy_habit_engine/handy_habit_engine.dart';
import 'package:handy_ui/kit.dart';
import '../ui/words.dart';
import 'insight_dates.dart';

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

/// Methods live behind a single disclosure, away from the findings.
List<String> insightMethods(BuildContext c) => [
  tr(
    c,
    'Compare the same elapsed portion of each month or quarter, shortened if the previous period is shorter. Only closed days and whole weeks count. Pauses, skips, unknown days and conflicts are excluded; each daily or weekly goal counts once.',
    'So cùng phần đã qua của tháng hoặc quý, rút ngắn nếu khoảng trước ngắn hơn. Chỉ tính ngày đã hết và tuần trọn. Bỏ ngày nghỉ, bỏ qua, chưa rõ và xung đột; mỗi mục tiêu ngày hoặc tuần tính một lần.',
  ),
  tr(
    c,
    'Groups use your current collection and chosen time of day, then the earliest enabled reminder or routine time. These are not past check-in times. Rates use the number of eligible goals in each group.',
    'Nhóm dùng nhóm và buổi hiện tại bạn chọn, rồi giờ nhắc hoặc quy trình sớm nhất. Đây không phải giờ ghi nhận trong quá khứ. Tỷ lệ tính theo số mục tiêu hợp lệ của mỗi nhóm.',
  ),
  tr(
    c,
    'Weekday patterns use daily goals only. The hardest day has the highest share of missed goals; tied weekdays are shown together. Difficulty: at least 80% kept is steady, at least 50% is building, otherwise a stretch; fewer than seven eligible goals needs more history.',
    'Mẫu theo thứ chỉ dùng mục tiêu ngày. Thứ khó nhất có tỷ lệ lỡ cao nhất; các thứ bằng nhau được nêu cùng nhau. Độ khó: giữ ít nhất 80% là đều đặn, ít nhất 50% là đang xây nhịp, còn lại cần nhẹ hơn; dưới bảy mục tiêu hợp lệ cần thêm lịch sử.',
  ),
  tr(
    c,
    'Mood is your recorded 1–5 rating. A comparison needs at least 14 paired days and three in each group. Weekly goals, unknown days, pauses and disputed moods are excluded. This can show co-occurrence, never causation.',
    'Tâm trạng là mức 1–5 bạn tự ghi. So sánh cần ít nhất 14 ngày ghép và ba ngày ở mỗi nhóm. Bỏ mục tiêu tuần, ngày chưa rõ, nghỉ và tâm trạng xung đột. Chỉ cho thấy cùng xuất hiện, không suy ra nguyên nhân.',
  ),
  tr(
    c,
    'Suggestions use the latest ten comparable daily goals within 28 days. Nine kept suggests a 25% increase; five or fewer a 25% decrease, rounded to whole units. Binary, reduction and weekly goals are excluded. Accept starts a new target tomorrow; past history stays unchanged.',
    'Gợi ý dùng mười mục tiêu ngày tương đương gần nhất trong 28 ngày. Giữ chín gợi ý tăng 25%; năm hoặc ít hơn gợi ý giảm 25%, làm tròn đơn vị. Bỏ mục tiêu có/không, giảm và theo tuần. Nhận sẽ đổi từ ngày mai; giữ nguyên lịch sử.',
  ),
  tr(
    c,
    'Heatmap filters combine current collection, time of day, build/reduce, weekday and recorded outcome. Weekly goals repeat their closed-week result. Hollow cells mean unknown; neutral cells mean no kept goal. Tap a cell for its date and counts.',
    'Bộ lọc kết hợp nhóm hiện tại, buổi, xây/giảm, thứ và kết quả. Mục tiêu tuần lặp kết quả tuần đã hết. Ô rỗng là chưa rõ; ô trung tính là chưa giữ mục tiêu. Chạm ô để xem ngày và số đếm.',
  ),
];

/// Both screen and PDF consume these computed findings.
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
  final a = current.percent, b = previous.percent;
  final period = kind == 'month' ? t('month', 'Tháng') : t('quarter', 'Quý');
  final sections = <ReviewSection>[
    (
      a == null || b == null
          ? t(
              'A little more history to compare.',
              'Thêm chút lịch sử để so sánh.',
            )
          : t(
              'You kept ${a > b
                  ? 'more'
                  : a < b
                  ? 'less'
                  : 'the same share'} this $period: $a% vs $b%.',
              '$period này bạn giữ ${a > b
                  ? 'nhiều hơn'
                  : a < b
                  ? 'ít hơn'
                  : 'tỷ lệ như trước'}: $a% so với $b%.',
            ),
      [
        '${insightDates(c, w.from, w.until ?? w.from)} · ${insightCountText(c, current)}',
        '${insightDates(c, w.previousFrom, w.previousUntil ?? w.previousFrom)} · ${insightCountText(c, previous)}',
      ],
    ),
  ];
  for (final byCollection in [false, true]) {
    final groups = insightGroups(
      s,
      from,
      until,
      today,
      byCollection: byCollection,
    );
    final known = groups.entries.where((e) => e.value.eligible > 0).toList()
      ..sort(
        (a, b) => (a.value.kept / a.value.eligible).compareTo(
          b.value.kept / b.value.eligible,
        ),
      );
    String name(String key) => byCollection
        ? (key.isEmpty ? t('Ungrouped habits', 'Thói quen chưa có nhóm') : key)
        : dayPartText(c, key);
    final first = known.firstOrNull, last = known.lastOrNull;
    sections.add((
      first == null
          ? t(
              'Your rhythm is still taking shape.',
              'Nhịp của bạn đang dần hình thành.',
            )
          : known.length < 2
          ? t(
              '${name(first.key)}: ${first.value.percent}% kept.',
              '${name(first.key)}: giữ ${first.value.percent}%.',
            )
          : first.value.kept * last!.value.eligible ==
                last.value.kept * first.value.eligible
          ? t(
              'Your ${byCollection ? 'collections' : 'times of day'} are in step.',
              'Các ${byCollection ? 'nhóm' : 'buổi'} đang cùng nhịp.',
            )
          : t(
              '${name(first.key)} slips more than ${name(last.key).toLowerCase()}.',
              '${name(first.key)} hay lỡ hơn ${name(last.key).toLowerCase()}.',
            ),
      [
        insightDates(c, from, until),
        for (final e in groups.entries)
          '${name(e.key)} · ${insightCountText(c, e.value)}',
      ],
    ));
  }
  final days = List.generate(7, (_) => const InsightCount(0, 0));
  for (final h in s.liveHabits) {
    final slips = weekdaySlips(h, from, until, today, index);
    for (var i = 0; i < 7; i++)
      days[i] = InsightCount(
        days[i].kept + slips[i].kept,
        days[i].eligible + slips[i].eligible,
      );
  }
  final known =
      [
        for (var i = 0; i < 7; i++)
          if (days[i].eligible > 0) i,
      ]..sort(
        (a, b) => (days[b].missed / days[b].eligible).compareTo(
          days[a].missed / days[a].eligible,
        ),
      );
  final worst = known.firstOrNull;
  final tied = worst == null
      ? <int>[]
      : (known
            .where(
              (i) =>
                  days[i].missed * days[worst].eligible ==
                  days[worst].missed * days[i].eligible,
            )
            .toList()
          ..sort());
  sections.add((
    worst == null
        ? t('More days will reveal a pattern.', 'Thêm ngày sẽ rõ nhịp hơn.')
        : days[worst].missed == 0
        ? t(
            'You kept every recorded daily goal.',
            'Bạn giữ mọi mục tiêu ngày đã ghi.',
          )
        : tied.length == 7
        ? t(
            'No weekday is harder than the others.',
            'Các thứ có tỷ lệ lỡ như nhau.',
          )
        : t(
            '${tied.map((i) => weekdayLong(c, i + 1)).join(', ')} ${tied.length == 1 ? 'is your hardest day' : 'are your hardest days'}.',
            '${tied.map((i) => weekdayLong(c, i + 1)).join(', ')} là ${tied.length == 1 ? 'ngày' : 'những ngày'} khó nhất.',
          ),
    [
      insightDates(c, from, until),
      if (worst != null)
        t(
          '${days[worst].missed} of ${days[worst].eligible} daily goals missed on ${weekdayLong(c, worst + 1)}.',
          'Lỡ ${days[worst].missed}/${days[worst].eligible} mục tiêu ngày vào ${weekdayLong(c, worst + 1)}.',
        ),
      for (final h in s.liveHabits)
        '${h.title} · ${difficultyText(c, insightCount([h], from, until, today, index).difficulty)} · ${insightCountText(c, insightCount([h], from, until, today, index))}',
    ],
  ));
  sections.add((
    t('Mood alongside your habits.', 'Tâm trạng cùng thói quen.'),
    [
      insightDates(c, from, until),
      for (final h in s.liveHabits)
        () {
          final m = moodCooccurrence(s, h, from, until, today);
          String average(double n) => isVi(c)
              ? n.toStringAsFixed(1).replaceAll('.', ',')
              : n.toStringAsFixed(1);
          return m.enough
              ? t(
                  '${h.title}: mood averaged ${average(m.keptAverage!)}/5 on ${m.keptDays} days kept, and ${average(m.otherAverage!)}/5 on ${m.otherDays} other days.',
                  '${h.title}: tâm trạng trung bình ${average(m.keptAverage!)}/5 trong ${m.keptDays} ngày giữ, và ${average(m.otherAverage!)}/5 trong ${m.otherDays} ngày còn lại.',
                )
              : t(
                  '${h.title}: ${m.keptDays + m.otherDays} days with mood and habit records; a little more history will help.',
                  '${h.title}: ${m.keptDays + m.otherDays} ngày có cả tâm trạng và thói quen; cần thêm chút lịch sử.',
                );
        }(),
      t(
        'Alongside, never causation.',
        'Cùng xuất hiện, không suy ra nguyên nhân.',
      ),
    ],
  ));
  return sections;
}
