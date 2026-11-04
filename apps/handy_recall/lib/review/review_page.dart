import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:handy_recall/handy_recall.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../study/card_text.dart';
import '../study/schedule.dart';
import 'card_face.dart';
import 'dictation_panel.dart';
import 'grade_bar.dart';
import 'review_done.dart';

/// A review session over what is due now ([deckId] or every deck). Each
/// grade is written before the next card shows; a failed write keeps the
/// card, its answer and its old schedule on screen.
class ReviewPage extends StatefulWidget {
  final RecallScope scope;
  final String? deckId;

  /// Practice: these cards, in this order, outside the schedule. Nothing
  /// is written; "Not yet" puts a card back at the end of the round.
  final List<String>? practice;
  final String? practiceTitle;
  const ReviewPage({
    super.key,
    required this.scope,
    this.deckId,
    this.practice,
    this.practiceTitle,
  });
  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final focus = FocusNode();
  bool revealed = false, busy = false;
  int done = 0, forgot = 0;

  /// Cards graded Forgot this session, to practise again at the end.
  final forgotten = <String>[];

  /// Practice order; a card leaves it when the person has it.
  late final List<String> round = [...?widget.practice];
  bool get practising => widget.practice != null;

  /// Notes already seen this session: their sibling cards wait their turn.
  final seen = <String>{};
  String error = '';

  /// Dictation: hear the answer, type it, check it word by word.
  bool dictation = false, ignoreAccents = false;
  final typed = TextEditingController();
  DictationCheck? checked;
  String? spokenFor;
  RecallScope get scope => widget.scope;

  @override
  void dispose() {
    focus.dispose();
    typed.dispose();
    super.dispose();
  }

  List<RecallCard> get queue => practising
      ? [
          for (final id in round)
            ?scope.state.cards.where((c) => c.id == id).firstOrNull,
        ]
      : reviewOrder(
          dueCards(scope.state, now: stamp(scope.now), deckId: widget.deckId),
          seen: seen,
        );

  /// A practice answer: the schedule is not touched.
  void practise(RecallCard card, bool knew) {
    if (!revealed) return;
    scope.speaker.stop();
    setState(() {
      round.remove(card.id);
      if (knew) {
        done++;
      } else {
        round.add(card.id);
      }
      revealed = false;
      typed.clear();
      checked = null;
    });
  }

  @override
  void deactivate() {
    scope.speaker.stop();
    super.deactivate();
  }

  /// Reads [text] aloud; says so plainly when the device has no voice.
  Future<void> speak(String text, String language, {double rate = 1}) async {
    final ok = await scope.speaker.speak(text, language, rate: rate);
    if (!ok && mounted) {
      showHandyMessage(
        context,
        tr(
          context,
          'No voice for $language on this device. Add one in the system text-to-speech settings.',
          'Máy chưa có giọng đọc $language. Hãy thêm trong cài đặt chuyển văn bản thành giọng nói của hệ thống.',
        ),
      );
    }
  }

  /// The answer to write down and its voice, for a card that has both
  /// (cloze and picture cards are reviewed the usual way).
  (String, String)? dictationOf(RecallCard card, RecallDeck? deck) {
    if (card.cloze > 0) return null;
    final t = cardText(card, deck, revealed: true);
    return t.answer.trim().isEmpty || t.answerLanguage.isEmpty
        ? null
        : (t.answer, t.answerLanguage);
  }

  void checkTyped((String, String) d) {
    if (revealed) return;
    setState(() {
      checked = checkDictation(d.$1, typed.text, ignoreAccents: ignoreAccents);
      revealed = true;
    });
  }

