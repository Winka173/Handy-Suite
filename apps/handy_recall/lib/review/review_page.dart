import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../study/schedule.dart';
import 'card_face.dart';
import 'grade_bar.dart';
import 'review_done.dart';

/// A review session over what is due now ([deckId] or every deck). Each
/// grade is written before the next card shows; a failed write keeps the
/// card, its answer and its old schedule on screen.
class ReviewPage extends StatefulWidget {
  final RecallScope scope;
  final String? deckId;
  const ReviewPage({super.key, required this.scope, this.deckId});
  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final focus = FocusNode();
  bool revealed = false, busy = false;
  int done = 0, forgot = 0;
  String error = '';
  RecallScope get scope => widget.scope;

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  List<RecallCard> get queue =>
      dueCards(scope.state, now: stamp(scope.now), deckId: widget.deckId);

  Future<void> grade(RecallCard card, String rating) async {
    if (busy || !revealed) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await scope.store.grade(card, rating);
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        HapticFeedback.selectionClick();
      }
      setState(() {
        done++;
        if (rating == 'again') forgot++;
        revealed = false;
      });
    } catch (e) {
      if (mounted) setState(() => error = errorText(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scope.store,
    builder: (context, _) {
      final q = queue;
      final card = q.isEmpty ? null : q.first;
      final total = done + q.length;
      final deck = scope.state.decks
          .where((d) => d.id == widget.deckId)
          .firstOrNull;
      void show() {
        if (card != null && !revealed) setState(() => revealed = true);
      }

      return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): show,
          const SingleActivator(LogicalKeyboardKey.enter): show,
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.maybePop(context),
          for (final (i, r) in ratings.indexed)
            SingleActivator(
              LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i),
            ): () {
              if (card != null) grade(card, r);
            },
        },
        child: Focus(
          focusNode: focus,
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              title: Text(deck?.name ?? tr(context, 'Review', 'Ôn tập')),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: total == 0 ? 1 : done / total),
                  duration: HandyMotion.of(context, HandyMotion.long),
                  curve: HandyMotion.curve,
                  builder: (context, v, _) => LinearProgressIndicator(
                    key: const Key('review-progress'),
                    value: v,
                    // Progress is the session's data: the app's hue.
                    color: Theme.of(context).colorScheme.primary,
                    semanticsLabel: tr(
                      context,
                      'Progress: $done of $total',
                      'Tiến độ: $done trên $total',
                    ),
                  ),
                ),
              ),
              actions: [
                if (card != null)
                  Padding(
                    padding: const EdgeInsets.only(right: HandySpace.l),
                    child: Center(
                      child: Text(
                        tr(context, '${q.length} left', 'còn ${q.length}'),
                        key: const Key('review-left'),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(fontFeatures: tabular),
                      ),
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: card == null
                ? null
                : HandyBottomBar(
                    child: HandySwap(
                      child: revealed
                          ? GradeBar(
                              key: const ValueKey('grades'),
                              card: card,
                              now: scope.now,
                              busy: busy,
                              onGrade: (r) => grade(card, r),
                            )
                          : FilledButton(
                              key: const Key('review-show'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(64),
                              ),
                              onPressed: show,
                              child: Text(
                                tr(context, 'Show answer', 'Hiện đáp án'),
                              ),
                            ),
                    ),
                  ),
            body: card == null
                ? ReviewDone(
                    scope: scope,
                    deckId: widget.deckId,
                    done: done,
                    forgot: forgot,
                  )
                : LayoutBuilder(
                    builder: (context, box) => ListView(
                      padding: const EdgeInsets.all(HandySpace.l),
                      children: [
                        HandyContent(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // The next card slides in from the right.
                              AnimatedSwitcher(
                                duration: HandyMotion.of(
                                  context,
                                  HandyMotion.long,
                                ),
                                switchInCurve: HandyMotion.curve,
                                // The finished card leaves to the left as the
                                // next one comes in from the right.
                                // Staggered: the old card is gone by halfway,
                                // the new one fades in after the first third.
                                transitionBuilder: (child, a) => FadeTransition(
                                  opacity: CurvedAnimation(
                                    parent: a,
                                    curve: child.key == ValueKey(card.id)
                                        ? const Interval(.35, 1)
                                        : const Interval(.5, 1),
                                  ),
                                  child: SlideTransition(
                                    position: Tween(
                                      begin: Offset(
                                        child.key == ValueKey(card.id)
                                            ? .08
                                            : -.08,
                                        0,
                                      ),
                                      end: Offset.zero,
                                    ).animate(a),
                                    child: child,
                                  ),
                                ),
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.topCenter,
                                  children: [...previous, ?current],
                                ),
                                // Tapping the card is a shortcut; screen readers
                                // use the Show answer button below.
                                child: GestureDetector(
                                  key: ValueKey(card.id),
                                  excludeFromSemantics: true,
                                  onTap: show,
                                  child: CardFace(
                                    card: card,
                                    revealed: revealed,
                                    minHeight: (box.maxHeight * .62).clamp(
                                      0,
                                      560,
                                    ),
                                  ),
                                ),
                              ),
                              HandyReveal(
                                child: error.isEmpty
                                    ? const SizedBox(width: double.infinity)
                                    : Padding(
                                        padding: const EdgeInsets.only(
                                          top: HandySpace.l,
                                        ),
                                        child: HandyNotice(
                                          error,
                                          tone: HandyTone.error,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      );
    },
  );
}
