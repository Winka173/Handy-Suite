import 'package:handy_ui/kit.dart';
import '../specs.dart';
import 'catalog.dart' show toolIcon, toolTitle;

/// The empty bench: entries to try with one tap, then pinned tools.
class BenchExamples extends StatelessWidget {
  final ValueChanged<String> onPick;
  final List<String> pinned, recent;
  final ValueChanged<String> onOpenTool;
  final VoidCallback onOpenCatalog;
  const BenchExamples({
    required this.onPick,
    required this.pinned,
    this.recent = const [],
    required this.onOpenTool,
    required this.onOpenCatalog,
  });
  @override
  Widget build(BuildContext context) {
    // Everyday situations, each a sentence the bench reads as typed.
    final examples = [
      tr(context, '1,000,000 + VAT 10%', '1.000.000 + VAT 10%'),
      tr(context, '2,400,000 - 15% - 5%', '2.400.000 - 15% - 5%'),
      tr(context, '120 to 150', '120 lên 150'),
      tr(context, '1,350,000 tip 10% split 3', '1.350.000 tip 10% chia 3'),
      tr(context, 'gross 25,000,000', 'lương 25.000.000'),
      tr(context, '5 km to mi', '5 km sang mi'),
      tr(context, '2026-12-31 to today', '2026-12-31 đến hôm nay'),
      tr(context, '1,250,000 in words', '1.250.000 bằng chữ'),
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
        if (recent.isNotEmpty) ...[
          const SizedBox(height: HandySpace.xl),
          Text(tr(context, 'Recent', 'Gần đây'), style: muted),
          const SizedBox(height: HandySpace.s),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              for (final id in recent.take(5))
                ActionChip(
                  key: Key('recent-$id'),
                  avatar: Icon(
                    toolIcon(id),
                    size: 18,
                    color: HandyColors.of(context).muted,
                  ),
                  label: Text(toolTitle(context, id)),
                  onPressed: () => onOpenTool(id),
                ),
            ],
          ),
        ],
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
            for (final id in {for (final p in pinned) canonicalToolId(p)})
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
