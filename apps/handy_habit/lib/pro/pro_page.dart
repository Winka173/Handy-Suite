import 'package:handy_ui/kit.dart';
import '../design/palette.dart';
import '../settings/legal.dart';
import 'entitlements.dart';
import 'feature_demo.dart';
import 'pro_demos.dart';
import 'purchase.dart';

/// One part of Pro as the page lists it: a name, one line, the words in
/// full, the demo it plays, and the gated features it stands for.
class HabitProPart {
  final HabitProFeature demo;
  final List<HabitProFeature> covers;
  final String title, line, body;
  const HabitProPart(this.demo, this.covers, this.title, this.line, this.body);
}

/// Every Pro part, in the groups the page lists them in (as Handy Boards):
/// nine parts, each standing for one or more gated features.
List<(String, List<HabitProPart>)> habitProGroups(BuildContext context) {
  String t(String en, String vi) => tr(context, en, vi);
  const f = HabitProFeature.values;
  return [
    (
      t('Routines that adapt', 'Quy trình linh hoạt'),
      [
        HabitProPart(
          HabitProFeature.days,
          [f[0], f[1], f[2], f[6]],
          t('Steps that fit the day', 'Bước hợp với từng ngày'),
          t(
            'Weekday steps, time left, skip what is done',
            'Bước theo thứ, thời gian còn lại, bỏ bước đã xong',
          ),
          t(
            'A step can run only on some weekdays, last longer on others, fit into the time you have left, or step aside when its habit is already done today.',
            'Một bước có thể chỉ chạy vài thứ trong tuần, dài hơn vào ngày khác, vừa với thời gian còn lại, hoặc tự bỏ qua khi thói quen của nó đã xong hôm nay.',
          ),
        ),
        HabitProPart(
          HabitProFeature.choices,
          [f[3], f[4], f[5]],
          t('Choices and order', 'Lựa chọn và thứ tự'),
          t(
            'Pick A or B, wait for a step, follow a habit',
            'Chọn A hoặc B, chờ bước trước, nối sau thói quen',
          ),
          t(
            'Offer two paths while running, keep a step until the ones before it are done, or start a routine right after a habit you just checked in.',
            'Đưa ra hai lựa chọn khi đang chạy, giữ một bước tới khi các bước trước xong, hoặc bắt đầu quy trình ngay sau thói quen vừa ghi.',
          ),
        ),
        HabitProPart(
          HabitProFeature.blocks,
          [f[7], f[8]],
          t('Reusable steps', 'Bước dùng lại'),
          t(
            'Save steps once, add them anywhere',
            'Lưu một lần, thêm vào đâu cũng được',
          ),
          t(
            'Keep a few steps you use in many routines and insert a fresh copy in one tap, or start a routine from a saved plan.',
            'Giữ vài bước dùng ở nhiều quy trình và chèn một bản mới bằng một chạm, hoặc bắt đầu quy trình từ một kế hoạch đã lưu.',
          ),
        ),
      ],
    ),
    (
      t('Understand your rhythm', 'Hiểu nhịp của bạn'),
      [
        HabitProPart(
          HabitProFeature.comparisons,
          [f[9], f[10]],
          t('Compare and spot patterns', 'So sánh và nhận ra nhịp'),
          t(
            'Months side by side, the days you tend to miss',
            'Các tháng cạnh nhau, những ngày hay lỡ',
          ),
          t(
            'Put months, quarters or groups of habits side by side, with the counts behind them, and see which weekdays and goals need more room.',
            'Đặt các tháng, quý hay nhóm thói quen cạnh nhau, kèm số liệu, và thấy thứ nào trong tuần, mục tiêu nào cần nới ra.',
          ),
        ),
        HabitProPart(
          HabitProFeature.goals,
          [f[11]],
          t('Small goal adjustments', 'Chỉnh mục tiêu nhẹ nhàng'),
          t(
            'A suggestion from your own history',
            'Gợi ý từ chính lịch sử của bạn',
          ),
          t(
            'When a goal is often missed or always passed, Habit suggests a small change. Accept or dismiss it; nothing changes on its own.',
            'Khi một mục tiêu hay bị lỡ hoặc luôn vượt, Habit gợi ý chỉnh nhẹ. Bạn nhận hay bỏ; không gì tự đổi.',
          ),
        ),
        HabitProPart(
          HabitProFeature.mood,
          [f[12]],
          t('Mood beside habits', 'Tâm trạng cạnh thói quen'),
          t(
            'How the days you kept them felt',
            'Những ngày giữ được thì thấy thế nào',
          ),
          t(
            'Compare the mood you recorded on days a habit was kept and days it was not, counted only from days you logged.',
            'So tâm trạng bạn ghi vào ngày giữ được thói quen và ngày không, chỉ đếm những ngày có ghi.',
          ),
        ),
        HabitProPart(
          HabitProFeature.heatmap,
          [f[13], f[14]],
          t(
            'Heatmaps and a review on paper',
            'Bản đồ nhiệt và bản xem lại để in',
          ),
          t(
            'Focused heatmaps, a designed PDF',
            'Bản đồ nhiệt theo lọc, PDF trình bày đẹp',
          ),
          t(
            'Filter heatmaps by group, time and direction, and print a review with its figures explained. Plain CSV, Markdown and PDF stay free.',
            'Lọc bản đồ nhiệt theo nhóm, thời gian, chiều, và in bản xem lại có giải thích số liệu. CSV, Markdown và PDF thường vẫn miễn phí.',
          ),
        ),
      ],
    ),
    (
      t('Make it yours', 'Theo ý bạn'),
      [
        HabitProPart(
          HabitProFeature.studio,
          [f[15]],
          t('Personalization studio', 'Xưởng giao diện'),
          t(
            'Palettes, Today layouts, icons, runner looks',
            'Bảng màu, bố cục Hôm nay, biểu tượng, màn chạy',
          ),
          t(
            'Choose palettes, a Today layout, extra icons and a look for the routine runner. Try each on your own habits first.',
            'Chọn bảng màu, bố cục Hôm nay, thêm biểu tượng và diện mạo màn chạy. Thử trên chính thói quen của bạn trước.',
          ),
        ),
        HabitProPart(
          HabitProFeature.convenience,
          [f[16]],
          t('Rules and batch changes', 'Quy tắc và thay đổi hàng loạt'),
          t(
            'When one thing happens, do the next',
            'Khi một việc xảy ra, tự làm việc kế',
          ),
          t(
            'Write a rule such as "after my morning routine, add a glass of water", change many habits at once after a preview, and keep the views you use most. Undo always works.',
            'Viết quy tắc như "sau quy trình buổi sáng, thêm một cốc nước", đổi nhiều thói quen cùng lúc sau khi xem trước, và giữ những cách xem hay dùng. Luôn hoàn tác được.',
          ),
        ),
      ],
    ),
  ];
}

