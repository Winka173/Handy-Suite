import 'package:handy_ui/kit.dart';
import 'package:handy_home_widget/handy_home_widget.dart';
import '../home_widget.dart';
import '../scope.dart';
import '../design/palette.dart';
import '../pro/entitlements.dart';
import 'settings_parts.dart';

class HabitWidgetsPage extends StatefulWidget {
  final HabitScope scope;
  const HabitWidgetsPage({super.key, required this.scope});
  @override
  State<HabitWidgetsPage> createState() => _HabitWidgetsPageState();
}

class _HabitWidgetsPageState extends State<HabitWidgetsPage> {
  bool large = false;
  Future<void> pref(String key, Object value) => widget.scope
      .write(
        context,
        (s) => s.copy({
          'settings': {...s.settings, key: value},
        }),
        remember: false,
      )
      .then((_) {});
  @override
  Widget build(BuildContext context) {
    String t(String en, String vi) => tr(context, en, vi);
    final scope = widget.scope, s = scope.state, p = HabitPalette.of(context);
    final views = habitWidgetViews(
      s,
      scope.today,
      vi: Localizations.localeOf(context).languageCode == 'vi',
      pro: scope.pro(context),
      dark: Theme.of(context).brightness == Brightness.dark,
    );
    Color colour(HomeWidgetView v, String key, Color fallback) =>
        v.style?[key] == null
        ? fallback
        : Color(int.parse(v.style![key]!.substring(1), radix: 16));
    Widget preview(String id, String name) {
      final v = views[id]!,
          ink = colour(views[id]!, 'ink', p.ink),
          muted = colour(views[id]!, 'muted', p.muted),
          accent = colour(views[id]!, 'accent', p.vermilion);
      return Padding(
        key: Key('widget-preview-$id'),
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Semantics(
              label: t('Preview of $name', 'Xem trước $name'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colour(v, 'bg', p.surface),
                  border: Border.all(color: p.line),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            v.title,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: muted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      v.value,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(color: ink),
                    ),
                    if (v.detail.isNotEmpty)
                      Text(v.detail, style: TextStyle(color: muted)),
                    if (v.progress != null) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: v.progress! / 100,
                        color: accent,
                        backgroundColor: muted.withValues(alpha: .2),
                        minHeight: 6,
                      ),
                    ],
                    if (large)
                      for (final r in v.rows)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(r.$1, style: TextStyle(color: ink)),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final habits = widgetHabits(s), routines = widgetRoutines(s);
    return Scaffold(
      appBar: AppBar(title: Text(t('Widgets', 'Tiện ích'))),
      body: ListView(
        key: const Key('widgets-scroll'),
        padding: const EdgeInsets.all(16),
        children: [
          HandyContent(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t(
                    'Your day, within reach.',
                    'Ngày của bạn, ngay trong tầm tay.',
                  ),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  homeWidgetsSupported
                      ? t(
                          'Touch and hold an empty spot on your home screen › Widgets › Handy Habit. Drag one out, then resize it for the compact or large layout.',
                          'Giữ chỗ trống trên màn hình chính › Tiện ích › Handy Habit. Kéo ra, rồi đổi kích thước để dùng bố cục gọn hoặc lớn.',
                        )
                      : t(
                          'Android home-screen widgets. Here you can preview them; iOS, Windows and Web widgets are not available.',
                          'Tiện ích màn hình chính có trên Android. Ở đây bạn xem trước; chưa có tiện ích cho iOS, Windows và Web.',
                        ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (flag, en, vi) in [
                      (false, 'Compact', 'Gọn'),
                      (true, 'Large', 'Lớn'),
                    ])
                      ChoiceChip(
                        key: Key('widget-size-${flag ? 'large' : 'compact'}'),
                        label: Text(t(en, vi)),
                        selected: large == flag,
                        onSelected: (_) => setState(() => large = flag),
                      ),
                  ],
                ),
                preview('today', t('Today’s progress', 'Tiến độ hôm nay')),
                const SizedBox(height: 12),
                if (homeWidgetsSupported) ...[
                  SwitchListTile.adaptive(
                    key: const Key('widget-names'),
                    title: Text(
                      t(
                        'Show habit and routine names',
                        'Hiện tên thói quen và quy trình',
                      ),
                    ),
                    subtitle: Text(
                      t(
                        'Off: counts and neutral labels only. Mood and notes are never included.',
                        'Tắt: chỉ số đếm và nhãn chung. Không bao giờ đưa tâm trạng hay ghi chú ra tiện ích.',
                      ),
                    ),
                    value: s.settings['widgetShowNames'] != false,
                    onChanged: (v) => pref('widgetShowNames', v),
                  ),
                  if (habits.isNotEmpty)
                    HabitSettingChoice(
                      id: 'widget-habit-choice',
                      icon: Icons.check_circle_outline,
                      title: t(
                        'Habit for quick check-in',
                        'Thói quen để ghi nhận nhanh',
                      ),
                      value:
                          s.settings['widgetHabit'] as String? ??
                          habits.first.id,
                      options: {
                        '': t('Choose a habit', 'Chọn thói quen'),
                        for (final h in habits) h.id: h.title,
                      },
                      onChanged: (v) => pref('widgetHabit', v),
                    ),
                  if (routines.isNotEmpty)
                    HabitSettingChoice(
                      id: 'widget-routine-choice',
                      icon: Icons.format_list_numbered,
                      title: t('Routine to open', 'Quy trình để mở'),
                      value:
                          s.settings['widgetRoutine'] as String? ??
                          routines.first.id,
                      options: {
                        '': t('Choose a routine', 'Chọn quy trình'),
                        for (final r in routines) r.id: r.title,
                      },
                      onChanged: (v) => pref('widgetRoutine', v),
                    ),
                ],
                if (habits.isEmpty)
                  Text(
                    t(
                      'Create a habit to choose a quick check-in widget.',
                      'Tạo thói quen để chọn tiện ích ghi nhận nhanh.',
                    ),
                  ),
                preview('habit', t('One habit', 'Một thói quen')),
                if (routines.isEmpty)
                  Text(
                    t(
                      'Create a routine to use the routine launcher.',
                      'Tạo quy trình để dùng tiện ích mở nhanh.',
                    ),
                  ),
                preview('routine', t('Routine launcher', 'Mở quy trình')),
                const SizedBox(height: 16),
                Text(
                  t(
                    'Selections apply to every widget of that type. Check-ins open Habit with Undo; amounts and reduction habits open for review. Routine taps open the routine to Start or Resume.',
                    'Lựa chọn áp dụng cho mọi tiện ích cùng loại. Ghi nhận mở Habit kèm Hoàn tác; số lượng và thói quen giảm mở để xem. Chạm quy trình mở trang Bắt đầu hoặc Tiếp tục.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  t(
                    'Widgets refresh after changes and when you open Habit. The launcher controls placement and timing; a closed app does not refresh at midnight. Long names can be shortened by the launcher.',
                    'Tiện ích làm mới sau thay đổi và khi mở Habit. Launcher quyết định vị trí và thời điểm; app đã đóng không tự làm mới lúc nửa đêm. Tên dài có thể bị rút gọn.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                ListTile(
                  key: const Key('widget-studio'),
                  contentPadding: EdgeInsets.zero,
                  minVerticalPadding: 16,
                  title: Text(
                    t(
                      'Palette from your studio',
                      'Bảng màu từ xưởng giao diện',
                    ),
                  ),
                  subtitle: Text(
                    t(
                      'Follows the system light/dark look. Pro also uses your studio palette.',
                      'Theo sáng/tối hệ thống. Pro dùng thêm bảng màu bạn chọn trong xưởng.',
                    ),
                  ),
                  trailing: scope.pro(context)
                      ? null
                      : const HabitProBadge(feature: HabitProFeature.studio),
                  onTap: () => Navigator.pushNamed(context, '/settings/studio'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/help/widgets'),
                  child: Text(t('How to use widgets', 'Cách dùng tiện ích')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
