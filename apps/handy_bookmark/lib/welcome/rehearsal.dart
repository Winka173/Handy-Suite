import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import 'motion.dart';
import 'samples.dart';

enum PracticeStage { video, apps, share, saved }

/// A practice save, the way it really goes: a video, the app's own share
/// list (where Handy Bookmark is never listed, so: More), then the phone's
/// share sheet, where the person's collections sit in the top row and
/// Handy Bookmark among the apps. Everything is dark except the one thing
/// to tap, in a lit window with a word beside it. Nothing is written.
///
/// [framed] draws it inside a pretend phone (wide screens). Unframed it
/// fills the screen at real size, as on a phone, with [top] left clear for
/// the guide's own bar.
class Rehearsal extends StatefulWidget {
  /// Told each stage; at the end, with the collection it went into.
  final void Function(PracticeStage stage, String? into) onStage;
  final bool framed;
  final double top;
  const Rehearsal({
    super.key,
    required this.onStage,
    this.framed = true,
    this.top = 44,
  });
  @override
  State<Rehearsal> createState() => _RehearsalState();
}

class _RehearsalState extends State<Rehearsal> {
  PracticeStage stage = PracticeStage.video;
  String? into;
  final share = GlobalKey(), more = GlobalKey(), direct = GlobalKey();

  void _go(PracticeStage next) {
    if (moves(context)) {
      next == PracticeStage.saved
          ? HapticFeedback.mediumImpact()
          : HapticFeedback.selectionClick();
    }
    setState(() => stage = next);
    widget.onStage(next, into);
  }

  /// What to tap now, what to call it, how round its window is, and where
  /// the word goes (below or above), so it never covers what it explains.
  (GlobalKey?, String?, double, bool?) _focus(BuildContext context) =>
      switch (stage) {
        PracticeStage.video => (
          share,
          tr(context, 'Tap Share', 'Bấm Chia sẻ'),
          18,
          false,
        ),
        PracticeStage.apps => (
          more,
          tr(context, 'Not here? Tap More', 'Không thấy? Bấm Khác'),
          30,
          false,
        ),
        PracticeStage.share => (
          direct,
          tr(context, 'Tap Good food: straight in', 'Bấm Món ngon: vào thẳng'),
          18,
          false,
        ),
        PracticeStage.saved => (null, null, 14, null),
      };

  /// The line at the top: what is on screen and why.
  String? _task(BuildContext context) => switch (stage) {
    PracticeStage.video => tr(
      context,
      'Try it: save this video',
      'Thử nhé: lưu video này',
    ),
    PracticeStage.apps => tr(
      context,
      'TikTok shows its own list first',
      'TikTok hiện danh sách riêng trước',
    ),
    PracticeStage.share => tr(
      context,
      'Now your phone’s share list',
      'Đây là danh sách chia sẻ của máy',
    ),
    PracticeStage.saved => null,
  };

