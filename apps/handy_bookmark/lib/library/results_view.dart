import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import '../pro/entitlements.dart';
import '../pro/layout_picker.dart';
import '../pro/layouts.dart';
import 'package:handy_ui/kit.dart';
import '../collections/collection_actions.dart';
import '../collections/identity.dart';
import '../ui/collection_picker.dart';
import '../collections/cover_chooser.dart';
import '../collections/share_collection.dart';
import '../controller.dart';
import '../links/link_actions.dart';
import '../links/task_strip.dart';
import '../scope.dart';
import '../view/library_view.dart';
import 'bookmark_tile.dart';
import 'filter_sheet.dart';
import 'link_card.dart';
import 'place_title.dart';
import '../design/theme.dart';
import '../ui/put_in.dart';
import '../ui/view_toggle.dart';
import '../ui/visual.dart';

/// The links of the current place, as rows or cards. More load as the end
/// comes into view; a new place or filter fades the list over.
class ResultsView extends StatelessWidget {
  final SaveScope scope;
  SaveController get controller => scope.c;
  LibraryView get view => scope.view;
  final String? current;
  final ValueChanged<Bookmark> onDetails;
  final VoidCallback onAdd;
  final List<Widget> leading;

  /// Shown after the results (Search's matches found inside items).
  final List<Widget> trailing;

  /// The side margin; a wide screen matches the header band above it.
  final double inset;
  const ResultsView({
    this.inset = HandySpace.l,
    super.key,
    required this.scope,
    required this.onDetails,
    required this.onAdd,
    this.current,
    this.leading = const [],
    this.trailing = const [],
  });

  /// Cards or rows: the collection's own choice, else the app's.
  /// A Pro layout chosen here (the collection's own, else the app's).
  String? get layout {
    final v = view;
    final own = v.place == Place.collection && v.id != null
        ? v.collectionView(v.id!)['layout']
        : null;
    final id = own ?? controller.preferences['layout'];
    return id is String ? id : null;
  }

  /// Each list keeps its own choice: a collection on itself, a fixed place
  /// (Not sorted, Favourites…) in the app's preferences; else the app's.
  bool get cards {
    final v = view;
    // Broken links stay rows: each says what went wrong.
    if (v.place == Place.broken) return false;
    final own = v.place == Place.collection && v.id != null
        ? v.collectionView(v.id!)['cards']
        : controller.preferences['cards:${v.place.name}'];
    // Cards unless the person chose rows.
    return own is bool ? own : controller.preferences['cards'] != false;
  }

