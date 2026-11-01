import 'package:handy_recall/handy_recall.dart';
import 'package:handy_ui/kit.dart';
import '../study/schedule.dart';

/// Four ways to answer "did I remember?", each saying when the card comes
/// back. Thumb-height buttons at the foot of the screen; keys 1–4 on desktop.
class GradeBar extends StatelessWidget {
  final RecallCard card;
  final DateTime now;
  final bool busy;
  final ValueChanged<String> onGrade;
  const GradeBar({
    super.key,
    required this.card,
    required this.now,
    required this.busy,
    required this.onGrade,
  });

  static String label(BuildContext c, String rating) => switch (rating) {
    'again' => tr(c, 'Forgot', 'Quên'),
    'hard' => tr(c, 'Hard', 'Khó'),
    'good' => tr(c, 'Got it', 'Nhớ'),
    _ => tr(c, 'Easy', 'Dễ'),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return Row(
      children: [
        for (final (i, r) in ratings.indexed) ...[
          if (i > 0) const SizedBox(width: HandySpace.s),
          Expanded(
            child: _GradeButton(
              key: Key('grade-$r'),
              primary: r == 'good',
              onPressed: busy ? null : () => onGrade(r),
              title: label(context, r),
              // When this answer brings the card back: the real scheduler.
              when: () {
                final (en, vi) = spanWords(nextInterval(card, r, now));
                return tr(context, en, vi);
              }(),
              whenStyle: theme.textTheme.bodySmall?.copyWith(
                color: r == 'good' ? null : c.muted,
                fontFeatures: tabular,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GradeButton extends StatelessWidget {
  final bool primary;
  final VoidCallback? onPressed;
  final String title, when;
  final TextStyle? whenStyle;
  const _GradeButton({
    super.key,
    required this.primary,
    required this.onPressed,
    required this.title,
    required this.when,
    required this.whenStyle,
  });
  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: HandySpace.s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            when,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: primary
                ? whenStyle?.copyWith(color: Colors.white)
                : whenStyle,
          ),
        ],
      ),
    );
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 64)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 4),
      ),
    );
    return primary
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton(onPressed: onPressed, style: style, child: child);
  }
}
