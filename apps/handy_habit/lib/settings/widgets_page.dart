import 'package:handy_home_widget/handy_home_widget.dart';
import 'package:handy_ui/kit.dart';
import 'package:home_widget/home_widget.dart' show HomeWidget;
import '../design/palette.dart';
import '../home_widget.dart';
import '../pro/entitlements.dart';
import '../scope.dart';
import '../today/beads.dart';
import 'settings_parts.dart';

/// Settings › Home-screen widgets: each widget as it will look, with the
/// button that puts it on the home screen, then what they show.
class HabitWidgetsPage extends StatefulWidget {
  final HabitScope scope;
  const HabitWidgetsPage({super.key, required this.scope});
  @override
  State<HabitWidgetsPage> createState() => _HabitWidgetsPageState();
}

class _HabitWidgetsPageState extends State<HabitWidgetsPage> {
  bool canPin = false;

  @override
  void initState() {
    super.initState();
    if (homeWidgetsSupported)
      HomeWidget.isRequestPinWidgetSupported()
          .then((v) {
            if (mounted && v == true) setState(() => canPin = true);
          })
          .catchError((Object _) {});
  }

  Future<void> pref(String key, Object value) => widget.scope
      .write(
        context,
        (s) => s.copy({
          'settings': {...s.settings, key: value},
        }),
        remember: false,
      )
      .then((_) {});