  @override
  Widget build(BuildContext context) {
    final time = moves(context)
        ? const Duration(milliseconds: 360)
        : Duration.zero;
    final (target, label, radius, below) = _focus(context);
    final task = _task(context);
    final screen = Stack(
      fit: StackFit.expand,
      children: [
        Spotlight(
          target: target,
          label: label,
          radius: radius,
          labelBelow: below,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Video(shareKey: share, onShare: _shared),
              _SlideUp(
                show: stage == PracticeStage.apps,
                time: time,
                child: _AppsSheet(moreKey: more, onMore: _more),
              ),
              _SlideUp(
                show: stage == PracticeStage.share,
                time: time,
                child: _ShareSheet(
                  directKey: direct,
                  onPick: (String? collection) => _saved(collection),
                ),
              ),
              if (stage == PracticeStage.saved)
                _Saved(
                  into: into ?? tr(context, 'Not sorted', 'Chưa xếp'),
                  lift: widget.framed ? 0 : .6,
                ),
            ],
          ),
        ),
        // The task, lit above the dark.
        Positioned(
          top: widget.top + 8,
          left: 12,
          right: 12,
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: task == null ? 0 : 1,
              child: Center(
                child: HandySwap(
                  child: Coach(
                    key: ValueKey(stage),
                    task ?? '',
                    icon: Icons.bookmark,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    if (widget.framed) return PhoneFrame(interactive: true, screen: screen);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: ColoredBox(color: Colors.black, child: screen),
    );
  }

  void _shared() {
    if (stage == PracticeStage.video) _go(PracticeStage.apps);
  }

  void _more() {
    if (stage == PracticeStage.apps) _go(PracticeStage.share);
  }

  void _saved(String? collection) {
    if (stage != PracticeStage.share) return;
    into = collection;
    _go(PracticeStage.saved);
  }
}

class _SlideUp extends StatelessWidget {
  final bool show;
  final Duration time;
  final Widget child;
  const _SlideUp({required this.show, required this.time, required this.child});
  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !show,
    child: AnimatedSlide(
      duration: time,
      curve: show ? Curves.easeOutCubic : Curves.easeInCubic,
      offset: show ? Offset.zero : const Offset(0, 1.05),
      child: Align(alignment: Alignment.bottomCenter, child: child),
    ),
  );
}

/// The video being watched, with the app's usual buttons down the side.
class _Video extends StatelessWidget {
  final GlobalKey shareKey;
  final VoidCallback onShare;
  const _Video({required this.shareKey, required this.onShare});
  @override
  Widget build(BuildContext context) {
    Widget side(IconData icon, String label) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 30),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(pho.asset, fit: BoxFit.cover),
        // A scrim under the words so they read on any picture.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0x00000000), Color(0xB3000000)],
              stops: [0, .5, 1],
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 90,
          bottom: 40 + MediaQuery.paddingOf(context).bottom,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '@bepnha',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                pho.title(context),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tr(
                  context,
                  '6 ingredients · 20 minutes',
                  '6 nguyên liệu · 20 phút',
                ),
                style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 13),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 36 + MediaQuery.paddingOf(context).bottom,
          child: Column(
            children: [
              side(Icons.favorite, '12k'),
              const SizedBox(height: 18),
              side(Icons.chat_bubble, '348'),
              const SizedBox(height: 18),
              Semantics(
                button: true,
                label: tr(context, 'Share', 'Chia sẻ'),
                excludeSemantics: true,
                child: GestureDetector(
                  key: const Key('practice-share'),
                  onTap: onShare,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    key: shareKey,
                    padding: const EdgeInsets.all(8),
                    child: side(Icons.reply, tr(context, 'Share', 'Chia sẻ')),
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

/// A round or rounded tile with a word under it, as share lists draw them.
Widget _tile({
  Key? key,
  required Widget face,
  required String label,
  bool strong = false,
}) => SizedBox(
  width: 64,
  child: Column(
    key: key,
    mainAxisSize: MainAxisSize.min,
    children: [
      face,
      const SizedBox(height: 6),
      Text(
        label,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          height: 1.2,
          fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
          color: GuideColors.ink,
        ),
      ),
    ],
  ),
);

Widget _circle(Widget child, {Color color = const Color(0xFFEFF1F2)}) =>
    Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: child,
    );

/// The video app's own share list, drawn plainly (each app's differs):
/// friends, then a few of its chosen apps. Handy Bookmark is not among
/// them, as in the real ones; More opens the phone's list.
class _AppsSheet extends StatelessWidget {
  final GlobalKey moreKey;
  final VoidCallback onMore;
  const _AppsSheet({required this.moreKey, required this.onMore});
  @override
  Widget build(BuildContext context) {
    Widget friend(String name, Color color) => ExcludeSemantics(
      child: _tile(
        face: _circle(
          Text(
            name.substring(0, 1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          color: color,
        ),
        label: name,
      ),
    );
    Widget action(IconData icon, String label) => ExcludeSemantics(
      child: _tile(
        face: _circle(Icon(icon, color: GuideColors.ink, size: 24)),
        label: label,
      ),
    );
    return _Sheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr(context, 'Send to', 'Gửi đến'),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: GuideColors.ink,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              friend('Lan', const Color(0xFFB5838D)),
              friend('Minh', const Color(0xFF6D8A96)),
              friend('Hà', const Color(0xFF9C8F5F)),
              friend('Tú', const Color(0xFF7A8F6E)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              action(Icons.link, tr(context, 'Copy link', 'Sao chép link')),
              action(
                Icons.chat_bubble_outline,
                tr(context, 'Message', 'Tin nhắn'),
              ),
              action(Icons.download, tr(context, 'Save video', 'Lưu video')),
              Semantics(
                button: true,
                label: tr(context, 'More', 'Khác'),
                excludeSemantics: true,
                child: GestureDetector(
                  key: const Key('practice-more'),
                  onTap: onMore,
                  behavior: HitTestBehavior.opaque,
                  child: _tile(
                    key: moreKey,
                    face: _circle(
                      const Icon(
                        Icons.more_horiz,
                        color: GuideColors.ink,
                        size: 26,
                      ),
                    ),
                    label: tr(context, 'More', 'Khác'),
                    strong: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// The phone's own share sheet (drawn plainly; every phone's looks
/// different): the top row holds direct targets, among them the person's
/// collections that Handy Bookmark offers there; the apps follow.
class _ShareSheet extends StatelessWidget {
  final GlobalKey directKey;
  final ValueChanged<String?> onPick;
  const _ShareSheet({required this.directKey, required this.onPick});
  @override
  Widget build(BuildContext context) {
    final food = tr(context, 'Good food', 'Món ngon');
    final trips = tr(context, 'Trips', 'Du lịch');
    // A collection as the system shows it: its colour and initial, with
    // the app's small badge.
    Widget collection(String name, Color color, {Key? key, GlobalKey? at}) {
      final tile = _tile(
        key: at,
        face: Stack(
          clipBehavior: Clip.none,
          children: [
            _circle(
              Text(
                name.substring(0, 1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              color: color,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: GuideColors.teal,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.bookmark,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        label: name,
        strong: at != null,
      );
      return Semantics(
        button: true,
        label: '$name, Handy Bookmark',
        excludeSemantics: true,
        child: GestureDetector(
          key: key,
          onTap: () => onPick(name),
          behavior: HitTestBehavior.opaque,
          child: tile,
        ),
      );
    }

    Widget app(IconData icon, String label, {bool ours = false}) {
      final tile = _tile(
        face: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: ours ? GuideColors.teal : const Color(0xFFEFF1F2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            icon,
            color: ours ? Colors.white : GuideColors.muted,
            size: 26,
          ),
        ),
        label: label,
        strong: ours,
      );
      if (!ours) return ExcludeSemantics(child: tile);
      return Semantics(
        button: true,
        label: 'Handy Bookmark',
        excludeSemantics: true,
        child: GestureDetector(
          key: const Key('practice-target'),
          // The app itself saves to Not sorted.
          onTap: () => onPick(null),
          behavior: HitTestBehavior.opaque,
          child: tile,
        ),
      );
    }

    final friend = ExcludeSemantics(
      child: _tile(
        face: _circle(
          const Text(
            'L',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          color: const Color(0xFFB5838D),
        ),
        label: 'Lan',
      ),
    );

    return _Sheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Preview(),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              collection(
                food,
                const Color(0xFFD9480F),
                key: const Key('practice-direct'),
                at: directKey,
              ),
              collection(trips, const Color(0xFF2B8A3E)),
              friend,
              const SizedBox(width: 64),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              app(
                Icons.chat_bubble_outline,
                tr(context, 'Messages', 'Tin nhắn'),
              ),
              app(Icons.mail_outline, 'Email'),
              app(Icons.bookmark, 'Handy Bookmark', ours: true),
              app(
                Icons.sticky_note_2_outlined,
                tr(context, 'Notes', 'Ghi chú'),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(pho.asset, width: 64, height: 64, fit: BoxFit.cover),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pho.title(context),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: GuideColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                SourcePill(pho),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'tiktok.com',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: GuideColors.muted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

/// A sheet from the bottom, as tall as its content, clear of the phone's
/// own navigation bar.
class _Sheet extends StatelessWidget {
  final Widget child;
  const _Sheet({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(
      18,
      10,
      18,
      22 + MediaQuery.paddingOf(context).bottom,
    ),
    decoration: const BoxDecoration(
      color: GuideColors.card,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFD5D8DB),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

/// The saved moment: a check that lands with a ring around it. [lift]
/// raises it above centre, clear of the panel that follows on a phone.
class _Saved extends StatefulWidget {
  final String into;
  final double lift;
  const _Saved({required this.into, this.lift = 0});
  @override
  State<_Saved> createState() => _SavedState();
}

class _SavedState extends State<_Saved> with SingleTickerProviderStateMixin {
  late final AnimationController run = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (run.value == 0 && !run.isAnimating) {
      moves(context) ? run.forward() : run.value = 1;
    }
  }

  @override
  void dispose() {
    run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xF2FFFFFF),
    child: Align(
      alignment: Alignment(0, -widget.lift),
      child: AnimatedBuilder(
        animation: run,
        builder: (context, _) {
          final pop = Curves.elasticOut.transform(
            (run.value / .7).clamp(0.0, 1.0),
          );
          final ring = Curves.easeOut.transform(
            (run.value / .8).clamp(0.0, 1.0),
          );
          final words = Curves.easeOut.transform(
            ((run.value - .35) / .5).clamp(0.0, 1.0),
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 96 + 60 * ring,
                      height: 96 + 60 * ring,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: GuideColors.teal.withValues(
                            alpha: (1 - ring) * .5,
                          ),
                          width: 3,
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: pop,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          color: GuideColors.teal,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 58,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Opacity(
                opacity: words,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - words)),
                  child: Column(
                    children: [
                      Text(
                        tr(
                          context,
                          'Saved to ${widget.into}',
                          'Đã lưu vào ${widget.into}',
                        ),
                        style: TextStyle(
                          fontFamily: handyFontFamily('Newsreader'),
                          fontSize: 26,
                          fontWeight: FontWeight.w500,
                          color: GuideColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr(
                          context,
                          'From the share list, in one tap.',
                          'Từ danh sách chia sẻ, chỉ một chạm.',
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: GuideColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
