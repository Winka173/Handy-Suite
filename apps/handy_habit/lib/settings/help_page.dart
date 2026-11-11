import 'package:handy_ui/kit.dart';
import '../design/palette.dart';
import 'help_topics.dart';
import 'how_to_mocks.dart';

/// One topic of How to use, as Handy Boards lists them: eleven, each
/// gathering the steps of one or more older articles (their ids stay valid
/// links, see [habitHowToIndex]).
class HabitHowTo {
  final String id;
  final IconData icon;
  final String en, vi, summaryEn, summaryVi;
  final List<String> sources;
  const HabitHowTo(
    this.id,
    this.icon,
    this.en,
    this.vi,
    this.summaryEn,
    this.summaryVi,
    this.sources,
  );
  String title(BuildContext c) => tr(c, en, vi);
  String summary(BuildContext c) => tr(c, summaryEn, summaryVi);

  /// Every step, with the article and index its picture comes from.
  List<(String, int, (String, String))> get steps => [
    for (final s in sources)
      for (final (i, step)
          in habitHelpTopics.firstWhere((t) => t.id == s).steps.indexed)
        (s, i, step),
  ];
}

const habitHowTo = [
  HabitHowTo(
    'start',
    Icons.add_circle_outline,
    'Make a habit',
    'Tạo thói quen',
    'From a template or your own words; a goal and how often.',
    'Từ một mẫu hay tự gõ; mục tiêu và bao lâu một lần.',
    ['start', 'templates'],
  ),
  HabitHowTo(
    'check-in',
    Icons.check_circle_outline,
    'Check in and undo',
    'Ghi nhận và hoàn tác',
    'Tap today’s bead; correct any day in its history.',
    'Chạm hạt hôm nay; sửa ngày bất kỳ trong lịch sử.',
    ['check-in'],
  ),
  HabitHowTo(
    'streaks',
    Icons.grain,
    'Beads and missed days',
    'Chuỗi hạt và ngày lỡ',
    'Full, part-filled and hollow beads; what a streak counts.',
    'Hạt đầy, một phần và rỗng; chuỗi ngày đếm những gì.',
    ['streaks'],
  ),
  HabitHowTo(
    'negative',
    Icons.remove_circle_outline,
    'Cutting something back',
    'Bớt một thói quen',
    'Count times against a limit; a blank day is unknown.',
    'Đếm số lần so với giới hạn; ngày trống là chưa rõ.',
    ['negative'],
  ),
  HabitHowTo(
    'routines',
    Icons.format_list_numbered,
    'Routines',
    'Quy trình',
    'Steps in order, timers, pause and come back.',
    'Các bước theo thứ tự, hẹn giờ, tạm dừng rồi quay lại.',
    ['routines', 'timers'],
  ),
  HabitHowTo(
    'pause',
    Icons.beach_access_outlined,
    'Pauses',
    'Kỳ nghỉ',
    'Days off that are not missed and keep your streak.',
    'Ngày nghỉ không tính là lỡ và giữ chuỗi ngày.',
    ['pause'],
  ),
  HabitHowTo(
    'reminders',
    Icons.notifications_outlined,
    'Reminders',
    'Nhắc nhở',
    'Set a time; why one might not appear.',
    'Đặt giờ nhắc; vì sao có khi không thấy.',
    ['reminders'],
  ),
  HabitHowTo(
    'progress',
    Icons.insights_outlined,
    'Progress and mood',
    'Tiến bộ và tâm trạng',
    'Week, month and year; how the days felt.',
    'Tuần, tháng, năm; những ngày ấy thấy thế nào.',
    ['progress', 'mood'],
  ),
  HabitHowTo(
    'widgets',
    Icons.widgets_outlined,
    'Home-screen widgets',
    'Widget màn hình chính',
    'Check in without opening the app.',
    'Ghi nhận mà không cần mở app.',
    ['widgets'],
  ),
  HabitHowTo(
    'backup',
    Icons.shield_outlined,
    'Keep it safe',
    'Giữ dữ liệu an toàn',
    'Everything stays on this device. Back up, sync, move phones.',
    'Mọi thứ ở trên máy. Sao lưu, đồng bộ, đổi máy.',
    ['backup', 'sync', 'new-phone', 'migration', 'trash', 'privacy'],
  ),
  HabitHowTo(
    'pro',
    Icons.workspace_premium_outlined,
    'Looks and Pro',
    'Giao diện và Pro',
    'Light, dark and language; one payment adds more.',
    'Sáng, tối và ngôn ngữ; trả một lần để có thêm.',
    ['appearance'],
  ),
];

/// The topic an article id (old or new) belongs to.
int habitHowToIndex(String id) {
  final i = habitHowTo.indexWhere((t) => t.id == id || t.sources.contains(id));
  return i < 0 ? 0 : i;
}