  /// A Pro layout is showing instead of cards or rows.
  bool premium(BuildContext context) =>
      layoutById(layout) != null && hasPro(context);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: view,
    builder: (context, _) {
      final v = view;
      final theme = Theme.of(context);
      final c = HandyColors.of(context);
      final rows = v.results;
      final children = v.place == Place.collection && v.id != null
          ? ([
              for (final c in controller.library!.collections)
                if (c.parentId == v.id) c,
            ]..sort((a, b) => a.position.compareTo(b.position)))
          : const <SaveCollection>[];
      final header = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...leading,
          TaskStrip(
            tasks: scope.tasks,
            onBroken: () {
              scope.tasks.dismiss();
              v.show(Place.broken);
            },
          ),
          // On a phone the name gets the whole width and the tools sit
          // under it; on wider screens they share one row.
          LayoutBuilder(
            builder: (context, box) {
              final tools = _tools(context);
              final title = Row(
                children: [
                  // A collection opens with its face: its newest picture beside
                  // its name, set in the library's serif.
                  if (v.place == Place.collection && rows.isNotEmpty)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 14),
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: ItemPicture(
                          controller,
                          v.chosenCover(v.id!) ??
                              rows.firstWhere(
                                hasPicture,
                                orElse: () => rows.first,
                              ),
                          radius: 18,
                          compact: true,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            placeTitle(
                              context,
                              controller.library!,
                              v.place,
                              v.id,
                            ),
                            style: v.place == Place.collection
                                ? bookmarkSerif(context, 26)
                                : theme.textTheme.headlineSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          // A search says how many it found, not how many
                          // the place holds.
                          v.text.trim().isNotEmpty || v.filters.narrows
                              ? tr(
                                  context,
                                  '${formatFigure(context, '${v.total}')} found',
                                  '${formatFigure(context, '${v.total}')} kết quả',
                                )
                              : [
                                  tr(
                                    context,
                                    '${formatFigure(context, '${v.total}')} saved',
                                    '${formatFigure(context, '${v.total}')} mục',
                                  ),
                                  if (children.isNotEmpty)
                                    tr(
                                      context,
                                      children.length == 1
                                          ? '1 folder'
                                          : '${children.length} folders',
                                      '${children.length} thư mục',
                                    ),
                                ].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: c.muted,
                            fontFeatures: tabular,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              // Side by side only where the column itself has the room (not
              // beside the open item on a narrower window).
              if (box.maxWidth >= 640)
                return Row(
                  children: [
                    Expanded(child: title),
                    ...tools,
                  ],
                );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: HandySpace.xs),
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: tools,
                  ),
                ],
              );
            },
          ),
          // This collection's folders, to step into.
          if (children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: HandySpace.s),
              child: SingleChildScrollView(
                key: const Key('sub-collections'),
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    for (final sub in children)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: HandySpace.s,
                        ),
                        child: ActionChip(
                          key: Key('sub-${sub.id}'),
                          avatar: CollectionBadge(
                            hue: collectionHue(controller.library!, sub.id),
                            mark: markOf(sub.icon),
                            size: 8,
                          ),
                          label: Text(sub.name),
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/collection/${sub.id}',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (v.filters.narrows) FilterChips(view: v),
          const SizedBox(height: HandySpace.s),
        ],
      );
      Widget body;
      if (v.loading) {
        body = const Padding(
          padding: EdgeInsets.all(HandySpace.xl),
          child: LinearProgressIndicator(),
        );
      } else if (v.failed) {
        body = HandyNotice(
          tr(
            context,
            'Could not read this list. Your links are safe.',
            'Chưa đọc được danh sách này. Link của bạn vẫn an toàn.',
          ),
          tone: HandyTone.error,
          action: TextButton(
            onPressed: v.reload,
            child: Text(tr(context, 'Try again', 'Thử lại')),
          ),
        );
      } else if (rows.isEmpty) {
        body = _empty(context);
      } else if (layoutById(layout) case final premium? when hasPro(context)) {
        body = premium.build(
          context,
          LayoutData(
            controller: controller,
            rows: rows,
            selected: v.selected,
            onOpen: onDetails,
            onDetails: onDetails,
            onToggle: (b) => v.toggle(b.id),
          ),
        );
      } else if (cards) {
        body = LayoutBuilder(
          builder: (context, box) {
            // Two photo-forward cards a row on a phone; one when the screen
            // is narrow or the text is large; more as the window widens.
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            const gap = 12.0;
            // Wider cards beside the open item, so a title keeps its two
            // lines instead of ending in an ellipsis after three words.
            final least = box.maxWidth >= 600 ? 200 : 165;
            final columns = (box.maxWidth / (least * scale.clamp(1.0, 2.0)))
                .floor()
                .clamp(1, 6);
            final width = (box.maxWidth - gap * (columns - 1)) / columns;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                mainAxisExtent: width / 1.28 + 82 * scale.clamp(1.0, 2.2),
              ),
              itemCount: rows.length,
              itemBuilder: (context, i) => HandyAppear(
                key: ValueKey('in-${rows[i].id}'),
                child: LinkCard(
                  controller: controller,
                  bookmark: rows[i],
                  putIn: _putIn(rows[i]),
                  selected: v.selected.contains(rows[i].id),
                  selecting: v.selecting,
                  onOpen: () => onDetails(rows[i]),
                  onDetails: () => onDetails(rows[i]),
                  onToggle: () => v.toggle(rows[i].id),
                ),
              ),
            );
          },
        );
      } else {
        body = HandyGroup(
          children: [
            for (final b in rows)
              BookmarkTile(
                controller: controller,
                bookmark: b,
                putIn: _putIn(b),
                selecting: v.selecting,
                selected: v.selected.contains(b.id),
                current: b.id == current,
                onOpen: () => onDetails(b),
                onDetails: () => onDetails(b),
                onToggle: () => v.toggle(b.id),
              ),
          ],
        );
      }
      return NotificationListener<ScrollEndNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 600) v.more();
          return false;
        },
        child: ListView(
          key: const Key('save-results'),
          padding: EdgeInsets.fromLTRB(inset, HandySpace.l, inset, 96),
          children: [
            header,
            HandySwap(
              child: KeyedSubtree(
                key: ValueKey('${v.place}-${v.id}-$cards'),
                child: body,
              ),
            ),
            if (rows.isNotEmpty && rows.length < v.total)
              Padding(
                padding: const EdgeInsets.all(HandySpace.l),
                child: Center(
                  child: TextButton(
                    key: const Key('save-more'),
                    onPressed: v.more,
                    child: Text(tr(context, 'Show more', 'Xem thêm')),
                  ),
                ),
              ),
            ...trailing,
          ],
        ),
      );
    },
  );

  /// Not sorted: each save carries its own "Put in" while nothing is
  /// being selected.
  Widget? _putIn(Bookmark b) =>
      view.place == Place.inbox && b.collectionId == null && !view.selecting
      ? PutIn(controller: controller, bookmark: b, onFile: scope.file)
      : null;

  /// Rows or cards, the order and the filters in words, then everything
  /// else for this list in one labelled sheet (the "…").
  List<Widget> _tools(BuildContext context) {
    final v = view;
    return [
      if (v.place != Place.broken)
        Padding(
          padding: const EdgeInsetsDirectional.only(end: HandySpace.xs),
          child: ViewToggle(
            cards: premium(context) ? null : cards,
            onChanged: (asCards) => _chooseLayout(null, asCards: asCards),
          ),
        ),
      SortButton(view: v),
      TextButton.icon(
        key: const Key('save-filters'),
        icon: const Icon(Icons.tune, size: 20),
        label: Text(
          v.filters.narrows
              ? tr(context, 'Filtered', 'Đang lọc')
              : tr(context, 'Filter', 'Lọc'),
        ),
        onPressed: () => showFilterSheet(context, controller.library!, v),
      ),
      IconButton(
        key: const Key('list-more'),
        tooltip: tr(context, 'More for this list', 'Tùy chọn danh sách'),
        icon: const Icon(Icons.more_horiz),
        onPressed: () => _options(context),
      ),
    ];
  }

  /// The list's options as a sheet of labelled rows: how it looks first,
  /// then (in a collection) the collection's own actions, then the check.
  Future<void> _options(BuildContext context) {
    final v = view;
    final collection = v.place == Place.collection && v.id != null;
    final l = controller.library!;
    final self = collection
        ? l.collections.where((c) => c.id == v.id).firstOrNull
        : null;
    final pictured =
        collection &&
        l.bookmarks.any(
          (b) => b.collectionId == v.id && !b.isArchived && hasPicture(b),
        );
    void layouts(BuildContext context) => showLayoutPicker(
      context,
      data: LayoutData(
        controller: controller,
        rows: view.results,
        onOpen: (_) {},
        onDetails: (_) {},
        onToggle: (_) {},
      ),
      current: layout,
      cards: cards,
      choose: _chooseLayout,
    );
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (sheet) {
        Widget row(
          Key key,
          IconData icon,
          String title,
          void Function(BuildContext context)? onTap, {
          String? subtitle,
        }) => ListTile(
          key: key,
          leading: Icon(icon),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          enabled: onTap != null,
          onTap: onTap == null
              ? null
              : () {
                  Navigator.pop(sheet);
                  onTap(context);
                },
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: HandySpace.l),
          child: Column(
            key: const Key('list-options'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, HandySpace.s),
                child: Text(
                  placeTitle(sheet, l, v.place, v.id),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bookmarkSerif(sheet, 24),
                ),
              ),
              row(
                const Key('save-layout'),
                Icons.dashboard_customize_outlined,
                tr(sheet, 'Layouts', 'Bố cục'),
                layouts,
                subtitle: tr(
                  sheet,
                  'Magazine, timeline, moodboard… (Pro)',
                  'Tạp chí, dòng thời gian, moodboard… (Pro)',
                ),
              ),
              if (self != null) ...[
                const Divider(),
                row(
                  const Key('collection-edit'),
                  Icons.edit_outlined,
                  tr(sheet, 'Edit collection', 'Sửa bộ sưu tập'),
                  (context) => scope.editCollection(context, self),
                  subtitle: tr(
                    sheet,
                    'Name, icon, colour',
                    'Tên, biểu tượng, màu',
                  ),
                ),
                // Folders are one level: a folder has none of its own.
                if (self.parentId == null)
                  row(
                    const Key('collection-sub'),
                    Icons.create_new_folder_outlined,
                    tr(sheet, 'New folder', 'Thư mục mới'),
                    (context) => scope.newSubCollection(context, self.id),
                    subtitle: hasPro(sheet)
                        ? null
                        : tr(
                            sheet,
                            'Sort this collection into folders (Pro)',
                            'Chia bộ này thành các thư mục (Pro)',
                          ),
                  ),
                row(
                  const Key('collection-share'),
                  Icons.send_rounded,
                  tr(sheet, 'Send to friends', 'Gửi cho bạn bè'),
                  (context) => scope.shareCollection(context, self.id),
                ),
                row(
                  const Key('collection-export'),
                  Icons.auto_awesome_outlined,
                  tr(sheet, 'Design an export', 'Thiết kế bản xuất'),
                  (context) =>
                      Navigator.pushNamed(context, '/export/${self.id}'),
                  subtitle: hasPro(sheet)
                      ? null
                      : tr(
                          sheet,
                          'A designed PDF or web page (Pro)',
                          'PDF hoặc trang web có thiết kế (Pro)',
                        ),
                ),
                if (pictured)
                  row(
                    const Key('collection-cover'),
                    Icons.photo_outlined,
                    tr(sheet, 'Choose cover', 'Chọn ảnh bìa'),
                    (context) => chooseCover(context, scope, self.id),
                  ),
              ],
              const Divider(),
              row(
                const Key('check-here'),
                Icons.link_off,
                tr(
                  sheet,
                  'Check links in this list',
                  'Kiểm tra link trong danh sách này',
                ),
                v.total == 0 ? null : (context) => scope.checkHere(context),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Stores a layout (null: back to cards or rows) where this list keeps
  /// its view: on the collection, or for the app.
  Future<void> _chooseLayout(String? id, {bool? asCards}) async {
    final v = view;
    if (v.place == Place.collection && v.id != null) {
      await v.setCollectionView(v.id!, 'layout', id);
      if (asCards != null) await v.setCollectionView(v.id!, 'cards', asCards);
    } else {
      await controller.update(
        (l) => l,
        prefs: {
          ...controller.preferences,
          'layout': ?id,
          if (asCards != null) 'cards:${v.place.name}': asCards,
        }..removeWhere((k, val) => k == 'layout' && id == null),
      );
    }
  }

  /// What an empty list says: nothing matched, or nothing is here yet.
  Widget _empty(BuildContext context) {
    final v = view;
    if (v.text.trim().isNotEmpty || v.filters.narrows) {
      return HandyEmpty(
        title: tr(context, 'Nothing matches', 'Không có mục nào khớp'),
        action: TextButton(
          key: const Key('save-clear-filters'),
          // The order stays: it is the list's, not a filter.
          onPressed: () => v.filter(Filters(sort: v.filters.sort)),
          child: Text(tr(context, 'Clear filters', 'Xóa bộ lọc')),
        ),
      );
    }
    return HandyEmpty(
      title: switch (v.place) {
        Place.inbox => tr(
          context,
          'Nothing waiting to be sorted',
          'Không còn link nào chờ xếp',
        ),
        Place.favorites => tr(
          context,
          'No favourites yet',
          'Chưa có link yêu thích',
        ),
        Place.unread => tr(context, 'Everything is read', 'Đã đọc hết'),
        Place.archive => tr(
          context,
          'The archive is empty',
          'Lưu trữ đang trống',
        ),
        Place.broken => tr(
          context,
          'No broken links in the last checks',
          'Lần kiểm tra gần nhất không thấy link hỏng',
        ),
        _ => tr(
          context,
          'Save something worth returning to',
          'Lưu lại thứ đáng quay lại xem',
        ),
      },
      message: controller.library!.bookmarks.isEmpty
          ? tr(
              context,
              'Paste a link, or use Share in any app and pick Handy Bookmark.',
              'Dán một link, hoặc bấm Chia sẻ ở bất kỳ app nào rồi chọn Handy Bookmark.',
            )
          : null,
      action: controller.library!.bookmarks.isEmpty
          ? FilledButton(
              key: const Key('save-add-empty'),
              onPressed: onAdd,
              child: Text(tr(context, 'Add a link', 'Thêm link')),
            )
          : null,
    );
  }
}
