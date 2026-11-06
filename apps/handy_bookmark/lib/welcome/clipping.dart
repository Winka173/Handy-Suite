import 'package:handy_ui/kit.dart';

/// A saved thing drawn as a newspaper clipping: a headline in the title
/// face over an ink rule, and the source in words underneath. The guide's
/// one motif; the person's real first save is drawn the same way.
class Clipping extends StatelessWidget {
  final String title, source;
  final Widget? picture;

  /// Marks a screenshot or photo when there is no picture to show.
  final bool screenshot;
  final double width;
  const Clipping({
    super.key,
    required this.title,
    required this.source,
    this.picture,
    this.screenshot = false,
    this.width = 264,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(height: 1.2),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: HandySpace.xs),
          height: 1,
          color: theme.colorScheme.onSurface,
        ),
        Row(
          children: [
            if (screenshot) ...[
              Icon(Icons.image_outlined, size: 14, color: c.muted),
              const SizedBox(width: HandySpace.xs),
            ],
            Expanded(
              child: Text(
                source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
              ),
            ),
          ],
        ),
      ],
    );
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(
        HandySpace.m,
        HandySpace.s,
        HandySpace.m,
        HandySpace.s,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(HandyRadius.card),
      ),
      child: picture == null
          ? text
          : Row(
              children: [
                picture!,
                const SizedBox(width: HandySpace.m),
                Expanded(child: text),
              ],
            ),
    );
  }
}

/// The four sample saves the story uses: the kinds of things people keep,
/// from the apps they keep them in. Illustration only; never saved.
List<({String title, String source, bool screenshot})> sampleClippings(
  BuildContext context,
) => [
  (
    title: tr(context, 'Noodle salad in 15 minutes', 'Bún chả trong 15 phút'),
    source: tr(context, 'TikTok · 3 weeks ago', 'TikTok · 3 tuần trước'),
    screenshot: false,
  ),
  (
    title: tr(context, 'Running shoes, size 42', 'Giày chạy bộ size 42'),
    source: tr(context, 'Shopee · last month', 'Shopee · tháng trước'),
    screenshot: false,
  ),
  (
    title: tr(
      context,
      'Your first guitar chords',
      'Học guitar: hợp âm đầu tiên',
    ),
    source: tr(context, 'YouTube · in March', 'YouTube · hồi tháng 3'),
    screenshot: false,
  ),
  (
    title: tr(context, 'Night train timetable', 'Lịch tàu Hà Nội – Huế'),
    source: tr(context, 'Screenshot · Photos', 'Ảnh chụp màn hình · Ảnh'),
    screenshot: true,
  ),
];
