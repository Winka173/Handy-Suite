import 'package:handy_recall/handy_recall.dart';
import 'package:handy_ui/kit.dart';
import '../occlusion_editor.dart';
import '../study/card_text.dart';

/// One card: the question large, and once revealed, the answer below a
/// rule. A cloze shows its blank in the app's hue and fills it on reveal;
/// covers on a picture lift; a picture kept for the answer appears with it.
/// A speaker reads a side aloud when its deck has a language for it.
class CardFace extends StatelessWidget {
  final RecallCard card;
  final RecallDeck? deck;
  final bool revealed;

  /// Reads text aloud in a language; null hides the speakers.
  final void Function(String text, String language)? onSpeak;

  /// The card's height before its answer opens: a card-shaped block, so the
  /// question sits where the eye lands instead of at the top of a void.
  final double minHeight;
  const CardFace({
    super.key,
    required this.card,
    required this.revealed,
    this.deck,
    this.onSpeak,
    this.minHeight = 0,
  });

  Widget _speaker(BuildContext context, String key, String text, String lang) =>
      IconButton(
        key: Key(key),
        tooltip: tr(context, 'Read aloud', 'Đọc to'),
        icon: const Icon(Icons.volume_up_outlined),
        onPressed: () => onSpeak!(text, lang),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final t = cardText(card, deck, revealed: revealed);
    final plain = t.question.map((s) => s.text).join();
    // A word or a short phrase is the biggest thing on screen.
    final style = plain.characters.length <= 24
        ? theme.textTheme.headlineMedium
        : theme.textTheme.headlineSmall;
    final speakQuestion =
        onSpeak != null && t.questionLanguage.isNotEmpty && plain.isNotEmpty;
    final speakAnswer =
        onSpeak != null && t.answerLanguage.isNotEmpty && t.answer.isNotEmpty;
    final picture = card.image == null
        ? null
        : OcclusionCanvas(image: card.image!, hidden: !revealed);
    return Card(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.all(HandySpace.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (card.reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: HandySpace.s),
                  child: Text(
                    tr(context, 'Reverse card', 'Thẻ đảo chiều'),
                    key: const Key('review-reversed'),
                    style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                  ),
                ),
              if (plain.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: SelectableText.rich(
                          TextSpan(
                            children: [
                              for (final s in t.question)
                                TextSpan(
                                  text: s.text,
                                  style: switch (s.part) {
                                    ClozePart.text => null,
                                    // The blank and, once shown, what
                                    // filled it: the card's one hue.
                                    ClozePart.blank => TextStyle(
                                      color: c.selectInk,
                                      backgroundColor: c.select,
                                    ),
                                    ClozePart.answer => TextStyle(
                                      color: c.selectInk,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      decorationColor: c.selectInk,
                                    ),
                                  },
                                ),
                            ],
                          ),
                          key: const Key('review-front'),
                          style: style,
                        ),
                      ),
                    ),
                    if (speakQuestion)
                      _speaker(
                        context,
                        'speak-question',
                        t.spokenQuestion,
                        t.questionLanguage,
                      ),
                  ],
                ),
              if (picture != null && card.imageOnQuestion) ...[
                if (plain.isNotEmpty) const SizedBox(height: HandySpace.l),
                picture,
              ],
              // The answer opens downward and fades in, like turning the card.
              HandyReveal(
                child: !revealed
                    ? const SizedBox(width: double.infinity)
                    : TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: HandyMotion.of(context),
                        curve: HandyMotion.curve,
                        builder: (context, v, child) => Opacity(
                          opacity: v,
                          child: Transform.translate(
                            offset: Offset(0, 8 * (1 - v)),
                            child: child,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (t.answer.isNotEmpty ||
                                (picture != null && !card.imageOnQuestion)) ...[
                              const SizedBox(height: HandySpace.xl),
                              Divider(color: c.border, height: 1),
                              const SizedBox(height: HandySpace.xl),
                            ],
                            if (t.answer.isNotEmpty)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: SelectableText(
                                      t.answer,
                                      key: const Key('review-back'),
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w400,
                                          ),
                                    ),
                                  ),
                                  if (speakAnswer)
                                    _speaker(
                                      context,
                                      'speak-answer',
                                      t.answer,
                                      t.answerLanguage,
                                    ),
                                ],
                              ),
                            if (picture != null && !card.imageOnQuestion) ...[
                              if (t.answer.isNotEmpty)
                                const SizedBox(height: HandySpace.l),
                              picture,
                            ],
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
