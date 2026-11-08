import 'package:flutter/services.dart';
import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';
import '../covers/cover_art.dart';
import 'motion.dart';
import 'practice_board.dart';

/// The guide's three stages: what the person mainly organises, a practice
/// on a pretend board, and where to start.
enum _Stage { purpose, practice, start }

/// The first run, in two branches with the same mechanics:
///
/// 1. "What would you mainly like to organise?" Study or Work (a
///    suggestion only; everything stays open), or straight to all
///    templates, or Skip;
/// 2. a practice board at real size, with the branch's own examples
///    (subjects or work areas): add a card, move it, focus its category
///    (the others stay), tick a subtask (the card stays put). Nothing is
///    written;
/// 3. three suggested templates for the branch, all templates, or a blank
///    board. Choosing one opens its own setup; nothing is made before the
///    person taps Create there.
///
/// Back and Skip on every stage, Android back and Esc step back, Enter
/// presses the button. With [replay] (from Settings) nothing changes.
class WelcomePage extends StatefulWidget {
  /// Called with what to open next ('template:<id>', 'gallery', 'blank',
  /// or null for home) and the purpose picked ('study', 'work' or null).
  final Future<void> Function(String? next, String? purpose) onDone;
  final bool replay;
  const WelcomePage({super.key, required this.onDone, this.replay = false});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  int at = 0;
  bool practiced = false, leaving = false;
  String? purpose;
  PracticeStep practiceStep = PracticeStep.add;
  final practice = GlobalKey<PracticeBoardState>();
  late final AnimationController clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  _Stage get stage => _Stage.values[at];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (clock.value == 0 && !clock.isAnimating) _play();
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  void _play() => moves(context) ? clock.forward(from: 0) : clock.value = 1;

  void _go(int next) {
    setState(() {
      at = next;
      if (stage == _Stage.practice) {
        practiced = false;
        practiceStep = PracticeStep.add;
      }
    });
    _play();
  }

  Future<void> _leave(String? next) async {
    if (leaving) return;
    setState(() => leaving = true);
    try {
      await widget.onDone(next, purpose);
    } finally {
      if (mounted) setState(() => leaving = false);
    }
  }

  void _back() {
    if (at == 0) {
      _leave(null);
    } else {
      _go(at - 1);
    }
  }

  void _practiceStep(PracticeStep step) {
    setState(() {
      practiceStep = step;
      practiced = step == PracticeStep.done;
    });
    if (practiced) _play();
  }

  bool get _work => purpose == 'work';

