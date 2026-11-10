import 'package:handy_ui/kit.dart';
import '../design/palette.dart';
import 'entitlements.dart';
import 'pro_demos.dart';
import 'purchase.dart';
import 'thumbnail.dart';

class HabitProPage extends StatefulWidget {
  final HabitProFeature feature;
  const HabitProPage({super.key, this.feature = HabitProFeature.days});
  @override
  State<HabitProPage> createState() => _HabitProPageState();
}

class _HabitProPageState extends State<HabitProPage> {
  late HabitProFeature shown = widget.feature;
  final stage = GlobalKey();
  int replay = 0;
  void show(HabitProFeature f) {
    setState(() {
      shown = f;
      replay++;
    });
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: HabitPalette.of(context).surface,
          border: Border(top: BorderSide(color: HabitPalette.of(context).line)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .45,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: HandyContent(
                  maxWidth: 920,
                  child: const HabitProPurchase(footer: true),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          key: const Key('pro-scroll'),
          padding: const EdgeInsets.all(16),
          child: HandyContent(
            maxWidth: 920,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t('Pay once. Your pace.', 'Một lần. Nhịp riêng.'),
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  t(
                    'More ways to plan, reflect and make Habit yours.',
                    'Thêm cách lên nhịp, nhìn lại và tạo diện mạo riêng.',
                  ),
                ),
                const SizedBox(height: 24),
                KeyedSubtree(
                  key: stage,
                  child: HabitProDemo(
                    key: ValueKey('$shown-$replay'),
                    feature: shown,
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  header: true,
                  child: Text(
                    proTitle(context, shown),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                Text(proLine(context, shown)),
                for (final (en, vi, features) in [
                  ('Routines', 'Quy trình', HabitProFeature.values.take(9)),
                  (
                    'Understand',
                    'Hiểu nhịp sống',
                    HabitProFeature.values.skip(9).take(6),
                  ),
                  ('Make it yours', 'Theo ý bạn', [HabitProFeature.studio]),
                ]) ...[
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: Text(t(en, vi), style: theme.textTheme.titleLarge),
                  ),
                  for (final f in features)
                    ListTile(
                      key: Key('pro-part-${f.name}'),
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      selected: shown == f,
                      leading: ExcludeSemantics(
                        child: SizedBox(
                          width: 56,
                          height: 48,
                          child: CustomPaint(
                            painter: ProThumbnail(f, HabitPalette.of(context)),
                          ),
                        ),
                      ),
                      title: Text(proTitle(context, f)),
                      subtitle: Text(proLine(context, f)),
                      trailing: Icon(
                        shown == f
                            ? Icons.play_circle
                            : Icons.play_circle_outline,
                      ),
                      onTap: () => show(f),
                    ),
                ],
                const SizedBox(height: 24),
                Text(
                  t('Always free', 'Luôn miễn phí'),
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  t(
                    'Unlimited tracking, basic routines, core Progress, mood, reminders and widgets. Export, backup, restore and supported sync stay free.',
                    'Ghi nhận không giới hạn, quy trình cơ bản, Tiến bộ cốt lõi, tâm trạng, nhắc nhở và tiện ích. Xuất, sao lưu, khôi phục và đồng bộ được hỗ trợ luôn miễn phí.',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  t(
                    'One-time purchase. No subscription. Ownership belongs to this Google Play account and does not transfer between stores.',
                    'Mua một lần. Không thuê bao. Quyền mua thuộc tài khoản Google Play này, không chuyển giữa các cửa hàng.',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  t(
                    'Pro also removes supported ads. Your history stays if Pro ends; saved advanced routines still run. Studio choices are kept and use the free look until Pro returns.',
                    'Pro cũng bỏ quảng cáo được hỗ trợ. Lịch sử vẫn còn khi hết Pro; quy trình nâng cao đã lưu vẫn chạy. Lựa chọn giao diện được giữ và dùng diện mạo miễn phí đến khi có Pro lại.',
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
