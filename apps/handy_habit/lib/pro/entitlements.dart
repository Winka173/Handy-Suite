import 'package:handy_monetization/handy_monetization.dart';
import 'package:handy_ui/kit.dart';

/// Only capabilities shipped in the Advanced routine builder.
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
}

String proTitle(BuildContext c, HabitProFeature feature) => switch (feature) {
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

/// A badge is a destination, never an entitlement toggle.
class HabitProBadge extends StatelessWidget {
  final HabitProFeature feature;
  const HabitProBadge({super.key, required this.feature});
  @override
  Widget build(BuildContext context) => TextButton(
    key: Key('pro-badge-${feature.name}'),
    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    onPressed: () => openHabitPro(context, feature),
    child: const Text('Pro'),
  );
}