/// Pro: a stage that plays the part that brought the person here, the
/// other parts by group (a tap plays one on the stage), Free beside Pro,
/// and one buy bar, as Handy Boards.
class HabitProPage extends StatefulWidget {
  final HabitProFeature feature;
  final bool focused;
  const HabitProPage({
    super.key,
    this.feature = HabitProFeature.days,
    this.focused = false,
  });
  @override
  State<HabitProPage> createState() => _HabitProPageState();
}

class _HabitProPageState extends State<HabitProPage> {
  final _scroll = ScrollController();
  late HabitProFeature shown = widget.feature;
  int replay = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void show(HabitProFeature f) {
    setState(() {
      shown = f;
      replay++;
    });
    if (!_scroll.hasClients) return;
    final d = HandyMotion.of(context, HandyMotion.long);
    if (d == Duration.zero) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(0, duration: d, curve: HandyMotion.curve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = HabitPalette.of(context);
    final groups = habitProGroups(context);
    final parts = [for (final g in groups) ...g.$2];
    final part = parts.firstWhere(
      (x) => x.covers.contains(shown) || x.demo == shown,
      orElse: () => parts.first,
    );
    Widget column(List<Widget> children) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Handy Habit Pro')),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: HandyContent(
              maxWidth: 720,
              child: const HabitProPurchase(footer: true),
            ),
          ),
        ),
      ),
      body: ListView(
        key: const Key('pro-scroll'),
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          column([
            if (!widget.focused) ...[
              Semantics(
                header: true,
                child: Text(
                  tr(context, 'Pay once. Keep it.', 'Trả một lần. Dùng mãi.'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.anchor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tr(
                  context,
                  'No subscription, no ads, no account. Your habits stay on your device either way.',
                  'Không thuê bao, không quảng cáo, không tài khoản. Thói quen của bạn luôn ở trên máy.',
                ),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
            ],
            HandyAppear(
              key: ValueKey('$shown-$replay'),
              child: HabitProDemo(feature: shown),
            ),
            const SizedBox(height: 14),
            HandySwap(
              child: Column(
                key: ValueKey(part.title),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      part.title,
                      key: const Key('pro-stage-title'),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(part.body, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
            for (final g in groups) ...[
              const SizedBox(height: 28),
              Semantics(
                header: true,
                child: Text(g.$1, style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: 6),
              for (final x in g.$2)
                _PartRow(
                  part: x,
                  shown: identical(x, part) || x.title == part.title,
                  onTap: () => show(x.demo),
                ),
            ],
            const SizedBox(height: 28),
            const _FreeAndPro(),
            const SizedBox(height: 20),
            Text(
              tr(
                context,
                'Always free: unlimited habits and check-ins, routines, Progress, mood, reminders, widgets, backup, sync and plain export. If Pro ever goes away, nothing you made is deleted; saved routines still run and Pro looks return with Pro.',
                'Luôn miễn phí: thói quen và lần ghi không giới hạn, quy trình, Tiến bộ, tâm trạng, nhắc nhở, widget, sao lưu, đồng bộ và xuất thường. Nếu không còn Pro, không gì bạn đã tạo bị xoá; quy trình đã lưu vẫn chạy và giao diện Pro trở lại khi có Pro.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
            ),
            const SizedBox(height: 8),
            const HabitLegalLinks(),
          ]),
        ],
      ),
    );
  }
}

/// One part in the list: its still frame, name and one line. A tap plays
/// it on the stage.
class _PartRow extends StatelessWidget {
  final HabitProPart part;
  final bool shown;
  final VoidCallback onTap;
  const _PartRow({
    required this.part,
    required this.shown,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = HabitPalette.of(context);
    return Semantics(
      button: true,
      selected: shown,
      label: tr(
        context,
        '${part.title}. ${part.line}. Play it above',
        '${part.title}. ${part.line}. Xem diễn ở trên',
      ),
      excludeSemantics: true,
      child: InkWell(
        key: Key('pro-part-${part.demo.name}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 88,
                height: 54,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: p.raised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: shown ? p.vermilion : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: FittedBox(
                      child: SizedBox(
                        width: 320,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: featureDemo(context, part.demo, true),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(part.title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      part.line,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: p.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                shown ? Icons.play_circle : Icons.play_circle_outline,
                color: shown ? p.vermilion : p.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Free beside Pro.
class _FreeAndPro extends StatelessWidget {
  const _FreeAndPro();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = HabitPalette.of(context);
    String t(String en, String vi) => tr(context, en, vi);
    final rows = [
      (
        t('Habits and check-ins', 'Thói quen và lần ghi'),
        t('No limits', 'Không giới hạn'),
        t('No limits', 'Không giới hạn'),
      ),
      (
        t('Routines', 'Quy trình'),
        t(
          'Steps in order, timers, runner',
          'Bước theo thứ tự, hẹn giờ, màn chạy',
        ),
        t(
          'Weekday steps, choices, reusable steps',
          'Bước theo thứ, lựa chọn, bước dùng lại',
        ),
      ),
      (
        t('Progress', 'Tiến bộ'),
        t('Week, month, year, streaks', 'Tuần, tháng, năm, chuỗi ngày'),
        t(
          'Comparisons, patterns, goal suggestions',
          'So sánh, nhịp hay lỡ, gợi ý mục tiêu',
        ),
      ),
      (
        t('Mood', 'Tâm trạng'),
        t('Log and history', 'Ghi và xem lại'),
        t('Mood beside habits', 'Tâm trạng cạnh thói quen'),
      ),
      (
        t('Reminders and widgets', 'Nhắc nhở và widget'),
        t(
          'Reminders; Today, one habit, routine widgets',
          'Nhắc nhở; widget Hôm nay, một thói quen, quy trình',
        ),
        t('Week and Year widgets', 'Widget Tuần và Năm'),
      ),
      (
        t('Looks', 'Giao diện'),
        t('Light and dark', 'Sáng và tối'),
        t('Studio palettes, layouts, icons', 'Bảng màu, bố cục, biểu tượng'),
      ),
      (
        t('Convenience', 'Tiện ích'),
        '—',
        t(
          'Rules, batch changes, saved views',
          'Quy tắc, thay đổi hàng loạt, cách xem đã lưu',
        ),
      ),
      (
        t('Export', 'Xuất'),
        t('CSV, Markdown, PDF, backups', 'CSV, Markdown, PDF, sao lưu'),
        t(
          'Focused heatmaps, review on paper',
          'Bản đồ nhiệt theo lọc, bản in xem lại',
        ),
      ),
    ];
    Widget cell(String label, String value, {bool pro = false}) => Expanded(
      child: Semantics(
        label: label,
        child: Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: pro ? FontWeight.w700 : null,
            color: pro ? p.vermilion : null,
          ),
        ),
      ),
    );
    Widget head(String s) => Expanded(
      child: Text(
        s,
        style: theme.textTheme.labelLarge?.copyWith(
          color: s == 'Pro' ? p.vermilion : p.muted,
          fontWeight: s == 'Pro' ? FontWeight.w700 : null,
        ),
      ),
    );
    return Column(
      key: const Key('pro-free-and-pro'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            t('Free and Pro', 'Miễn phí và Pro'),
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: Row(
            children: [
              head(t('Free', 'Miễn phí')),
              const SizedBox(width: 12),
              head('Pro'),
            ],
          ),
        ),
        for (final r in rows)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: p.line)),
            ),
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.$1, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      cell(t('Free', 'Miễn phí'), r.$2),
                      const SizedBox(width: 12),
                      cell('Pro', r.$3, pro: true),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
