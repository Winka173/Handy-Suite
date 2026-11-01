import 'package:handy_ui/kit.dart';
import '../specs.dart';
import 'catalog.dart';

/// Every tool as chips by kind, under the bench on wide screens, so a
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
    Widget chip(String id) => ActionChip(
      key: Key('shelf-$id'),
      avatar: Icon(toolIcon(id), size: 18),
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
        group(tr(context, 'Make', 'Tạo mới'), [
          for (final g in generators) g.$1,
        ]),
        for (final k in Category.values)
          group(categoryLabel(context, k), [
            for (final s in specs.where((s) => s.category == k)) s.id,
          ]),
      ],
    );
  }
}
