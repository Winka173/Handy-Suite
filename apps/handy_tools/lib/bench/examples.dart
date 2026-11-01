import 'package:handy_ui/kit.dart';
import '../specs.dart';

/// The empty bench: entries to try with one tap, then pinned tools.
class BenchExamples extends StatelessWidget {
  final ValueChanged<String> onPick;
  final List<String> pinned;
  final ValueChanged<String> onOpenTool;
  final VoidCallback onOpenCatalog;
  const BenchExamples({
    required this.onPick,
    required this.pinned,
    required this.onOpenTool,
    required this.onOpenCatalog,
  });
  @override
  Widget build(BuildContext context) {
    final examples = [
      '1.385.000 / 3',
      tr(context, '5 km to mi', '5 km sang mi'),
      tr(context, '15% of 2,400,000', '15% của 2.400.000'),
      tr(context, '2026-12-31 to today', '2026-12-31 đến hôm nay'),
      '#E8590C',
    ];
    final muted = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: HandyColors.of(context).muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, 'Try', 'Thử gõ'), style: muted),
        const SizedBox(height: HandySpace.s),
        Wrap(
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          children: [
            for (final e in examples)
              ActionChip(
                key: Key('example-$e'),
                label: Text(e),
                onPressed: () => onPick(e),
              ),
          ],
        ),
        const SizedBox(height: HandySpace.xl),
        Text(
          pinned.isEmpty
              ? tr(context, 'Or pick a tool', 'Hoặc chọn công cụ')
              : tr(context, 'Pinned', 'Đã ghim'),
          style: muted,
        ),
        const SizedBox(height: HandySpace.s),
        Wrap(
          spacing: HandySpace.s,
          runSpacing: HandySpace.s,
          children: [
            for (final id in pinned)
              if (specById[id] != null)
                ActionChip(
                  key: Key('pinned-$id'),
                  avatar: Icon(
                    specById[id]!.icon,
                    size: 18,
                    color: HandyColors.of(context).muted,
                  ),
                  label: Text(specById[id]!.title(context)),
                  onPressed: () => onOpenTool(id),
                ),
            ActionChip(
              key: const Key('examples-all-tools'),
              avatar: Icon(
                Icons.apps,
                size: 18,
                color: HandyColors.of(context).muted,
              ),
              label: Text(tr(context, 'All tools', 'Tất cả công cụ')),
              onPressed: onOpenCatalog,
            ),
          ],
        ),
      ],
    );
  }
}
