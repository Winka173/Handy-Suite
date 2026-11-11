import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import 'motion.dart';
import 'practice_today.dart';
import 'story_scene.dart';

/// The guide's three stages, as in Handy Boards and Handy Bookmark.
enum _Stage { story, practice, missed }

/// The first run:
///
/// 1. the story, in two beats: good intentions lie about as a sticky note,
///    a message and a calendar page; then the same scraps fly into Today
///    and become bead strings. Nothing to choose;
/// 2. a pretend Today at real size: tick a habit's bead, fill a counted
///    one, run a one-step routine. Nothing is written;
/// 3. a missed day: one hollow bead in a week, and the figures that stay.
///    One button, Start.
///
/// Back and Skip on every stage, Android back and Esc step back, Enter
/// presses the button. The guide never reaches real data: only [onDone]
/// (the caller saves that it was seen) leaves it.
class HabitWelcomePage extends StatefulWidget {
  final Future<void> Function() onDone;
  final bool replay;
  const HabitWelcomePage({
    super.key,
    required this.onDone,
    this.replay = false,
  });
  @override
  State<HabitWelcomePage> createState() => _HabitWelcomePageState();
}

class _HabitWelcomePageState extends State<HabitWelcomePage>
    with SingleTickerProviderStateMixin {
  int at = 0;
  bool gathered = false, leaving = false;
  String? error;
  PracticeStep practiceStep = PracticeStep.read;
  final practice = GlobalKey<PracticeTodayState>();
  late final AnimationController clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  _Stage get stage => _Stage.values[at];
  bool get practiced => practiceStep == PracticeStep.done;

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
      // Coming back to the story finds it already gathered.
      gathered = next < at || gathered;
      at = next;
      if (stage == _Stage.practice) practiceStep = PracticeStep.read;
    });
    _play();
  }

  Future<void> _leave() async {
    if (leaving) return;
    setState(() {
      leaving = true;
      error = null;
    });
    try {
      await widget.onDone();
    } catch (_) {
      if (mounted)
        setState(
          () => error = tr(
            context,
            'Could not save. Try again.',
            'Chưa lưu được. Hãy thử lại.',
          ),
        );
    } finally {
      if (mounted) setState(() => leaving = false);
    }
  }

  void _gather() {
    setState(() => gathered = true);
    _play();
  }

  void _back() {
    if (stage == _Stage.story && gathered) {
      setState(() => gathered = false);
      _play();
    } else if (at == 0) {
      _leave();
    } else {
      _go(at - 1);
    }
  }

  void _practiceStep(PracticeStep step) {
    setState(() => practiceStep = step);
    if (practiced) _play();
  }

  _Page _page(BuildContext context) => switch (stage) {
    _Stage.story when !gathered => _Page(
      before: tr(context, 'Good intentions ', 'Ý định tốt '),
      words: tr(context, 'drift away', 'rồi nhạt dần'),
      after: '.',
      body: tr(
        context,
        'A note to drink water, a message about reading, a gym day on the calendar… and the week is over.',
        'Tờ nhắc uống nước, tin nhắn hẹn đọc sách, buổi tập ghi trên lịch… rồi một tuần trôi qua.',
      ),
      primary: tr(context, 'Bring them into today', 'Gom về hôm nay'),
      onPrimary: _gather,
    ),
    _Stage.story => _Page(
      before: tr(context, 'Small actions. ', 'Việc nhỏ. '),
      words: tr(context, 'Visible days', 'Ngày rõ ràng'),
      after: '.',
      body: tr(
        context,
        'Each intention becomes a string of beads, one a day. Fill today’s bead and watch the string grow. On your device, without an account.',
        'Mỗi ý định thành một chuỗi hạt, mỗi ngày một hạt. Lấp hạt hôm nay và nhìn chuỗi dài ra. Ngay trên máy, không cần tài khoản.',
      ),
      primary: tr(context, 'Show me how', 'Chỉ tôi cách dùng'),
      onPrimary: () => _go(1),
    ),
    _Stage.practice when practiced => _Page(
      before: tr(context, 'Today is ', 'Hôm nay '),
      words: tr(context, 'all done', 'đã xong'),
      after: '.',
      body: tr(
        context,
        'A tap fills a bead; a count fills it step by step; a routine walks you through. This was practice; nothing was saved.',
        'Một chạm lấp một hạt; việc đếm lấp dần từng phần; quy trình dẫn bạn từng bước. Đây là bản tập, chưa lưu gì.',
      ),
      primary: tr(context, 'Next', 'Tiếp'),
      onPrimary: () => _go(2),
      check: true,
    ),
    _Stage.practice => _Page(
      before: tr(context, 'Try ', 'Thử '),
      words: tr(context, 'a day in Habit', 'một ngày cùng Habit'),
      after: '.',
      body: switch (practiceStep) {
        PracticeStep.read => tr(
          context,
          'Today’s bead sits at the end of each string. Tap it when it is done.',
          'Hạt hôm nay nằm cuối mỗi chuỗi. Làm xong thì chạm vào nó.',
        ),
        PracticeStep.water => tr(
          context,
          'Some habits count: three glasses a day. Each tap fills a third.',
          'Có thói quen tính theo lần: ba cốc mỗi ngày. Mỗi chạm lấp một phần ba.',
        ),
        PracticeStep.start => tr(
          context,
          'A routine is a few steps in order. Start this one.',
          'Quy trình là vài bước theo thứ tự. Bắt đầu quy trình này.',
        ),
        _ => tr(
          context,
          'One step, then it is done. Finish it.',
          'Một bước là xong. Hoàn thành nó.',
        ),
      },
      primary: null,
      onPrimary: () {},
      secondary: TextButton(
        key: const Key('welcome-do-it'),
        style: TextButton.styleFrom(foregroundColor: GuideColors.deep),
        onPressed: () => practice.currentState?.advance(),
        child: Text(tr(context, 'Do it for me', 'Làm giúp tôi')),
      ),
    ),
    _Stage.missed => _Page(
      before: tr(context, 'A missed day ', 'Ngày lỡ '),
      words: tr(context, 'keeps its place', 'vẫn có chỗ của mình'),
      after: '.',
      body: tr(
        context,
        'A hollow bead is a day, not a failure. Your current streak may restart; your best streak and the days you kept stay.',
        'Hạt rỗng là một ngày, không phải thất bại. Chuỗi hiện tại có thể bắt đầu lại; chuỗi tốt nhất và những ngày đã giữ vẫn còn.',
      ),
      primary: widget.replay
          ? tr(context, 'Done', 'Xong')
          : tr(context, 'Start', 'Bắt đầu'),
      onPrimary: _leave,
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
          const SingleActivator(LogicalKeyboardKey.enter): page.primary != null
              ? page.onPrimary
              : () => practice.currentState?.advance(),
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

  Widget _scene({required bool framed}) => switch (stage) {
    _Stage.practice => PhoneFrame(
      interactive: true,
      bare: !framed,
      minHeight: 560,
      screen: PracticeToday(key: practice, onStep: _practiceStep),
    ),
    _Stage.story => HabitStoryScene(
      key: const ValueKey('story'),
      gathered: gathered,
    ),
    _Stage.missed => const HabitMissedScene(key: ValueKey('missed')),
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
                                ? GuideColors.hue
                                : const Color(0xFFE9DDD3),
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
            onPressed: leaving ? null : _leave,
            child: Text(tr(context, 'Skip', 'Bỏ qua')),
          ),
        ],
      ),
    );
  }

  Widget _words(BuildContext context, _Page p, {required bool wide}) {
    final title = TextStyle(
      fontFamily: handyFontFamily('Nunito'),
      fontSize: wide ? 44 : 30,
      height: 1.1,
      letterSpacing: -.6,
      fontWeight: FontWeight.w800,
      color: GuideColors.deep,
    );
    return HandySwap(
      child: Column(
        key: ValueKey('words-$at-$gathered-$practiceStep'),
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  color: GuideColors.hue,
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
                key: Key('welcome-title-$at-$gathered'),
                before: p.before,
                words: p.words,
                after: p.after,
                style: title,
              ),
            ),
          ),
          SizedBox(height: wide ? 16 : 10),
          Reveal(
            from: .12,
            to: .5,
            child: Text(
              p.body,
              style: TextStyle(
                fontSize: wide ? 18 : 16,
                height: 1.5,
                color: GuideColors.muted,
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            HandyNotice(error!, tone: HandyTone.error),
          ],
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
              key: const Key('welcome-next'),
              style: FilledButton.styleFrom(
                backgroundColor: GuideColors.hue,
                foregroundColor: Colors.white,
                minimumSize: Size(wide ? 260 : double.infinity, 56),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
  /// (or the practice in a phone) on the right.
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
