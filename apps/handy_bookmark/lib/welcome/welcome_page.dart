import 'dart:async';
import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import '../data/import_export.dart';
import '../scope.dart';
import 'more_scenes.dart';
import 'motion.dart';
import 'rehearsal.dart';
import 'story_scene.dart';

/// The preference that records a finished (or skipped) guide. It lives with
/// the library, so a restored backup does not show the guide again.
const guideDoneKey = 'guideDone';

/// Whether to open the guide on start: never finished, and nothing saved
/// or recently deleted (someone who already has links never sees it unasked).
bool shouldShowGuide(SaveScope scope) =>
    scope.c.preferences[guideDoneKey] != true &&
    scope.library.bookmarks.isEmpty &&
    scope.library.trash.isEmpty;

enum _Step { scattered, gathered, practice, find, nudge }

/// The first run: a short story told with real photos (saved everywhere,
/// found nowhere; then one place), a practice save on a pretend phone,
/// finding it again, and the weekly nudge. Nothing in it is saved.
/// Skip on every step; replayable from Settings (`/welcome`).
class WelcomePage extends StatefulWidget {
  final SaveScope scope;
  const WelcomePage({super.key, required this.scope});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  int at = 0;
  bool practiced = false, leaving = false;
  late final AnimationController clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  SaveScope get scope => widget.scope;

