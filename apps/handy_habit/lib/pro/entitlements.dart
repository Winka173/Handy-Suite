import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_ui/kit.dart';

/// Only capabilities shipped in Habit.
enum HabitProFeature {
  days,
  unfinished,
  timeLeft,
  choices,
  dependencies,
  stacking,
  durations,
  blocks,
  presets,
  comparisons,
  patterns,
  goals,
  mood,
  heatmap,
  reports,
  studio,
  convenience,
}

String proTitle(BuildContext c, HabitProFeature feature) => switch (feature) {
  HabitProFeature.comparisons => tr(
    c,
    'Compare your rhythms',
    'So sánh nhịp sống',
  ),
  HabitProFeature.patterns => tr(
    c,
    'Difficulty & missed days',
    'Độ khó & ngày hay lỡ',
  ),
  HabitProFeature.goals => tr(
    c,
    'Small goal adjustments',
    'Điều chỉnh mục tiêu nhỏ',
  ),
  HabitProFeature.mood => tr(
    c,
    'Mood alongside habits',
    'Tâm trạng cùng thói quen',
  ),
  HabitProFeature.heatmap => tr(
    c,
    'Focused heatmaps',
    'Biểu đồ nhiệt có bộ lọc',
  ),
  HabitProFeature.reports => tr(
    c,
    'Your review on paper',
    'Bản nhìn lại trên giấy',
  ),
  HabitProFeature.convenience => tr(
    c,
    'Everyday convenience',
    'Tiện ích hằng ngày',
  ),
  HabitProFeature.studio => tr(c, 'Personalization studio', 'Xưởng giao diện'),
  HabitProFeature.days => tr(c, 'Days to run', 'Ngày thực hiện'),
  HabitProFeature.unfinished => tr(
    c,
    'Unfinished habit',
    'Thói quen chưa xong',
  ),
  HabitProFeature.timeLeft => tr(c, 'Time left', 'Thời gian còn lại'),
  HabitProFeature.choices => tr(c, 'Choose A or B', 'Chọn A hoặc B'),
  HabitProFeature.dependencies => tr(c, 'Dependencies', 'Bước cần xong trước'),
  HabitProFeature.stacking => tr(c, 'After a habit', 'Sau một thói quen'),
  HabitProFeature.durations => tr(c, 'Duration by day', 'Thời lượng theo ngày'),
  HabitProFeature.blocks => tr(c, 'Reusable step blocks', 'Nhóm bước dùng lại'),
  HabitProFeature.presets => tr(c, 'Saved presets', 'Cấu hình đã lưu'),
};

String proLine(BuildContext c, HabitProFeature feature) => switch (feature) {
  HabitProFeature.comparisons => tr(
    c,
    'Months, quarters and groups, with the counts behind them.',
    'Tháng, quý và nhóm, kèm số liệu rõ ràng.',
  ),
  HabitProFeature.patterns => tr(
    c,
    'See which daily goals and weekdays need room.',
    'Biết mục tiêu và thứ nào cần nhẹ nhàng hơn.',
  ),
  HabitProFeature.goals => tr(
    c,
    'Accept or dismiss a suggestion from your own history.',
    'Nhận hoặc bỏ qua gợi ý từ lịch sử của bạn.',
  ),
  HabitProFeature.mood => tr(
    c,
    'Compare recorded mood on known habit days.',
    'So sánh tâm trạng vào ngày thói quen đã rõ.',
  ),
  HabitProFeature.heatmap => tr(
    c,
    'Combine collection, time, direction and day filters.',
    'Kết hợp bộ lọc nhóm, buổi, hướng và ngày.',
  ),
  HabitProFeature.reports => tr(
    c,
    'Preview a designed PDF with explained figures.',
    'Xem trước PDF được dàn trang, giải thích số liệu.',
  ),
  HabitProFeature.convenience => tr(
    c,
    'Saved views, batch changes and clear local rules.',
    'Lưu bộ lọc, sửa hàng loạt và quy tắc cục bộ rõ ràng.',
  ),
  HabitProFeature.studio => tr(
    c,
    'Habit palettes, Today layouts, extra icons and runner looks.',
    'Bảng màu Habit, bố cục Hôm nay, biểu tượng và màn chạy.',
  ),
  HabitProFeature.days => tr(
    c,
    'Run a step on selected weekdays.',
    'Chạy bước vào những thứ đã chọn.',
  ),
  HabitProFeature.unfinished => tr(
    c,
    'Skip a step when its habit is already done.',
    'Bỏ qua bước khi thói quen đã xong.',
  ),
  HabitProFeature.timeLeft => tr(
    c,
    'Fit a step into the time remaining.',
    'Chọn bước vừa thời gian còn lại.',
  ),
  HabitProFeature.choices => tr(
    c,
    'Pick one of two paths while running.',
    'Chọn một trong hai nhánh khi chạy.',
  ),
  HabitProFeature.dependencies => tr(
    c,
    'Wait for earlier steps to be completed.',
    'Chờ các bước trước hoàn thành.',
  ),
  HabitProFeature.stacking => tr(
    c,
    'Follow a linked habit with the next action.',
    'Tiếp nối thói quen liên kết bằng hành động sau.',
  ),
  HabitProFeature.durations => tr(
    c,
    'Give different days different durations.',
    'Đặt thời lượng khác nhau theo ngày.',
  ),
  HabitProFeature.blocks => tr(
    c,
    'Insert independent copies of saved steps.',
    'Chèn bản sao độc lập của nhóm bước đã lưu.',
  ),
  HabitProFeature.presets => tr(
    c,
    'Replace draft steps with a saved plan.',
    'Thay bước trong nháp bằng phương án đã lưu.',
  ),
};

bool get habitStoreSupported => monetizationPlatform == 'android';

Future<void> openHabitPro(BuildContext context, [HabitProFeature? feature]) =>
    Navigator.pushNamed<void>(
      context,
      feature == null ? '/pro' : '/pro?feature=${feature.name}',
    );

/// The small tinted 'Pro' pill, as Settings and the siblings draw it
/// beside a feature's name.
class HabitProPill extends StatelessWidget {
  const HabitProPill({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Pro',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A badge is a destination, never an entitlement toggle: the pill, with a
/// 48 px target that opens Pro at [feature].
class HabitProBadge extends StatelessWidget {
  final HabitProFeature feature;
  const HabitProBadge({super.key, required this.feature});
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tr(context, 'Pro: learn more', 'Pro: tìm hiểu thêm'),
    excludeSemantics: true,
    child: InkWell(
      key: Key('pro-badge-${feature.name}'),
      borderRadius: BorderRadius.circular(8),
      onTap: () => openHabitPro(context, feature),
      child: const SizedBox(
        width: 48,
        height: 48,
        child: Center(child: HabitProPill()),
      ),
    ),
  );
}
