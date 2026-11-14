import 'package:flutter/foundation.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import '../design/theme.dart';
import '../pro/entitlements.dart';
import 'package:handy_ui/kit.dart';
import '../collections/collection_actions.dart';
import '../collections/share_collection.dart';
import '../links/link_actions.dart';
import '../home/collection_covers.dart';
import '../library/place_title.dart';
import '../scope.dart';
import '../ui/capped.dart';
import '../ui/collection_picker.dart';
import '../view/library_view.dart';

/// Every place a save can be found: the fixed views with their counts, the
/// collections as a tree and the tags. Smart collections and saved searches
/// wait under "Advanced", shown once there is one (or with Pro, where new
/// smart collections are made). The sidebar on wide screens; the Library
/// page on a phone, which ends with the Archive (once it holds something)
/// and Recently Deleted, as the sidebar's foot does.
class PlacesList extends StatelessWidget {
  final SaveScope scope;
  final void Function(Place, [String?]) onPick;

  /// Opens Focus; null leaves its row out (the phone's home has its own).
  final VoidCallback? onFocus;

  /// Opens a saved search (its place, words and filters).
  final ValueChanged<SavedSearch> onSearch;

  /// Marks the current place (sidebar); the phone list has none.
  final bool marking;

  /// The wide screen's sidebar: rows straight on the ground, compact, no
  /// boxes; Trash lives at the sidebar's foot instead.
  final bool flat;

  /// The overview is showing: no place is marked.
  final bool overview;