  Future<void> pin(String cls) async {
    try {
      await HomeWidget.requestPinWidget(qualifiedAndroidName: cls);
    } catch (_) {
      if (mounted)
        showHandyMessage(
          context,
          tr(
            context,
            'This launcher cannot add widgets from an app. Add it from the home screen.',
            'Launcher này không cho app thêm widget. Hãy thêm từ màn hình chính.',
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(String en, String vi) => tr(context, en, vi);
    final scope = widget.scope, s = scope.state;
    final pro = scope.pro(context);
    final vi = Localizations.localeOf(context).languageCode == 'vi';
    final views = habitWidgetViews(s, scope.today, vi: vi, pro: pro);
    final data = {for (final e in views.entries) e.key: e.value.toData()};
    final habits = widgetHabits(s), routines = widgetRoutines(s);

    Widget card(
      String id,
      String name,
      String cls,
      Widget body, {
      bool paid = false,
    }) => Padding(
      key: Key('widget-preview-$id'),
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleMedium),
              if (paid && !pro) const HabitProPill(),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: t('Preview of $name', 'Xem trước $name'),
            child: _Frame(child: body),
          ),
          if (canPin)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: Key('widget-pin-$id'),
                onPressed: () => pin(cls),
                icon: const Icon(Icons.add_to_home_screen, size: 18),
                label: Text(t('Add to home screen', 'Thêm vào màn hình chính')),
              ),
            ),
        ],
      ),
    );

    return HabitSettingsView(
      key: const Key('widgets-scroll'),
      title: t('Home-screen widgets', 'Widget màn hình chính'),
      listenable: scope.controller,
      children: (context) => [
        SettingsGroup(
          first: true,
          title: t('Your day, within reach', 'Ngày của bạn, trong tầm tay'),
          note: homeWidgetsSupported
              ? t(
                  'Tap a bead on the home screen to check in; it fills at once. Counted habits add one per tap; minutes and amounts open Habit.',
                  'Chạm một hạt ngoài màn hình chính là ghi nhận, hạt lấp ngay. Thói quen đếm cộng một mỗi chạm; số phút và lượng thì mở Habit.',
                )
              : t(
                  'Widgets are on Android. Here you can see how they look.',
                  'Widget có trên Android. Ở đây bạn xem chúng trông thế nào.',
                ),
          children: [
            card(
              'today',
              t('Today', 'Hôm nay'),
              habitWidgetClass,
              _TodayPreview(data: data['today']!),
            ),
            card(
              'habit',
              t('One habit', 'Một thói quen'),
              singleHabitWidgetClass,
              _SinglePreview(data: data['habit']!),
            ),
            card(
              'routine',
              t('Routine', 'Quy trình'),
              routineWidgetClass,
              _RoutinePreview(data: data['routine']!),
            ),
            card(
              'week',
              t('This week', 'Tuần này'),
              weekWidgetClass,
              _WeekPreview(data: data['week']!),
              paid: true,
            ),
            card(
              'year',
              t('16 weeks', '16 tuần'),
              yearWidgetClass,
              _YearPreview(data: data['year']!),
              paid: true,
            ),
          ],
        ),
        SettingsGroup(
          title: t('What they show', 'Widget hiện gì'),
          children: [
            SettingsPanel(
              gap: false,
              rows: [
                HabitSettingToggle(
                  id: 'widget-names',
                  icon: Icons.visibility_outlined,
                  title: t(
                    'Show habit and routine names',
                    'Hiện tên thói quen và quy trình',
                  ),
                  subtitle: t(
                    'Off: neutral labels only. Mood and notes never leave the app.',
                    'Tắt: chỉ nhãn chung. Tâm trạng và ghi chú không bao giờ rời app.',
                  ),
                  value: s.settings['widgetShowNames'] != false,
                  onChanged: (v) => pref('widgetShowNames', v),
                ),
                if (habits.isNotEmpty)
                  HabitSettingChoice(
                    id: 'widget-habit-choice',
                    icon: Icons.check_circle_outline,
                    title: t(
                      'Habit for One habit and 16 weeks',
                      'Thói quen cho Một thói quen và 16 tuần',
                    ),
                    value:
                        s.settings['widgetHabit'] as String? ?? habits.first.id,
                    options: {for (final h in habits) h.id: h.title},
                    onChanged: (v) => pref('widgetHabit', v),
                  ),
                if (routines.isNotEmpty)
                  HabitSettingChoice(
                    id: 'widget-routine-choice',
                    icon: Icons.format_list_numbered,
                    title: t('Routine to start', 'Quy trình để bắt đầu'),
                    value:
                        s.settings['widgetRoutine'] as String? ??
                        routines.first.id,
                    options: {for (final r in routines) r.id: r.title},
                    onChanged: (v) => pref('widgetRoutine', v),
                  ),
                SettingsRow(
                  key: const Key('widget-studio'),
                  icon: Icons.palette_outlined,
                  title: t('Colours', 'Màu sắc'),
                  badge: pro ? null : const HabitProPill(),
                  subtitle: t(
                    'Light or dark follows the phone; Pro uses your studio palette.',
                    'Sáng hay tối theo điện thoại; Pro dùng bảng màu trong xưởng.',
                  ),
                  navigates: true,
                  onTap: () => Navigator.pushNamed(context, '/settings/studio'),
                ),
                SettingsRow(
                  icon: Icons.help_outline,
                  title: t('How to use widgets', 'Cách dùng widget'),
                  navigates: true,
                  onTap: () => Navigator.pushNamed(context, '/help/widgets'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: HandySpace.xxl),
      ],
    );
  }
}

/// The widget's own ground and corners.
class _Frame extends StatelessWidget {
  final Widget child;
  const _Frame({required this.child});
  @override
  Widget build(BuildContext context) {
    final p = HabitPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line),
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: child,
      ),
    );
  }
}

Color _colour(String? hex, Color fallback) => hex == null || hex.length < 7
    ? fallback
    : Color(int.parse(hex.substring(1).padLeft(8, 'f'), radix: 16));

String _status(String letter) => switch (letter) {
  'c' => 'completed',
  'p' => 'partial',
  's' => 'skipped',
  'z' => 'paused',
  'v' => 'overLimit',
  'n' => 'notScheduled',
  'x' => 'before',
  _ => 'open',
};

Widget _beads(String letters, Color colour, {double size = 14}) => Wrap(
  spacing: size * .3,
  children: [
    for (final ch in letters.split(''))
      Bead(status: _status(ch), fill: .5, size: size, color: colour),
  ],
);

Widget _today(int fill, Color colour, {double size = 36}) => SizedBox.square(
  dimension: size,
  child: Stack(
    alignment: Alignment.center,
    children: [
      Bead(
        status: fill >= 100 ? 'completed' : 'progress',
        fill: fill / 100,
        size: size * .9,
        color: colour,
      ),
      if (fill >= 100) Icon(Icons.check, size: size * .5, color: Colors.white),
    ],
  ),
);

