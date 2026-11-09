import 'package:flutter/services.dart';
import 'package:handy_ui/kit.dart';
import 'motion.dart';
import 'samples.dart';
import '../ui/app_mark.dart';

enum PracticeStage { video, apps, share, found, pick, saved }

/// A practice save, the way it really goes: a video, the app's own share
/// list (where Handy Bookmark is never listed, so: More), then the phone's
/// share sheet, where the person's collections sit in the top row and
/// Handy Bookmark sits further along the apps, found by swiping the row.
/// Then Handy Bookmark's own sheet, as the real one: saved already, one tap
/// on a collection puts it there. Everything is dark except the one thing
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

  /// The collection it arrived in (its top-row shortcut), or null.
  String? from;
  final share = GlobalKey(), more = GlobalKey(), direct = GlobalKey();
  final appsRow = GlobalKey(), ours = GlobalKey();
  final firstPlace = GlobalKey(), close = GlobalKey();

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
        // As on a real phone: the app is further along, past the edge.
        PracticeStage.share => (
          appsRow,
          tr(
            context,
            'Swipe to find Handy Bookmark',
            'Vuốt sang để tìm Handy Bookmark',
          ),
          18,
          false,
        ),
        PracticeStage.found => (
          ours,
          tr(context, 'Tap Handy Bookmark', 'Bấm Handy Bookmark'),
          18,
          false,
        ),
        // Handy Bookmark's sheet: one tap on a collection files it; one
        // that came through a collection is there already.
        PracticeStage.pick when from == null => (
          firstPlace,
          tr(context, 'Tap a collection', 'Chạm một bộ sưu tập'),
          16,
          false,
        ),
        PracticeStage.pick => (
          close,
          tr(context, 'Already in $from. Tap ✕', 'Đã ở $from. Bấm ✕'),
          24,
          true,
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
    PracticeStage.share || PracticeStage.found => tr(
      context,
      'Now your phone’s share list',
      'Đây là danh sách chia sẻ của máy',
    ),
    PracticeStage.pick => tr(
      context,
      'Saved already. Now where?',
      'Đã lưu rồi. Cho vào đâu?',
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
                show:
                    stage == PracticeStage.share ||
                    stage == PracticeStage.found,
                time: time,
                child: _ShareSheet(
                  directKey: direct,
                  rowKey: appsRow,
                  oursKey: ours,
                  hint: stage == PracticeStage.share,
                  onFound: _found,
                  // The lit window keeps up with the app as the row moves.
                  onScroll: () {
                    if (stage == PracticeStage.found) setState(() {});
                  },
                  onPick: _open,
                ),
              ),
              _SlideUp(
                show: stage == PracticeStage.pick,
                time: time,
                child: _OurSheet(
                  from: from,
                  firstKey: firstPlace,
                  closeKey: close,
                  onPut: _put,
                  onClose: () => _put(from),
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

  void _found() {
    if (stage == PracticeStage.share) _go(PracticeStage.found);
  }

  /// Shared to the app (or one of its collections): its sheet opens.
  void _open(String? collection) {
    if (stage != PracticeStage.share && stage != PracticeStage.found) return;
    from = collection;
    _go(PracticeStage.pick);
  }

  void _put(String? collection) {
    if (stage != PracticeStage.pick) return;
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
/// The phone's own share sheet: what is shared, the person's collections
/// and people in the top row, then the apps in a row that scrolls
/// sideways, where Handy Bookmark sits past the edge. While [hint], the
/// row nudges once to show it moves; [onFound] fires when the app is in
/// full view.
class _ShareSheet extends StatefulWidget {
  final GlobalKey directKey, rowKey, oursKey;
  final bool hint;
  final VoidCallback onFound, onScroll;
  final ValueChanged<String?> onPick;
  const _ShareSheet({
    required this.directKey,
    required this.rowKey,
    required this.oursKey,
    required this.hint,
    required this.onFound,
    required this.onScroll,
    required this.onPick,
  });
  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final row = ScrollController();
  bool _nudged = false;

  @override
  void didUpdateWidget(_ShareSheet old) {
    super.didUpdateWidget(old);
    if (widget.hint && !old.hint) _nudge();
  }

  @override
  void dispose() {
    row.dispose();
    super.dispose();
  }

  /// Once, after the sheet has risen: the row slides a little and back.
  Future<void> _nudge() async {
    if (_nudged || !moves(context)) return;
    _nudged = true;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted || !row.hasClients || !widget.hint) return;
    await row.animateTo(
      56,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
    if (!mounted || !row.hasClients || !widget.hint) return;
    await row.animateTo(
      0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  /// Whether Handy Bookmark is wholly inside the row's view.
  void _check() {
    widget.onScroll();
    final tile = widget.oursKey.currentContext?.findRenderObject();
    final view = widget.rowKey.currentContext?.findRenderObject();
    if (tile is! RenderBox || view is! RenderBox) return;
    if (!tile.hasSize || !view.hasSize) return;
    final at = tile.localToGlobal(Offset.zero, ancestor: view);
    if (at.dx >= -1 && at.dx + tile.size.width <= view.size.width + 1) {
      widget.onFound();
    }
  }

  @override
  Widget build(BuildContext context) {
    final food = tr(context, 'Good food', 'Món ngon');
    final trips = tr(context, 'Trips', 'Du lịch');
    // A collection as the system shows it (ShareTargets.kt): its initial
    // in its colour on a pale tint of it, with the app's small badge.
    Widget collection(String name, Color color, {Key? key, GlobalKey? at}) {
      final tile = _tile(
        key: at,
        face: Stack(
          clipBehavior: Clip.none,
          children: [
            _circle(
              Text(
                name.substring(0, 1),
                style: TextStyle(
                  color: Color.lerp(color, Colors.black, .22),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              color: Color.lerp(color, Colors.white, .84)!,
            ),
            const Positioned(
              right: -2,
              bottom: -2,
              child: AppMark(size: 22, radius: 6, ring: Colors.white),
            ),
          ],
        ),
        label: name,
      );
      return Semantics(
        button: true,
        label: '$name, Handy Bookmark',
        excludeSemantics: true,
        child: GestureDetector(
          key: key,
          onTap: () => widget.onPick(name),
          behavior: HitTestBehavior.opaque,
          child: tile,
        ),
      );
    }

    Widget app(IconData icon, String label, {bool ours = false}) {
      final tile = _tile(
        key: ours ? widget.oursKey : null,
        face: ours
            ? const AppMark(size: 56, radius: 16)
            : Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF1F2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: GuideColors.muted, size: 26),
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
          onTap: () => widget.onPick(null),
          behavior: HitTestBehavior.opaque,
          child: tile,
        ),
      );
    }

    Widget person(String initial, String name, Color color) => ExcludeSemantics(
      child: _tile(
        face: _circle(
          Text(
            initial,
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

    // The phone's usual apps first, as on a real phone; Handy Bookmark is
    // the eighth, past the edge of any phone screen.
    final apps = [
      app(Icons.chat_bubble_outline, tr(context, 'Messages', 'Tin nhắn')),
      app(Icons.mail_outline, 'Email'),
      app(Icons.sticky_note_2_outlined, tr(context, 'Notes', 'Ghi chú')),
      app(Icons.share_outlined, tr(context, 'Nearby', 'Gần đây')),
      app(Icons.bluetooth, 'Bluetooth'),
      app(Icons.print_outlined, tr(context, 'Print', 'In')),
      app(Icons.folder_outlined, tr(context, 'Files', 'Tệp')),
      app(Icons.bookmark, 'Handy Bookmark', ours: true),
      app(Icons.calendar_today_outlined, tr(context, 'Calendar', 'Lịch')),
      app(Icons.copy_rounded, tr(context, 'Copy', 'Sao chép')),
    ];

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
                at: widget.directKey,
              ),
              collection(trips, const Color(0xFF2B8A3E)),
              person('L', 'Lan', const Color(0xFFB5838D)),
              person('M', 'Minh', const Color(0xFF5C7C99)),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          NotificationListener<ScrollNotification>(
            onNotification: (_) {
              _check();
              return false;
            },
            child: SingleChildScrollView(
              key: widget.rowKey,
              controller: row,
              scrollDirection: Axis.horizontal,
              child: Row(
                key: const Key('practice-apps'),
                children: [
                  for (final (i, a) in apps.indexed) ...[
                    if (i > 0) const SizedBox(width: 18),
                    a,
                  ],
                ],
              ),
            ),
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

/// Handy Bookmark's own sheet (lib/share_sheet), drawn for the practice:
/// saved already, what it is, and the collections to tap. The one it is in
/// is not listed; one that came through a collection can come back out.
class _OurSheet extends StatelessWidget {
  final String? from;
  final GlobalKey firstKey, closeKey;
  final ValueChanged<String?> onPut;
  final VoidCallback onClose;
  const _OurSheet({
    required this.from,
    required this.firstKey,
    required this.closeKey,
    required this.onPut,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final places = [
      (
        tr(context, 'Good food', 'Món ngon'),
        const Color(0xFFD9480F),
        Icons.restaurant,
        8,
        'food',
      ),
      (
        tr(context, 'Trips', 'Du lịch'),
        const Color(0xFF2B8A3E),
        Icons.luggage_outlined,
        5,
        'trips',
      ),
      (
        tr(context, 'Read later', 'Đọc sau'),
        const Color(0xFF5C7C99),
        Icons.menu_book_outlined,
        3,
        'read',
      ),
    ];
    final here = from ?? tr(context, 'Not sorted', 'Chưa xếp');
    var first = true;
    Widget row(
      String name,
      Widget leading,
      String note, {
      required String? to,
      required String id,
    }) {
      final key = first ? firstKey : null;
      first = false;
      return Semantics(
        button: true,
        label: name,
        excludeSemantics: true,
        child: GestureDetector(
          key: Key('practice-pick-$id'),
          onTap: () => onPut(to),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            key: key,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          color: GuideColors.ink,
                        ),
                      ),
                      Text(
                        note,
                        style: const TextStyle(
                          fontSize: 12,
                          color: GuideColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget badge(Color color, IconData icon) => Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Color.lerp(color, Colors.white, .84),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: GuideColors.ink),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        18,
        14,
        8,
        14 + MediaQuery.paddingOf(context).bottom,
      ),
      constraints: BoxConstraints(
        // Like the real sheet: never taller than the screen; it scrolls.
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      decoration: const BoxDecoration(
        color: GuideColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          key: const Key('practice-our-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppMark(size: 36, radius: 9),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Handy Bookmark',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: GuideColors.ink,
                        ),
                      ),
                      Text(
                        tr(context, 'Saved in $here', 'Đã lưu vào $here'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: GuideColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: tr(context, 'Close', 'Đóng'),
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: const Key('practice-close'),
                    onTap: from == null ? null : onClose,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox.square(
                      key: closeKey,
                      dimension: 44,
                      child: const Icon(Icons.close, color: GuideColors.ink),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF1F4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE1E5E9)),
                ),
                child: _Preview(),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(
                        context,
                        'Put it in a collection',
                        'Cho vào bộ sưu tập',
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: GuideColors.ink,
                      ),
                    ),
                  ),
                  const Icon(Icons.add, size: 18, color: GuideColors.teal),
                  const SizedBox(width: 4),
                  Text(
                    tr(context, 'New collection', 'Bộ sưu tập mới'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: GuideColors.teal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            for (final (name, color, icon, count, id) in places)
              if (name != from)
                row(
                  name,
                  badge(color, icon),
                  tr(context, '$count links', '$count link'),
                  to: name,
                  id: id,
                ),
            if (from != null)
              row(
                tr(context, 'Not sorted', 'Chưa xếp'),
                badge(const Color(0xFF5B5E63), Icons.inbox_outlined),
                tr(context, 'Take it out of $from', 'Bỏ ra khỏi $from'),
                to: null,
                id: 'inbox',
              ),
          ],
        ),
      ),
    );
  }
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
                          fontFamily: handyFontFamily('Manrope'),
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: GuideColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr(
                          context,
                          'Saved at once, sorted with one tap.',
                          'Lưu ngay, một chạm là xếp xong.',
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
