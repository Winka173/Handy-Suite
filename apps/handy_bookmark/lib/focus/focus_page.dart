import 'dart:math' as math;
import '../pro/focus_skins.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';
import 'focus_card.dart';

/// Unread things one at a time, oldest first, as a deck: swipe right (or
/// Read, or →) when it is done with, left (or Later, or ←) to keep it for
/// later, Archive (or A) to put it away. Nothing changes until a swipe
/// passes the threshold or a button is pressed; every step can be undone
/// once. "Later" lasts until the page closes.
class FocusPage extends StatefulWidget {
  final SaveScope scope;
  const FocusPage({super.key, required this.scope});
  @override
  State<FocusPage> createState() => _FocusPageState();
}

enum _Move { read, later, archive }

/// How long the card takes to fly off or settle back.
const _fly = Duration(milliseconds: 220);
const _settle = Duration(milliseconds: 180);

class _FocusPageState extends State<FocusPage>
    with SingleTickerProviderStateMixin {
  final skipped = <String>[];
  late final AnimationController motion;
  double dx = 0;

  /// 0 → 1 while an archived card sinks away.
  double sink = 0;
  double width = 400;
  bool busy = false;
  int done = 0;
  SaveScope get scope => widget.scope;

  List<Bookmark> get queue => [
    for (final b in scope.library.bookmarks)
      if (!b.isRead && !b.isArchived && !skipped.contains(b.id)) b,
  ]..sort((a, b) => a.savedAt.compareTo(b.savedAt));

  @override
  void initState() {
    super.initState();
    motion = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  /// Runs [apply] with t from 0 to 1 over [time] (skipped when motion is
  /// reduced).
  Future<void> _animate(
    Duration time,
    Curve curve,
    void Function(double t) apply,
  ) async {
    final d = HandyMotion.of(context, time);
    if (d == Duration.zero) return;
    motion.duration = d;
    final a = CurvedAnimation(parent: motion, curve: curve);
    void step() => setState(() => apply(a.value));
    motion.addListener(step);
    await motion.forward(from: 0);
    motion.removeListener(step);
  }

  /// A drag let go before the threshold: the card settles back, unchanged.
  Future<void> _back() async {
    final from = dx;
    await _animate(_settle, Curves.easeOutCubic, (t) => dx = from * (1 - t));
    if (mounted) setState(() => dx = 0);
  }

  /// Sends the top card off (right for read, left for later, down for
  /// archive) unless motion is reduced, then applies the move.
  Future<void> _go(Bookmark b, _Move move) async {
    if (busy) return;
    busy = true;
    final from = dx;
    switch (move) {
      case _Move.read || _Move.later:
        final to = (move == _Move.read ? 1 : -1) * width * 1.5;
        await _animate(
          _fly,
          Curves.easeInCubic,
          (t) => dx = from + (to - from) * t,
        );
      case _Move.archive:
        await _animate(_fly, Curves.easeInCubic, (t) => sink = t);
    }
    if (!mounted) return;
    final ok =
        move == _Move.later ||
        await scope.run(
          context,
          () => scope.put(
            move == _Move.read
                ? b.copyWith(isRead: true)
                : b.copyWith(isArchived: true),
          ),
        );
    if (!mounted) return;
    setState(() {
      dx = 0;
      sink = 0;
      busy = false;
      if (move == _Move.later) skipped.add(b.id);
      if (ok) done++;
    });
    if (!ok) return;
    if (_phone) HapticFeedback.selectionClick();
    _undoMessage(b, move);
  }

  static bool get _phone =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void _undoMessage(Bookmark b, _Move move) {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        // Shown long enough to act on, then it goes (with an action
        // Flutter would keep it until dismissed).
        persist: false,
        content: Text(switch (move) {
          _Move.read => tr(context, 'Marked as read.', 'Đã đánh dấu đã đọc.'),
          _Move.later => tr(context, 'Kept for later.', 'Để sau.'),
          _Move.archive => tr(context, 'Archived.', 'Đã lưu trữ.'),
        }),
        action: SnackBarAction(
          key: const Key('focus-undo'),
          label: tr(context, 'Undo', 'Hoàn tác'),
          onPressed: () async {
            if (move == _Move.later) {
              setState(() {
                skipped.remove(b.id);
                done--;
              });
            } else if (await scope.view.undo() && mounted) {
              setState(() => done--);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.c,
    builder: (context, _) {
      final q = queue;
      final b = q.firstOrNull;
      final theme = Theme.of(context);
      final p = BookmarkPalette.of(context);
      return CallbackShortcuts(
        bindings: {
          if (b != null) ...{
            const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                _go(b, _Move.read),
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                _go(b, _Move.later),
            const SingleActivator(LogicalKeyboardKey.keyA): () =>
                _go(b, _Move.archive),
            const SingleActivator(LogicalKeyboardKey.enter): () =>
                scope.open(context, b),
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              scrolledUnderElevation: 0,
              title: Text(tr(context, 'Focus', 'Tập trung')),
              actions: [
                IconButton(
                  key: const Key('focus-skins'),
                  tooltip: tr(context, 'Card style', 'Kiểu thẻ'),
                  icon: const Icon(Icons.style_outlined),
                  onPressed: () => showFocusSkins(
                    context,
                    widget.scope,
                    b,
                    b == null
                        ? null
                        : (b.media != null
                              ? widget.scope.c.mediaPreview(b.media!.id)
                              : widget.scope.c.thumbnail(b.id)),
                  ),
                ),
                if (b != null)
                  Padding(
                    padding: const EdgeInsets.only(right: HandySpace.l),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: ShapeDecoration(
                          color: p.raised,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          tr(context, '${q.length} to go', 'còn ${q.length}'),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: p.ink,
                            fontFeatures: tabular,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: b == null ? null : _buttons(context, b),
            body: b == null ? _done(context) : _deck(context, q),
          ),
        ),
      );
    },
  );

  Widget _deck(BuildContext context, List<Bookmark> q) => LayoutBuilder(
    builder: (context, box) {
      final p = BookmarkPalette.of(context);
      final dark = Theme.of(context).brightness == Brightness.dark;
      final reduced = MediaQuery.of(context).disableAnimations;
      width = math.min(box.maxWidth - 2 * HandySpace.l, 520.0);
      // Room under the card for the two that peek out below it.
      final height = math.min(box.maxHeight - 2 * HandySpace.l - 28, 640.0);
      final b = q.first;
      final pull = (dx / (width * .35)).clamp(-1.0, 1.0);
      // The card under it rises into place as the top one leaves.
      final lift = math.max(pull.abs(), sink);
      Widget behind(int i) {
        final rise = i == 1 ? lift : 0.0;
        final step = i - rise;
        return Transform.translate(
          offset: Offset(0, 14.0 * step),
          child: Transform.scale(
            scale: 1 - .045 * step,
            alignment: Alignment.bottomCenter,
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: i == 1
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          FocusCard(
                            key: ValueKey('behind-${q[i].id}'),
                            scope: scope,
                            bookmark: q[i],
                          ),
                          // A veil of the ground keeps it a step back.
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: p.canvas.withValues(
                                alpha: (dark ? .3 : .55) * (1 - rise),
                              ),
                              borderRadius: BorderRadius.circular(
                                BookmarkRadii.focus,
                              ),
                            ),
                          ),
                        ],
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: dark
                              ? Color.lerp(p.surface, p.canvas, .55)
                              : p.sunk,
                          borderRadius: BorderRadius.circular(
                            BookmarkRadii.focus,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        );
      }

      // With reduced motion the card barely travels and does not turn.
      final shown = reduced ? dx * .25 : dx;
      return Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: HandySpace.l),
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = math.min(2, q.length - 1); i >= 1; i--)
                Positioned.fill(child: behind(i)),
              Positioned.fill(
                child: GestureDetector(
                  key: const Key('focus-card'),
                  onHorizontalDragUpdate: busy
                      ? null
                      : (d) => setState(() => dx += d.delta.dx),
                  onHorizontalDragEnd: busy
                      ? null
                      : (d) {
                          final v = d.primaryVelocity ?? 0;
                          if (dx > width * .35 || (v > 900 && dx > 0)) {
                            _go(b, _Move.read);
                          } else if (dx < -width * .35 ||
                              (v < -900 && dx < 0)) {
                            _go(b, _Move.later);
                          } else {
                            _back();
                          }
                        },
                  onHorizontalDragCancel: busy ? null : _back,
                  child: Opacity(
                    opacity: 1 - sink,
                    child: Transform.translate(
                      offset: Offset(
                        shown,
                        (reduced ? 0 : pull.abs() * 10) + 40 * sink,
                      ),
                      child: Transform.rotate(
                        angle: reduced ? 0 : pull * .08,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: FocusCard(
                                key: ValueKey(b.id),
                                scope: scope,
                                bookmark: b,
                                lifted: true,
                              ),
                            ),
                            Positioned(
                              top: HandySpace.l,
                              left: HandySpace.l,
                              child: SwipeLabel(
                                text: tr(context, 'Read', 'Đã đọc'),
                                icon: Icons.check_rounded,
                                opacity: pull * 1.6,
                                background: p.primary,
                                foreground: p.onPrimary,
                              ),
                            ),
                            Positioned(
                              top: HandySpace.l,
                              right: HandySpace.l,
                              child: SwipeLabel(
                                text: tr(context, 'Later', 'Để sau'),
                                icon: Icons.schedule_rounded,
                                opacity: -pull * 1.6,
                                background: Theme.of(
                                  context,
                                ).colorScheme.inverseSurface,
                                foreground: Theme.of(
                                  context,
                                ).colorScheme.onInverseSurface,
                              ),
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
    },
  );

  Widget _buttons(BuildContext context, Bookmark b) {
    final p = BookmarkPalette.of(context);
    // How far the card leans: right to Read, left to Later.
    final lean = (dx / (width * .35)).clamp(-1.0, 1.0);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          HandySpace.l,
          HandySpace.s,
          HandySpace.l,
          HandySpace.m,
        ),
        child: HandyContent(
          maxWidth: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // With large text the buttons' own words are enough.
              if (MediaQuery.textScalerOf(context).scale(14) < 20) ...[
                // While a swipe is under way it says where the card is going.
                Text(
                  lean > .1
                      ? tr(context, 'Let go: Read', 'Thả ra: Đã đọc')
                      : lean < -.1
                      ? tr(context, 'Let go: Later', 'Thả ra: Để sau')
                      : tr(
                          context,
                          'Swipe right when done, left for later.',
                          'Vuốt phải khi xong, vuốt trái để sau.',
                        ),
                  key: const Key('focus-hint'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: HandySpace.m),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DeckButton(
                    key: const Key('focus-later'),
                    icon: Icons.schedule_rounded,
                    label: tr(context, 'Later', 'Để sau'),
                    size: 60,
                    emphasis: math.max(0, -lean),
                    dimmed: lean > .1,
                    background: Theme.of(context).colorScheme.inverseSurface,
                    foreground: Theme.of(context).colorScheme.onInverseSurface,
                    onPressed: () => _go(b, _Move.later),
                  ),
                  _DeckButton(
                    key: const Key('focus-archive'),
                    icon: Icons.archive_outlined,
                    label: tr(context, 'Archive', 'Lưu trữ'),
                    size: 48,
                    dimmed: lean.abs() > .1,
                    background: dark ? p.raised : p.sunk,
                    foreground: p.ink,
                    onPressed: () => _go(b, _Move.archive),
                  ),
                  _DeckButton(
                    key: const Key('focus-read'),
                    icon: Icons.check_rounded,
                    label: tr(context, 'Read', 'Đã đọc'),
                    size: 60,
                    emphasis: math.max(0, lean),
                    dimmed: lean < -.1,
                    background: p.primary,
                    foreground: p.onPrimary,
                    onPressed: () => _go(b, _Move.read),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _done(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Center(
      key: const ValueKey('done'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(HandySpace.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: p.tint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  done > 0 ? Icons.done_all_rounded : Icons.inbox_outlined,
                  size: 40,
                  color: dark ? p.primary : p.pressed,
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  done > 0
                      ? tr(
                          context,
                          'Done: $done went through',
                          'Xong: đã đi qua $done mục',
                        )
                      : tr(
                          context,
                          'Nothing left to read',
                          'Không còn gì chưa đọc',
                        ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: HandySpace.s),
              Text(
                skipped.isNotEmpty
                    ? tr(
                        context,
                        'What you kept for later is still unread.',
                        'Những mục để sau vẫn đang chờ bạn.',
                      )
                    : tr(
                        context,
                        'New saves wait here until you read them.',
                        'Mục mới lưu sẽ chờ ở đây đến khi bạn đọc.',
                      ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
              ),
              const SizedBox(height: HandySpace.xl),
              if (skipped.isNotEmpty) ...[
                FilledButton(
                  key: const Key('focus-again'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () => setState(skipped.clear),
                  child: Text(
                    tr(
                      context,
                      'Bring back the ${skipped.length} for later',
                      'Đưa lại ${skipped.length} mục để sau',
                    ),
                  ),
                ),
                const SizedBox(height: HandySpace.s),
              ],
              TextButton(
                key: const Key('focus-back'),
                onPressed: () => Navigator.maybePop(context),
                child: Text(tr(context, 'Back to the library', 'Về thư viện')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round deck button with its word under it; the whole column is the
/// target.
class _DeckButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final double size;
  final Color background, foreground;
  final VoidCallback onPressed;

  /// How far a swipe leans this way (0–1): the button grows with it.
  final double emphasis;

  /// A swipe leans the other way: this one steps back.
  final bool dimmed;
  const _DeckButton({
    super.key,
    required this.icon,
    required this.label,
    required this.size,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.emphasis = 0,
    this.dimmed = false,
  });
  @override
  Widget build(BuildContext context) {
    final p = BookmarkPalette.of(context);
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onPressed,
        child: InkWell(
          borderRadius: BorderRadius.circular(BookmarkRadii.item),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SizedBox(
                  height: 60,
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: dimmed ? .4 : 1,
                      duration: HandyMotion.of(
                        context,
                        const Duration(milliseconds: 120),
                      ),
                      child: Transform.scale(
                        scale: 1 + .2 * emphasis.clamp(0.0, 1.0),
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            color: background,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icon,
                            color: foreground,
                            size: size * .45,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