  _Page _page(BuildContext context) => switch (stage) {
    _Stage.purpose => _Page(
      before: tr(
        context,
        'What would you mainly like to ',
        'Bạn chủ yếu muốn ',
      ),
      words: tr(context, 'organise', 'sắp xếp gì'),
      after: '?',
      body: tr(
        context,
        'Pick one for examples that fit. You can use both, and every '
            'template, later.',
        'Chọn một để ví dụ và gợi ý hợp với bạn. Sau này vẫn dùng được cả '
            'hai và mọi mẫu.',
      ),
      primary: tr(context, 'Next', 'Tiếp'),
      enabled: purpose != null,
      onPrimary: () => _go(1),
      secondary: TextButton(
        key: const Key('welcome-all-templates'),
        style: TextButton.styleFrom(foregroundColor: GuideColors.tealDeep),
        onPressed: () => _leave('gallery'),
        child: Text(
          tr(
            context,
            'Something else? See all templates',
            'Việc khác? Xem tất cả mẫu',
          ),
        ),
      ),
    ),
    _Stage.practice when practiced => _Page(
      before: tr(context, 'Ticked, and ', 'Đã tích, mà thẻ '),
      words: tr(context, 'it stayed put', 'vẫn ở yên'),
      after: '.',
      body: _work
          ? tr(
              context,
              'Columns are progress, categories are work areas, dates are '
                  'separate. When it is done, you drag it to Done yourself. '
                  'This was practice; nothing was saved.',
              'Cột là tiến độ, nhóm là mảng việc, ngày hạn là chuyện riêng. '
                  'Khi xong, bạn tự kéo thẻ sang Xong. Đây là bản tập, chưa '
                  'lưu gì.',
            )
          : tr(
              context,
              'Columns are progress, categories are subjects, dates are '
                  'separate (see them in Time). When it is done, you drag it '
                  'to Done yourself. This was practice; nothing was saved.',
              'Cột là tiến độ, nhóm là môn học, ngày hạn là chuyện riêng (xem '
                  'ở chế độ Thời gian). Khi xong, bạn tự kéo thẻ sang Xong. '
                  'Đây là bản tập, chưa lưu gì.',
            ),
      primary: tr(context, 'Next', 'Tiếp'),
      onPrimary: () => _go(2),
      check: true,
    ),
    _Stage.practice => _Page(
      before: tr(context, 'Try ', 'Thử '),
      words: tr(context, 'a card of your own', 'một thẻ của bạn'),
      after: '.',
      body: switch (practiceStep) {
        PracticeStep.add => tr(
          context,
          'A card is one thing to do; a column is how far along it is. Tap '
              'Add card in To Do.',
          'Mỗi thẻ là một việc; cột cho biết việc tới đâu. Chạm Thêm thẻ ở '
              'cột Cần làm.',
        ),
        PracticeStep.drag => tr(
          context,
          'Started it? Hold the card, then drag it to Doing.',
          'Bắt đầu làm rồi? Giữ thẻ rồi kéo sang Đang làm.',
        ),
        PracticeStep.focus =>
          _work
              ? tr(
                  context,
                  'Categories are work areas. Tap Interface: its cards light '
                      'up, the others stay.',
                  'Nhóm là các mảng việc. Chạm Giao diện: thẻ của nó sáng lên, '
                      'thẻ khác vẫn ở đó.',
                )
              : tr(
                  context,
                  'Categories are your subjects. Tap Maths: its cards light up, '
                      'the others stay.',
                  'Nhóm là các môn học. Chạm Toán: thẻ môn Toán sáng lên, thẻ '
                      'khác vẫn ở đó.',
                ),
        _ => tr(
          context,
          'A card can hold small steps. Tick one.',
          'Một thẻ có thể gồm các việc con. Tích một việc.',
        ),
      },
      primary: null,
      onPrimary: () {},
      secondary: TextButton(
        key: const Key('welcome-do-it'),
        style: TextButton.styleFrom(foregroundColor: GuideColors.tealDeep),
        onPressed: () => practice.currentState?.advance(),
        child: Text(tr(context, 'Do it for me', 'Làm giúp tôi')),
      ),
    ),
    _Stage.start => _Page(
      before: tr(context, 'Where do you ', 'Bạn muốn '),
      words: tr(context, 'want to start', 'bắt đầu từ đâu'),
      after: '?',
      body: tr(
        context,
        'A template asks a few questions and shows the board before it is '
            'made. Nothing is created until you tap Create.',
        'Mẫu hỏi vài câu và cho xem bảng trước khi tạo. Chưa có gì được tạo '
            'cho tới khi bạn bấm Tạo bảng.',
      ),
      primary: widget.replay ? tr(context, 'Done', 'Xong') : null,
      onPrimary: () => _leave(null),
    ),
  };

