import 'package:handy_recall/handy_recall.dart';
import 'package:handy_ui/kit.dart';
import '../occlusion_editor.dart';

/// One card: the question large, and once revealed, the answer below a
/// rule. Covers on a picture lift when the answer shows.
class CardFace extends StatelessWidget {
  final RecallCard card;
  final bool revealed;

  /// The card's height before its answer opens: a card-shaped block, so the
  /// question sits where the eye lands instead of at the top of a void.
  final double minHeight;
  const CardFace({
    super.key,
    required this.card,
    required this.revealed,
    this.minHeight = 0,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return Card(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.all(HandySpace.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: SelectableText(
                  card.front,
                  key: const Key('review-front'),
                  // A word or a short phrase is the biggest thing on screen.
                  style: card.front.characters.length <= 24
                      ? theme.textTheme.headlineMedium
                      : theme.textTheme.headlineSmall,
                ),
              ),
              if (card.image != null) ...[
                const SizedBox(height: HandySpace.l),
                OcclusionCanvas(image: card.image!, hidden: !revealed),
              ],
              // The answer opens downward and fades in, like turning the card.
              HandyReveal(
                child: !revealed
                    ? const SizedBox(width: double.infinity)
                    : TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: HandyMotion.of(context),
                        curve: HandyMotion.curve,
                        builder: (context, t, child) => Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, 8 * (1 - t)),
                            child: child,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: HandySpace.xl),
                            Divider(color: c.border, height: 1),
                            const SizedBox(height: HandySpace.xl),
                            SelectableText(
                              card.back,
                              key: const Key('review-back'),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w400,
                              ),
                            ),
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
