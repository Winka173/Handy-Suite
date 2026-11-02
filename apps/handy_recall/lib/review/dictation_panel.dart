import 'package:handy_recall/handy_recall.dart';
import 'package:handy_ui/kit.dart';

/// "Did I write it right?": hear the answer, type it, then see each word
/// against the expected one. Grading stays the learner's (the grade bar).
class DictationPanel extends StatelessWidget {
  final TextEditingController typed;
  final DictationCheck? checked;
  final bool ignoreAccents;
  final VoidCallback onPlay, onSlower, onCheck;
  final ValueChanged<bool> onIgnoreAccents;
  const DictationPanel({
    super.key,
    required this.typed,
    required this.checked,
    required this.ignoreAccents,
    required this.onPlay,
    required this.onSlower,
    required this.onCheck,
    required this.onIgnoreAccents,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), c = HandyColors.of(context);
    final check = checked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (check != null) ...[
          Text(
            check.allRight
                ? tr(context, 'All right', 'Đúng hết')
                : tr(
                    context,
                    '${check.rightCount} of ${check.expectedCount} words right',
                    'Đúng ${check.rightCount} trên ${check.expectedCount} từ',
                  ),
            key: const Key('dictation-summary'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: check.allRight ? c.positive : null,
              fontFeatures: tabular,
            ),
          ),
          const SizedBox(height: HandySpace.s),
          Semantics(
            container: true,
            label: tr(
              context,
              'Your words, checked',
              'Các từ bạn viết, đã chấm',
            ),
            child: Wrap(
              key: const Key('dictation-words'),
              spacing: HandySpace.s,
              runSpacing: HandySpace.s,
              children: [for (final w in check.words) _Word(w)],
            ),
          ),
          const SizedBox(height: HandySpace.l),
        ] else ...[
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              FilledButton.tonalIcon(
                key: const Key('dictation-play'),
                onPressed: onPlay,
                icon: const Icon(Icons.volume_up_outlined),
                label: Text(tr(context, 'Play again', 'Nghe lại')),
              ),
              OutlinedButton.icon(
                key: const Key('dictation-slower'),
                onPressed: onSlower,
                icon: const Icon(Icons.slow_motion_video),
                label: Text(tr(context, 'Slower', 'Chậm hơn')),
              ),
            ],
          ),
          const SizedBox(height: HandySpace.m),
          TextField(
            key: const Key('dictation-input'),
            controller: typed,
            autofocus: true,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onCheck(),
            decoration: InputDecoration(
              labelText: tr(
                context,
                'Write what you hear',
                'Viết điều bạn nghe',
              ),
            ),
          ),
          SwitchListTile.adaptive(
            key: const Key('dictation-accents'),
            contentPadding: EdgeInsets.zero,
            title: Text(tr(context, 'Ignore accents', 'Bỏ qua dấu')),
            subtitle: Text(
              tr(
                context,
                'Case and punctuation never count.',
                'Hoa thường và dấu câu không tính.',
              ),
            ),
            value: ignoreAccents,
            onChanged: onIgnoreAccents,
          ),
        ],
      ],
    );
  }
}

class _Word extends StatelessWidget {
  final DictationWord w;
  const _Word(this.w);
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), c = HandyColors.of(context);
    final big = theme.textTheme.titleLarge!;
    final struck = big.copyWith(
      color: c.negative,
      decoration: TextDecoration.lineThrough,
      decorationColor: c.negative,
    );
    final (Widget child, String spoken) = switch (w.mark) {
      DictationMark.right => (Text(w.typed, style: big), w.typed),
      DictationMark.wrong => (
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: w.typed, style: struck),
              const TextSpan(text: ' '),
              TextSpan(
                text: w.expected,
                style: big.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        tr(
          context,
          '${w.typed}, should be ${w.expected}',
          '${w.typed}, đúng là ${w.expected}',
        ),
      ),
      DictationMark.missing => (
        Container(
          padding: const EdgeInsets.symmetric(horizontal: HandySpace.xs),
          decoration: BoxDecoration(
            color: c.warningBg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            w.expected,
            style: big.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        tr(context, 'missing ${w.expected}', 'thiếu ${w.expected}'),
      ),
      DictationMark.extra => (
        Text(w.typed, style: struck),
        tr(context, 'extra ${w.typed}', 'thừa ${w.typed}'),
      ),
    };
    return Semantics(label: spoken, excludeSemantics: true, child: child);
  }
}
