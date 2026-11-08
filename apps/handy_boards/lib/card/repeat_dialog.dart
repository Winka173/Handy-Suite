import 'package:handy_boards_engine/handy_boards_engine.dart';
import 'package:handy_ui/kit.dart';

/// Card › Repeat › Custom (Pro): every N days, weeks or months; for weeks,
/// which weekdays; ends never, on a date, or after a number of times. The
/// next card is made when this one is finished, one at a time, so nothing
/// floods the board.
Future<Json?> customRepeat(BuildContext context, BoardRecord card) =>
    showDialog<Json>(
      context: context,
      builder: (_) => _RepeatDialog(card: card),
    );

class _RepeatDialog extends StatefulWidget {
  final BoardRecord card;
  const _RepeatDialog({required this.card});
  @override
  State<_RepeatDialog> createState() => _RepeatDialogState();
}

class _RepeatDialogState extends State<_RepeatDialog> {
  late String unit = widget.card.data['repeat'] as String? ?? 'weekly';
  late int every = widget.card.data['repeatEvery'] as int? ?? 1;
  late Set<int> days = {
    for (final d in (widget.card.data['repeatDays'] as List? ?? const []))
      if (d is int) d,
  };
  late String end = widget.card.data['repeatUntil'] != null
      ? 'date'
      : widget.card.data['repeatLeft'] != null
      ? 'count'
      : 'never';
  late String until = widget.card.data['repeatUntil'] as String? ?? '';
  late int left = widget.card.data['repeatLeft'] as int? ?? 5;

  @override
  Widget build(BuildContext context) {
    final names = [
      tr(context, 'Mo', 'T2'),
      tr(context, 'Tu', 'T3'),
      tr(context, 'We', 'T4'),
      tr(context, 'Th', 'T5'),
      tr(context, 'Fr', 'T6'),
      tr(context, 'Sa', 'T7'),
      tr(context, 'Su', 'CN'),
    ];
    return AlertDialog(
      title: Text(tr(context, 'Repeat', 'Lặp lại')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(tr(context, 'Every', 'Mỗi')),
                IconButton(
                  key: const Key('repeat-less'),
                  tooltip: tr(context, 'Fewer', 'Bớt'),
                  onPressed: every > 1 ? () => setState(() => every--) : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('$every', key: const Key('repeat-every')),
                IconButton(
                  key: const Key('repeat-more'),
                  tooltip: tr(context, 'More', 'Thêm'),
                  onPressed: every < 30 ? () => setState(() => every++) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            SegmentedButton<String>(
              key: const Key('repeat-unit'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: 'daily',
                  label: Text(tr(context, 'days', 'ngày')),
                ),
                ButtonSegment(
                  value: 'weekly',
                  label: Text(tr(context, 'weeks', 'tuần')),
                ),
                ButtonSegment(
                  value: 'monthly',
                  label: Text(tr(context, 'months', 'tháng')),
                ),
              ],
              selected: {unit},
              onSelectionChanged: (v) => setState(() => unit = v.first),
            ),
            if (unit == 'weekly') ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      key: Key('repeat-day-$d'),
                      label: Text(names[d - 1]),
                      selected: days.contains(d),
                      onSelected: (v) =>
                          setState(() => v ? days.add(d) : days.remove(d)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(tr(context, 'Ends', 'Kết thúc')),
            RadioGroup<String>(
              groupValue: end,
              onChanged: (v) => setState(() => end = v ?? 'never'),
              child: Column(
                children: [
                  RadioListTile<String>(
                    key: const Key('repeat-end-never'),
                    contentPadding: EdgeInsets.zero,
                    value: 'never',
                    title: Text(tr(context, 'Never', 'Không bao giờ')),
                  ),
                  RadioListTile<String>(
                    key: const Key('repeat-end-date'),
                    contentPadding: EdgeInsets.zero,
                    value: 'date',
                    title: Text(
                      until.isEmpty
                          ? tr(context, 'On a date…', 'Vào ngày…')
                          : tr(context, 'On $until', 'Vào ngày $until'),
                    ),
                    secondary: IconButton(
                      tooltip: tr(context, 'Pick the date', 'Chọn ngày'),
                      onPressed: () async {
                        final v = await pickHandyDate(context, until);
                        if (v != null && mounted) {
                          setState(() {
                            until = v;
                            end = v.isEmpty ? 'never' : 'date';
                          });
                        }
                      },
                      icon: const Icon(Icons.event_outlined),
                    ),
                  ),
                  RadioListTile<String>(
                    key: const Key('repeat-end-count'),
                    contentPadding: EdgeInsets.zero,
                    value: 'count',
                    title: Text(
                      tr(
                        context,
                        'After $left more times',
                        'Sau $left lần nữa',
                      ),
                    ),
                    secondary: IconButton(
                      tooltip: tr(context, 'More times', 'Thêm lần'),
                      onPressed: left < 999
                          ? () => setState(() => left++)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr(context, 'Cancel', 'Huỷ')),
        ),
        FilledButton(
          key: const Key('repeat-save'),
          onPressed: () => Navigator.pop<Json>(context, {
            'repeat': unit,
            'repeatEvery': every == 1 ? null : every,
            'repeatDays': unit == 'weekly' && days.isNotEmpty
                ? (days.toList()..sort())
                : null,
            'repeatUntil': end == 'date' && until.isNotEmpty ? until : null,
            'repeatLeft': end == 'count' ? left : null,
            'repeatedAs': null,
          }),
          child: Text(tr(context, 'Save', 'Lưu')),
        ),
      ],
    );
  }
}
