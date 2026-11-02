import 'package:flutter/semantics.dart';
import 'package:handy_bookmark_engine/handy_bookmark_engine.dart';
import 'package:handy_ui/kit.dart';
import '../controller.dart';
import '../links/link_actions.dart';
import '../links/task_strip.dart';
import '../scope.dart';
import '../ui/words.dart';
import '../view/library_view.dart';
import 'bookmark_tile.dart';
import 'filter_sheet.dart';
import 'link_card.dart';
import 'place_title.dart';

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

  bool get cards => controller.preferences['cards'] == true;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: view,
    builder: (context, _) {
      final v = view;
      final theme = Theme.of(context);
      final c = HandyColors.of(context);
      final rows = v.results;
      final wide = MediaQuery.sizeOf(context).width >= 600;
      final canArrange = v.manual && !cards && rows.length > 1;
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
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    placeTitle(context, controller.library!, v.place, v.id),
                    style: theme.textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Text(
                formatFigure(context, '${v.total}'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: c.muted,
                  fontFeatures: tabular,
                ),
              ),
              if (v.arranging)
                Padding(
                  padding: const EdgeInsets.only(left: HandySpace.s),
                  child: FilledButton(
                    key: const Key('arrange-done'),
                    onPressed: () => v.arrange(false),
                    child: Text(tr(context, 'Done', 'Xong')),
                  ),
                )
              else ...[
                if (canArrange)
                  IconButton(
                    key: const Key('arrange'),
                    tooltip: tr(context, 'Rearrange', 'Xếp lại'),
                    icon: const Icon(Icons.swap_vert),
                    onPressed: () => v.arrange(true),
                  ),
                if (wide && v.canSaveSearch && v.place != Place.smart)
                  IconButton(
                    key: const Key('save-search-here'),
                    tooltip: tr(
                      context,
                      'Save this search',
                      'Lưu tìm kiếm này',
                    ),
                    icon: const Icon(Icons.saved_search),
                    onPressed: () => scope.saveSearch(context),
                  ),
                ..._tools(context),
              ],
            ],
          ),
          if (v.filters.any) FilterChips(view: v),
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
      } else if (v.arranging) {
        body = _arrange(context);
      } else if (cards) {
        body = LayoutBuilder(
          builder: (context, box) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: (box.maxWidth / 260).floor().clamp(1, 6),
              mainAxisSpacing: HandySpace.m,
              crossAxisSpacing: HandySpace.m,
              mainAxisExtent: 204,
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
          ),
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
                key: ValueKey('${v.place}-${v.id}-$cards-${v.arranging}'),
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

  /// Filters, rows or cards, and the list's other tools.
  List<Widget> _tools(BuildContext context) {
    final v = view;
    final wide = MediaQuery.sizeOf(context).width >= 600;
    return [
      IconButton(
        key: const Key('save-filters'),
        tooltip: tr(context, 'Filter and sort', 'Lọc và sắp xếp'),
        isSelected: v.filters.any,
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
          if (!wide && v.canSaveSearch && v.place != Place.smart)
            HandyMenuItem(
              Icons.saved_search,
              tr(context, 'Save this search', 'Lưu tìm kiếm này'),
              () => scope.saveSearch(context),
              key: const Key('save-search-here'),
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

  void _flipCards() => controller.update(
    (l) => l,
    prefs: {...controller.preferences, 'cards': !cards},
  );

  /// Rows that move: up and down buttons for every input, and a handle to
  /// drag. Pinned links stay above the rest, so a step across is disabled.
  Widget _arrange(BuildContext context) {
    final v = view;
    final rows = v.results;
    final c = HandyColors.of(context);
    Future<void> move(int from, int to) async {
      try {
        await v.move(from, to);
      } catch (e) {
        if (context.mounted)
          showHandyMessage(
            context,
            tr(
              context,
              'Could not move it: ${errorText(context, e)}.',
              'Chưa dời được: ${errorText(context, e)}.',
            ),
          );
      }
    }

    bool step(int from, int to) =>
        to >= 0 && to < rows.length && rows[from].isPinned == rows[to].isPinned;
    return HandyGroup(
      children: [
        ReorderableListView.builder(
          key: const Key('arrange-list'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: rows.length,
          onReorderItem: (from, to) {
            if (from != to && rows[from].isPinned == rows[to].isPinned)
              move(from, to);
          },
          itemBuilder: (context, i) {
            final b = rows[i];
            final title = b.title.isEmpty ? b.sourceDomain : b.title;
            return Material(
              key: ValueKey('arrange-${b.id}'),
              color: Colors.transparent,
              child: Semantics(
                customSemanticsActions: {
                  if (step(i, i - 1))
                    CustomSemanticsAction(
                      label: tr(context, 'Move up', 'Lên'),
                    ): () =>
                        move(i, i - 1),
                  if (step(i, i + 1))
                    CustomSemanticsAction(
                      label: tr(context, 'Move down', 'Xuống'),
                    ): () =>
                        move(i, i + 1),
                },
                child: ListTile(
                  contentPadding: const EdgeInsets.only(
                    left: HandySpace.l,
                    right: HandySpace.xs,
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    sourceLine(b),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.muted),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        disabledColor: c.border,
                        key: Key('up-${b.id}'),
                        tooltip: tr(context, 'Move up', 'Lên'),
                        icon: const Icon(Icons.arrow_upward),
                        onPressed: step(i, i - 1) ? () => move(i, i - 1) : null,
                      ),
                      IconButton(
                        disabledColor: c.border,
                        key: Key('down-${b.id}'),
                        tooltip: tr(context, 'Move down', 'Xuống'),
                        icon: const Icon(Icons.arrow_downward),
                        onPressed: step(i, i + 1) ? () => move(i, i + 1) : null,
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: Tooltip(
                          message: tr(context, 'Drag to move', 'Kéo để dời'),
                          child: Padding(
                            padding: const EdgeInsets.all(HandySpace.m),
                            child: Icon(Icons.drag_indicator, color: c.muted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    final v = view;
    if (v.text.trim().isNotEmpty || v.filters.any) {
      return HandyEmpty(
        title: tr(context, 'Nothing matches', 'Không có link nào khớp'),
        action: TextButton(
          key: const Key('save-clear-filters'),
          onPressed: () => v.filter(const Filters()),
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