/// How to use, as Handy Boards: the welcome again on a soft card, then
/// the topics; a topic opens as a sheet of numbered steps with pictures.
/// Opened for one [topic] (a "?" elsewhere in the app), its sheet shows at
/// once and closing it goes back where the person was.
class HabitHelpPage extends StatefulWidget {
  final String? topic;
  final String query;
  const HabitHelpPage({super.key, this.topic, this.query = ''});
  @override
  State<HabitHelpPage> createState() => _HabitHelpPageState();
}

class _HabitHelpPageState extends State<HabitHelpPage> {
  @override
  void initState() {
    super.initState();
    final topic = widget.topic;
    if (topic != null)
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showHabitHowTo(context, habitHowToIndex(topic));
        if (mounted) Navigator.maybePop(context);
      });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = HabitPalette.of(context);
    return HandyPage(
      title: tr(context, 'How to use', 'Cách dùng'),
      children: [
        const SizedBox(height: HandySpace.m),
        Material(
          color: p.tint,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: const Key('help-replay'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.pushNamed(context, '/welcome'),
            child: Padding(
              padding: const EdgeInsets.all(HandySpace.l),
              child: Row(
                children: [
                  Icon(Icons.play_circle_outline, size: 36, color: p.anchor),
                  const SizedBox(width: HandySpace.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(
                            context,
                            'Watch the welcome again',
                            'Xem lại phần giới thiệu',
                          ),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: p.anchor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr(
                            context,
                            'Practise on a sample day: tick a bead, fill a count, run a routine. Nothing is kept.',
                            'Tập trên một ngày mẫu: lấp một hạt, đếm đủ lần, chạy một quy trình. Không lưu gì thật.',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: p.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: HandySpace.xl),
        Semantics(
          header: true,
          child: Text(
            tr(context, 'Topics', 'Chủ đề'),
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: HandySpace.s),
        for (final (i, t) in habitHowTo.indexed)
          ListTile(
            key: Key('help-topic-${t.id}'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            minVerticalPadding: 10,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: p.raised,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(t.icon, color: p.anchor),
            ),
            title: Text(
              t.title(context),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(t.summary(context)),
            trailing: Icon(Icons.chevron_right, color: p.muted),
            onTap: () => showHabitHowTo(context, i),
          ),
        const SizedBox(height: HandySpace.xl),
      ],
    );
  }
}

/// A topic as a sheet: numbered step cards, Previous and Next, and Done.
Future<void> showHabitHowTo(BuildContext context, int start) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .92,
        minChildSize: .5,
        maxChildSize: .96,
        expand: false,
        builder: (_, scroll) => _TopicSheet(start: start, scroll: scroll),
      ),
    );

class _TopicSheet extends StatefulWidget {
  final int start;
  final ScrollController scroll;
  const _TopicSheet({required this.start, required this.scroll});
  @override
  State<_TopicSheet> createState() => _TopicSheetState();
}

class _TopicSheetState extends State<_TopicSheet> {
  late int _at = widget.start;

  void _go(int to) {
    if (widget.scroll.hasClients) widget.scroll.jumpTo(0);
    setState(() => _at = to);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = HabitPalette.of(context);
    final t = habitHowTo[_at];
    return Column(
      key: Key('help-sheet-${t.id}'),
      children: [
        Expanded(
          child: ListView(
            controller: widget.scroll,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            children: [
              Text(
                tr(
                  context,
                  'Topic ${_at + 1} of ${habitHowTo.length}',
                  'Chủ đề ${_at + 1}/${habitHowTo.length}',
                ),
                style: theme.textTheme.bodySmall?.copyWith(color: p.muted),
              ),
              const SizedBox(height: 4),
              Semantics(
                header: true,
                child: Text(
                  t.title(context),
                  key: Key('help-article-${t.id}'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.anchor,
                  ),
                ),
              ),
              const SizedBox(height: HandySpace.s),
              Text(
                t.summary(context),
                style: theme.textTheme.bodyLarge?.copyWith(color: p.muted),
              ),
              const SizedBox(height: HandySpace.l),
              for (final (i, (source, index, words)) in t.steps.indexed)
                Container(
                  key: Key('help-step-$i'),
                  margin: const EdgeInsets.only(bottom: HandySpace.m),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: p.canvas,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 30,
                            child: Text(
                              '${i + 1}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: p.vermilion,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                tr(context, words.$1, words.$2),
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: HandySpace.m),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: HabitHelpMock(topic: source, step: index),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _at > 0
                        ? TextButton.icon(
                            key: const Key('help-previous'),
                            onPressed: () => _go(_at - 1),
                            icon: const Icon(Icons.arrow_back, size: 18),
                            label: Text(tr(context, 'Previous', 'Trước')),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: _at < habitHowTo.length - 1
                        ? TextButton.icon(
                            key: const Key('help-next'),
                            onPressed: () => _go(_at + 1),
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: Text(tr(context, 'Next', 'Tiếp')),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: HandySpace.xs),
              FilledButton(
                key: const Key('help-done'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(tr(context, 'Done', 'Xong')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
