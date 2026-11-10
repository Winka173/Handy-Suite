import 'package:handy_ui/kit.dart';
import 'entitlements.dart';
import 'pro_demos.dart';
import 'purchase.dart';

class HabitProPage extends StatefulWidget {
  final HabitProFeature feature;
  const HabitProPage({super.key, this.feature = HabitProFeature.days});
  @override
  State<HabitProPage> createState() => _HabitProPageState();
}

class _HabitProPageState extends State<HabitProPage> {
  late HabitProFeature shown = widget.feature;
  final stage = GlobalKey();
  void show(HabitProFeature f) {
    setState(() => shown = f);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && stage.currentContext != null)
        Scrollable.ensureVisible(
          stage.currentContext!,
          duration: HandyMotion.of(context),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    String t(String en, String vi) => tr(context, en, vi);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t('Pro Lifetime', 'Pro trọn đời'))),
      body: SafeArea(
        child: SingleChildScrollView(
          key: const Key('pro-scroll'),
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width >= 840 ? 24 : 16,
          ),
          child: HandyContent(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    t('Advanced routines', 'Quy trình nâng cao'),
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t(
                    'A routine that adapts to your day. Try each part before deciding.',
                    'Quy trình linh hoạt theo ngày của bạn. Thử từng phần trước khi quyết định.',
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(
                    proTitle(context, shown),
                    key: stage,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 6),
                Text(proLine(context, shown)),
                const SizedBox(height: 12),
                HabitProDemo(key: ValueKey(shown), feature: shown),
                const SizedBox(height: 20),
                const HabitProPurchase(),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text(
                    t('Explore every part', 'Khám phá từng phần'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                for (final f in HabitProFeature.values)
                  ListTile(
                    key: Key('pro-part-${f.name}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(proTitle(context, f)),
                    subtitle: Text(proLine(context, f)),
                    trailing: Icon(
                      shown == f
                          ? Icons.play_circle
                          : Icons.play_circle_outline,
                    ),
                    selected: shown == f,
                    onTap: () => show(f),
                  ),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text(
                    t('Always free', 'Luôn miễn phí'),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 8),
                for (final pair in [
                  (
                    'Unlimited tracking, negative habits and history',
                    'Ghi nhận không giới hạn, thói quen cần giảm và lịch sử',
                  ),
                  (
                    'Routines, runner and templates',
                    'Quy trình, màn chạy và mẫu',
                  ),
                  (
                    'Progress, heatmap and weekly review',
                    'Tiến bộ, biểu đồ nhiệt và nhìn lại tuần',
                  ),
                  (
                    'Mood, reminders and basic appearance',
                    'Tâm trạng, nhắc nhở và giao diện cơ bản',
                  ),
                  (
                    'Export, backup, restore and supported sync',
                    'Xuất, sao lưu, khôi phục và đồng bộ được hỗ trợ',
                  ),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text('• ${t(pair.$1, pair.$2)}'),
                  ),
                const SizedBox(height: 16),
                Text(
                  t(
                    'Pro adds the Advanced routine parts above and removes supported ads. If Pro goes away, your data stays; saved routines still run. Creating or editing advanced rules needs Pro.',
                    'Pro thêm các phần quy trình nâng cao ở trên và bỏ quảng cáo được hỗ trợ. Nếu không còn Pro, dữ liệu vẫn còn; quy trình đã lưu vẫn chạy. Cần Pro để tạo hoặc sửa quy tắc nâng cao.',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t(
                    'Planned later: smart insights and personalization studio. They are not available in this version.',
                    'Dự kiến sau: phân tích chuyên sâu và tùy chỉnh giao diện. Bản này chưa có các phần đó.',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
