import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
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
  const ResultsView({
    super.key,
    required this.scope,
    required this.onDetails,
    required this.onAdd,
    this.current,
    this.leading = const [],
  });

  /// Cards or rows: the collection's own choice, else the app's.
  bool get cards {
    final v = view;
    final own = v.place == Place.collection && v.id != null
        ? v.collectionView(v.id!)['cards']
        : null;
    return own is bool ? own : controller.preferences['cards'] == true;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: view,
    builder: (context, _) {
      final v = view;
      final theme = Theme.of(context);
      final c = HandyColors.of(context);
      final rows = v.results;
      final wide = MediaQuery.sizeOf(context).width >= 600;
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
          Builder(
            builder: (context) {
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
                              : tr(
                                  context,
                                  '${formatFigure(context, '${v.total}')} saved',
                                  '${formatFigure(context, '${v.total}')} mục',
                                ),
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
              if (wide)
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
      } else if (cards) {
        body = LayoutBuilder(
          builder: (context, box) {
            // Two photo-forward cards a row on a phone; one when the screen
            // is narrow or the text is large; more as the window widens.
            final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
            const gap = 12.0;
            final columns = (box.maxWidth / (165 * scale.clamp(1.0, 2.0)))
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
                mainAxisExtent: width / 1.28 + 74 * scale.clamp(1.0, 2.2),
              ),
              itemCount: rows.length,
              itemBuilder: (context, i) => LinkCard(
                controller: controller,
                bookmark: rows[i],
                selected: v.selected.contains(rows[i].id),
                selecting: v.selecting,
                onOpen: () => controller.open(rows[i]),
                onDetails: () => onDetails(rows[i]),
                onToggle: () => v.toggle(rows[i].id),
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
                selecting: v.selecting,
                selected: v.selected.contains(b.id),
                current: b.id == current,
                onOpen: () => controller.open(b),
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
          padding: const EdgeInsets.fromLTRB(
            HandySpace.l,
            HandySpace.l,
            HandySpace.l,
            96,
          ),
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
          ],
        ),
      );
    },
  );

  /// The order, filters, rows or cards, and the list's other tools.
  List<Widget> _tools(BuildContext context) {
    final v = view;
    final collection = v.place == Place.collection && v.id != null;
    final pictured =
        collection &&
        controller.library!.bookmarks.any(
          (b) => b.collectionId == v.id && !b.isArchived && hasPicture(b),
        );
    return [
      SortButton(view: v),
      IconButton(
        key: const Key('save-filters'),
        tooltip: tr(context, 'Filter', 'Lọc'),
        isSelected: v.filters.narrows,
        icon: const Icon(Icons.tune),
        onPressed: () => showFilterSheet(context, controller.library!, v),
      ),
      IconButton(
        key: const Key('save-view'),
        tooltip: cards
            ? tr(context, 'Show as rows', 'Xem dạng dòng')
            : tr(context, 'Show as cards', 'Xem dạng thẻ'),
        icon: Icon(cards ? Icons.view_list_outlined : Icons.grid_view_outlined),
        onPressed: _flipCards,
      ),
      HandyMenuButton(
        key: const Key('list-more'),
        items: [
          if (collection)
            HandyMenuItem(
              Icons.ios_share,
              tr(context, 'Share as a page', 'Chia sẻ thành trang'),
              () => scope.shareCollection(context, v.id!),
              key: const Key('collection-share'),
            ),
          if (pictured)
            HandyMenuItem(
              Icons.photo_outlined,
              tr(context, 'Choose cover', 'Chọn ảnh bìa'),
              () => chooseCover(context, scope, v.id!),
              key: const Key('collection-cover'),
            ),
          HandyMenuItem(
            Icons.link_off,
            tr(
              context,
              'Check links in this list',
              'Kiểm tra link trong danh sách này',
            ),
            v.total == 0 ? null : () => scope.checkHere(context),
            key: const Key('check-here'),
          ),
        ],
      ),
    ];
  }

  void _flipCards() => view.place == Place.collection && view.id != null
      ? view.rememberForCollection('cards', !cards)
      : controller.update(
          (l) => l,
          prefs: {...controller.preferences, 'cards': !cards},
        );

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
