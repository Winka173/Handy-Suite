import 'package:handy_ui/kit.dart';
import '../specs.dart';
import 'catalog.dart';

/// Tools by the situation people reach for them in; the rare ones wait
/// under More. Text transforms are not here: the bench does them on any
/// pasted text.
const shelfGroups = [
  (
    'Everyday',
    'Hằng ngày',
    ['calculate', 'units', 'dates', 'number-words', 'split-bill'],
  ),
  ('Money', 'Tiền', ['salary', 'qr', 'loan', 'compound']),
  ('Text', 'Văn bản', ['literal-replace']),
  ('More', 'Thêm', ['password', 'draw', 'measure', 'subtitles', 'lunar']),
];

/// Every tool as chips by situation, under the bench on wide screens, so a
/// desktop never shows an empty field and any tool is one click away.
class ToolShelf extends StatelessWidget {
  final ValueChanged<String> onOpen;
  const ToolShelf({super.key, required this.onOpen});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.titleSmall?.copyWith(
      color: HandyColors.of(context).muted,
    );
    // Grey icons: a colour per kind would be a colour per category, and
    // the bench keeps its one colour for the answer.
    Widget chip(String id) => ActionChip(
      key: Key('shelf-$id'),
      avatar: Icon(
        toolIcon(id),
        size: 18,
        color: HandyColors.of(context).muted,
      ),
      label: Text(toolTitle(context, id)),
      onPressed: () => onOpen(id),
    );
    Widget group(String title, List<String> ids) => Padding(
      padding: const EdgeInsets.only(bottom: HandySpace.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(title, style: muted),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: HandySpace.s,
              runSpacing: HandySpace.s,
              children: [for (final id in ids) chip(id)],
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            tr(context, 'All tools', 'Tất cả công cụ'),
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: HandySpace.l),
        for (final (en, vi, ids) in shelfGroups)
          group(tr(context, en, vi), [
            for (final id in ids)
              if (specById[id] != null || generators.any((g) => g.$1 == id)) id,
          ]),
      ],
    );
  }
}
