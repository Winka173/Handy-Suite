import 'package:handy_media_engine/handy_media_engine.dart';
import 'package:handy_ui/kit.dart';
import '../guide/film_frame.dart';

/// One guide: its name, what kind and how long, and its steps as film.
class GuideCard extends StatelessWidget {
  final PortableCapture guide;
  final VoidCallback? onOpen, onDelete;
  const GuideCard({
    super.key,
    required this.guide,
    required this.onOpen,
    required this.onDelete,
  });

  static String kindName(BuildContext context, String kind) => switch (kind) {
    'bug' => tr(context, 'Bug report', 'Báo lỗi'),
    'comparison' => tr(context, 'Comparison', 'So sánh'),
    _ => tr(context, 'How-to', 'Hướng dẫn'),
  };

  @override
  Widget build(BuildContext context) {
    final p = guide.project;
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final shown = p.steps.take(8).toList();
    final edited = DateTime.tryParse(p.updatedAt)?.toLocal();
    final days = edited == null
        ? null
        : DateTime(edited.year, edited.month, edited.day)
              .difference(
                DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day,
                ),
              )
              .inDays;
    final meta = [
      tr(context, '${p.steps.length} steps', '${p.steps.length} bước'),
      kindName(context, p.kind),
      if (days != null)
        days > -7
            ? relativeDays(context, days)
            : formatDay(context, p.updatedAt),
      ...p.tags.take(3),
    ].join(' · ');
    return Material(
      color: c.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('guide-${p.id}'),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            HandySpace.l,
            HandySpace.s,
            HandySpace.xs,
            HandySpace.l,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title.isEmpty
                              ? tr(
                                  context,
                                  'Untitled guide',
                                  'Hướng dẫn chưa đặt tên',
                                )
                              : p.title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          meta,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: c.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  HandyMenuButton(
                    items: [
                      HandyMenuItem(
                        Icons.delete_outline,
                        tr(context, 'Delete guide', 'Xóa hướng dẫn'),
                        onDelete,
                        destructive: true,
                        key: Key('guide-delete-${p.id}'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: HandySpace.m),
              if (p.steps.isEmpty)
                Text(
                  tr(context, 'No steps yet', 'Chưa có bước nào'),
                  style: theme.textTheme.bodyMedium,
                )
              else
                LayoutBuilder(
                  builder: (context, box) {
                    // Eight frames fill a wide card; never smaller than 112.
                    final frame = ((box.maxWidth - 7 * HandySpace.s) / 8).clamp(
                      112.0,
                      200.0,
                    );
                    return SizedBox(
                      height: frame * .62 + 2,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: shown.length + (p.steps.length > 8 ? 1 : 0),
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: HandySpace.s),
                        itemBuilder: (_, i) => i == shown.length
                            ? Center(
                                child: Text(
                                  '+${p.steps.length - 8}',
                                  style: theme.textTheme.titleMedium,
                                ),
                              )
                            : ExcludeSemantics(
                                child: FilmFrame(
                                  number: i + 1,
                                  width: frame,
                                  picture: guide.assets[shown[i].imageUri],
                                  step: shown[i],
                                ),
                              ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
