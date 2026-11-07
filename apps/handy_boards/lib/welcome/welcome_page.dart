import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import 'motion.dart';
import 'practice_board.dart';
import 'story_scene.dart';

/// The guide's three stages: the story (one stage, two beats), the
/// practice on a pretend board, and how to start.
enum _Stage { story, practice, start }

/// The first run, built like Handy Bookmark's and Sticky Wall's guides:
///
/// 1. the story: to-dos scattered in notes, chats and scraps, then the same
///    scraps gathered into one board as cards with their categories;
/// 2. a practice board at real size: move a card, filter by its category,
///    finish it (everything dark except the next thing to do, with a word
///    beside it). Nothing is written;
/// 3. how to start: a study board, a blank board, or the templates.
///
/// Back and Skip on every stage, Android back and Esc step back, Enter
/// presses the button. With [replay] (from Settings) the last stage offers
/// no choices and nothing changes.
class WelcomePage extends StatefulWidget {
  /// Called with 'study', 'blank', 'templates', or null (skipped/replay).
  final Future<void> Function(String? start) onDone;
  final bool replay;
  const WelcomePage({super.key, required this.onDone, this.replay = false});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  int at = 0;
  bool gathered = false, practiced = false, leaving = false;
  String start = 'study';
  PracticeStep practiceStep = PracticeStep.drag;
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
      gathered = next < at || gathered;
      at = next;
      if (stage == _Stage.practice) {
        practiced = false;
        practiceStep = PracticeStep.drag;
      }
    });
    _play();
  }

  void _gather() {
    setState(() => gathered = true);
    _play();
  }

  Future<void> _leave(String? choice) async {
    if (leaving) return;
    setState(() => leaving = true);
    try {
      await widget.onDone(choice);
    } finally {
      if (mounted) setState(() => leaving = false);
    }
  }

  void _back() {
    if (stage == _Stage.story && gathered) {
      setState(() => gathered = false);
      _play();
    } else if (at == 0) {
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

  _Page _page(BuildContext context) => switch (stage) {
    _Stage.story when !gathered => _Page(
      before: tr(
        context,
        'Your to-dos are everywhere.\n',
        'Việc nằm khắp nơi.\n',
      ),
      words: tr(context, 'Then they slip away.', 'Rồi rơi mất.'),
      body: tr(
        context,
        'A note here, a chat there, a scrap of paper on the desk… and the deadline comes first.',
        'Một dòng ghi chú, một tin nhắn, một mẩu giấy trên bàn… và hạn nộp đến trước khi kịp nhớ.',
      ),
      primary: tr(context, 'Put them on one board', 'Gom về một bảng'),
      onPrimary: _gather,
    ),
    _Stage.story => _Page(
      before: tr(context, 'One board for ', 'Một bảng cho '),
      words: tr(context, 'all of it', 'tất cả'),
      after: '.',
      body: tr(
        context,
        'Columns say where each thing is. Colours say what it is about. On your device, no account.',
        'Cột cho biết việc đang ở đâu. Màu cho biết việc thuộc về gì. Ngay trên máy, không tài khoản.',
      ),
      primary: tr(context, 'Show me how', 'Chỉ tôi cách dùng'),
      onPrimary: () => _go(1),
    ),
    _Stage.practice when practiced => _Page(
      before: tr(context, 'Done, and ', 'Xong rồi, mà '),
      words: tr(context, 'still Maths', 'vẫn thuộc Toán'),
      after: '.',
      body: tr(
        context,
        'A card keeps its category in every column, so each subject always shows how far it has come. This was practice; nothing was saved.',
        'Thẻ giữ nhóm của nó ở mọi cột, nên môn nào cũng luôn cho thấy đã làm tới đâu. Đây là bản tập, chưa lưu gì.',
      ),
      primary: tr(context, 'Next', 'Tiếp'),
      onPrimary: () => _go(2),
      check: true,
    ),
    _Stage.practice => _Page(
      before: tr(context, 'Try ', 'Thử '),
      words: tr(context, 'moving a card', 'chuyển một thẻ'),
      after: '.',
      body: switch (practiceStep) {
        PracticeStep.drag => tr(
          context,
          'Do what is lit on the board. Hold the card, then drag it to Doing.',
          'Làm theo chỗ đang sáng trên bảng. Giữ thẻ rồi kéo sang Đang làm.',
        ),
        PracticeStep.filter => tr(
          context,
          'Now tap Maths: the board shows only Maths cards.',
          'Giờ chạm Toán: bảng chỉ còn thẻ môn Toán.',
        ),
        _ => tr(
          context,
          'Last, drag it to Done.',
          'Cuối cùng, kéo thẻ sang Xong.',
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
      before: widget.replay
          ? tr(context, 'That is ', 'Chỉ ')
          : tr(context, 'How do you ', 'Bạn muốn '),
      words: widget.replay
          ? tr(context, 'all it takes', 'vậy thôi')
          : tr(context, 'want to start', 'bắt đầu thế nào'),
      after: widget.replay ? '.' : '?',
      body: widget.replay
          ? tr(
              context,
              'Cards, columns and categories. Everything else is in each card.',
              'Thẻ, cột và nhóm. Mọi thứ khác nằm trong từng thẻ.',
            )
          : tr(
              context,
              'You can change anything later.',
              'Đổi được mọi thứ sau này.',
            ),
      primary: widget.replay
          ? tr(context, 'Done', 'Xong')
          : tr(context, 'Start', 'Bắt đầu'),
      onPrimary: () => _leave(widget.replay ? null : start),
    ),
  };

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
          if (page.primary != null)
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

  /// The stage's picture: the story, the practice board, or the choices.
  Widget _scene({required bool framed}) => switch (stage) {
    _Stage.practice => PhoneFrame(
      interactive: true,
      bare: !framed,
      minHeight: 480,
      screen: PracticeBoard(key: practice, onStep: _practiceStep),
    ),
    _Stage.start when !widget.replay => _choices(),
    _ => BoardsStoryScene(
      key: const ValueKey('story'),
      gathered: gathered || stage == _Stage.start,
    ),
  };

  Widget _bar(BuildContext context) {
    const total = 3;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: at == 0 && !gathered
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
        key: ValueKey('words-$at-$gathered-$practiced-$practiceStep'),
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
              onPressed: leaving ? null : p.onPrimary,
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

  /// The three ways to start, as large choices.
  Widget _choices() {
    final rows = [
      (
        'study',
        Icons.school_outlined,
        tr(context, 'A study board', 'Bảng học tập'),
        tr(
          context,
          'Maths, Literature, English, Physics, ready to edit.',
          'Toán, Văn, Anh, Lý, sửa được ngay.',
        ),
      ),
      (
        'blank',
        Icons.view_week_outlined,
        tr(context, 'A blank board', 'Bảng trống'),
        tr(context, 'To Do, Doing, Done.', 'Cần làm, Đang làm, Xong.'),
      ),
      (
        'templates',
        Icons.dashboard_customize_outlined,
        tr(context, 'Browse templates', 'Xem các mẫu'),
        tr(
          context,
          'Projects, shopping, events and more.',
          'Dự án, mua sắm, sự kiện và hơn thế.',
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
            for (final (id, icon, title, hint) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Semantics(
                  selected: start == id,
                  button: true,
                  child: Material(
                    color: start == id ? GuideColors.tint : GuideColors.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: start == id
                            ? GuideColors.teal
                            : const Color(0xFFE4DCDE),
                        width: start == id ? 2 : 1,
                      ),
                    ),
                    child: InkWell(
                      key: Key('welcome-choice-$id'),
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => setState(() => start = id),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(icon, color: GuideColors.ink),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
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
                            if (start == id)
                              const Icon(
                                Icons.check_circle,
                                color: GuideColors.teal,
                              ),
                          ],
                        ),
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

  /// Phones: the bar, the words, the picture as large as the screen allows
  /// (the practice at real size), the button at the foot.
  Widget _narrow(BuildContext context, _Page p, BoxConstraints box) {
    final roomy =
        box.maxHeight >= 600 &&
        MediaQuery.textScalerOf(context).scale(16) <= 16 * 1.3;
    final words = Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: _words(context, p, wide: false, center: stage == _Stage.story),
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
  final bool check;
  const _Page({
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
