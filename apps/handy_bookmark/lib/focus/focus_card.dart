import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../scope.dart';
import '../ui/words.dart';

/// One saved thing in the Focus deck: its picture, title, where it came
/// from, a few lines of its description, and Open.
class FocusCard extends StatelessWidget {
  final SaveScope scope;
  final Bookmark bookmark;
  const FocusCard({super.key, required this.scope, required this.bookmark});
  @override
  Widget build(BuildContext context) {
    final b = bookmark;
    final theme = Theme.of(context);
    final c = HandyColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(HandyRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(HandySpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => LinkThumb(
                  scope.c,
                  b,
                  size: box.maxWidth,
                  height: box.maxHeight,
                ),
              ),
            ),
            const SizedBox(height: HandySpace.l),
            Semantics(
              header: true,
              child: Text(
                b.title.isNotEmpty
                    ? b.title
                    : b.isImage
                    ? tr(context, 'Picture', 'Ảnh')
                    : b.sourceDomain,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: HandySpace.xs),
            Text(
              '${b.isImage ? tr(context, 'Picture', 'Ảnh') : sourceLine(b)} · ${tr(context, 'saved', 'lưu')} ${ago(context, b.savedAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
            ),
            if ((b.description ?? '').isNotEmpty) ...[
              const SizedBox(height: HandySpace.s),
              Text(
                b.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: HandySpace.l),
            OutlinedButton.icon(
              key: const Key('focus-open'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () => scope.open(context, b),
              icon: Icon(b.hasUrl ? Icons.open_in_new : Icons.image_outlined),
              label: Text(
                b.hasUrl
                    ? tr(context, 'Open original', 'Mở bản gốc')
                    : tr(context, 'View picture', 'Xem ảnh'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The word that appears on the card while it is dragged toward a side.
class SwipeLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  final double opacity;
  const SwipeLabel({
    super.key,
    required this.text,
    required this.icon,
    required this.opacity,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: opacity.clamp(0, 1),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HandySpace.m,
          vertical: HandySpace.s,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface,
          borderRadius: BorderRadius.circular(HandyRadius.control),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.surface),
            const SizedBox(width: HandySpace.xs),
            Text(
              text,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
