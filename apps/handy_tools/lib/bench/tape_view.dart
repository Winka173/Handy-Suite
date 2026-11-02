import 'package:handy_ui/kit.dart';
import 'tape.dart';

/// The tape: newest answer on top, what was typed in grey beside it, and the
/// exact total of every numeric answer at the foot.
class TapeView extends StatelessWidget {
  final TapeController tape;
  final ValueChanged<TapeEntry> onReuse;
  final VoidCallback? onNotebook;
  const TapeView({
    super.key,
    required this.tape,
    required this.onReuse,
    this.onNotebook,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: tape,
    builder: (context, _) {
      final theme = Theme.of(context);
      final c = HandyColors.of(context);
      final total = tape.total;
      final figure = theme.textTheme.titleMedium?.copyWith(
        fontFeatures: tabular,
      );
      return Column(
        key: const Key('tape'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      tr(context, 'Tape', 'Băng kết quả'),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                if (onNotebook != null)
                  TextButton(
                    key: const Key('open-notebook'),
                    onPressed: onNotebook,
                    child: Text(tr(context, 'Notebook', 'Sổ tính')),
                  ),
                if (tape.entries.isNotEmpty)
                  TextButton(
                    key: const Key('tape-clear'),
                    onPressed: tape.clear,
                    child: Text(tr(context, 'Clear', 'Xóa băng')),
                  ),
              ],
            ),
          ),
          const SizedBox(height: HandySpace.s),
          Card(
            color: c.lead,
            // New entries grow the tape instead of pushing it in one frame.
            child: HandyReveal(
              child: tape.entries.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(HandySpace.l),
                      child: Text(
                        tr(
                          context,
                          'Press Enter or Copy and the answer lands here. Numbers add up at the bottom. Kept until you close the app.',
                          'Nhấn Enter hoặc Sao chép, đáp án sẽ nằm ở đây. Các số được cộng dồn ở cuối. Giữ đến khi đóng app.',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: c.muted,
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < tape.entries.length; i++)
                          InkWell(
                            key: Key('tape-entry-$i'),
                            onTap: () => onReuse(tape.entries[i]),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: HandySpace.l,
                                vertical: 10,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Text(
                                      tape.entries[i].input,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: c.muted),
                                    ),
                                  ),
                                  const SizedBox(width: HandySpace.m),
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      tape.entries[i].answer,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.end,
                                      // Only numbers join the total; the rest read grey.
                                      style: tape.entries[i].number == null
                                          ? figure?.copyWith(color: c.muted)
                                          : figure,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (total != null) ...[
                          Divider(color: c.border, height: 1),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              HandySpace.l,
                              HandySpace.m,
                              HandySpace.l,
                              HandySpace.m,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  tr(
                                    context,
                                    'Total of ${tape.counted}',
                                    'Tổng ${tape.counted} số',
                                  ),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: c.muted,
                                  ),
                                ),
                                const SizedBox(width: HandySpace.m),
                                // A long total shrinks to fit; it never wraps or
                                // spills past the tape's edge.
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: SelectionArea(
                                      child: Text(
                                        formatFigure(context, total),
                                        key: const Key('tape-total'),
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              color: c.accent,
                                              fontFeatures: tabular,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      );
    },
  );
}