  Future<void> grade(RecallCard card, String rating) async {
    if (practising) return practise(card, rating != 'again');
    if (busy || !revealed) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      await scope.store.grade(card, rating);
      seen.add(noteOf(card));
      scope.speaker.stop();
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        HapticFeedback.selectionClick();
      }
      setState(() {
        done++;
        if (rating == 'again') {
          forgot++;
          if (!forgotten.contains(card.id)) forgotten.add(card.id);
        }
        revealed = false;
        typed.clear();
        checked = null;
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
      final cardDeck = card == null
          ? null
          : scope.state.decks.where((d) => d.id == card.deckId).firstOrNull;
      void show() {
        if (card != null && !revealed) setState(() => revealed = true);
      }

      final dict = dictation && card != null
          ? dictationOf(card, cardDeck)
          : null;
      // Each new card is read once on arrival; Play again repeats it.
      if (dict != null && spokenFor != card!.id) {
        spokenFor = card.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) speak(dict.$1, dict.$2);
        });
      }
      final writing = dict != null && !revealed;

      // R reads the side in front of the reader: the answer once shown.
      void readAloud() {
        if (card == null) return;
        final t = cardText(card, cardDeck, revealed: revealed);
        if (revealed && t.answer.isNotEmpty && t.answerLanguage.isNotEmpty) {
          speak(t.answer, t.answerLanguage);
        } else if (t.questionLanguage.isNotEmpty) {
          speak(t.spokenQuestion, t.questionLanguage);
        }
      }

      return CallbackShortcuts(
        // While writing, keys belong to the answer field.
        bindings: writing
            ? {
                const SingleActivator(LogicalKeyboardKey.escape): () =>
                    Navigator.maybePop(context),
              }
            : {
                const SingleActivator(LogicalKeyboardKey.space): show,
                const SingleActivator(LogicalKeyboardKey.enter): show,
                const SingleActivator(LogicalKeyboardKey.keyR): readAloud,
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
              title: Text(
                practising
                    ? widget.practiceTitle ??
                          tr(context, 'Practice', 'Luyện thêm')
                    : deck?.name ?? tr(context, 'Review', 'Ôn tập'),
              ),
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
                if (card != null && dictationOf(card, cardDeck) != null)
                  IconButton(
                    key: const Key('review-dictation'),
                    tooltip: tr(context, 'Dictation', 'Chép chính tả'),
                    isSelected: dictation,
                    icon: const Icon(Icons.keyboard_outlined),
                    selectedIcon: const Icon(Icons.keyboard),
                    onPressed: revealed
                        ? null
                        : () => setState(() {
                            dictation = !dictation;
                            spokenFor = null;
                            typed.clear();
                            checked = null;
                          }),
                  ),
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
                      child: writing
                          ? FilledButton(
                              key: const Key('dictation-check'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(64),
                              ),
                              onPressed: () => checkTyped(dict),
                              child: Text(tr(context, 'Check', 'Kiểm tra')),
                            )
                          : revealed && practising
                          ? Row(
                              key: const ValueKey('practice'),
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    key: const Key('practice-again'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(64),
                                    ),
                                    onPressed: () => practise(card, false),
                                    child: Text(
                                      tr(context, 'Not yet', 'Chưa nhớ'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: HandySpace.s),
                                Expanded(
                                  child: FilledButton(
                                    key: const Key('practice-ok'),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(64),
                                    ),
                                    onPressed: () => practise(card, true),
                                    child: Text(
                                      tr(context, 'Got it', 'Nhớ rồi'),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : revealed
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
                    practice: practising,
                    forgotten: forgotten,
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
                                    deck: cardDeck,
                                    onSpeak: speak,
                                    revealed: revealed,
                                    // In dictation the writing and the
                                    // check matter most: a shorter card.
                                    minHeight:
                                        (box.maxHeight *
                                                (dict != null ? .28 : .62))
                                            .clamp(0, 560),
                                  ),
                                ),
                              ),
                              if (dict != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: HandySpace.l,
                                  ),
                                  child: DictationPanel(
                                    typed: typed,
                                    checked: checked,
                                    ignoreAccents: ignoreAccents,
                                    onPlay: () => speak(dict.$1, dict.$2),
                                    onSlower: () =>
                                        speak(dict.$1, dict.$2, rate: .6),
                                    onCheck: () => checkTyped(dict),
                                    onIgnoreAccents: (v) =>
                                        setState(() => ignoreAccents = v),
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
