import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../scope.dart';
import '../ui/visual.dart';
import '../view/library_view.dart';

/// The pictures a collection's cover can be chosen from: its own saves that
/// show one, newest first. Nothing is copied; the cover points at a save.
List<Bookmark> coverCandidates(SaveLibrary l, String collectionId) => [
  for (final b in l.bookmarks)
    if (b.collectionId == collectionId && !b.isArchived && hasPicture(b)) b,
]..sort((a, b) => b.savedAt.compareTo(a.savedAt));

/// Lets the person pick one of the collection's own pictures as its cover,
/// or go back to the automatic one (its newest pictures). Kept as
/// `collectionViews[<id>]['cover']`; a cover whose save is gone falls back
/// to automatic by itself.
Future<void> chooseCover(
  BuildContext context,
  SaveScope scope,
  String collectionId,
) async {
  final v = scope.view;
  final picked = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) => _CoverSheet(scope: scope, id: collectionId),
  );
  if (picked == null || !context.mounted) return;
  await scope.run(
    context,
    () => v.setCollectionView(
      collectionId,
      'cover',
      picked.isEmpty ? null : picked,
    ),
  );
}

class _CoverSheet extends StatelessWidget {
  final SaveScope scope;
  final String id;
  const _CoverSheet({required this.scope, required this.id});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final items = coverCandidates(scope.library, id);
    final chosen = scope.view.chosenCover(id)?.id;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    Widget tile({
      required Key key,
      required bool on,
      required String label,
      required Widget picture,
      required String value,
    }) => Semantics(
      button: true,
      selected: on,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        key: key,
        borderRadius: BorderRadius.circular(BookmarkRadii.item),
        onTap: () => Navigator.pop(context, value),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BookmarkRadii.item + 3),
            border: Border.all(
              color: on ? p.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(BookmarkRadii.item - 2),
                child: picture,
              ),
              if (on)
                PositionedDirectional(
                  top: 6,
                  end: 6,
                  child: CircleAvatar(
                    radius: 13,
                    backgroundColor: p.primary,
                    child: Icon(Icons.check, size: 16, color: p.onPrimary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
        final columns = (box.maxWidth / (150 * scale.clamp(1.0, 1.6)))
            .floor()
            .clamp(2, 5);
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Semantics(
              header: true,
              child: Text(
                tr(context, 'Choose a cover', 'Chọn ảnh bìa'),
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                context,
                'Pick one of the pictures saved here.',
                'Chọn một ảnh đã lưu trong bộ này.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 4 / 3,
              children: [
                tile(
                  key: const Key('cover-auto'),
                  on: chosen == null,
                  label: tr(context, 'Automatic', 'Tự động'),
                  value: '',
                  picture: ColoredBox(
                    color: p.raised,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_mosaic_outlined,
                              color: p.muted,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr(context, 'Automatic', 'Tự động'),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                for (final b in items)
                  tile(
                    key: Key('cover-${b.id}'),
                    on: chosen == b.id,
                    label: b.title.isEmpty ? b.sourceDomain : b.title,
                    value: b.id,
                    picture: ItemPicture(scope.c, b, radius: 0, compact: true),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
