import 'package:handy_ui/kit.dart';
import '../specs.dart';
import '../tool_output.dart';
import 'evaluate.dart';
import 'tape.dart';

/// One line for the tape: the figure that answers, or the text's start.
String tapeAnswer(BuildContext context, Output o) => switch (o) {
  ValueOutput o => formatFigure(context, o.value),
  RowsOutput o => formatFigure(context, o.rows[o.lead].$2),
  WordsOutput o => o.words,
  TextOutput o => o.text.split('\n').first,
};

TapeEntry tapeEntry(
  BuildContext context, {
  required String input,
  required String toolId,
  required Map<String, String> values,
  required Evaluation result,
  bool free = false,
}) => TapeEntry(
  free: free,
  input: input.replaceAll('\n', ' ').trim(),
  answer: tapeAnswer(context, result.output!),
  number: result.number,
  toolId: toolId,
  values: values,
);

/// The answer panel: the result on the app's pale tint, its actions under it.
class AnswerPanel extends StatelessWidget {
  final Evaluation result;
  final VoidCallback onCopy, onRecord;
  final List<Widget> extra;
  const AnswerPanel({
    super.key,
    required this.result,
    required this.onCopy,
    required this.onRecord,
    this.extra = const [],
  });
  @override
  Widget build(BuildContext context) {
    final o = result.output!;
    // A schedule's summary leads; its month table follows the actions so
    // Copy never sits under a long table.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          container: true,
          child: o is ScheduleOutput
              ? HandyValueRows(o.rows, lead: o.lead)
              : OutputView(o),
        ),
        const SizedBox(height: HandySpace.m),
        Wrap(
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              key: const Key('bench-copy'),
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(tr(context, 'Copy', 'Sao chép')),
            ),
            // With two or more extra actions the label would push the row onto
            // a second line on phones; the icon keeps its tooltip.
            if (extra.length < 2)
              OutlinedButton.icon(
                key: const Key('bench-record'),
                onPressed: onRecord,
                icon: const Icon(Icons.playlist_add, size: 20),
                label: Text(tr(context, 'Add to tape', 'Ghi vào băng')),
              )
            else
              IconButton.outlined(
                key: const Key('bench-record'),
                tooltip: tr(context, 'Add to tape', 'Ghi vào băng'),
                onPressed: onRecord,
                icon: const Icon(Icons.playlist_add, size: 20),
              ),
            ...extra,
          ],
        ),
        if (o is ScheduleOutput) ...[
          const SizedBox(height: HandySpace.l),
          ScheduleTable(o.schedule),
        ],
      ],
    );
  }
}

/// The quiet line under the input that says how the entry was read, with the
/// other readings one tap away.
class ReadingRow extends StatelessWidget {
  final List<String> ids;
  final int selected;
  final ValueChanged<int> onSelect;
  const ReadingRow({
    super.key,
    required this.ids,
    required this.selected,
    required this.onSelect,
  });
  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    return Wrap(
      spacing: HandySpace.s,
      runSpacing: HandySpace.s,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          tr(context, 'Read as', 'Hiểu là'),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: c.muted),
        ),
        for (var i = 0; i < ids.length; i++)
          ChoiceChip(
            key: Key('reading-${ids[i]}'),
            label: Text(
              ids[i] == 'qr'
                  ? tr(context, 'QR code', 'Mã QR')
                  : stepTitle(context, ids[i]),
            ),
            selected: i == selected,
            onSelected: (_) => onSelect(i),
          ),
      ],
    );
  }
}