class _TodayPreview extends StatelessWidget {
  final Map<String, String?> data;
  const _TodayPreview({required this.data});
  @override
  Widget build(BuildContext context) {
    final p = HabitPalette.of(context), theme = Theme.of(context);
    final count = int.tryParse(data['hcount'] ?? '') ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          data['title'] ?? '',
          style: TextStyle(color: p.muted, fontSize: 12),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              data['value'] ?? '',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: p.ink,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                data['detail'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.muted, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: (int.tryParse(data['progress'] ?? '') ?? 0) / 100,
          color: p.vermilion,
          backgroundColor: p.raised,
          minHeight: 6,
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < count; i++)
          SizedBox(
            height: 46,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['h${i}_name'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      _beads(
                        data['h${i}_beads'] ?? '',
                        _colour(data['h${i}_color'], p.vermilion),
                        size: 12,
                      ),
                    ],
                  ),
                ),
                _today(
                  int.tryParse(data['h${i}_fill'] ?? '') ?? 0,
                  _colour(data['h${i}_color'], p.vermilion),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SinglePreview extends StatelessWidget {
  final Map<String, String?> data;
  const _SinglePreview({required this.data});
  @override
  Widget build(BuildContext context) {
    final p = HabitPalette.of(context);
    final colour = _colour(data['color'], p.vermilion);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['name'] ?? data['value'] ?? '',
                style: TextStyle(
                  color: p.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                data['streak'] ?? data['detail'] ?? '',
                style: TextStyle(color: p.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              if ((data['beads'] ?? '').isNotEmpty)
                _beads(data['beads']!, colour, size: 11),
            ],
          ),
        ),
        if ((data['id'] ?? '').isNotEmpty)
          _today(int.tryParse(data['fill'] ?? '') ?? 0, colour, size: 56),
      ],
    );
  }
}

class _RoutinePreview extends StatelessWidget {
  final Map<String, String?> data;
  const _RoutinePreview({required this.data});
  @override
  Widget build(BuildContext context) {
    final p = HabitPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data['value'] ?? '',
          style: TextStyle(
            color: p.ink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          data['detail'] ?? '',
          style: TextStyle(color: p.muted, fontSize: 12),
        ),
        if ((data['button'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: p.vermilion,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              data['button'] ?? '',
              style: TextStyle(
                color: p.onVermilion,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _WeekPreview extends StatelessWidget {
  final Map<String, String?> data;
  const _WeekPreview({required this.data});
  @override
  Widget build(BuildContext context) {
    final p = HabitPalette.of(context);
    final count = int.tryParse(data['count'] ?? '') ?? 0;
    final days = (data['days'] ?? '').split('|');
    const cell = 16.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                data['title'] ?? '',
                style: TextStyle(color: p.ink, fontWeight: FontWeight.w600),
              ),
            ),
            for (final d in days)
              SizedBox(
                width: cell * 1.3,
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.muted, fontSize: 10),
                ),
              ),
          ],
        ),
        for (var i = 0; i < count; i++)
          SizedBox(
            height: 30,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    data['w${i}_name'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.ink, fontSize: 13),
                  ),
                ),
                for (final ch in (data['w${i}_beads'] ?? '').split(''))
                  SizedBox(
                    width: cell * 1.3,
                    child: Center(
                      child: Bead(
                        status: _status(ch),
                        fill: .5,
                        size: cell,
                        color: _colour(data['w${i}_color'], p.vermilion),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _YearPreview extends StatelessWidget {
  final Map<String, String?> data;
  const _YearPreview({required this.data});
  @override
  Widget build(BuildContext context) {
    final p = HabitPalette.of(context);
    final grid = data['grid'] ?? '';
    final colour = _colour(data['color'], p.vermilion);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data['name'] ?? '',
          style: TextStyle(color: p.ink, fontWeight: FontWeight.w600),
        ),
        Text(
          data['detail'] ?? '',
          style: TextStyle(color: p.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, box) {
            final cell = (box.maxWidth / 16).clamp(8.0, 18.0);
            return Row(
              children: [
                for (var w = 0; w < grid.length ~/ 7; w++)
                  Column(
                    children: [
                      for (var d = 0; d < 7; d++)
                        SizedBox.square(
                          dimension: cell,
                          child: Center(
                            child: Bead(
                              status: _status(grid[w * 7 + d]),
                              fill: .5,
                              size: cell * .82,
                              color: colour,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