  /// The phone's Library page: the collections as picture tiles, as on
  /// Home, instead of a list.
  final bool tiles;
  const PlacesList({
    super.key,
    required this.scope,
    required this.onPick,
    required this.onSearch,
    this.onFocus,
    this.marking = true,
    this.flat = false,
    this.overview = false,
    this.tiles = false,
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
    final tree = collectionTree(l);
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
      VoidCallback? onSecondary,
      int? hue,
    }) {
      final on =
          marking &&
          !overview &&
          place != null &&
          v.place == place &&
          v.id == id;
      // The chosen place is a rounded pill inset in its row, so the
      // group's hairlines run in the gap and never cross it. In the
      // sidebar it is the pale tint with the teal's dark as ink and a
      // bolder name: the band stays the one deep field on the page.
      final band = flat && on;
      final bp = BookmarkPalette.of(context);
      final picked = theme.brightness == Brightness.dark ? bp.ink : bp.pressed;
      // A wide screen with a pointer shows a row's "…" on hover or focus
      // only, so the names keep their room; touch screens keep it.
      final hover = flat && menu != null && !_touch;
      final shownMenu = hover ? null : menu;
      if (n == 0) n = null;
      final tile = Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: flat ? 1 : 3),
        child: ListTile(
          key: key,
          selected: on,
          dense: flat,
          // The sidebar is a list to scan: 48-point rows (the touch target), 50 apart.
          minTileHeight: flat ? 48 : null,
          selectedTileColor: flat ? bp.tint : c.select,
          selectedColor: flat ? picked : theme.colorScheme.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BookmarkRadii.item),
          ),
          contentPadding: EdgeInsets.only(
            left: HandySpace.l - 6 + indent,
            right: shownMenu == null ? HandySpace.l - 6 : HandySpace.xs,
          ),
          // A collection shows its colour as a dot where the icon would be;
          // the fixed places keep their grey icons.
          leading: hue == null
              ? Icon(
                  icon,
                  size: 20,
                  color: band
                      ? picked
                      : on
                      ? c.selectInk
                      : c.muted,
                )
              : SizedBox(
                  width: 20,
                  child: Center(child: HandyDot(hue, size: 10)),
                ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            // An explicit style sets its own colour, so the picked row's
            // white has to be named here too (selectedColor never reaches it).
            style: flat
                ? theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: on ? FontWeight.w700 : null,
                    color: band ? picked : null,
                  )
                : null,
          ),
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
              ?shownMenu,
            ],
          ),
          onTap: onTap ?? () => onPick(place!, id),
        ),
      );
      return hover
          ? _HoverMenu(menu: menu, onSecondary: onSecondary, child: tile)
          : tile;
    }

    // The sidebar names its groups in a small grey label, as in the mock.
    Widget heading(String text, {Widget? trailing}) => flat
        ? Padding(
            padding: const EdgeInsets.fromLTRB(16, HandySpace.m, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: c.muted,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.only(left: HandySpace.xs),
            child: HandyLabel(text, trailing: trailing),
          );

    // The phone's Library keeps its grouped boxes; the sidebar is flat.
    Widget group({required List<Widget> children}) => flat
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          )
        : HandyGroup(children: children);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        group(
          children: [
            // The sidebar leaves out Everything (the overview's See all)
            // and keeps the Archive at its foot.
            for (final p in [
              Place.inbox,
              if (!flat) Place.all,
              Place.favorites,
              Place.unread,
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
          ],
        ),
        if (tiles)
          CollectionCovers(
            scope: scope,
            cap: 6,
            onOpen: (col) => onPick(Place.collection, col.id),
          )
        else ...[
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
            Capped(
              name: 'collections',
              count: tree.length,
              max: 8,
              // The open collection is never folded away.
              open:
                  marking &&
                  v.place == Place.collection &&
                  tree.indexWhere((e) => e.$1.id == v.id) >= 8,
              builder: (context, shown) => group(
                children: [
                  for (final (col, depth) in tree.take(shown))
                    row(
                      Key('collection-${col.id}'),
                      Icons.folder,
                      col.name,
                      onSecondary: () =>
                          showCollectionQuick(context, scope, col),
                      hue: collectionHue(l, col.id),
                      n: inCollection[col.id] ?? 0,
                      id: col.id,
                      place: Place.collection,
                      indent: depth * 20.0,
                      menu: HandyMenuButton(
                        key: Key('collection-menu-${col.id}'),
                        // Named for its row, so a screen reader does not
                        // hear "More" once per collection.
                        tooltip: tr(
                          context,
                          'Options for ${col.name}',
                          'Tùy chọn cho ${col.name}',
                        ),
                        items: [
                          HandyMenuItem(
                            Icons.send_rounded,
                            tr(context, 'Send to friends', 'Gửi cho bạn bè'),
                            () => scope.shareCollection(context, col.id),
                            key: const Key('collection-send'),
                          ),
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
            ),
        ],
        // The sidebar: the tags as one row that opens their list.
        if (l.tags.isNotEmpty && flat)
          Padding(
            padding: const EdgeInsets.only(top: HandySpace.s),
            child: row(
              const Key('place-tags'),
              Icons.tag,
              tr(context, 'Tags', 'Thẻ'),
              n: l.tags.length,
              onTap: () => _tags(context),
            ),
          ),
        if (l.tags.isNotEmpty && !flat) ...[
          heading(tr(context, 'Tags', 'Thẻ')),
          Capped(
            name: 'tags',
            count: l.tags.length,
            max: 12,
            open:
                marking &&
                v.place == Place.tag &&
                l.tags.indexOf(v.id ?? '') >= 12,
            builder: (context, shown) => Wrap(
              spacing: HandySpace.s,
              runSpacing: HandySpace.s,
              children: [
                for (final t in l.tags.take(shown))
                  InputChip(
                    key: Key('tagplace-$t'),
                    label: Text('#$t'),
                    selected: marking && v.place == Place.tag && v.id == t,
                    showCheckmark: false,
                    onPressed: () => onPick(Place.tag, t),
                    deleteIcon: const Icon(Icons.edit_outlined, size: 16),
                    deleteButtonTooltipMessage: tr(
                      context,
                      'Rename',
                      'Đổi tên',
                    ),
                    onDeleted: () => scope.renameTag(context, t),
                  ),
              ],
            ),
          ),
        ],
        // Smart collections and saved searches are no longer offered to
        // everyone (2026-11-06): no new saved searches are made, and those
        // kept stay here to open, rename or delete. New smart collections
        // are made here only, and only with Pro.
        if (l.smartCollections.isNotEmpty ||
            l.savedSearches.isNotEmpty ||
            hasPro(context)) ...[
          const SizedBox(height: HandySpace.l),
          _Advanced(
            open: marking && v.place == Place.smart,
            children: [
              if (l.smartCollections.isNotEmpty || l.savedSearches.isNotEmpty)
                group(
                  children: [
                    for (final s in l.smartCollections)
                      row(
                        Key('smart-${s.id}'),
                        Icons.auto_awesome_outlined,
                        s.name,
                        id: s.id,
                        place: Place.smart,
                        menu: HandyMenuButton(
                          tooltip: tr(
                            context,
                            'Options for ${s.name}',
                            'Tùy chọn cho ${s.name}',
                          ),
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
                          tooltip: tr(
                            context,
                            'Options for ${s.name}',
                            'Tùy chọn cho ${s.name}',
                          ),
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
        // The phone's Library ends as the sidebar does: the Archive once
        // it holds something, and Recently Deleted always.
        if (!flat) ...[
          const SizedBox(height: HandySpace.l),
          group(
            children: [
              if (count(Place.archive) > 0)
                row(
                  const Key('place-archive'),
                  placeIcon(Place.archive),
                  placeTitle(context, l, Place.archive, null),
                  n: count(Place.archive),
                  place: Place.archive,
                ),
              row(
                const Key('place-trash'),
                Icons.delete_outline,
                tr(context, 'Recently Deleted', 'Thùng rác'),
                n: l.trash.length,
                onTap: () => Navigator.of(context).pushNamed('/trash'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Every tag in a sheet: tap one to see its saves, or rename it.
  Future<void> _tags(BuildContext context) {
    final l = scope.library;
    final v = scope.view;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (sheet) => ListView(
        key: const Key('tags-sheet'),
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: HandySpace.l),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, HandySpace.s),
            child: Text(
              tr(sheet, 'Tags', 'Thẻ'),
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
          ),
          for (final t in l.tags)
            ListTile(
              key: Key('tagplace-$t'),
              selected: v.place == Place.tag && v.id == t,
              leading: const Icon(Icons.tag),
              title: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                tooltip: tr(sheet, 'Rename #$t', 'Đổi tên #$t'),
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  Navigator.pop(sheet);
                  scope.renameTag(context, t);
                },
              ),
              onTap: () {
                Navigator.pop(sheet);
                onPick(Place.tag, t);
              },
            ),
        ],
      ),
    );
  }
}

/// Phones and tablets without a pointer keep every row's "…" in view.
bool get _touch =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// A sidebar row whose "…" shows while the pointer is over the row or
/// anything in it has keyboard focus (Tab still reaches it), laid over the
/// row's right end so the name keeps its room. A right-click opens the
/// collection's quick actions.
class _HoverMenu extends StatefulWidget {
  final Widget child;
  final Widget? menu;
  final VoidCallback? onSecondary;
  const _HoverMenu({required this.child, this.menu, this.onSecondary});
  @override
  State<_HoverMenu> createState() => _HoverMenuState();
}

class _HoverMenuState extends State<_HoverMenu> {
  bool hover = false, focus = false;
  @override
  Widget build(BuildContext context) {
    final shown = hover || focus;
    final p = BookmarkPalette.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (f) => setState(() => focus = f),
        child: GestureDetector(
          onSecondaryTap: widget.onSecondary,
          child: Stack(
            children: [
              widget.child,
              PositionedDirectional(
                end: 10,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: !shown,
                  child: Opacity(
                    opacity: shown ? 1 : 0,
                    child: Center(
                      child: Material(
                        color: p.raised,
                        shape: const CircleBorder(),
                        child: widget.menu,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
