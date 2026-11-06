import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import 'package:handy_monetization/handy_monetization.dart';
import '../collections/collection_actions.dart';
import '../links/link_actions.dart';
import '../library/place_title.dart';
import '../scope.dart';
import '../ui/collection_picker.dart';
import '../view/library_view.dart';

/// Every place a save can be found: the fixed views with their counts, the
/// collections as a tree and the tags. Smart collections and saved searches
/// wait under "Advanced", shown once there is one (or with Pro, where new
/// smart collections are made). The sidebar on wide screens; the Library
/// page on a phone.
class PlacesList extends StatelessWidget {
  final SaveScope scope;
  final void Function(Place, [String?]) onPick;

  /// Opens Focus; null leaves its row out (the phone's home has its own).
  final VoidCallback? onFocus;

  /// Opens a saved search (its place, words and filters).
  final ValueChanged<SavedSearch> onSearch;

  /// Marks the current place (sidebar); the phone list has none.
  final bool marking;
  const PlacesList({
    super.key,
    required this.scope,
    required this.onPick,
    required this.onSearch,
    this.onFocus,
    this.marking = true,
  });

  @override
  Widget build(BuildContext context) {
    final l = scope.library;
    final v = scope.view;
    final c = HandyColors.of(context);
    final theme = Theme.of(context);
    final live = [
      for (final b in l.bookmarks)
        if (!b.isArchived) b,
    ];
    int count(Place p) => switch (p) {
      Place.inbox => live.where((b) => b.collectionId == null).length,
      Place.all => live.length,
      Place.favorites => live.where((b) => b.isFavorite).length,
      Place.unread => live.where((b) => !b.isRead).length,
      Place.archive => l.bookmarks.length - live.length,
      Place.broken =>
        l.bookmarks.where((b) => b.linkCheck?.broken ?? false).length,
      _ => 0,
    };
    final inCollection = <String, int>{};
    for (final b in live) {
      if (b.collectionId != null)
        inCollection[b.collectionId!] =
            (inCollection[b.collectionId!] ?? 0) + 1;
    }
    Widget row(
      Key key,
      IconData icon,
      String title, {
      int? n,
      String? id,
      Place? place,
      double indent = 0,
      Widget? menu,
      VoidCallback? onTap,
      int? hue,
    }) {
      final on = marking && place != null && v.place == place && v.id == id;
      return ListTile(
        key: key,
        selected: on,
        selectedTileColor: c.select,
        selectedColor: theme.colorScheme.onSurface,
        contentPadding: EdgeInsets.only(
          left: HandySpace.l + indent,
          right: menu == null ? HandySpace.l : HandySpace.xs,
        ),
        // A collection shows its colour as a dot where the icon would be;
        // the fixed places keep their grey icons.
        leading: hue == null
            ? Icon(icon, size: 20, color: on ? c.selectInk : c.muted)
            : SizedBox(
                width: 20,
                child: Center(child: HandyDot(hue, size: 10)),
              ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (n != null)
              Text(
                '$n',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: c.muted,
                  fontFeatures: tabular,
                ),
              ),
            ?menu,
          ],
        ),
        onTap: onTap ?? () => onPick(place!, id),
      );
    }

    Widget heading(String text, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.only(left: HandySpace.xs),
      child: HandyLabel(text, trailing: trailing),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HandyGroup(
          children: [
            for (final p in [
              Place.inbox,
              Place.all,
              Place.favorites,
              Place.unread,
              Place.archive,
              // Only once a check has found something.
              if (count(Place.broken) > 0) Place.broken,
            ])
              row(
                Key('place-${p.name}'),
                placeIcon(p),
                placeTitle(context, l, p, null),
                n: count(p),
                place: p,
              ),
            if (onFocus != null)
              row(
                const Key('place-focus'),
                Icons.center_focus_strong_outlined,
                tr(context, 'Focus', 'Tập trung'),
                onTap: onFocus,
              ),
            // Only while something is waiting there.
            if (l.trash.isNotEmpty)
              row(
                const Key('place-trash'),
                Icons.delete_outline,
                tr(context, 'Recently Deleted', 'Thùng rác'),
                n: l.trash.length,
                onTap: () => Navigator.of(context).pushNamed('/trash'),
              ),
          ],
        ),
        heading(
          tr(context, 'Collections', 'Bộ sưu tập'),
          trailing: IconButton(
            key: const Key('collection-new'),
            tooltip: tr(context, 'New collection', 'Bộ sưu tập mới'),
            icon: const Icon(Icons.add),
            onPressed: () => scope.editCollection(context),
          ),
        ),
        if (l.collections.isEmpty)
          Text(
            tr(
              context,
              'Group links by topic: Recipes, Trips, To buy…',
              'Gom link theo chủ đề: Công thức, Du lịch, Cần mua…',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
          )
        else
          HandyGroup(
            children: [
              for (final (col, depth) in collectionTree(l))
                row(
                  Key('collection-${col.id}'),
                  Icons.folder,
                  col.name,
                  hue: collectionHue(l, col.id),
                  n: inCollection[col.id] ?? 0,
                  id: col.id,
                  place: Place.collection,
                  indent: depth * 20.0,
                  menu: HandyMenuButton(
                    key: Key('collection-menu-${col.id}'),
                    items: [
                      HandyMenuItem(
                        Icons.edit_outlined,
                        tr(context, 'Edit', 'Sửa'),
                        () => scope.editCollection(context, col),
                        key: const Key('collection-edit'),
                      ),
                      HandyMenuItem(
                        Icons.delete_outline,
                        tr(context, 'Delete', 'Xóa'),
                        () async {
                          if (await scope.deleteCollection(context, col) &&
                              v.place == Place.collection &&
                              v.id == col.id)
                            onPick(Place.all);
                        },
                        key: const Key('collection-delete'),
                        destructive: true,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        if (l.tags.isNotEmpty) ...[
          heading(tr(context, 'Tags', 'Thẻ')),
          Wrap(
            spacing: HandySpace.s,
            runSpacing: HandySpace.s,
            children: [
              for (final t in l.tags)
                InputChip(
                  key: Key('tagplace-$t'),
                  label: Text('#$t'),
                  selected: marking && v.place == Place.tag && v.id == t,
                  showCheckmark: false,
                  onPressed: () => onPick(Place.tag, t),
                  deleteIcon: const Icon(Icons.edit_outlined, size: 16),
                  deleteButtonTooltipMessage: tr(context, 'Rename', 'Đổi tên'),
                  onDeleted: () => scope.renameTag(context, t),
                ),
            ],
          ),
        ],
        // Smart collections and saved searches are no longer offered to
        // everyone (2026-11-06): no new saved searches are made, and those
        // kept stay here to open, rename or delete. New smart collections
        // are made here only, and only with Pro.
        if (l.smartCollections.isNotEmpty ||
            l.savedSearches.isNotEmpty ||
            LifetimeScope.maybeOf(context)?.pro == true) ...[
          const SizedBox(height: HandySpace.l),
          _Advanced(
            open: marking && v.place == Place.smart,
            children: [
              if (l.smartCollections.isNotEmpty || l.savedSearches.isNotEmpty)
                HandyGroup(
                  children: [
                    for (final s in l.smartCollections)
                      row(
                        Key('smart-${s.id}'),
                        Icons.auto_awesome_outlined,
                        s.name,
                        id: s.id,
                        place: Place.smart,
                        menu: HandyMenuButton(
                          items: [
                            HandyMenuItem(
                              Icons.edit_outlined,
                              tr(context, 'Edit', 'Sửa'),
                              () => scope.editSmart(context, s),
                            ),
                            HandyMenuItem(
                              Icons.delete_outline,
                              tr(context, 'Delete', 'Xóa'),
                              () => scope.deleteSmart(context, s),
                              destructive: true,
                            ),
                          ],
                        ),
                      ),
                    for (final s in l.savedSearches)
                      row(
                        Key('search-${s.id}'),
                        Icons.saved_search,
                        s.name,
                        onTap: () => onSearch(s),
                        menu: HandyMenuButton(
                          key: Key('search-menu-${s.id}'),
                          items: [
                            HandyMenuItem(
                              Icons.edit_outlined,
                              tr(context, 'Rename', 'Đổi tên'),
                              () => scope.renameSaved(context, s),
                              key: const Key('search-rename'),
                            ),
                            HandyMenuItem(
                              Icons.delete_outline,
                              tr(context, 'Delete', 'Xóa'),
                              () => scope.deleteSaved(context, s),
                              key: const Key('search-delete'),
                              destructive: true,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const Key('smart-new'),
                  onPressed: () => scope.editSmart(context),
                  icon: const Icon(Icons.add),
                  label: Text(
                    tr(
                      context,
                      'New smart collection',
                      'Bộ sưu tập thông minh mới',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A quiet disclosure for the lists the person kept by rules or by search.
class _Advanced extends StatelessWidget {
  final bool open;
  final List<Widget> children;
  const _Advanced({required this.open, required this.children});
  @override
  Widget build(BuildContext context) {
    final c = HandyColors.of(context);
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const Key('library-advanced'),
        initiallyExpanded: open,
        tilePadding: const EdgeInsets.symmetric(horizontal: HandySpace.xs),
        childrenPadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        title: Text(
          tr(context, 'Advanced', 'Nâng cao'),
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          tr(
            context,
            'Smart collections and saved searches',
            'Bộ sưu tập thông minh và tìm kiếm đã lưu',
          ),
          style: theme.textTheme.bodySmall?.copyWith(color: c.muted),
        ),
        children: children,
      ),
    );
  }
}
