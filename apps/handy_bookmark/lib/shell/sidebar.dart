import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../design/theme.dart';
import '../collections/share_collection.dart';
import '../data/import_export.dart';
import '../home/collection_covers.dart';
import '../home/home_queues.dart';
import '../home/home_sections.dart';
import '../home/pastel_blocks.dart';
import '../scope.dart';
import '../view/library_view.dart';
import 'places_list.dart';

/// The wide screen's sidebar, as in the chosen mock: the app's name, the
/// Library overview, every place with its count and the collections with
/// their colour, then Trash and Settings at the foot.
class BookmarkSidebar extends StatelessWidget {
  final SaveScope scope;
  final bool overview;
  final VoidCallback onOverview;
  final void Function(Place, [String?]) onPick;
  final ValueChanged<SavedSearch> onSearch;

  /// Folds the sidebar away.
  final VoidCallback? onCollapse;
  const BookmarkSidebar({
    super.key,
    this.onCollapse,
    required this.scope,
    required this.overview,
    required this.onOverview,
    required this.onPick,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = BookmarkPalette.of(context);
    final l = scope.library;
    final live = l.bookmarks.where((b) => !b.isArchived).length;
    Widget foot(
      Key key,
      IconData icon,
      String label,
      VoidCallback onTap, {
      int? n,
    }) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: ListTile(
        key: key,
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BookmarkRadii.item),
        ),
        leading: Icon(icon, size: 20, color: p.muted),
        title: Text(label, style: theme.textTheme.bodyMedium),
        trailing: n == null
            ? null
            : Text(
                '$n',
                style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
              ),
        onTap: onTap,
      ),
    );
    // Below the status bar on a tablet or a phone held sideways.
    return SafeArea(
      right: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/icon.png',
                    width: 28,
                    height: 28,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Handy Bookmark',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onCollapse != null)
                  IconButton(
                    key: const Key('side-collapse'),
                    tooltip: tr(
                      context,
                      'Hide the sidebar',
                      'Thu gọn thanh bên',
                    ),
                    icon: const Icon(Icons.keyboard_double_arrow_left),
                    onPressed: onCollapse,
                  ),
              ],
            ),
          ),
          Expanded(
            // The rows' fills and ripples are painted on this Material,
            // clipped to the list, so a picked row scrolled up never
            // slides over the brand or the status bar.
            child: ClipRect(
              child: Material(
                type: MaterialType.transparency,
                child: ListView(
                  key: const Key('bookmark-sidebar'),
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                  children: [
                    Padding(
                      // The same insets as the places below it, so the
                      // icons and names line up in one column.
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: ListTile(
                        key: const Key('side-overview'),
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: HandySpace.l - 6,
                        ),
                        selected: overview,
                        selectedTileColor: p.band,
                        selectedColor: p.bandInk,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            BookmarkRadii.item,
                          ),
                        ),
                        leading: Icon(
                          Icons.collections_bookmark_outlined,
                          size: 20,
                          color: overview ? p.bandInk : p.muted,
                        ),
                        title: Text(
                          tr(context, 'Library', 'Thư viện'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: overview ? FontWeight.w700 : null,
                            color: overview ? p.bandInk : null,
                          ),
                        ),
                        trailing: Text(
                          formatFigure(context, '$live'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: overview ? p.bandSub : p.muted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        onTap: onOverview,
                      ),
                    ),
                    PlacesList(
                      scope: scope,
                      flat: true,
                      overview: overview,
                      onPick: onPick,
                      onFocus: () => Navigator.pushNamed(context, '/focus'),
                      onSearch: onSearch,
                    ),
                  ],
                ),
              ),
            ),
          ),
          foot(
            const Key('side-trash'),
            Icons.delete_outline,
            tr(context, 'Recently Deleted', 'Thùng rác'),
            () => Navigator.of(context).pushNamed('/trash'),
            n: l.trash.isEmpty ? null : l.trash.length,
          ),
          foot(
            const Key('open-settings'),
            Icons.settings_outlined,
            tr(context, 'Settings', 'Cài đặt'),
            () => Navigator.pushNamed(context, '/settings'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// The Library overview on a wide screen: what waits (Not sorted, Focus)
/// as one slim strip, Read later side by side, then the collections and
/// the newest saves in six columns; each section straight on the ground.
class LibraryOverview extends StatelessWidget {
  final SaveScope scope;
  final ValueChanged<Bookmark> onOpen;
  final void Function(Place, [String?]) onPick;

  /// Collections › See all: every collection, not every save.
  final VoidCallback onAllCollections;
  const LibraryOverview({
    super.key,
    required this.scope,
    required this.onOpen,
    required this.onPick,
    required this.onAllCollections,
  });

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('library-overview'),
    padding: const EdgeInsets.fromLTRB(
      HandySpace.xl,
      0,
      HandySpace.xl,
      HandySpace.xxl,
    ),
    children: [
      // What waits, as one slim strip across the top.
      Padding(
        padding: const EdgeInsets.only(top: HandySpace.s),
        child: HomeQueues(
          scope: scope,
          across: true,
          onFocus: () => Navigator.pushNamed(context, '/focus'),
        ),
      ),
      // Tonight, Tomorrow, This weekend side by side.
      ReadLaterShelf(scope: scope, onOpen: onOpen, across: true),
      CollectionCovers(
        scope: scope,
        limit: 6,
        onAll: onAllCollections,
        onOpen: (c) => onPick(Place.collection, c.id),
      ),
      RecentlySaved(
        scope: scope,
        onOpen: onOpen,
        onAll: () => onPick(Place.all),
        maxColumns: 6,
      ),
    ],
  );
}

/// Every collection as tiles, in the person's own order (Collections ›
/// See all on a wide screen); a tile opens its saves.
class AllCollections extends StatelessWidget {
  final SaveScope scope;
  final void Function(Place, [String?]) onPick;
  const AllCollections({super.key, required this.scope, required this.onPick});

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('all-collections'),
    padding: const EdgeInsets.fromLTRB(
      HandySpace.xl,
      0,
      HandySpace.xl,
      HandySpace.xxl,
    ),
    children: [
      CollectionCovers(
        scope: scope,
        onOpen: (c) => onPick(Place.collection, c.id),
      ),
      const SizedBox(height: HandySpace.l),
      // Sharing with friends: send some collections, add ones sent here.
      Wrap(
        spacing: HandySpace.s,
        runSpacing: HandySpace.s,
        children: [
          if (scope.library.collections.isNotEmpty)
            OutlinedButton.icon(
              key: const Key('collections-send'),
              onPressed: () => scope.sendCollections(context),
              icon: const Icon(Icons.send_rounded, size: 20),
              label: Text(tr(context, 'Send collections', 'Gửi bộ sưu tập')),
            ),
          OutlinedButton.icon(
            key: const Key('collections-receive'),
            onPressed: () => scope.importLinks(context),
            icon: const Icon(Icons.move_to_inbox_outlined, size: 20),
            label: Text(
              tr(
                context,
                'Add collections sent to you',
                'Thêm bộ sưu tập được gửi cho bạn',
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

/// Shown while the sidebar is folded away: brings it back.
class SideReopen extends StatelessWidget {
  final VoidCallback onTap;
  const SideReopen({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('side-open'),
    tooltip: tr(context, 'Show the sidebar', 'Hiện thanh bên'),
    icon: const Icon(Icons.keyboard_double_arrow_right),
    onPressed: onTap,
  );
}
