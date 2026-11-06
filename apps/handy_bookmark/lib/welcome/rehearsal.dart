import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import 'motion.dart';
import 'samples.dart';

enum PracticeStage { video, share, save, saved }

/// A practice save: a video, the system's share row, Handy Bookmark's save
/// sheet, a collection, Save. Everything is dark except the one thing to
/// tap, which sits in a lit window with a word beside it. Nothing is
/// written anywhere.
///
/// [framed] draws it inside a pretend phone (wide screens). Unframed it
/// fills the screen at real size, as on a phone, with [top] left clear for
/// the guide's own bar.
class Rehearsal extends StatefulWidget {
  final ValueChanged<PracticeStage> onStage;
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
  bool picked = false;
  final share = GlobalKey(), app = GlobalKey(), food = GlobalKey();
  final save = GlobalKey();

  void _go(PracticeStage next) {
    if (moves(context)) HapticFeedback.selectionClick();
    setState(() => stage = next);
    widget.onStage(next);
  }

  /// What to tap now, what to call it, and how round its window is.
  /// The last value says where the word goes (below or above the window),
  /// so it never covers what it points at or the words that explain it.
  (GlobalKey?, String?, double, bool?) _focus(BuildContext context) =>
      switch (stage) {
        PracticeStage.video => (
          share,
          tr(context, 'Tap Share', 'Bấm Chia sẻ'),
          18,
          false,
        ),
        PracticeStage.share => (
          app,
          tr(context, 'Tap Handy Bookmark', 'Chọn Handy Bookmark'),
          18,
          true,
        ),
        PracticeStage.save when !picked => (
          food,
          tr(context, 'Put it in Good food', 'Xếp vào Món ngon'),
          12,
          true,
        ),
        PracticeStage.save => (
          save,
          tr(context, 'Now tap Save', 'Giờ bấm Lưu'),
          14,
          false,
        ),
        PracticeStage.saved => (null, null, 14, null),
      };

  @override
  Widget build(BuildContext context) {
    final time = moves(context)
        ? const Duration(milliseconds: 360)
        : Duration.zero;
    final (target, label, radius, below) = _focus(context);
    final screen = LayoutBuilder(
      builder: (context, box) => Stack(
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
                  show: stage == PracticeStage.share,
                  time: time,
                  child: _ShareSheet(appKey: app, onPick: _picked),
                ),
                _SlideUp(
                  show: stage == PracticeStage.save,
                  time: time,
                  child: _SaveSheet(
                    height: widget.framed
                        ? 520
                        : math.min(box.maxHeight - widget.top, 600),
                    foodKey: food,
                    saveKey: save,
                    picked: picked,
                    onPick: () => setState(() => picked = true),
                    onSave: () {
                      if (moves(context)) HapticFeedback.mediumImpact();
                      _go(PracticeStage.saved);
                    },
                  ),
                ),
                if (stage == PracticeStage.saved)
                  _Saved(lift: widget.framed ? 0 : .4),
              ],
            ),
          ),
          // The task, lit above the dark.
          Positioned(
            top: widget.top + 8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: stage == PracticeStage.video ? 1 : 0,
                child: Center(
                  child: Coach(
                    tr(
                      context,
                      'Try it: save this video',
                      'Thử nhé: lưu video này',
                    ),
                    icon: Icons.bookmark,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (widget.framed) return PhoneFrame(interactive: true, screen: screen);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: ColoredBox(color: Colors.black, child: screen),
    );
  }

  void _shared() {
    if (stage == PracticeStage.video) _go(PracticeStage.share);
  }

  void _picked() {
    if (stage == PracticeStage.share) _go(PracticeStage.save);
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

/// The system's share row (drawn plainly; every phone's looks different).
class _ShareSheet extends StatelessWidget {
  final GlobalKey appKey;
  final VoidCallback onPick;
  const _ShareSheet({required this.appKey, required this.onPick});
  @override
  Widget build(BuildContext context) {
    Widget target(IconData icon, String label, {bool ours = false}) {
      final face = Column(
        key: ours ? appKey : null,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
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
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: ours ? FontWeight.w700 : FontWeight.w400,
              color: GuideColors.ink,
            ),
          ),
        ],
      );
      return SizedBox(
        width: 68,
        child: ours
            ? Semantics(
                button: true,
                label: 'Handy Bookmark',
                excludeSemantics: true,
                child: GestureDetector(
                  key: const Key('practice-target'),
                  onTap: onPick,
                  behavior: HitTestBehavior.opaque,
                  child: face,
                ),
              )
            : ExcludeSemantics(child: face),
      );
    }

    return _Sheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Preview(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              target(
                Icons.chat_bubble_outline,
                tr(context, 'Messages', 'Tin nhắn'),
              ),
              target(Icons.mail_outline, 'Email'),
              target(Icons.bookmark, 'Handy Bookmark', ours: true),
              target(
                Icons.sticky_note_2_outlined,
                tr(context, 'Notes', 'Ghi chú'),
              ),
            ],
          ),
          // Room for the word under the lit app.
          const SizedBox(height: 64),
          const Divider(height: 1),
          ListTile(
            dense: true,
            title: Text(tr(context, 'Copy link', 'Sao chép link')),
            trailing: const Icon(Icons.copy, size: 18),
          ),
        ],
      ),
    );
  }
}

