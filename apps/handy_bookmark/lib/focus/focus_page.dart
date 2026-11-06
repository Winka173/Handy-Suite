import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import 'focus_card.dart';

/// Unread things one at a time, oldest first, as a deck: swipe right (or
/// Read, or →) when it is done with, left (or Later, or ←) to keep it for
/// later, Archive to put it away. Every step can be undone once. "Later"
/// lasts until the page closes.
class FocusPage extends StatefulWidget {
  final SaveScope scope;
  const FocusPage({super.key, required this.scope});
  @override
  State<FocusPage> createState() => _FocusPageState();
}

enum _Move { read, later, archive }

class _FocusPageState extends State<FocusPage>
    with SingleTickerProviderStateMixin {
  final skipped = <String>[];
  late final AnimationController fling;
  double dx = 0;
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
    fling = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    fling.dispose();
    super.dispose();
  }

  /// Slides the top card off toward [to] (unless motion is reduced), then
  /// applies the move.
  Future<void> _go(Bookmark b, _Move move, {double width = 400}) async {
    if (busy) return;
    busy = true;
    final to = switch (move) {
      _Move.read => width * 1.4,
      _Move.later => -width * 1.4,
      _Move.archive => 0.0,
    };
    final time = HandyMotion.of(context, HandyMotion.medium);
    if (time > Duration.zero && to != 0) {
      final from = dx;
      fling.duration = time;
      final a = Tween(
        begin: from,
        end: to,
      ).animate(CurvedAnimation(parent: fling, curve: Curves.easeIn));
      void step() => setState(() => dx = a.value);
      fling.addListener(step);
      await fling.forward(from: 0);
      fling.removeListener(step);
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
              title: Text(tr(context, 'Focus', 'Tập trung')),
              actions: [
                if (b != null)
                  Padding(
                    padding: const EdgeInsets.only(right: HandySpace.l),
                    child: Center(
                      child: Text(
                        tr(context, '${q.length} to go', 'còn ${q.length}'),
                        style: const TextStyle(fontFeatures: tabular),
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
      final width = math.min(box.maxWidth - 2 * HandySpace.l, 560.0);
      final height = math.min(box.maxHeight - 2 * HandySpace.l - 40, 620.0);
      final b = q.first;
      final pull = (dx / (width * .35)).clamp(-1.0, 1.0);
      Widget behind(int i) => Transform.translate(
        offset: Offset(0, 26.0 * i - 14 * pull.abs() * (i == 1 ? 1 : 0)),
        child: Transform.scale(
          scale: 1 - .04 * i + (i == 1 ? .04 * pull.abs() : 0),
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: FocusCard(
                key: ValueKey('behind-${q[i].id}'),
                scope: scope,
                bookmark: q[i],
              ),
            ),
          ),
        ),
      );
      return Center(
        child: SizedBox(
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
                          if (dx > width * .35 || v > 900) {
                            _go(b, _Move.read, width: width);
                          } else if (dx < -width * .35 || v < -900) {
                            _go(b, _Move.later, width: width);
                          } else {
                            setState(() => dx = 0);
                          }
                        },
                  child: AnimatedSlide(
                    offset: Offset.zero,
                    duration: Duration.zero,
                    child: Transform.translate(
                      offset: Offset(dx, 0),
                      child: Transform.rotate(
                        angle: pull * .07,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: FocusCard(
                                key: ValueKey(b.id),
                                scope: scope,
                                bookmark: b,
                              ),
                            ),
                            Positioned(
                              top: HandySpace.l,
                              left: HandySpace.l,
                              child: SwipeLabel(
                                text: tr(context, 'Read', 'Đã đọc'),
                                icon: Icons.check,
                                opacity: pull * 1.6,
                              ),
                            ),
                            Positioned(
                              top: HandySpace.l,
                              right: HandySpace.l,
                              child: SwipeLabel(
                                text: tr(context, 'Later', 'Để sau'),
                                icon: Icons.schedule,
                                opacity: -pull * 1.6,
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

  Widget _buttons(BuildContext context, Bookmark b) => HandyBottomBar(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tr(
            context,
            'Swipe right when done, left for later.',
            'Vuốt phải khi xong, vuốt trái để sau.',
          ),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: HandyColors.of(context).muted),
        ),
        const SizedBox(height: HandySpace.s),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('focus-later'),
                onPressed: () => _go(b, _Move.later),
                icon: const Icon(Icons.schedule),
                label: Text(tr(context, 'Later', 'Để sau')),
              ),
            ),
            const SizedBox(width: HandySpace.s),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('focus-archive'),
                onPressed: () => _go(b, _Move.archive),
                icon: const Icon(Icons.archive_outlined),
                label: Text(tr(context, 'Archive', 'Lưu trữ')),
              ),
            ),
            const SizedBox(width: HandySpace.s),
            Expanded(
              child: FilledButton.icon(
                key: const Key('focus-read'),
                onPressed: () => _go(b, _Move.read),
                icon: const Icon(Icons.check),
                label: Text(tr(context, 'Read', 'Đã đọc')),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _done(BuildContext context) => HandyEmpty(
    key: const ValueKey('done'),
    title: done > 0
        ? tr(context, 'Done: $done went through', 'Xong: đã đi qua $done mục')
        : tr(context, 'Nothing left to read', 'Không còn gì chưa đọc'),
    action: skipped.isEmpty
        ? null
        : TextButton(
            key: const Key('focus-again'),
            onPressed: () => setState(skipped.clear),
            child: Text(
              tr(
                context,
                'Bring back the ${skipped.length} for later',
                'Đưa lại ${skipped.length} mục để sau',
              ),
            ),
          ),
  );
}