  List<_Step> get steps => [
    _Step.scattered,
    _Step.gathered,
    _Step.practice,
    _Step.find,
    if (scope.reminders.supported) _Step.nudge,
  ];
  _Step get step => steps[at];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (clock.value == 0 && !clock.isAnimating) _play();
  }

  void _play() {
    // The search needs time to be typed; the other steps are quicker.
    clock.duration = Duration(milliseconds: step == _Step.find ? 2400 : 1500);
    moves(context) ? clock.forward(from: 0) : clock.value = 1;
  }

  @override
  void dispose() {
    clock.dispose();
    unawaited(_markDone());
    super.dispose();
  }

  void _go(int next) {
    setState(() {
      at = next;
      if (step == _Step.practice) practiced = false;
    });
    _play();
  }

  Future<void> _markDone() async {
    if (scope.c.preferences[guideDoneKey] == true) return;
    try {
      await scope.c.update(
        (l) => l,
        prefs: {...scope.c.preferences, guideDoneKey: true},
      );
    } catch (_) {
      // Not remembered: the guide may show again on an empty library.
    }
  }

  /// Leaves the guide. A plain pop: the page's own PopScope turns system
  /// back into a step back, so maybePop would only come round to here.
  Future<void> _finish() async {
    if (leaving) return;
    leaving = true;
    await _markDone();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _turnOnNudge() async {
    final allowed = await scope.reminders.request();
    if (allowed && mounted)
      await scope.run(
        context,
        () => scope.c.update(
          (l) => l,
          prefs: {...scope.c.preferences, 'revisit': true},
        ),
      );
    await _finish();
  }

  void _back() => at == 0 ? _finish() : _go(at - 1);

  void _next() => at == steps.length - 1 ? _finish() : _go(at + 1);

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
          if (page.ready)
            const SingleActivator(LogicalKeyboardKey.enter): page.onPrimary,
        },
        child: Focus(
          autofocus: true,
          child: Beat(
            clock: clock,
            child: Scaffold(
              backgroundColor: GuideColors.paper,
              body: LayoutBuilder(
                builder: (context, box) => box.maxWidth >= 700
                    ? SafeArea(child: _wide(context, page))
                    : step.index >= _Step.practice.index
                    ? _full(context, page)
                    : SafeArea(child: _narrow(context, page)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _Page _page(BuildContext context) => switch (step) {
    _Step.scattered => _Page(
      before: tr(context, 'Saved everywhere.\n', 'Lưu khắp nơi.\n'),
      words: tr(context, 'Found nowhere.', 'Tìm chẳng thấy.'),
      after: '',
      body: tr(
        context,
        'On TikTok, Facebook, YouTube, in your screenshots…',
        'Trên TikTok, Facebook, YouTube, trong ảnh chụp màn hình…',
      ),
      primary: tr(context, 'Bring it together', 'Gom về một chỗ'),
      onPrimary: () => _go(1),
      secondary: TextButton(
        key: const Key('welcome-import'),
        style: TextButton.styleFrom(foregroundColor: GuideColors.tealDeep),
        onPressed: () async {
          await scope.importLinks(context);
          if (mounted && scope.library.bookmarks.isNotEmpty) await _finish();
        },
        child: Text(
          tr(context, 'I have links in another app', 'Tôi có link ở app khác'),
        ),
      ),
    ),
    _Step.gathered => _Page(
      before: tr(context, 'One place for ', 'Một chỗ cho '),
      words: tr(context, 'all of it', 'tất cả'),
      after: '.',
      body: tr(
        context,
        'On your device, in collections. No account, no ads.',
        'Ngay trên máy, xếp theo bộ sưu tập. Không tài khoản, không quảng cáo.',
      ),
      primary: tr(context, 'Show me how', 'Chỉ tôi cách lưu'),
      onPrimary: () => _go(2),
    ),
    _Step.practice => _Page(
      before: practiced
          ? tr(context, 'That is ', 'Chỉ ')
          : tr(context, 'Try saving ', 'Thử lưu '),
      words: practiced
          ? tr(context, 'all it takes', 'vậy thôi')
          : tr(context, 'a video', 'một video'),
      after: '.',
      body: practiced
          ? tr(
              context,
              'In TikTok or Facebook: Share, then More. Recent collections sit in the top row; Handy Bookmark itself saves to Not sorted. Press and hold it to pin it first. Nothing was saved.',
              'Trong TikTok, Facebook: bấm Chia sẻ, rồi Khác. Collection dùng gần đây nằm ở hàng đầu; chọn Handy Bookmark thì vào Chưa xếp. Nhấn giữ nó để ghim lên đầu. Bản tập, chưa lưu gì.',
            )
          : tr(
              context,
              'Tap what is lit on the phone. It is practice; nothing is saved.',
              'Bấm vào chỗ đang sáng trên điện thoại. Đây là bản tập, không lưu gì thật.',
            ),
      primary: practiced ? tr(context, 'Next', 'Tiếp') : null,
      onPrimary: () => _go(3),
    ),
    _Step.find => _Page(
      before: tr(context, 'Find it ', 'Tìm lại '),
      words: tr(context, 'in a moment', 'trong tích tắc'),
      after: '.',
      body: tr(
        context,
        'Type a few letters, accents optional. Tap the result to open the original video.',
        'Gõ vài chữ, không dấu cũng được. Chạm kết quả là mở đúng video gốc.',
      ),
      primary: at == steps.length - 1
          ? tr(context, 'Start saving', 'Bắt đầu lưu')
          : tr(context, 'Next', 'Tiếp'),
      onPrimary: _next,
    ),
    _Step.nudge => _Page(
      before: tr(context, 'A gentle ', 'Nhắc nhẹ '),
      words: tr(context, 'weekly nudge', 'mỗi tuần'),
      after: '?',
      body: tr(
        context,
        'Only when something new is waiting unread. It says how many, never which.',
        'Chỉ khi có món mới lưu mà chưa xem. Thông báo chỉ ghi số lượng, không ghi tiêu đề.',
      ),
      primary: tr(context, 'Turn on the nudge', 'Bật nhắc'),
      onPrimary: _turnOnNudge,
      secondary: TextButton(
        key: const Key('welcome-later'),
        style: TextButton.styleFrom(foregroundColor: GuideColors.tealDeep),
        onPressed: _finish,
        child: Text(tr(context, 'Not now', 'Để sau')),
      ),
    ),
  };

  /// The step's picture. [full]: a phone's whole screen, real size, with
  /// [top] left clear for the bar.
  Widget _scene({bool full = false, double top = 48}) => switch (step) {
    _Step.scattered || _Step.gathered => StoryScene(
      key: const ValueKey('story'),
      gathered: step == _Step.gathered,
    ),
    _Step.practice => Rehearsal(
      key: const ValueKey('practice'),
      framed: !full,
      top: full ? top : 44,
      onStage: (s, _) {
        if (s == PracticeStage.saved) {
          setState(() => practiced = true);
          _play();
        }
      },
    ),
    _Step.find => FindScene(
      key: const ValueKey('find'),
      bare: full,
      top: full ? top + 8 : 48,
    ),
    _Step.nudge => NudgeScene(
      key: const ValueKey('nudge'),
      bare: full,
      top: full ? top : 48,
    ),
  };

  Widget _bar(BuildContext context, {bool light = false}) {
    final ink = light ? Colors.white : GuideColors.ink;
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
                    color: ink,
                    onPressed: _back,
                    icon: const Icon(Icons.arrow_back),
                  ),
          ),
          Expanded(
            child: Semantics(
              label: tr(
                context,
                'Step ${at + 1} of ${steps.length}',
                'Bước ${at + 1} trên ${steps.length}',
              ),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 0; i < steps.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: AnimatedContainer(
                          duration: HandyMotion.of(context, HandyMotion.long),
                          height: 5,
                          decoration: BoxDecoration(
                            color: i <= at
                                ? (light
                                      ? const Color(0xFF7FE3F5)
                                      : GuideColors.teal)
                                : (light
                                      ? const Color(0x59FFFFFF)
                                      : const Color(0xFFE2E4E6)),
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
            style: TextButton.styleFrom(foregroundColor: ink),
            onPressed: _finish,
            child: Text(tr(context, 'Skip', 'Bỏ qua')),
          ),
        ],
      ),
    );
  }

  /// The step's title and its one line. [center]: the phone story steps,
  /// where the words head the page above the picture.
  Widget _words(
    BuildContext context,
    _Page p, {
    required bool wide,
    bool center = false,
  }) {
    final align = center ? TextAlign.center : TextAlign.start;
    final title = TextStyle(
      fontFamily: handyFontFamily('Newsreader'),
      fontSize: wide ? 46 : (center ? 36 : 32),
      height: 1.08,
      letterSpacing: -.6,
      fontWeight: FontWeight.w500,
      color: GuideColors.ink,
    );
    return HandySwap(
      child: Column(
        key: ValueKey('words-$at-$practiced'),
        crossAxisAlignment: center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Reveal(
            to: .35,
            child: Highlighted(
              before: p.before,
              words: p.words,
              after: p.after,
              style: title,
              textAlign: align,
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
                color: const Color(0xFF3A3D42),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, _Page p, {required bool wide}) {
    final button = p.primary == null
        ? const SizedBox(height: 56)
        : Reveal(
            from: .6,
            to: .95,
            rise: 10,
            scale: .96,
            child: FilledButton(
              key: Key('welcome-next-$at'),
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
              onPressed: p.onPrimary,
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

  /// On a phone, from the practice on: the step is the whole screen at
  /// real size (so the things to tap are their real size), the bar floats
  /// on top, and the words arrive in a panel from below once the picture
  /// has played (after the save, in the practice).
  Widget _full(BuildContext context, _Page p) {
    final pad = MediaQuery.paddingOf(context);
    const barHeight = 56.0;
    final dark = step == _Step.nudge || (step == _Step.practice && !practiced);
    final panel = step != _Step.practice || practiced;
    final from = switch (step) {
      _Step.find => .72,
      _Step.nudge => .55,
      _ => 0.0,
    };
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: ColoredBox(
        color: step == _Step.find ? GuideColors.paper : Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _scene(full: true, top: pad.top + barHeight),
            if (dark)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: pad.top + barHeight + 32,
                child: const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x99000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: pad.top,
              left: pad.left,
              right: pad.right,
              child: _bar(context, light: dark),
            ),
            if (panel)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Reveal(
                  from: from,
                  to: from + .25,
                  rise: 80,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .62,
                    ),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: GuideColors.paper,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x40000000),
                            blurRadius: 30,
                            offset: Offset(0, -6),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          20 + pad.left,
                          24,
                          20 + pad.right,
                          16 + pad.bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _words(context, p, wide: false),
                            const SizedBox(height: 18),
                            _actions(context, p, wide: false),
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

  /// Phones, the two story steps: a short title and one line at the top,
  /// the picture as large as the screen allows, the button at the foot.
  /// With little height or large text the page scrolls instead.
  Widget _narrow(BuildContext context, _Page p) => LayoutBuilder(
    builder: (context, box) {
      final words = Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: _words(context, p, wide: false, center: true),
      );
      Widget scene(double? height) => SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: _scene(),
        ),
      );
      final actions = Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: _actions(context, p, wide: false),
      );
      final roomy =
          box.maxHeight >= 600 &&
          MediaQuery.textScalerOf(context).scale(16) <= 16 * 1.3;
      if (roomy) {
        return Column(
          children: [
            _bar(context),
            words,
            Expanded(child: scene(null)),
            actions,
          ],
        );
      }
      return SingleChildScrollView(
        child: Column(
          children: [
            _bar(context),
            words,
            scene((box.maxHeight * .52).clamp(220.0, 560.0)),
            actions,
          ],
        ),
      );
    },
  );

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
                  Expanded(flex: 6, child: _scene()),
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
  const _Page({
    required this.before,
    required this.words,
    required this.after,
    required this.body,
    required this.primary,
    required this.onPrimary,
    this.secondary,
  });
  bool get ready => primary != null;
}