/// Handy Bookmark's own save sheet: the video, where to put it, Save.
class _SaveSheet extends StatelessWidget {
  final double height;
  final GlobalKey foodKey, saveKey;
  final bool picked;
  final VoidCallback onPick, onSave;
  const _SaveSheet({
    required this.height,
    required this.foodKey,
    required this.saveKey,
    required this.picked,
    required this.onPick,
    required this.onSave,
  });
  @override
  Widget build(BuildContext context) {
    final rows = [
      (
        key: 'inbox',
        label: tr(context, 'Not sorted', 'Chưa xếp'),
        color: GuideColors.muted,
      ),
      (
        key: 'food',
        label: tr(context, 'Good food', 'Món ngon'),
        color: const Color(0xFFD9480F),
      ),
      (
        key: 'trips',
        label: tr(context, 'Trips', 'Du lịch'),
        color: const Color(0xFF2B8A3E),
      ),
      (
        key: 'later',
        label: tr(context, 'Read later', 'Đọc sau'),
        color: const Color(0xFF1971C2),
      ),
    ];
    return _Sheet(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: GuideColors.teal,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bookmark,
                  size: 17,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr(
                    context,
                    'Save to Handy Bookmark',
                    'Lưu vào Handy Bookmark',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: GuideColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Preview(),
          const SizedBox(height: 16),
          Text(
            tr(context, 'Put it in', 'Xếp vào'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: GuideColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _choice(
                      context,
                      key: r.key,
                      label: r.label,
                      color: r.color,
                      selected: r.key == 'food'
                          ? picked
                          : (r.key == 'inbox' && !picked),
                    ),
                  ),
                // Room for the word under the lit collection.
                const SizedBox(height: 56),
              ],
            ),
          ),
          SizedBox(
            key: saveKey,
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('practice-save'),
              style: FilledButton.styleFrom(
                backgroundColor: GuideColors.teal,
                disabledBackgroundColor: const Color(0xFFB9D9E1),
                disabledForegroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: picked ? onSave : null,
              icon: const Icon(Icons.bookmark_added),
              label: Text(tr(context, 'Save', 'Lưu')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _choice(
    BuildContext context, {
    required String key,
    required String label,
    required Color color,
    required bool selected,
  }) {
    final row = AnimatedContainer(
      key: key == 'food' ? foodKey : null,
      duration: const Duration(milliseconds: 200),
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: selected ? GuideColors.tint : const Color(0xFFF6F7F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? GuideColors.teal : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: GuideColors.ink,
              ),
            ),
          ),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? GuideColors.teal : const Color(0xFFB8BCC0),
            size: 22,
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('practice-col-$key'),
        behavior: HitTestBehavior.opaque,
        onTap: key == 'food' ? onPick : null,
        child: row,
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

/// A sheet from the bottom: as tall as [height], or as its content.
class _Sheet extends StatelessWidget {
  final double? height;
  final Widget child;
  const _Sheet({this.height, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: height,
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
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
        if (height == null) child else Expanded(child: child),
      ],
    ),
  );
}

/// The saved moment: a check that lands with a ring around it. [lift]
/// raises it above centre, clear of the panel that follows on a phone.
class _Saved extends StatefulWidget {
  final double lift;
  const _Saved({this.lift = 0});
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
                          'Saved to Good food',
                          'Đã lưu vào Món ngon',
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
                          'Title, picture and source filled in.',
                          'Tiêu đề, ảnh và nguồn đã tự điền.',
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