  /// The two purposes, as large illustrated choices.
  Widget _purposes() {
    final rows = [
      (
        'study',
        'study.open-book',
        tr(context, 'Study', 'Học tập'),
        tr(
          context,
          'Assignments, subjects, exam prep.',
          'Bài tập, môn học, ôn thi.',
        ),
      ),
      (
        'work',
        'work.sticky-plan',
        tr(context, 'Work', 'Công việc'),
        tr(
          context,
          'Projects, tasks, priorities.',
          'Dự án, đầu việc, ưu tiên.',
        ),
      ),
    ];
    return Reveal(
      from: .2,
      to: .6,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (id, cover, title, hint) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Semantics(
                  selected: purpose == id,
                  button: true,
                  child: Material(
                    color: purpose == id ? GuideColors.tint : GuideColors.card,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: purpose == id
                            ? GuideColors.teal
                            : const Color(0xFFE4DCDE),
                        width: purpose == id ? 2 : 1,
                      ),
                    ),
                    child: InkWell(
                      key: Key('welcome-purpose-$id'),
                      onTap: () => setState(() => purpose = id),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 96,
                            height: 88,
                            child: ExcludeSemantics(child: CoverArt(cover)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: GuideColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hint,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: GuideColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              purpose == id
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: purpose == id
                                  ? GuideColors.teal
                                  : GuideColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Three suggested templates for the branch, then all templates and a
  /// blank board. Each opens its own setup; nothing is made here.
  Widget _suggestions() {
    final vi = Localizations.localeOf(context).languageCode == 'vi';
    final ids = _work
        ? const ['project', 'weekly', 'ideas']
        : const ['semester', 'group-assignment', 'exam-revision'];
    final rows = [
      for (final id in ids)
        if (templateById(id) case final t?)
          (
            'template:${t.id}',
            Icons.dashboard_customize_outlined,
            t.name.of(vi),
            t.goal.of(vi),
            t.cover,
          ),
      (
        'gallery',
        Icons.grid_view_outlined,
        tr(context, 'All templates', 'Tất cả mẫu'),
        tr(
          context,
          '30 boards for study, work, home and plans.',
          '30 mẫu cho học tập, công việc, nhà cửa, kế hoạch.',
        ),
        null,
      ),
      (
        'blank',
        Icons.view_week_outlined,
        tr(context, 'A blank board', 'Bảng trống'),
        tr(context, 'To Do, Doing, Done.', 'Cần làm, Đang làm, Xong.'),
        null,
      ),
    ];
    return Reveal(
      from: .2,
      to: .6,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (next, icon, title, hint, cover) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: GuideColors.card,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: Color(0xFFE4DCDE)),
                  ),
                  child: InkWell(
                    key: Key('welcome-start-$next'),
                    onTap: leaving ? null : () => _leave(next),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: cover == null
                              ? Icon(icon, color: GuideColors.ink)
                              : ExcludeSemantics(child: CoverArt(cover)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: GuideColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                hint,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: GuideColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.chevron_right,
                            color: GuideColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _page(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _back,
          if (page.primary != null && page.enabled)
            const SingleActivator(LogicalKeyboardKey.enter): page.onPrimary,
        },
        child: Focus(
          autofocus: true,
          child: Beat(
            clock: clock,
            child: Scaffold(
              backgroundColor: GuideColors.paper,
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, box) => box.maxWidth >= 700
                      ? _wide(context, page)
                      : _narrow(context, page, box),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The stage's picture: the purposes, the practice board, or where to
  /// start.
  Widget _scene({required bool framed}) => switch (stage) {
    _Stage.practice => PhoneFrame(
      interactive: true,
      bare: !framed,
      minHeight: 480,
      screen: PracticeBoard(key: practice, onStep: _practiceStep, work: _work),
    ),
    _Stage.purpose => _purposes(),
    _Stage.start => _suggestions(),
  };

  Widget _bar(BuildContext context) {
    const total = 3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: at == 0
                ? null
                : IconButton(
                    key: const Key('welcome-back'),
                    tooltip: tr(context, 'Back', 'Quay lại'),
                    color: GuideColors.ink,
                    onPressed: _back,
                    icon: const Icon(Icons.arrow_back),
                  ),
          ),
          Expanded(
            child: Semantics(
              container: true,
              label: tr(
                context,
                'Step ${at + 1} of $total',
                'Bước ${at + 1} trên $total',
              ),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 0; i < total; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: AnimatedContainer(
                          duration: HandyMotion.of(context, HandyMotion.long),
                          height: 5,
                          decoration: BoxDecoration(
                            color: i <= at
                                ? GuideColors.teal
                                : const Color(0xFFE4DCDE),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: const Key('welcome-skip'),
            style: TextButton.styleFrom(foregroundColor: GuideColors.ink),
            onPressed: () => _leave(null),
            child: Text(tr(context, 'Skip', 'Bỏ qua')),
          ),
        ],
      ),
    );
  }

  Widget _words(
    BuildContext context,
    _Page p, {
    required bool wide,
    bool center = false,
  }) {
    final align = center ? TextAlign.center : TextAlign.start;
    final title = TextStyle(
      fontFamily: handyFontFamily('PlusJakartaSans'),
      fontSize: wide ? 44 : (center ? 32 : 30),
      height: 1.1,
      letterSpacing: -.8,
      fontWeight: FontWeight.w600,
      color: GuideColors.ink,
    );
    return HandySwap(
      child: Column(
        key: ValueKey('words-$at-$purpose-$practiced-$practiceStep'),
        crossAxisAlignment: center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (p.check)
            Reveal(
              to: .3,
              scale: .6,
              child: Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: const BoxDecoration(
                  color: GuideColors.teal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 26),
              ),
            ),
          Reveal(
            to: .35,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.5,
              child: Highlighted(
                before: p.before,
                words: p.words,
                after: p.after,
                style: title,
                textAlign: align,
              ),
            ),
          ),
          SizedBox(height: wide ? 16 : 10),
          Reveal(
            from: .12,
            to: .5,
            child: Text(
              p.body,
              textAlign: align,
              style: TextStyle(
                fontSize: wide ? 18 : 16,
                height: 1.5,
                color: GuideColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, _Page p, {required bool wide}) {
    final button = p.primary == null
        ? const SizedBox.shrink()
        : Reveal(
            from: .6,
            to: .95,
            rise: 10,
            scale: .96,
            child: FilledButton(
              key: const Key('welcome-primary'),
              style: FilledButton.styleFrom(
                backgroundColor: GuideColors.teal,
                foregroundColor: Colors.white,
                minimumSize: Size(wide ? 260 : double.infinity, 56),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: leaving || !p.enabled ? null : p.onPrimary,
              child: Text(p.primary!),
            ),
          );
    return wide
        ? Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [button, ?p.secondary],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              button,
              if (p.secondary != null) Center(child: p.secondary),
            ],
          );
  }

  /// Phones: the bar, the words, the picture as large as the screen allows
  /// (the practice at real size), the button at the foot.
  Widget _narrow(BuildContext context, _Page p, BoxConstraints box) {
    final roomy =
        box.maxHeight >= 600 &&
        MediaQuery.textScalerOf(context).scale(16) <= 16 * 1.3;
    final words = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: _words(context, p, wide: false),
    );
    Widget scene(double? height) => SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: _scene(framed: false),
      ),
    );
    final actions = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: _actions(context, p, wide: false),
    );
    if (roomy)
      return Column(
        children: [
          _bar(context),
          words,
          Expanded(child: scene(null)),
          actions,
        ],
      );
    return SingleChildScrollView(
      child: Column(
        children: [
          _bar(context),
          words,
          scene((box.maxHeight * .6).clamp(320.0, 620.0)),
          actions,
        ],
      ),
    );
  }

  /// Tablets and wide windows: words and button on the left, the picture
  /// (or the practice in a phone, or the choices) on the right.
  Widget _wide(BuildContext context, _Page p) => Column(
    children: [
      _bar(context),
      Expanded(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 8, 40, 24),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _words(context, p, wide: true),
                          const SizedBox(height: 32),
                          _actions(context, p, wide: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                  Expanded(flex: 6, child: _scene(framed: true)),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _Page {
  final String before, words, after, body;
  final String? primary;
  final VoidCallback onPrimary;
  final Widget? secondary;
  final bool check, enabled;
  const _Page({
    this.enabled = true,
    required this.before,
    required this.words,
    this.after = '',
    required this.body,
    required this.primary,
    required this.onPrimary,
    this.secondary,
    this.check = false,
  });
}
