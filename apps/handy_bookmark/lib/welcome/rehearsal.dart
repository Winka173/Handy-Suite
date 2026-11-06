import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import 'motion.dart';
import 'samples.dart';

enum PracticeStage { video, share, save, saved }

/// A practice save on a pretend phone: a video, the system's share row,
/// Handy Bookmark's save sheet, a collection, Save. One thing glows at a
/// time, with a word next to it. Nothing is written anywhere.
class Rehearsal extends StatefulWidget {
  final ValueChanged<PracticeStage> onStage;
  const Rehearsal({super.key, required this.onStage});
  @override
  State<Rehearsal> createState() => _RehearsalState();
}

class _RehearsalState extends State<Rehearsal> {
  PracticeStage stage = PracticeStage.video;
  bool picked = false;

  void _go(PracticeStage next) {
    if (moves(context)) HapticFeedback.selectionClick();
    setState(() => stage = next);
    widget.onStage(next);
  }

  @override
  Widget build(BuildContext context) {
    final time = moves(context)
        ? const Duration(milliseconds: 360)
        : Duration.zero;
    return PhoneFrame(
      interactive: true,
      screen: Stack(
        fit: StackFit.expand,
        children: [
          _Video(
            active: stage == PracticeStage.video,
            onShare: () => _go(PracticeStage.share),
          ),
          // Dim behind any sheet.
          IgnorePointer(
            child: AnimatedContainer(
              duration: time,
              color: stage == PracticeStage.video
                  ? const Color(0x00000000)
                  : const Color(0x8C000000),
            ),
          ),
          _SlideUp(
            show: stage == PracticeStage.share,
            time: time,
            child: _ShareSheet(onPick: () => _go(PracticeStage.save)),
          ),
          _SlideUp(
            show: stage == PracticeStage.save,
            time: time,
            child: _SaveSheet(
              picked: picked,
              onPick: () => setState(() => picked = true),
              onSave: () {
                if (moves(context)) HapticFeedback.mediumImpact();
                _go(PracticeStage.saved);
              },
            ),
          ),
          if (stage == PracticeStage.saved) const _Saved(),
        ],
      ),
    );
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
  final bool active;
  final VoidCallback onShare;
  const _Video({required this.active, required this.onShare});
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
          top: 44,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: active ? 1 : 0,
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
        Positioned(
          left: 16,
          right: 90,
          bottom: 28,
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
          right: 14,
          bottom: 28,
          child: Column(
            children: [
              side(Icons.favorite, '12k'),
              const SizedBox(height: 18),
              side(Icons.chat_bubble, '348'),
              // Room for the "Tap Share" word above the button.
              const SizedBox(height: 52),
              Semantics(
                button: true,
                label: tr(context, 'Share', 'Chia sẻ'),
                child: GestureDetector(
                  key: const Key('practice-share'),
                  onTap: active ? onShare : null,
                  behavior: HitTestBehavior.opaque,
                  child: Pulse(
                    on: active,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: side(Icons.reply, tr(context, 'Share', 'Chia sẻ')),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (active)
          Positioned(
            right: 8,
            bottom: 104,
            child: Coach(
              tr(context, 'Tap Share', 'Bấm Chia sẻ'),
              icon: Icons.arrow_downward,
            ),
          ),
      ],
    );
  }
}

/// The system's share row (drawn plainly; every phone's looks different).
class _ShareSheet extends StatelessWidget {
  final VoidCallback onPick;
  const _ShareSheet({required this.onPick});
  @override
  Widget build(BuildContext context) {
    Widget target(IconData icon, String label, {bool ours = false}) {
      final face = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
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
        width: 64,
        child: ours
            ? Semantics(
                button: true,
                label: 'Handy Bookmark',
                child: GestureDetector(
                  key: const Key('practice-target'),
                  onTap: onPick,
                  behavior: HitTestBehavior.opaque,
                  child: Pulse(radius: 16, child: face),
                ),
              )
            : ExcludeSemantics(child: face),
      );
    }

    return _Sheet(
      height: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Preview(),
          const SizedBox(height: 18),
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
          const SizedBox(height: 14),
          Center(
            child: Coach(
              tr(context, 'Pick Handy Bookmark', 'Chọn Handy Bookmark'),
              icon: Icons.arrow_upward,
            ),
          ),
          const SizedBox(height: 14),
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
  final bool picked;
  final VoidCallback onPick, onSave;
  const _SaveSheet({
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
      height: 520,
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
                      glow: r.key == 'food' && !picked,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: Pulse(
              on: picked,
              radius: 14,
              child: FilledButton.icon(
                key: const Key('practice-save'),
                style: FilledButton.styleFrom(
                  backgroundColor: GuideColors.teal,
                  disabledBackgroundColor: const Color(0xFFB9D9E1),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: picked ? onSave : null,
                icon: const Icon(Icons.bookmark_added),
                label: Text(tr(context, 'Save', 'Lưu')),
              ),
            ),
          ),
          if (picked) ...[
            const SizedBox(height: 8),
            Center(
              child: Coach(
                tr(context, 'Now tap Save', 'Giờ bấm Lưu'),
                icon: Icons.arrow_upward,
              ),
            ),
          ],
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
    required bool glow,
  }) {
    final row = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: GuideColors.ink,
              ),
            ),
          ),
          if (glow) Coach(tr(context, 'Pick this', 'Chọn mục này')),
          if (selected)
            const Icon(Icons.check_circle, color: GuideColors.teal, size: 20),
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
        child: Pulse(on: glow, radius: 12, child: row),
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
                const Text(
                  'tiktok.com',
                  style: TextStyle(fontSize: 12, color: GuideColors.muted),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class _Sheet extends StatelessWidget {
  final double height;
  final Widget child;
  const _Sheet({required this.height, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: 360,
    height: height,
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
    decoration: const BoxDecoration(
      color: GuideColors.card,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Column(
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
        Expanded(child: child),
      ],
    ),
  );
}

/// The saved moment: a check that lands with a ring around it.
class _Saved extends StatefulWidget {
  const _Saved();
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
    child: AnimatedBuilder(
      animation: run,
      builder: (context, _) {
        final pop = Curves.elasticOut.transform(
          (run.value / .7).clamp(0.0, 1.0),
        );
        final ring = Curves.easeOut.transform((run.value / .8).clamp(0.0, 1.0));
        final words = Curves.easeOut.transform(
          ((run.value - .35) / .5).clamp(0.0, 1.0),
        );
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
                      tr(context, 'Saved to Good food', 'Đã lưu vào Món ngon'),
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
  );
}
